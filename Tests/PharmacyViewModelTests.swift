import XCTest
@testable import NearbyPharmacy

@MainActor
final class PharmacyViewModelTests: XCTestCase {
    func testAddressSearchWorksWithoutRequestingDeviceLocation() async {
        let search = StubSearchService()
        let location = StubLocationService()
        let model = PharmacyViewModel(searchService: search, locationService: location)
        model.query = "  Helsinki  "
        await model.searchPlaces()
        XCTAssertEqual(search.receivedQuery, "Helsinki")
        XCTAssertEqual(model.places.count, 1)
        XCTAssertEqual(location.requestCount, 0)
        await model.select(search.place)
        XCTAssertEqual(model.results.map(\.pharmacy.name), ["Near", "Far"])
        XCTAssertEqual(location.requestCount, 0)
        XCTAssertFalse(model.isBusy)
        XCTAssertTrue(model.hasSearched)
        XCTAssertFalse(model.origin?.isDeviceLocation ?? true)
    }

    func testDeniedLocationStillAllowsManualSearch() async {
        let search = StubSearchService()
        let location = StubLocationService()
        location.shouldDeny = true
        let model = PharmacyViewModel(searchService: search, locationService: location)
        await model.useCurrentLocation()
        XCTAssertTrue(model.showSettings)
        XCTAssertNotNil(model.message)
        XCTAssertFalse(model.isBusy)
        model.query = "Helsinki"
        await model.searchPlaces()
        await model.select(search.place)
        XCTAssertNil(model.message)
        XCTAssertFalse(model.showSettings)
        XCTAssertEqual(model.results.count, 2)
    }

    func testEmptyInputDoesNotCallProvider() async {
        let search = StubSearchService()
        let model = PharmacyViewModel(searchService: search, locationService: StubLocationService())
        model.query = "  "
        await model.searchPlaces()
        XCTAssertNil(search.receivedQuery)
        XCTAssertNotNil(model.message)
        XCTAssertFalse(model.isBusy)
    }

    func testNoResultsIsACompletedSearch() async {
        let search = StubSearchService()
        search.pharmacies = []
        let model = PharmacyViewModel(searchService: search, locationService: StubLocationService())
        await model.select(search.place)
        XCTAssertTrue(model.hasSearched)
        XCTAssertTrue(model.results.isEmpty)
        XCTAssertNil(model.message)
        XCTAssertFalse(model.isBusy)
    }

    func testNetworkFailureIsRecoverable() async {
        let search = StubSearchService()
        search.shouldFail = true
        let model = PharmacyViewModel(searchService: search, locationService: StubLocationService())
        await model.select(search.place)
        XCTAssertNotNil(model.message)
        XCTAssertFalse(model.isBusy)
        XCTAssertFalse(model.hasSearched)
        search.shouldFail = false
        await model.refresh()
        XCTAssertNil(model.message)
        XCTAssertEqual(model.results.count, 2)
    }

    func testDeviceLocationBecomesSearchOrigin() async {
        let search = StubSearchService()
        let location = StubLocationService()
        let model = PharmacyViewModel(searchService: search, locationService: location)
        await model.useCurrentLocation()
        XCTAssertEqual(location.requestCount, 1)
        XCTAssertTrue(model.origin?.isDeviceLocation ?? false)
        XCTAssertEqual(model.origin?.accuracy, 100)
        XCTAssertEqual(model.results.count, 2)
    }
}

@MainActor
private final class StubSearchService: PharmacySearching {
    let place = SearchPlace(id: "helsinki", title: "Helsinki", subtitle: "Suomi",
                            coordinate: Coordinate(latitude: 60.1699, longitude: 24.9384))
    var receivedQuery: String?
    var shouldFail = false
    var pharmacies = [
        Pharmacy(id: "far", name: "Far", address: "Test", coordinate: Coordinate(latitude: 60.18, longitude: 24.9384), phone: nil, website: nil),
        Pharmacy(id: "near", name: "Near", address: "Test", coordinate: Coordinate(latitude: 60.17, longitude: 24.9384), phone: nil, website: nil)
    ]

    func findPlaces(query: String) async throws -> [SearchPlace] {
        receivedQuery = query
        if shouldFail { throw URLError(.notConnectedToInternet) }
        return [place]
    }

    func findPharmacies(near coordinate: Coordinate) async throws -> [Pharmacy] {
        if shouldFail { throw URLError(.notConnectedToInternet) }
        return pharmacies
    }
}

@MainActor
private final class StubLocationService: LocationProviding {
    var requestCount = 0
    var shouldDeny = false
    func currentLocation() async throws -> LocationFix {
        requestCount += 1
        if shouldDeny { throw LocationFailure.denied }
        return LocationFix(coordinate: Coordinate(latitude: 60.1699, longitude: 24.9384), accuracy: 100)
    }
}
