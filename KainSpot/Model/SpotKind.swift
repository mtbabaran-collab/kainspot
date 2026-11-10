//
//  SpotKind.swift
//  KainSpot
//
//  The four kinds of places Kain Spot plans a vacant around: Kain, Tambay, Galaw, Gala.
//  Feature: Vacant Planner (one shared list of kinds for the model, parser, ranker and UI).
//

import Foundation

/// Raw values match the `kind` strings stored in spots.json and Core Data.
enum SpotKind: String, CaseIterable {
    /// Food: carinderias, street food, food halls.
    case kain
    /// Cafés, libraries and study/hangout spots.
    case tambay
    /// Gyms, sports venues, running and biking routes.
    case galaw
    /// Fun activities: parks, arcades, bowling, markets.
    case gala

    /// Display name used in segmented controls and chips.
    var title: String {
        switch self {
        case .kain: return "Kain"
        case .tambay: return "Tambay"
        case .galaw: return "Galaw"
        case .gala: return "Gala"
        }
    }

    /// Emoji shown next to the title.
    var emoji: String {
        switch self {
        case .kain: return "🍜"
        case .tambay: return "☕"
        case .galaw: return "🏋️"
        case .gala: return "🎳"
        }
    }

    /// Short English explanation for accessibility labels and onboarding text.
    var subtitle: String {
        switch self {
        case .kain: return "Food"
        case .tambay: return "Cafés, study and hangout"
        case .galaw: return "Gym, sports and running"
        case .gala: return "Activities and fun"
        }
    }
}
