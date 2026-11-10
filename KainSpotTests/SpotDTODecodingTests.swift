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

    /// The offline fallback file shipped in the app must decode to the 10 campus spots.
    func testBundledSpotsJSONDecodes() throws {
        let bundle = Bundle(for: SpotSyncService.self)
        let url = try XCTUnwrap(bundle.url(forResource: "spots", withExtension: "json"),
                                "spots.json should be copied into the app bundle")
        let spots = try SpotSyncService.decode(Data(contentsOf: url))
        XCTAssertEqual(spots.count, 10)
        XCTAssertTrue(spots.contains { $0.isTrending })
        XCTAssertTrue(spots.allSatisfy { (1...3).contains($0.priceLevel) })
    }
}
