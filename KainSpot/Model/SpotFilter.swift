//
//  SpotFilter.swift
//  KainSpot
//
//  The user's search choices, passed as a value from Preferences to the Spot list.
//  Course week: Week 2 (passing data between screens with a struct).
//

import Foundation

/// Value type carried through `prepare(for:sender:)`. Being a struct, each screen gets its own copy.
struct SpotFilter: Equatable {
    /// Name shown in greetings and the list title.
    var nickname: String
    /// 0 = any price, otherwise 1...3 meaning "this band or cheaper".
    var maxPrice: Int16
    /// When true only spots flagged `isTrending` are shown.
    var trendingOnly: Bool
    /// Radius from FEU Diliman, in kilometers.
    var maxDistanceKm: Double

    /// Starting values for first launch: no price limit, all spots, within 5 km (matches the slider default).
    static let `default` = SpotFilter(nickname: "", maxPrice: 0, trendingOnly: false, maxDistanceKm: 5)

    /// Core Data fetch filter for the fields the database can check directly (price and trending).
    /// Distance is not stored per user, so it is filtered in memory with `matches(distanceKm:)`.
    func predicate() -> NSPredicate {
        var parts: [NSPredicate] = []
        if maxPrice > 0 {
            parts.append(NSPredicate(format: "priceLevel <= %@", NSNumber(value: maxPrice)))
        }
        if trendingOnly {
            parts.append(NSPredicate(format: "isTrending == %@", NSNumber(value: true)))
        }
        // No conditions means "everything"; an empty AND compound would also work but TRUEPREDICATE is clearer.
        guard !parts.isEmpty else { return NSPredicate(value: true) }
        return NSCompoundPredicate(andPredicateWithSubpredicates: parts)
    }

    /// In-memory distance check applied after the fetch (inclusive, so a spot exactly on the edge counts).
    func matches(distanceKm: Double) -> Bool {
        distanceKm <= maxDistanceKm
    }
}
