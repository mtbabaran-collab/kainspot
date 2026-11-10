//
//  SmartRankerTests.swift
//  KainSpotTests
//
//  Unit tests for the offline smart-picks score and its human reasons, using real Core Data `Spot`
//  objects in a throwaway in-memory store. Feature: Smart picks verified with XCTest.
//

import CoreData
import XCTest
@testable import KainSpot

final class SmartRankerTests: XCTestCase {

    private var stack: CoreDataStack?

    override func setUpWithError() throws {
        try super.setUpWithError()
        stack = CoreDataStack(inMemory: true)
    }

    override func tearDownWithError() throws {
        stack = nil
        try super.tearDownWithError()
    }

    /// 2:00 PM today in the test calendar.
    private func twoPM() throws -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 14
        components.minute = 0
        return try XCTUnwrap(Calendar.current.date(from: components))
    }

    /// Creates a spot north/east of campus `offsetKm` away (roughly; 0.009 degrees of latitude ~ 1 km).
    private func makeSpot(id: String,
                          kind: String,
                          rating: Double = 4.0,
                          offsetKm: Double = 0.5,
                          avgSpend: Int32 = 100,
                          stayMinutes: Int16 = 30,
                          hasWifi: Bool = false,
                          isTrending: Bool = false,
                          openHour: Int16 = 8,
                          closeHour: Int16 = 22) throws -> Spot {
        let context = try XCTUnwrap(stack?.viewContext)
        let spot = Spot(context: context)
        spot.id = id
        spot.name = id
        spot.category = kind
        spot.blurb = ""
        spot.kind = kind
        spot.rating = rating
        spot.latitude = DistanceCalculator.feuDiliman.latitude + offsetKm * 0.009
        spot.longitude = DistanceCalculator.feuDiliman.longitude
        spot.avgSpend = avgSpend
        spot.stayMinutes = stayMinutes
        spot.hasWifi = hasWifi
        spot.isTrending = isTrending
        spot.openHour = openHour
        spot.closeHour = closeHour
        return spot
    }

    /// "cheap coffee with wifi": the close, cheap café with WiFi beats a pricey far café and a food spot.
    func testCoffeeQueryPrefersCheapNearbyWifiCafe() throws {
        let goodCafe = try makeSpot(id: "good-cafe", kind: "tambay", offsetKm: 0.8, avgSpend: 120, hasWifi: true)
        let farCafe = try makeSpot(id: "far-cafe", kind: "tambay", rating: 4.8, offsetKm: 6, avgSpend: 300)
        let food = try makeSpot(id: "food", kind: "kain", rating: 4.8, offsetKm: 0.3, avgSpend: 80)

        let ranked = SmartRanker.rank(spots: [farCafe, food, goodCafe],
                                      query: QueryParser.parse("cheap coffee with wifi"),
                                      filter: nil,
                                      distanceFrom: DistanceCalculator.feuDiliman,
                                      now: try twoPM())

        XCTAssertEqual(ranked.map { $0.spot.id ?? "" }.first, "good-cafe")
        let reasons = try XCTUnwrap(ranked.first?.reasons)
        XCTAssertTrue(reasons.contains("Under ₱150"))
        XCTAssertTrue(reasons.contains("Has WiFi 📶"))
        XCTAssertTrue(reasons.contains("Open now"))
    }

    /// The saved filter's vacant is used when the query does not mention time.
    func testVacantFromFilterAddsReasonAndPenalizesFarSpots() throws {
        let near = try makeSpot(id: "near", kind: "kain", offsetKm: 0.5, stayMinutes: 30)
        let far = try makeSpot(id: "far", kind: "kain", rating: 4.5, offsetKm: 8, stayMinutes: 30)

        var filter = SpotFilter.default
        filter.vacantMinutes = 60
        let ranked = SmartRanker.rank(spots: [far, near],
                                      query: ParsedQuery(),
                                      filter: filter,
                                      distanceFrom: DistanceCalculator.feuDiliman,
                                      now: try twoPM())

        XCTAssertEqual(ranked.first?.spot.id, "near")
        XCTAssertTrue(ranked.first?.reasons.contains("Fits your 60-min vacant") ?? false)
        XCTAssertTrue(ranked.first?.plan.fits ?? false)
        XCTAssertFalse(ranked.last?.plan.fits ?? true)
        XCTAssertFalse(ranked.last?.reasons.contains("Fits your 60-min vacant") ?? true)
    }

    /// A closed spot sinks below an open one and says so.
    func testClosedSpotIsPenalizedAndExplained() throws {
        let open = try makeSpot(id: "open", kind: "kain", rating: 4.0)
        let closed = try makeSpot(id: "closed", kind: "kain", rating: 5.0, openHour: 17, closeHour: 23)

        let ranked = SmartRanker.rank(spots: [closed, open],
                                      query: ParsedQuery(),
                                      filter: nil,
                                      distanceFrom: DistanceCalculator.feuDiliman,
                                      now: try twoPM())

        XCTAssertEqual(ranked.first?.spot.id, "open")
        XCTAssertTrue(ranked.last?.reasons.contains("Closed now") ?? false)
        XCTAssertFalse(ranked.last?.isOpenNow ?? true)
    }

    /// Typed query beats the saved filter: query says gym, filter says food -> gym first.
    func testQueryKindOverridesFilterKind() throws {
        let gym = try makeSpot(id: "gym", kind: "galaw", rating: 4.0)
        let food = try makeSpot(id: "food", kind: "kain", rating: 4.5)
        var filter = SpotFilter.default
        filter.kind = "kain"

        let ranked = SmartRanker.rank(spots: [food, gym],
                                      query: QueryParser.parse("gym"),
                                      filter: filter,
                                      distanceFrom: DistanceCalculator.feuDiliman,
                                      now: try twoPM())
        XCTAssertEqual(ranked.first?.spot.id, "gym")
    }

    /// Trending gets a visible reason; free places say "Free!".
    func testTrendingAndFreeReasons() throws {
        let park = try makeSpot(id: "park", kind: "gala", avgSpend: 0, isTrending: true)
        let ranked = SmartRanker.rank(spots: [park],
                                      query: QueryParser.parse("park under 100"),
                                      filter: nil,
                                      distanceFrom: DistanceCalculator.feuDiliman,
                                      now: try twoPM())
        let reasons = try XCTUnwrap(ranked.first?.reasons)
        XCTAssertTrue(reasons.contains("Trending 🔥"))
        XCTAssertTrue(reasons.contains("Free! 🎉"))
    }

    /// Opening-hours rules: normal day, overnight and 24 hours.
    func testIsOpenRules() throws {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 23
        let elevenPM = try XCTUnwrap(calendar.date(from: components))
        components.hour = 1
        let oneAM = try XCTUnwrap(calendar.date(from: components))

        XCTAssertFalse(SmartRanker.isOpen(openHour: 8, closeHour: 22, at: elevenPM))
        XCTAssertTrue(SmartRanker.isOpen(openHour: 18, closeHour: 2, at: elevenPM))
        XCTAssertTrue(SmartRanker.isOpen(openHour: 18, closeHour: 2, at: oneAM))
        XCTAssertTrue(SmartRanker.isOpen(openHour: 0, closeHour: 24, at: oneAM))
        XCTAssertTrue(SmartRanker.isOpen(openHour: 10, closeHour: 24, at: elevenPM))
        XCTAssertFalse(SmartRanker.isOpen(openHour: 10, closeHour: 24, at: oneAM))
    }
}
