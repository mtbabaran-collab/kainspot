//
//  SpotDTODecodingTests.swift
//  KainSpotTests
//
//  Unit tests for decoding the snake_case spots JSON into SpotDTO (no network needed).
//  Course week: Week 5 (JSON + Codable) verified with XCTest.
//

import XCTest
@testable import KainSpot

final class SpotDTODecodingTests: XCTestCase {

    private let sampleJSON = """
    [{"id":"mang-larrys-isawan","name":"Mang Larry's Isawan","category":"Street Food","price_level":1,"rating":4.6,
      "latitude":14.6566,"longitude":121.0690,"is_trending":true,"address":"Beside Kalayaan Residence Hall, UP Diliman, QC",
      "blurb":"Legendary isaw and BBQ grilled to order."}]
    """

    /// snake_case keys (price_level, is_trending) must map to camelCase properties.
    func testDecodesSnakeCaseSample() throws {
        let data = Data(sampleJSON.utf8)
        let spots = try SpotSyncService.decode(data)

        XCTAssertEqual(spots.count, 1)
        let spot = try XCTUnwrap(spots.first)
        XCTAssertEqual(spot.id, "mang-larrys-isawan")
        XCTAssertEqual(spot.name, "Mang Larry's Isawan")
        XCTAssertEqual(spot.category, "Street Food")
        XCTAssertEqual(spot.priceLevel, 1)
        XCTAssertEqual(spot.rating, 4.6, accuracy: 0.0001)
        XCTAssertEqual(spot.latitude, 14.6566, accuracy: 0.00001)
        XCTAssertEqual(spot.longitude, 121.0690, accuracy: 0.00001)
        XCTAssertTrue(spot.isTrending)
        XCTAssertEqual(spot.address, "Beside Kalayaan Residence Hall, UP Diliman, QC")
    }

    /// Broken JSON must throw so the sync can fall back to the bundled file instead of crashing.
    func testBadJSONThrows() {
        let data = Data("{ this is not json ".utf8)
        XCTAssertThrowsError(try SpotSyncService.decode(data))
    }

    /// A missing required field is also a decoding error.
    func testMissingFieldThrows() {
        let data = Data(#"[{"id":"x","name":"No price"}]"#.utf8)
        XCTAssertThrowsError(try SpotSyncService.decode(data))
    }

    /// The offline fallback file shipped in the app must decode to the 30 verified real places across all four kinds.
    func testBundledSpotsJSONDecodes() throws {
        let bundle = Bundle(for: SpotSyncService.self)
        let url = try XCTUnwrap(bundle.url(forResource: "spots", withExtension: "json"),
                                "spots.json should be copied into the app bundle")
        let spots = try SpotSyncService.decode(Data(contentsOf: url))
        XCTAssertEqual(spots.count, 30)
        XCTAssertTrue(spots.contains { $0.isTrending })
        XCTAssertTrue(spots.allSatisfy { (1...3).contains($0.priceLevel) })

        // Every kind is represented, and every kind string is one the app understands.
        XCTAssertEqual(Set(spots.map { $0.kind }), Set(SpotKind.allCases.map { $0.rawValue }))
        XCTAssertTrue(spots.allSatisfy { (0...24).contains($0.openHour) && (0...24).contains($0.closeHour) })
        XCTAssertTrue(spots.allSatisfy { $0.avgSpend >= 0 && $0.stayMinutes > 0 && !$0.emoji.isEmpty })

        // Ids kept from the first version (places re-verified as still open) so saved photos ("spot-<id>.jpg") still match.
        // The other first-version places were replaced after an online check (closed, moved or unverifiable).
        let ids = Set(spots.map { $0.id })
        let originalIDs = ["mang-larrys-isawan", "rodics-diner", "pino-restaurant"]
        for oldID in originalIDs {
            XCTAssertTrue(ids.contains(oldID), "missing original id \(oldID)")
        }
        XCTAssertEqual(ids.count, spots.count, "ids must be unique")
    }

    /// JSON published before the Vacant Planner upgrade (no new keys) still decodes, using defaults.
    func testOldJSONWithoutNewFieldsUsesDefaults() throws {
        let spots = try SpotSyncService.decode(Data(sampleJSON.utf8))
        let spot = try XCTUnwrap(spots.first)
        XCTAssertEqual(spot.kind, "kain")
        XCTAssertEqual(spot.avgSpend, 0)
        XCTAssertEqual(spot.stayMinutes, 45)
        XCTAssertFalse(spot.hasWifi)
        XCTAssertFalse(spot.hasOutlets)
        XCTAssertFalse(spot.studentDiscount)
        XCTAssertFalse(spot.openLate)
        XCTAssertEqual(spot.openHour, 8)
        XCTAssertEqual(spot.closeHour, 22)
        XCTAssertEqual(spot.emoji, "📍")
    }

    /// The new snake_case keys (avg_spend, stay_minutes, has_wifi...) map onto the new properties.
    func testDecodesNewVacantPlannerFields() throws {
        let json = """
        [{"id":"up-academic-oval","name":"UP Diliman Academic Oval","category":"Running Route","price_level":1,
          "rating":4.8,"latitude":14.6549,"longitude":121.0684,"is_trending":true,"address":"UP Diliman",
          "blurb":"Loop","kind":"galaw","avg_spend":0,"stay_minutes":40,"has_wifi":true,"has_outlets":true,
          "student_discount":true,"open_late":true,"open_hour":5,"close_hour":21,"emoji":"🏃"}]
        """
        let spots = try SpotSyncService.decode(Data(json.utf8))
        let spot = try XCTUnwrap(spots.first)
        XCTAssertEqual(spot.kind, "galaw")
        XCTAssertEqual(spot.avgSpend, 0)
        XCTAssertEqual(spot.stayMinutes, 40)
        XCTAssertTrue(spot.hasWifi)
        XCTAssertTrue(spot.hasOutlets)
        XCTAssertTrue(spot.studentDiscount)
        XCTAssertTrue(spot.openLate)
        XCTAssertEqual(spot.openHour, 5)
        XCTAssertEqual(spot.closeHour, 21)
        XCTAssertEqual(spot.emoji, "🏃")
    }
}
