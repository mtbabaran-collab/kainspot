//
//  TravelEstimatorTests.swift
//  KainSpotTests
//
//  Unit tests for the walk/ride rule and the rounded-up minutes.
//  Feature: Vacant Planner (travel time) verified with XCTest.
//

import XCTest
@testable import KainSpot

final class TravelEstimatorTests: XCTestCase {

    /// Right next door still counts as at least 1 minute.
    func testZeroDistanceIsOneMinuteWalk() {
        let result = TravelEstimator.estimate(distanceKm: 0)
        XCTAssertEqual(result.mode, .walk)
        XCTAssertEqual(result.minutes, 1)
    }

    /// 1.2 km at 4.8 km/h is exactly 15 minutes (floating-point noise must not round it to 16).
    func testExactWalkMinutesAreNotOverRounded() {
        let result = TravelEstimator.estimate(distanceKm: 1.2)
        XCTAssertEqual(result.mode, .walk)
        XCTAssertEqual(result.minutes, 15)
    }

    /// 1.5 km is still walking (inclusive limit): 18.75 min rounds up to 19.
    func testWalkLimitIsInclusiveAndRoundsUp() {
        let result = TravelEstimator.estimate(distanceKm: 1.5)
        XCTAssertEqual(result.mode, .walk)
        XCTAssertEqual(result.minutes, 19)
    }

    /// Just past 1.5 km switches to a ride: 1.6 km / 18 km/h = 5.33 -> 6 min + 8 min waiting.
    func testJustOverLimitRides() {
        let result = TravelEstimator.estimate(distanceKm: 1.6)
        XCTAssertEqual(result.mode, .ride)
        XCTAssertEqual(result.minutes, 14)
    }

    /// 3.6 km / 18 km/h = 12 min + 8 min waiting = 20 min.
    func testRideAddsWaitingTime() {
        let result = TravelEstimator.estimate(distanceKm: 3.6)
        XCTAssertEqual(result.mode, .ride)
        XCTAssertEqual(result.minutes, 20)
    }

    /// Bad input never produces negative or zero minutes.
    func testNegativeDistanceIsTreatedAsZero() {
        let result = TravelEstimator.estimate(distanceKm: -3)
        XCTAssertEqual(result.mode, .walk)
        XCTAssertEqual(result.minutes, 1)
    }
}
