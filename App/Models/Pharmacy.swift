import Foundation
import CoreLocation
import MapKit

struct Coordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double

    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(to other: Coordinate) -> Double {
        let radians = Double.pi / 180
        let deltaLatitude = (other.latitude - latitude) * radians
        let deltaLongitude = (other.longitude - longitude) * radians
        let a = pow(sin(deltaLatitude / 2), 2)
            + cos(latitude * radians) * cos(other.latitude * radians)
            * pow(sin(deltaLongitude / 2), 2)
        return 6_371_000 * 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
    }
}

struct Pharmacy: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let address: String
    let coordinate: Coordinate
    let phone: String?
    let website: URL?

    var mapsURL: URL? {
        var url = URLComponents(string: "https://maps.apple.com/")!
        url.queryItems = [
            URLQueryItem(name: "daddr", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "dirflg", value: "w")
        ]
        return url.url
    }
}

struct NearbyPharmacy: Identifiable, Equatable {
    let pharmacy: Pharmacy
    let distance: Double
    var id: String { pharmacy.id }

    var distanceLabel: String {
        if distance < 1_000 {
            return "\(max(10, Int((distance / 10).rounded()) * 10)) m"
        }
        return String(format: "%.1f km", locale: Locale(identifier: "fi_FI"), distance / 1_000)
    }
}

struct SearchPlace: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let coordinate: Coordinate
}

struct SearchOrigin: Equatable {
    let title: String
    let coordinate: Coordinate
    let isDeviceLocation: Bool
    let accuracy: Double?
}

struct LocationFix: Sendable {
    let coordinate: Coordinate
    let accuracy: Double
}

enum PharmacyRanking {
    static func nearest(_ pharmacies: [Pharmacy], to origin: Coordinate,
                        within radius: Double = 50_000) -> [NearbyPharmacy] {
        var seen = Set<String>()
        return pharmacies.compactMap { pharmacy -> NearbyPharmacy? in
            let distance = origin.distance(to: pharmacy.coordinate)
            let duplicateKey = "\(pharmacy.name.lowercased())|\(String(format: "%.4f", pharmacy.coordinate.latitude))|\(String(format: "%.4f", pharmacy.coordinate.longitude))"
            guard distance.isFinite, distance <= radius,
                  seen.insert(duplicateKey).inserted else { return nil }
            return NearbyPharmacy(pharmacy: pharmacy, distance: distance)
        }.sorted {
            if $0.distance == $1.distance { return $0.pharmacy.name < $1.pharmacy.name }
            return $0.distance < $1.distance
        }
    }
}
