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
        XCTAssertNil(filter.kind)
        XCTAssertEqual(filter.maxSpend, 0)
        XCTAssertEqual(filter.vacantMinutes, 60)
        XCTAssertFalse(filter.needsWifi)
        XCTAssertFalse(filter.studentDiscount)
    }

    /// Kind, peso budget, WiFi and student discount become Core Data conditions.
    func testPredicateIncludesVacantPlannerFields() {
        var filter = SpotFilter.default
        filter.kind = "tambay"
        filter.maxSpend = 250
        filter.needsWifi = true
        filter.studentDiscount = true
        let format = filter.predicate().predicateFormat
        XCTAssertTrue(format.contains("kind"))
        XCTAssertTrue(format.contains("avgSpend"))
        XCTAssertTrue(format.contains("hasWifi"))
        XCTAssertTrue(format.contains("studentDiscount"))
    }

    /// Evaluating the new conditions against dictionaries: right kind, within budget, with WiFi passes.
    func testPredicateEvaluatesKindBudgetAndWifi() {
        var filter = SpotFilter.default
        filter.kind = "tambay"
        filter.maxSpend = 250
        filter.needsWifi = true
        let predicate = filter.predicate()

        let goodCafe: [String: Any] = ["kind": "tambay", "avgSpend": 220, "hasWifi": true]
        let pricey: [String: Any] = ["kind": "tambay", "avgSpend": 400, "hasWifi": true]
        let noWifi: [String: Any] = ["kind": "tambay", "avgSpend": 100, "hasWifi": false]
        let food: [String: Any] = ["kind": "kain", "avgSpend": 100, "hasWifi": true]

        XCTAssertTrue(predicate.evaluate(with: goodCafe))
        XCTAssertFalse(predicate.evaluate(with: pricey))
        XCTAssertFalse(predicate.evaluate(with: noWifi))
        XCTAssertFalse(predicate.evaluate(with: food))
    }

    /// The vacant check uses the planner: 1 km walk (13 min each way) + 30 min stay fits in 60, not in 50.
    func testFitsVacant() {
        var filter = SpotFilter.default
        filter.vacantMinutes = 60
        XCTAssertTrue(filter.fitsVacant(distanceKm: 1.0, stayMinutes: 30))
        filter.vacantMinutes = 50
        XCTAssertFalse(filter.fitsVacant(distanceKm: 1.0, stayMinutes: 30))
    }
}
