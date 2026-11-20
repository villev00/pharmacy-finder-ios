import SwiftUI

@main
struct NearbyPharmacyApp: App {
    @StateObject private var model: PharmacyViewModel

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing") {
            _model = StateObject(wrappedValue: PharmacyViewModel(
                searchService: PreviewSearchService(),
                locationService: PreviewLocationService(denied: arguments.contains("-location-denied"))))
        } else {
            _model = StateObject(wrappedValue: PharmacyViewModel(
                searchService: MapKitPharmacySearchService(), locationService: DeviceLocationService()))
        }
    }

    var body: some Scene {
        WindowGroup { PharmacyHomeView(model: model) }
    }
}

@MainActor
final class PreviewSearchService: PharmacySearching {
    func findPlaces(query: String) async throws -> [SearchPlace] {
        [SearchPlace(id: "helsinki", title: "Helsinki", subtitle: "Suomi",
                     coordinate: Coordinate(latitude: 60.1699, longitude: 24.9384))]
    }

    func findPharmacies(near coordinate: Coordinate) async throws -> [Pharmacy] {
        [Pharmacy(id: "demo-near", name: "Keskustan Apteekki", address: "Esimerkkikatu 1, Helsinki",
                  coordinate: Coordinate(latitude: 60.1704, longitude: 24.9400), phone: nil, website: nil),
         Pharmacy(id: "demo-far", name: "Puiston Apteekki", address: "Esimerkkikatu 8, Helsinki",
                  coordinate: Coordinate(latitude: 60.1760, longitude: 24.9480), phone: nil, website: nil)]
    }
}

@MainActor
final class PreviewLocationService: LocationProviding {
    let denied: Bool
    init(denied: Bool = false) { self.denied = denied }
    func currentLocation() async throws -> LocationFix {
        if denied { throw LocationFailure.denied }
        return LocationFix(coordinate: Coordinate(latitude: 60.1699, longitude: 24.9384), accuracy: 100)
    }
}
