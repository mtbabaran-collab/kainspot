//
//  DistanceCalculator.swift
//  KainSpot
//
//  Pure distance math (haversine) and friendly formatting; no UIKit, fully unit-tested.
//  Course week: Week 6 (maps and location — distances from FEU Diliman).
//

import CoreLocation
import Foundation

/// Lets callers write either `Coordinate(...)` or `DistanceCalculator.Coordinate(...)`.
typealias Coordinate = DistanceCalculator.Coordinate

/// Stateless helpers, so they are easy to test and safe to call from anywhere.
enum DistanceCalculator {

    /// Plain latitude/longitude pair (degrees) that keeps the math independent of MapKit.
    struct Coordinate: Equatable {
        let latitude: Double
        let longitude: Double

        init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }

        /// Bridge from Core Location (user position, map annotations).
        init(_ location: CLLocationCoordinate2D) {
            self.latitude = location.latitude
            self.longitude = location.longitude
        }

        /// Bridge back for MKPointAnnotation / MKCoordinateRegion.
        var clCoordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    /// Fixed campus point: FEU Diliman, Sampaguita Ave, Mapayapa Village, Quezon City.
    static let feuDiliman = Coordinate(latitude: 14.68444, longitude: 121.06333)

    /// Mean Earth radius in kilometers used by the haversine formula.
    static let earthRadiusKm = 6371.0

    /// Great-circle distance in km. Haversine stays accurate for the short city distances we need
    /// and avoids depending on CLLocation so it can be tested as pure math.
    static func kilometers(from: Coordinate, to: Coordinate) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLat = (to.latitude - from.latitude) * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180

        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        // min(1, a) guards against tiny floating-point overshoot before sqrt/asin.
        let c = 2 * asin(sqrt(min(1, a)))
        return earthRadiusKm * c
    }

    /// Student-friendly text: under 1 km shows whole meters ("850 m"), otherwise one decimal ("2.4 km").
    static func formatted(_ km: Double) -> String {
        if km < 1 {
            return "\(Int((km * 1000).rounded())) m"
        }
        return String(format: "%.1f km", km)
    }
}
