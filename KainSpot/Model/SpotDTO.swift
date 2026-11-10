//
//  SpotDTO.swift
//  KainSpot
//
//  Plain Codable mirror of one entry in the remote spots.json (snake_case keys).
//  Course week: Week 5 (JSON decoding with Codable before saving to Core Data).
//

import Foundation

/// Data Transfer Object: decoded from JSON, then copied into a Core Data `Spot`.
/// Keeping it separate from the managed object lets us decode and unit-test without a Core Data stack.
/// Keys are camelCase here; `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` maps
/// `price_level` -> `priceLevel`, `is_trending` -> `isTrending`.
struct SpotDTO: Codable, Equatable {
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
}
