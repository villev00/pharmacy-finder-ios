import CoreLocation
import Foundation

enum LocationFailure: LocalizedError {
    case denied, disabled, unavailable, timeout, alreadyRequesting

    var errorDescription: String? {
        switch self {
        case .denied: return "Sijaintilupaa ei ole. Voit hakea osoitteella tai sallia sijainnin Asetuksissa."
        case .disabled: return "Laitteen sijaintipalvelut ovat pois käytöstä. Hae osoitteella tai tarkista Asetukset."
        case .unavailable: return "Sijaintia ei saatu. Kokeile uudelleen tai hae osoitteella."
        case .timeout: return "Sijainnin haku kesti liian kauan. Kokeile uudelleen tai hae osoitteella."
        case .alreadyRequesting: return "Sijaintia haetaan jo."
        }
    }
}

@MainActor
protocol LocationProviding {
    func currentLocation() async throws -> LocationFix
}

@MainActor
final class DeviceLocationService: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<LocationFix, Error>?
    private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentLocation() async throws -> LocationFix {
        guard continuation == nil else { throw LocationFailure.alreadyRequesting }
        guard CLLocationManager.locationServicesEnabled() else { throw LocationFailure.disabled }
        try Task.checkCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                switch manager.authorizationStatus {
                case .notDetermined: manager.requestWhenInUseAuthorization()
                case .authorizedAlways, .authorizedWhenInUse: requestFix()
                case .denied, .restricted: finish(.failure(LocationFailure.denied))
                @unknown default: finish(.failure(LocationFailure.unavailable))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish(.failure(CancellationError())) }
        }
    }

    private func requestFix() {
        guard continuation != nil else { return }
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(20)) }
            catch { return }
            self?.finish(.failure(LocationFailure.timeout))
        }
        manager.requestLocation()
    }

    private func finish(_ result: Result<LocationFix, Error>) {
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()
        let waiting = continuation
        continuation = nil
        waiting?.resume(with: result)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self, self.continuation != nil else { return }
            switch status {
            case .authorizedAlways, .authorizedWhenInUse: self.requestFix()
            case .denied, .restricted: self.finish(.failure(LocationFailure.denied))
            case .notDetermined: break
            @unknown default: self.finish(.failure(LocationFailure.unavailable))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last(where: {
            $0.horizontalAccuracy >= 0 && abs($0.timestamp.timeIntervalSinceNow) < 60
        }) else { return }
        let fix = LocationFix(coordinate: Coordinate(latitude: location.coordinate.latitude,
                                                    longitude: location.coordinate.longitude),
                              accuracy: location.horizontalAccuracy)
        Task { @MainActor [weak self] in self?.finish(.success(fix)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // A transient locationUnknown can recover before the explicit timeout.
        if (error as? CLError)?.code == .locationUnknown { return }
        let failure: LocationFailure = (error as? CLError)?.code == .denied ? .denied : .unavailable
        Task { @MainActor [weak self] in self?.finish(.failure(failure)) }
    }
}
