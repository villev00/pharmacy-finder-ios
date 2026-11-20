import Foundation
import MapKit

@MainActor
protocol PharmacySearching {
    func findPlaces(query: String) async throws -> [SearchPlace]
    func findPharmacies(near coordinate: Coordinate) async throws -> [Pharmacy]
}

@MainActor
final class MapKitPharmacySearchService: PharmacySearching {
    func findPlaces(query: String) async throws -> [SearchPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        let response = try await perform(request)
        return response.mapItems.prefix(8).map { item in
            let coordinate = Self.coordinate(item)
            return SearchPlace(id: Self.identifier(item), title: item.name ?? query,
                               subtitle: Self.address(item), coordinate: coordinate)
        }
    }

    func findPharmacies(near coordinate: Coordinate) async throws -> [Pharmacy] {
        // A region biases Apple's search; the distance filter enforces our actual search area.
        for radius in [5_000.0, 20_000.0, 50_000.0] {
            try Task.checkCancellation()
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "pharmacy"
            request.resultTypes = .pointOfInterest
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.pharmacy])
            request.region = MKCoordinateRegion(center: coordinate.mapCoordinate,
                                                latitudinalMeters: radius * 2,
                                                longitudinalMeters: radius * 2)
            let response = try await perform(request)
            let pharmacies = response.mapItems.filter { item in
                // Some regions omit POI metadata. The request still filters to pharmacies.
                item.pointOfInterestCategory == nil || item.pointOfInterestCategory == .pharmacy
            }.map { item in
                Pharmacy(id: Self.identifier(item), name: item.name ?? "Apteekki",
                         address: Self.address(item), coordinate: Self.coordinate(item),
                         phone: item.phoneNumber, website: item.url)
            }
            let nearby = PharmacyRanking.nearest(pharmacies, to: coordinate, within: radius)
            if !nearby.isEmpty { return nearby.map(\.pharmacy) }
        }
        return []
    }

    private func perform(_ request: MKLocalSearch.Request) async throws -> MKLocalSearch.Response {
        let search = MKLocalSearch(request: request)
        return try await withTaskCancellationHandler {
            let response = try await search.start()
            try Task.checkCancellation()
            return response
        } onCancel: {
            Task { @MainActor in search.cancel() }
        }
    }

    private static func coordinate(_ item: MKMapItem) -> Coordinate {
        Coordinate(latitude: item.placemark.coordinate.latitude,
                   longitude: item.placemark.coordinate.longitude)
    }

    private static func identifier(_ item: MKMapItem) -> String {
        "\(item.name ?? "")|\(item.placemark.coordinate.latitude)|\(item.placemark.coordinate.longitude)"
    }

    private static func address(_ item: MKMapItem) -> String {
        let placemark = item.placemark
        let street = [placemark.thoroughfare, placemark.subThoroughfare].compactMap { $0 }.joined(separator: " ")
        return [street.isEmpty ? nil : street, placemark.locality, placemark.country]
            .compactMap { $0 }.joined(separator: ", ")
    }
}
