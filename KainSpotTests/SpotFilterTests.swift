//
//  SpotFilterTests.swift
//  KainSpotTests
//
//  Unit tests for the Core Data predicate and in-memory distance check built by SpotFilter.
//  Course week: Week 2 (value passed between screens) verified with XCTest.
//

import XCTest
@testable import KainSpot

final class SpotFilterTests: XCTestCase {

    /// A price limit must appear in the fetch predicate.
    func testPredicateIncludesPriceWhenLimited() {
        let filter = SpotFilter(nickname: "Sis", maxPrice: 2, trendingOnly: false, maxDistanceKm: 5)
        XCTAssertTrue(filter.predicate().predicateFormat.contains("priceLevel"))
    }

    /// "Any" price (0) must not filter by price at all.
    func testPredicateOmitsPriceWhenAny() {
        let filter = SpotFilter(nickname: "Sis", maxPrice: 0, trendingOnly: false, maxDistanceKm: 5)
        XCTAssertFalse(filter.predicate().predicateFormat.contains("priceLevel"))
    }

    /// Trending only adds the isTrending condition.
    func testPredicateIncludesTrending() {
        let filter = SpotFilter(nickname: "Sis", maxPrice: 0, trendingOnly: true, maxDistanceKm: 5)
        XCTAssertTrue(filter.predicate().predicateFormat.contains("isTrending"))
    }

    /// Evaluating against plain dictionaries proves the logic: cheaper-or-equal and trending pass.
    func testPredicateEvaluatesPriceAndTrending() {
        let filter = SpotFilter(nickname: "Sis", maxPrice: 2, trendingOnly: true, maxDistanceKm: 5)
        let predicate = filter.predicate()

        let cheapTrending: [String: Any] = ["priceLevel": 1, "isTrending": true]
        let midTrending: [String: Any] = ["priceLevel": 2, "isTrending": true]
        let pricey: [String: Any] = ["priceLevel": 3, "isTrending": true]
        let notTrending: [String: Any] = ["priceLevel": 1, "isTrending": false]

        XCTAssertTrue(predicate.evaluate(with: cheapTrending))
        XCTAssertTrue(predicate.evaluate(with: midTrending))
        XCTAssertFalse(predicate.evaluate(with: pricey))
        XCTAssertFalse(predicate.evaluate(with: notTrending))
    }

    /// Distance is inclusive: on the edge counts, beyond does not.
    func testMatchesDistance() {
        let filter = SpotFilter(nickname: "Sis", maxPrice: 0, trendingOnly: false, maxDistanceKm: 5)
        XCTAssertTrue(filter.matches(distanceKm: 3.2))
        XCTAssertTrue(filter.matches(distanceKm: 5))
        XCTAssertFalse(filter.matches(distanceKm: 5.1))
    }

    /// The default filter shows everything within 5 km.
    func testDefaultFilter() {
        let filter = SpotFilter.default
        XCTAssertEqual(filter.maxPrice, 0)
        XCTAssertFalse(filter.trendingOnly)
        XCTAssertEqual(filter.maxDistanceKm, 5, accuracy: 0.0001)
    }
}
