import Foundation
import Combine

@MainActor
final class PharmacyViewModel: ObservableObject {
    enum Activity: Equatable { case idle, locating, findingPlaces, findingPharmacies }

    @Published var query = ""
    @Published private(set) var activity: Activity = .idle
    @Published private(set) var origin: SearchOrigin?
    @Published private(set) var results: [NearbyPharmacy] = []
    @Published private(set) var places: [SearchPlace] = []
    @Published private(set) var message: String?
    @Published private(set) var showSettings = false
    @Published private(set) var hasSearched = false

    private let searchService: any PharmacySearching
    private let locationService: any LocationProviding
    private var requestID = UUID()

    init(searchService: any PharmacySearching, locationService: any LocationProviding) {
        self.searchService = searchService
        self.locationService = locationService
    }

    var isBusy: Bool { activity != .idle }
    var activityLabel: String {
        switch activity {
        case .idle: return ""
        case .locating: return "Haetaan sijaintia…"
        case .findingPlaces: return "Etsitään osoitetta…"
        case .findingPharmacies: return "Etsitään lähimpiä apteekkeja…"
        }
    }

    func useCurrentLocation() async {
        let id = begin(.locating)
        do {
            let fix = try await locationService.currentLocation()
            guard id == requestID, !Task.isCancelled else { return }
            await search(near: SearchOrigin(title: "Oma sijainti", coordinate: fix.coordinate,
                                           isDeviceLocation: true, accuracy: fix.accuracy), id: id)
        } catch {
            guard id == requestID else { return }
            activity = .idle
            if error is CancellationError { return }
            message = (error as? LocationFailure)?.errorDescription ?? "Sijaintia ei saatu. Hae osoitteella."
            if let failure = error as? LocationFailure {
                switch failure {
                case .denied, .disabled: showSettings = true
                default: break
                }
            }
        }
    }

    func searchPlaces() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else {
            message = "Kirjoita vähintään kaksi merkkiä, esimerkiksi kaupunki tai katuosoite."
            return
        }
        let id = begin(.findingPlaces)
        places = []
        do {
            let candidates = try await searchService.findPlaces(query: text)
            guard id == requestID, !Task.isCancelled else { return }
            places = candidates
            activity = .idle
            if candidates.isEmpty { message = "Osoitetta ei löytynyt. Lisää esimerkiksi kaupunki tai postinumero." }
        } catch { handleSearchError(error, id: id) }
    }

    func select(_ place: SearchPlace) async {
        let id = begin(.findingPharmacies)
        places = []
        await search(near: SearchOrigin(title: place.title, coordinate: place.coordinate,
                                       isDeviceLocation: false, accuracy: nil), id: id)
    }

    func refresh() async {
        guard let origin else { return }
        let id = begin(.findingPharmacies)
        await search(near: origin, id: id)
    }

    private func begin(_ newActivity: Activity) -> UUID {
        requestID = UUID()
        activity = newActivity
        message = nil
        showSettings = false
        return requestID
    }

    private func search(near newOrigin: SearchOrigin, id: UUID) async {
        origin = newOrigin
        results = []
        hasSearched = false
        activity = .findingPharmacies
        do {
            let pharmacies = try await searchService.findPharmacies(near: newOrigin.coordinate)
            guard id == requestID, !Task.isCancelled else { return }
            results = PharmacyRanking.nearest(pharmacies, to: newOrigin.coordinate)
            hasSearched = true
            activity = .idle
        } catch { handleSearchError(error, id: id) }
    }

    private func handleSearchError(_ error: Error, id: UUID) {
        guard id == requestID else { return }
        activity = .idle
        if error is CancellationError { return }
        message = "Haku ei onnistunut. Tarkista internetyhteys ja kokeile uudelleen."
    }
}
