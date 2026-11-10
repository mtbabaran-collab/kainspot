//
//  TravelEstimator.swift
//  KainSpot
//
//  Pure estimate of how long it takes to get from campus to a spot (walk or jeep/ride).
//  Feature: Vacant Planner (travel time is the first half of "will I be back for class?").
//

import Foundation

/// How the student gets there.
enum TravelMode: String {
    case walk
    case ride

    /// Friendly label for cells and the detail screen.
    var label: String {
        switch self {
        case .walk: return "walk"
        case .ride: return "ride"
        }
    }

    /// Emoji shown beside the minutes ("🚶 12 min", "🛺 21 min").
    var emoji: String {
        switch self {
        case .walk: return "🚶"
        case .ride: return "🛺"
        }
    }
}

/// Stateless, unit-tested travel time rules.
enum TravelEstimator {

    /// Up to this distance we assume students simply walk.
    static let walkLimitKm = 1.5
    /// Average walking speed in km/h.
    static let walkSpeedKmh = 4.8
    /// Average jeepney / tricycle / ride-hailing speed in QC traffic, in km/h.
    static let rideSpeedKmh = 18.0
    /// Minutes lost waiting for a jeep or a booked ride.
    static let rideWaitMinutes = 8

    /// One-way trip estimate. Walk at 4.8 km/h when the spot is within 1.5 km, otherwise ride at
    /// 18 km/h plus 8 minutes of waiting. Minutes are rounded UP (being late for class is worse than
    /// being early) and never less than 1.
    static func estimate(distanceKm: Double) -> (mode: TravelMode, minutes: Int) {
        // Negative or NaN distances should never happen, but treat them as "right here".
        let km = distanceKm.isFinite ? max(0, distanceKm) : 0

        if km <= walkLimitKm {
            return (.walk, roundedUpMinutes(hours: km / walkSpeedKmh))
        }
        let rideMinutes = roundedUpMinutes(hours: km / rideSpeedKmh) + rideWaitMinutes
        return (.ride, max(1, rideMinutes))
    }

    /// Converts hours to whole minutes, rounding up. A tiny tolerance stops values like 15.000000000002
    /// (floating-point noise) from becoming 16.
    private static func roundedUpMinutes(hours: Double) -> Int {
        let minutes = (hours * 60 - 1e-9).rounded(.up)
        return max(1, Int(minutes))
    }
}
