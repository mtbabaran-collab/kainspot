//
//  VacantPlannerTests.swift
//  KainSpotTests
//
//  Unit tests for "can I go there and be back for class?" and the "Leave by" time.
//  Feature: Vacant Planner verified with XCTest.
//

import XCTest
@testable import KainSpot

final class VacantPlannerTests: XCTestCase {

    /// 2:00 PM today in the phone's calendar, so the formatter (same time zone) prints predictable times.
    private func twoPM() throws -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 14
        components.minute = 0
        components.second = 0
        return try XCTUnwrap(Calendar.current.date(from: components))
    }

    /// 3.6 km ride (20 min each way) + 15 min stay = 55 min: fits a 60-min vacant; leave by 2:40 PM.
    func testFitsAndLeaveByTime() throws {
        let now = try twoPM()
        let plan = VacantPlanner.plan(distanceKm: 3.6, stayMinutes: 15, vacantMinutes: 60, now: now)

        XCTAssertTrue(plan.fits)
        XCTAssertEqual(plan.mode, .ride)
        XCTAssertEqual(plan.travelMinutesOneWay, 20)
        XCTAssertEqual(plan.stayMinutes, 15)
        XCTAssertEqual(plan.totalMinutes, 55)
        XCTAssertEqual(plan.leaveBy.timeIntervalSince(now), 40 * 60, accuracy: 0.5)
        XCTAssertEqual(plan.formattedLeaveBy, "Leave by 2:40 PM")
        XCTAssertEqual(plan.spareMinutes(in: 60), 5)
    }

    /// Same trip with a 45-min stay needs 85 min, so it does not fit a 60-min vacant.
    func testDoesNotFitWhenTooLong() throws {
        let plan = VacantPlanner.plan(distanceKm: 3.6, stayMinutes: 45, vacantMinutes: 60, now: try twoPM())
        XCTAssertFalse(plan.fits)
        XCTAssertEqual(plan.totalMinutes, 85)
        XCTAssertEqual(plan.spareMinutes(in: 60), -25)
    }

    /// Exactly using the whole vacant still counts as fitting (inclusive).
    func testExactFitIsInclusive() throws {
        // 1.2 km walk = 15 min each way; 15 + 15 + 30 = 60.
        let plan = VacantPlanner.plan(distanceKm: 1.2, stayMinutes: 30, vacantMinutes: 60, now: try twoPM())
        XCTAssertEqual(plan.mode, .walk)
        XCTAssertEqual(plan.totalMinutes, 60)
        XCTAssertTrue(plan.fits)
        XCTAssertEqual(plan.formattedLeaveBy, "Leave by 2:45 PM")
    }

    /// A 2-hour vacant: leave-by is now + (120 - travel).
    func testLongVacantLeaveBy() throws {
        let now = try twoPM()
        let plan = VacantPlanner.plan(distanceKm: 0.48, stayMinutes: 60, vacantMinutes: 120, now: now)
        XCTAssertEqual(plan.travelMinutesOneWay, 6)
        XCTAssertTrue(plan.fits)
        XCTAssertEqual(plan.formattedLeaveBy, "Leave by 3:54 PM")
    }
}
