//
//  SpotDTO.swift
//  KainSpot
//
//  Plain Codable mirror of one entry in the remote spots.json (snake_case keys).
//  Course week: Week 5 (JSON decoding with Codable before saving to Core Data).
//  Feature: Vacant Planner fields (kind, avg_spend, stay_minutes, amenities, hours, emoji).
//

import Foundation

/// Data Transfer Object: decoded from JSON, then copied into a Core Data `Spot`.
/// Keeping it separate from the managed object lets us decode and unit-test without a Core Data stack.
/// Keys are camelCase here; `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` maps
/// `price_level` -> `priceLevel`, `is_trending` -> `isTrending`, `avg_spend` -> `avgSpend`, etc.
struct SpotDTO: Codable, Equatable {
    // Original fields (required: missing one is a decoding error, as before).
    let id: String
    let name: String
    let category: String
    let priceLevel: Int16
    let rating: Double
    let latitude: Double
    let longitude: Double
    let isTrending: Bool
    let address: String
    let blurb: String

    // Vacant-planner fields (optional in JSON: older files without them still decode with these defaults).
    /// "kain" (food), "tambay" (café/study), "galaw" (gym/sports), "gala" (activities).
    var kind: String = "kain"
    /// Typical pesos spent per person.
    var avgSpend: Int32 = 0
    /// Typical minutes spent at the spot (eating, a workout, a study block).
    var stayMinutes: Int16 = 45
    var hasWifi: Bool = false
    var hasOutlets: Bool = false
    var studentDiscount: Bool = false
    var openLate: Bool = false
    /// Opening and closing hour, 0...24 (24 = midnight; open 0 + close 24 = always open).
    var openHour: Int16 = 8
    var closeHour: Int16 = 22
    var emoji: String = "📍"

    /// Explicit keys (camelCase, because the decoder converts snake_case first).
    enum CodingKeys: String, CodingKey {
        case id, name, category, priceLevel, rating, latitude, longitude, isTrending, address, blurb
        case kind, avgSpend, stayMinutes, hasWifi, hasOutlets, studentDiscount, openLate, openHour, closeHour, emoji
    }
}

// Written in an extension so Swift keeps the memberwise initializer for tests and previews.
extension SpotDTO {

    /// Old fields stay strict (`decode`), new fields are lenient (`decodeIfPresent ?? default`)
    /// so a remote JSON published before this upgrade never breaks the sync.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        priceLevel = try container.decode(Int16.self, forKey: .priceLevel)
        rating = try container.decode(Double.self, forKey: .rating)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        isTrending = try container.decode(Bool.self, forKey: .isTrending)
        address = try container.decode(String.self, forKey: .address)
        blurb = try container.decode(String.self, forKey: .blurb)

        kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? "kain"
        avgSpend = try container.decodeIfPresent(Int32.self, forKey: .avgSpend) ?? 0
        stayMinutes = try container.decodeIfPresent(Int16.self, forKey: .stayMinutes) ?? 45
        hasWifi = try container.decodeIfPresent(Bool.self, forKey: .hasWifi) ?? false
        hasOutlets = try container.decodeIfPresent(Bool.self, forKey: .hasOutlets) ?? false
        studentDiscount = try container.decodeIfPresent(Bool.self, forKey: .studentDiscount) ?? false
        openLate = try container.decodeIfPresent(Bool.self, forKey: .openLate) ?? false
        openHour = try container.decodeIfPresent(Int16.self, forKey: .openHour) ?? 8
        closeHour = try container.decodeIfPresent(Int16.self, forKey: .closeHour) ?? 22
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? "📍"
    }
}
