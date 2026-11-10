//
//  DistanceCalculatorTests.swift
//  KainSpotTests
//
//  Unit tests for the haversine distance and the "850 m" / "2.4 km" formatting.
//  Course week: Week 6 (location math) verified with XCTest.
//

import XCTest
@testable import KainSpot

final class DistanceCalculatorTests: XCTestCase {

    /// A point is zero km from itself — sanity check for the formula.
    func testSamePointIsZero() {
        let feu = DistanceCalculator.feuDiliman
        XCTAssertEqual(DistanceCalculator.kilometers(from: feu, to: feu), 0, accuracy: 0.0001)
    }

    /// FEU Diliman to UP Town Center on Katipunan is roughly 4 km as the crow flies.
    func testFEUToUPTownCenterIsAboutFourKm() {
        let upTownCenter = DistanceCalculator.Coordinate(latitude: 14.6508, longitude: 121.0754)
        let km = DistanceCalculator.kilometers(from: DistanceCalculator.feuDiliman, to: upTownCenter)
        XCTAssertEqual(km, 4.0, accuracy: 0.6)
    }

    /// Distance must not depend on direction.
    func testDistanceIsSymmetric() {
        let a = DistanceCalculator.Coordinate(latitude: 14.6566, longitude: 121.0690)
        let b = DistanceCalculator.feuDiliman
        XCTAssertEqual(DistanceCalculator.kilometers(from: a, to: b),
                       DistanceCalculator.kilometers(from: b, to: a),
                       accuracy: 0.000001)
    }

    /// Under 1 km shows whole meters.
    func testFormatsMetersBelowOneKm() {
        XCTAssertEqual(DistanceCalculator.formatted(0.85), "850 m")
    }

    /// 1 km and up shows one decimal place.
    func testFormatsKilometersWithOneDecimal() {
        XCTAssertEqual(DistanceCalculator.formatted(2.4), "2.4 km")
        XCTAssertEqual(DistanceCalculator.formatted(2.44), "2.4 km")
        XCTAssertEqual(DistanceCalculator.formatted(1.0), "1.0 km")
    }
}
