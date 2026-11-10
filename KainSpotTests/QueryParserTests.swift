//
//  QueryParserTests.swift
//  KainSpotTests
//
//  Unit tests for turning English, Filipino and Taglish search phrases into filters.
//  Feature: Smart search verified with XCTest.
//

import XCTest
@testable import KainSpot

final class QueryParserTests: XCTestCase {

    func testCheapCoffeeWithWifi() {
        let query = QueryParser.parse("cheap coffee with wifi")
        XCTAssertEqual(query.kind, "tambay")
        XCTAssertEqual(query.maxSpend, 150)
        XCTAssertTrue(query.needsWifi)
        XCTAssertEqual(query.keywords, [])
    }

    func testGymUnderAmount() {
        let query = QueryParser.parse("gym under 300")
        XCTAssertEqual(query.kind, "galaw")
        XCTAssertEqual(query.maxSpend, 300)
        XCTAssertNil(query.vacantMinutes)
    }

    func testTambayOpenLate() {
        let query = QueryParser.parse("tambay open late")
        XCTAssertEqual(query.kind, "tambay")
        XCTAssertTrue(query.openLate)
        XCTAssertNil(query.maxSpend)
    }

    func testFoodBelowPesoSignTrending() {
        let query = QueryParser.parse("food below ₱150 trending")
        XCTAssertEqual(query.kind, "kain")
        XCTAssertEqual(query.maxSpend, 150)
        XCTAssertTrue(query.trendingOnly)
    }

    func testOneHourVacant() {
        let query = QueryParser.parse("1 hr vacant")
        XCTAssertEqual(query.vacantMinutes, 60)
        XCTAssertNil(query.kind)
        XCTAssertNil(query.maxSpend, "a time length must not be read as pesos")
    }

    /// Taglish: "gutom" means hungry, "mura" means cheap.
    func testTaglishHungryAndCheap() {
        let query = QueryParser.parse("Gutom na ako, may 45 mins vacant, mura lang")
        XCTAssertEqual(query.kind, "kain")
        XCTAssertEqual(query.vacantMinutes, 45)
        XCTAssertEqual(query.maxSpend, 150)
    }

    /// "mag-aral" (to study) with an outlet ("saksakan") -> tambay with outlets.
    func testFilipinoStudyWithOutlet() {
        let query = QueryParser.parse("saan pwede mag-aral na may saksakan")
        XCTAssertEqual(query.kind, "tambay")
        XCTAssertTrue(query.needsOutlets)
        XCTAssertEqual(query.keywords, [])
    }

    /// "takbo" (run) plus leftover place words become keywords.
    func testTakboKeepsKeywords() {
        let query = QueryParser.parse("takbo tayo sa academic oval")
        XCTAssertEqual(query.kind, "galaw")
        XCTAssertEqual(query.keywords, ["academic", "oval"])
    }

    /// Hours and minutes add up; "php" works as a peso prefix.
    func testHoursPlusMinutesAndPhp() {
        let query = QueryParser.parse("1 hr 30 mins vacant, arcade php 500")
        XCTAssertEqual(query.vacantMinutes, 90)
        XCTAssertEqual(query.kind, "gala")
        XCTAssertEqual(query.maxSpend, 500)
    }

    /// "under 30 mins" is a time limit, not a ₱30 budget.
    func testUnderMinutesIsNotBudget() {
        let query = QueryParser.parse("bowling under 30 mins")
        XCTAssertEqual(query.kind, "gala")
        XCTAssertEqual(query.vacantMinutes, 30)
        XCTAssertNil(query.maxSpend)
    }

    /// Wi-Fi spelled with a hyphen and a student discount request.
    func testHyphenWifiAndStudentDiscount() {
        let query = QueryParser.parse("study spot with Wi-Fi and student discount")
        XCTAssertEqual(query.kind, "tambay")
        XCTAssertTrue(query.needsWifi)
        XCTAssertTrue(query.studentDiscount)
    }

    /// The first kind word in the sentence wins.
    func testFirstKindWins() {
        XCTAssertEqual(QueryParser.parse("kape muna then gym").kind, "tambay")
    }

    /// "an hour" and "isang oras" both mean 60 minutes.
    func testWordHours() {
        XCTAssertEqual(QueryParser.parse("I have an hour").vacantMinutes, 60)
        XCTAssertEqual(QueryParser.parse("isang oras lang vacant ko").vacantMinutes, 60)
    }

    /// Blank text understands nothing.
    func testEmptyText() {
        XCTAssertTrue(QueryParser.parse("   ").isEmpty)
    }
}
