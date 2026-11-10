//
//  SpotFilter.swift
//  KainSpot
//
//  The user's search choices, passed as a value from Preferences to the Spot list.
//  Course week: Week 2 (passing data between screens with a struct).
//  Feature: Vacant Planner adds kind, peso budget, vacant length, WiFi and student-discount choices.
//

import Foundation

/// Value type carried through `prepare(for:sender:)`. Being a struct, each screen gets its own copy.
/// New properties have default values so the original memberwise calls
/// `SpotFilter(nickname:maxPrice:trendingOnly:maxDistanceKm:)` still compile unchanged.
struct SpotFilter: Equatable {
    /// Name shown in greetings and the list title.
    var nickname: String
    /// 0 = any price, otherwise 1...3 meaning "this band or cheaper".
    var maxPrice: Int16
    /// When true only spots flagged `isTrending` are shown.
    var trendingOnly: Bool
    /// Radius from FEU Diliman, in kilometers.
    var maxDistanceKm: Double
    /// nil = every kind, otherwise "kain", "tambay", "galaw" or "gala".
    var kind: String? = nil
    /// Peso budget per person; 0 = no budget limit.
    var maxSpend: Int = 0
    /// Length of the student's free period ("vacant") in minutes, used by the Vacant Planner.
    var vacantMinutes: Int = 60
    /// Only spots with WiFi (study sessions).
    var needsWifi: Bool = false
    /// Only spots that give a student discount.
    var studentDiscount: Bool = false

    /// Starting values for first launch: no price limit, all spots, within 5 km (matches the slider default).
    static let `default` = SpotFilter(nickname: "", maxPrice: 0, trendingOnly: false, maxDistanceKm: 5)

    /// Core Data fetch filter for the fields the database can check directly
    /// (price band, trending, kind, peso budget, WiFi, student discount).
    /// Distance and "fits my vacant" depend on where the user is, so they are checked in memory.
    func predicate() -> NSPredicate {
        var parts: [NSPredicate] = []
        if maxPrice > 0 {
            parts.append(NSPredicate(format: "priceLevel <= %@", NSNumber(value: maxPrice)))
        }
        if trendingOnly {
            parts.append(NSPredicate(format: "isTrending == %@", NSNumber(value: true)))
        }
        if let kind = kind, !kind.isEmpty {
            parts.append(NSPredicate(format: "kind == %@", kind))
        }
        if maxSpend > 0 {
            parts.append(NSPredicate(format: "avgSpend <= %@", NSNumber(value: maxSpend)))
        }
        if needsWifi {
            parts.append(NSPredicate(format: "hasWifi == %@", NSNumber(value: true)))
        }
        if studentDiscount {
            parts.append(NSPredicate(format: "studentDiscount == %@", NSNumber(value: true)))
        }
        // No conditions means "everything"; an empty AND compound would also work but TRUEPREDICATE is clearer.
        guard !parts.isEmpty else { return NSPredicate(value: true) }
        return NSCompoundPredicate(andPredicateWithSubpredicates: parts)
    }

    /// In-memory distance check applied after the fetch (inclusive, so a spot exactly on the edge counts).
    func matches(distanceKm: Double) -> Bool {
        distanceKm <= maxDistanceKm
    }

    /// In-memory vacant check: can the student go there, stay, and come back within `vacantMinutes`?
    func fitsVacant(distanceKm: Double, stayMinutes: Int) -> Bool {
        VacantPlanner.plan(distanceKm: distanceKm, stayMinutes: stayMinutes, vacantMinutes: vacantMinutes).fits
    }
}
