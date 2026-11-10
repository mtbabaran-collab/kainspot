//
//  VacantPlanner.swift
//  KainSpot
//
//  Answers "I have a vacant of N minutes - can I go there and still be back for class?"
//  Feature: Vacant Planner (pure logic, unit-tested).
//

import Foundation

/// The result of planning one trip during a vacant.
struct VacantPlan: Equatable {
    /// True when the whole round trip plus the stay fits inside the vacant.
    let fits: Bool
    /// Campus -> spot travel time.
    let travelMinutesOneWay: Int
    /// Time spent at the spot.
    let stayMinutes: Int
    /// 2 x travel + stay.
    let totalMinutes: Int
    /// Latest moment to leave the spot and still make it back to class.
    let leaveBy: Date
    /// Walk or ride.
    let mode: TravelMode

    /// Shared formatter: creating DateFormatters is expensive, and table cells call this often.
    /// en_US_POSIX keeps "AM/PM" stable regardless of the phone's region settings; with no explicit
    /// timeZone the formatter uses the phone's current time zone.
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    /// "Leave by 2:40 PM" in the phone's current time zone.
    var formattedLeaveBy: String {
        "Leave by \(VacantPlan.timeFormatter.string(from: leaveBy))"
    }

    /// Minutes left over after the round trip (negative when it does not fit).
    func spareMinutes(in vacantMinutes: Int) -> Int {
        vacantMinutes - totalMinutes
    }
}

/// Stateless planner built on `TravelEstimator`.
enum VacantPlanner {

    /// Plans a trip from campus to a spot `distanceKm` away.
    /// - total = 2 x one-way travel + stay
    /// - fits = total <= vacantMinutes
    /// - leaveBy = now + (vacantMinutes - one-way travel), i.e. leave the spot early enough to travel back.
    static func plan(distanceKm: Double, stayMinutes: Int, vacantMinutes: Int, now: Date = Date()) -> VacantPlan {
        let travel = TravelEstimator.estimate(distanceKm: distanceKm)
        let stay = max(0, stayMinutes)
        let total = 2 * travel.minutes + stay
        let leaveBy = now.addingTimeInterval(TimeInterval((vacantMinutes - travel.minutes) * 60))
        return VacantPlan(fits: total <= vacantMinutes,
                          travelMinutesOneWay: travel.minutes,
                          stayMinutes: stay,
                          totalMinutes: total,
                          leaveBy: leaveBy,
                          mode: travel.mode)
    }
}
