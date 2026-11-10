//
//  UserPrefs.swift
//  KainSpot
//
//  UserDefaults wrapper for the handful of small settings the app remembers between launches.
//  Course week: Week 4 (UserDefaults for a small set of values).
//

import Foundation

/// Remembers the last SpotFilter (nickname, price, trending, distance, plus the Vacant Planner choices)
/// and the last sync time.
/// Use `UserPrefs.shared` in the app; tests inject their own `UserDefaults(suiteName:)`.
final class UserPrefs {

    static let shared = UserPrefs()

    /// Keys are namespaced with "ks." so they never clash with system or library defaults.
    enum Key {
        static let nickname = "ks.nickname"
        static let maxPrice = "ks.maxPrice"
        static let trendingOnly = "ks.trendingOnly"
        static let maxDistanceKm = "ks.maxDistanceKm"
        static let lastSync = "ks.lastSync"
        // Vacant Planner choices.
        static let kind = "ks.kind"
        static let maxSpend = "ks.maxSpend"
        static let vacantMinutes = "ks.vacantMinutes"
        static let needsWifi = "ks.needsWifi"
        static let studentDiscount = "ks.studentDiscount"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Instance API (preferred: UserPrefs.shared.…)

    /// Stores every field of the filter so Preferences can pre-fill next time.
    func save(_ filter: SpotFilter) {
        defaults.set(filter.nickname, forKey: Key.nickname)
        defaults.set(Int(filter.maxPrice), forKey: Key.maxPrice)
        defaults.set(filter.trendingOnly, forKey: Key.trendingOnly)
        defaults.set(filter.maxDistanceKm, forKey: Key.maxDistanceKm)
        // nil kind means "all kinds", stored as a missing key.
        if let kind = filter.kind, !kind.isEmpty {
            defaults.set(kind, forKey: Key.kind)
        } else {
            defaults.removeObject(forKey: Key.kind)
        }
        defaults.set(filter.maxSpend, forKey: Key.maxSpend)
        defaults.set(filter.vacantMinutes, forKey: Key.vacantMinutes)
        defaults.set(filter.needsWifi, forKey: Key.needsWifi)
        defaults.set(filter.studentDiscount, forKey: Key.studentDiscount)
    }

    /// Rebuilds the saved filter. Missing keys fall back to `SpotFilter.default`, and odd stored values
    /// are clamped so a bad value can never break the price segment or slider.
    func loadFilter() -> SpotFilter {
        let fallback = SpotFilter.default
        let nickname = defaults.string(forKey: Key.nickname) ?? fallback.nickname

        var maxPrice = fallback.maxPrice
        if let stored = defaults.object(forKey: Key.maxPrice) as? Int {
            maxPrice = Int16(min(max(stored, 0), 3))
        }

        let trendingOnly = defaults.object(forKey: Key.trendingOnly) as? Bool ?? fallback.trendingOnly

        var maxDistanceKm = fallback.maxDistanceKm
        if let stored = defaults.object(forKey: Key.maxDistanceKm) as? Double, stored > 0 {
            maxDistanceKm = stored
        }

        // Vacant Planner values: an unknown kind, a negative budget or a non-positive vacant fall back to defaults.
        var kind = fallback.kind
        if let stored = defaults.string(forKey: Key.kind), SpotKind(rawValue: stored) != nil {
            kind = stored
        }

        var maxSpend = fallback.maxSpend
        if let stored = defaults.object(forKey: Key.maxSpend) as? Int, stored >= 0 {
            maxSpend = stored
        }

        var vacantMinutes = fallback.vacantMinutes
        if let stored = defaults.object(forKey: Key.vacantMinutes) as? Int, stored > 0 {
            vacantMinutes = stored
        }

        let needsWifi = defaults.object(forKey: Key.needsWifi) as? Bool ?? fallback.needsWifi
        let studentDiscount = defaults.object(forKey: Key.studentDiscount) as? Bool ?? fallback.studentDiscount

        return SpotFilter(nickname: nickname,
                          maxPrice: maxPrice,
                          trendingOnly: trendingOnly,
                          maxDistanceKm: maxDistanceKm,
                          kind: kind,
                          maxSpend: maxSpend,
                          vacantMinutes: vacantMinutes,
                          needsWifi: needsWifi,
                          studentDiscount: studentDiscount)
    }

    /// Saved nickname trimmed of spaces; empty string when none (Home shows "Hi, foodie!").
    var nickname: String {
        (defaults.string(forKey: Key.nickname) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// When the spots were last downloaded successfully; nil means never (triggers a first sync).
    var lastSync: Date? {
        get { defaults.object(forKey: Key.lastSync) as? Date }
        set {
            if let date = newValue {
                defaults.set(date, forKey: Key.lastSync)
            } else {
                defaults.removeObject(forKey: Key.lastSync)
            }
        }
    }

    // MARK: - Static conveniences (forward to `shared`, as named in the spec)

    static func save(_ filter: SpotFilter) {
        shared.save(filter)
    }

    static func loadFilter() -> SpotFilter {
        shared.loadFilter()
    }

    static var lastSync: Date? {
        get { shared.lastSync }
        set { shared.lastSync = newValue }
    }
}
