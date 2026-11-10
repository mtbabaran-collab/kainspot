//
//  PriceLevel.swift
//  KainSpot
//
//  Price bands for a food spot (Budget / Mid / Splurge) with display helpers.
//  Course week: Week 2 (Swift enums with raw values and computed properties).
//

import Foundation

/// Student-friendly price band. Raw values match the `priceLevel` stored in Core Data (Integer 16).
enum PriceLevel: Int16, CaseIterable {
    case budget = 1
    case mid = 2
    case splurge = 3

    /// Peso signs shown in cells and the detail screen, one per band.
    var symbol: String {
        switch self {
        case .budget: return "₱"
        case .mid: return "₱₱"
        case .splurge: return "₱₱₱"
        }
    }

    /// Plain-language label for accessibility and the preferences screen.
    var label: String {
        switch self {
        case .budget: return "Budget"
        case .mid: return "Mid"
        case .splurge: return "Splurge"
        }
    }

    /// Safe conversion from any stored value: out-of-range data falls back to `.budget`
    /// instead of crashing, because remote JSON is outside our control.
    static func from(_ rawValue: Int16) -> PriceLevel {
        PriceLevel(rawValue: rawValue) ?? .budget
    }
}
