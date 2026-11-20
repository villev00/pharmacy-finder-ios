import XCTest
@testable import NearbyPharmacy

final class PharmacyRankingTests: XCTestCase {
    private let helsinki = Coordinate(latitude: 60.1699, longitude: 24.9384)

    func testDistanceIsZeroForSameCoordinate() {
        XCTAssertEqual(helsinki.distance(to: helsinki), 0, accuracy: 0.001)
    }

    func testHelsinkiToTampereDistanceIsPlausibleAndSymmetric() {
        let tampere = Coordinate(latitude: 61.4978, longitude: 23.7610)
        let distance = helsinki.distance(to: tampere)
        XCTAssertEqual(distance, 160_500, accuracy: 2_000)
        XCTAssertEqual(distance, tampere.distance(to: helsinki), accuracy: 0.001)
    }

    func testResultsAreSortedByActualDistance() {
        let far = pharmacy("Far", latitude: 60.1900)
        let close = pharmacy("Close", latitude: 60.1701)
        let middle = pharmacy("Middle", latitude: 60.1800)
        let result = PharmacyRanking.nearest([far, close, middle], to: helsinki)
        XCTAssertEqual(result.map(\.pharmacy.name), ["Close", "Middle", "Far"])
        XCTAssertLessThan(result[0].distance, result[1].distance)
    }

    func testOutOfRadiusResultsAreExcluded() {
        let distant = pharmacy("Outside", latitude: 61.5)
        XCTAssertTrue(PharmacyRanking.nearest([distant], to: helsinki, within: 5_000).isEmpty)
    }

    func testDuplicateProviderEntriesDoNotAppearTwice() {
        let original = pharmacy("Apteekki", latitude: 60.17)
        let duplicate = Pharmacy(id: "other-provider-id", name: "APTEEKKI", address: "Different formatting",
                                 coordinate: original.coordinate, phone: nil, website: nil)
        XCTAssertEqual(PharmacyRanking.nearest([original, duplicate], to: helsinki).count, 1)
    }

    func testInvalidCoordinateDistanceDoesNotEnterResults() {
        let invalid = pharmacy("Invalid", latitude: .nan)
        XCTAssertTrue(PharmacyRanking.nearest([invalid], to: helsinki).isEmpty)
    }

    func testWalkingDirectionsTargetPharmacyCoordinates() throws {
        let item = pharmacy("Apteekki", latitude: 60.17)
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(item.mapsURL), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.host, "maps.apple.com")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "dirflg" })?.value, "w")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "daddr" })?.value, "60.17,24.9384")
    }

    private func pharmacy(_ name: String, latitude: Double) -> Pharmacy {
        Pharmacy(id: name, name: name, address: "Test address",
                 coordinate: Coordinate(latitude: latitude, longitude: 24.9384), phone: nil, website: nil)
    }
}
