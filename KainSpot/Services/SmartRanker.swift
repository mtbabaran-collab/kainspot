//
//  SmartRanker.swift
//  KainSpot
//
//  Offline "smart picks" engine: scores every spot with a transparent weighted formula and keeps
//  short human reasons ("Fits your 60-min vacant", "Under ₱150", "Has WiFi 📶") for the UI.
//  Feature: Smart picks (works without internet; the Gemini assistant only re-explains these results).
//

import Foundation

/// One spot with its score and the reasons that earned it.
struct ScoredSpot {
    let spot: Spot
    let score: Double
    /// Short, human-readable strings, most important first.
    let reasons: [String]
    /// Distance from the origin used for ranking (handy for cells and the Gemini prompt).
    let distanceKm: Double
    /// Trip plan for the vacant being considered.
    let plan: VacantPlan
    /// Whether the spot is open at the ranking time.
    let isOpenNow: Bool
}

/// Stateless ranking rules. Every weight is a named constant so the scoring is easy to explain in the demo.
enum SmartRanker {

    // MARK: - Weights (points)

    /// Rating is out of 5, so ratings contribute up to 10 points: quality matters most.
    static let ratingWeight = 2.0
    /// Each km away costs this many points.
    static let distancePenaltyPerKm = 0.6
    static let fitsVacantBonus = 3.0
    static let missesVacantPenalty = 4.0
    static let budgetFitBonus = 2.0
    static let overBudgetPenalty = 3.0
    static let kindMatchBonus = 2.5
    static let kindMismatchPenalty = 5.0
    static let amenityBonus = 1.5
    static let missingAmenityPenalty = 2.0
    static let trendingBonus = 1.0
    static let notTrendingPenalty = 4.0
    static let openNowBonus = 1.0
    static let closedNowPenalty = 6.0
    static let keywordBonus = 0.5

    /// Scores and sorts spots (best first). Query values win over the saved filter when both exist,
    /// because what the student just typed is the freshest intent.
    /// - Parameters:
    ///   - spots: Core Data spots to consider.
    ///   - query: parsed free text (may be empty).
    ///   - filter: saved Preferences, or nil to rank on the query alone.
    ///   - distanceFrom: where the student is (usually campus or the GPS position).
    ///   - now: current time, injected so tests are deterministic.
    ///   - calendar: used to read the hour for "open now"; injectable for tests.
    static func rank(spots: [Spot],
                     query: ParsedQuery,
                     filter: SpotFilter?,
                     distanceFrom origin: Coordinate,
                     now: Date,
                     calendar: Calendar = .current) -> [ScoredSpot] {
        // Merge intent: typed query first, then saved filter.
        let wantedKind = query.kind ?? filter?.kind
        var budget = query.maxSpend
        if budget == nil, let spend = filter?.maxSpend, spend > 0 {
            budget = spend
        }
        let vacant: Int? = query.vacantMinutes ?? filter?.vacantMinutes
        let needsWifi = query.needsWifi || (filter?.needsWifi ?? false)
        let needsDiscount = query.studentDiscount || (filter?.studentDiscount ?? false)
        let trendingOnly = query.trendingOnly || (filter?.trendingOnly ?? false)

        let scored = spots.map { spot -> ScoredSpot in
            var score = spot.rating * ratingWeight
            var reasons: [String] = []

            // Distance: closer is better.
            let km = DistanceCalculator.kilometers(from: origin,
                                                   to: Coordinate(latitude: spot.latitude, longitude: spot.longitude))
            score -= km * distancePenaltyPerKm

            // Vacant: will they be back for class?
            let plan = VacantPlanner.plan(distanceKm: km,
                                          stayMinutes: Int(spot.stayMinutes),
                                          vacantMinutes: vacant ?? 0,
                                          now: now)
            if let vacant = vacant {
                if plan.fits {
                    score += fitsVacantBonus
                    reasons.append("Fits your \(vacant)-min vacant")
                } else {
                    score -= missesVacantPenalty
                }
            }

            // Kind: a strong signal because "gym" and "food" answer different needs.
            if let wantedKind = wantedKind {
                if spot.kind == wantedKind {
                    score += kindMatchBonus
                } else {
                    score -= kindMismatchPenalty
                }
            }

            // Budget (pesos per person).
            if let budget = budget {
                let spend = Int(spot.avgSpend)
                if spend <= budget {
                    score += budgetFitBonus
                    reasons.append(spend == 0 ? "Free! 🎉" : "Under ₱\(budget)")
                } else {
                    score -= overBudgetPenalty
                }
            }

            // Amenities the student asked for.
            if needsWifi {
                if spot.hasWifi {
                    score += amenityBonus
                    reasons.append("Has WiFi 📶")
                } else {
                    score -= missingAmenityPenalty
                }
            }
            if query.needsOutlets {
                if spot.hasOutlets {
                    score += amenityBonus
                    reasons.append("Has outlets 🔌")
                } else {
                    score -= missingAmenityPenalty
                }
            }
            if needsDiscount {
                if spot.studentDiscount {
                    score += amenityBonus
                    reasons.append("Student discount 🎓")
                } else {
                    score -= missingAmenityPenalty
                }
            }
            if query.openLate {
                if spot.openLate {
                    score += amenityBonus
                    reasons.append("Open late 🌙")
                } else {
                    score -= missingAmenityPenalty
                }
            }

            // Trending: small bonus normally, a hard push down when the user asked for trending only.
            if spot.isTrending {
                score += trendingBonus
                reasons.append("Trending 🔥")
            } else if trendingOnly {
                score -= notTrendingPenalty
            }

            // Open now / closed now.
            let open = isOpen(openHour: Int(spot.openHour), closeHour: Int(spot.closeHour), at: now, calendar: calendar)
            if open {
                score += openNowBonus
                reasons.append("Open now")
            } else {
                score -= closedNowPenalty
                reasons.append("Closed now")
            }

            // Free-text keywords ("isaw", "ramen") found in the name, category or blurb.
            let haystack = [spot.name ?? "", spot.category ?? "", spot.blurb ?? ""].joined(separator: " ").lowercased()
            for keyword in query.keywords where haystack.contains(keyword) {
                score += keywordBonus
                reasons.append("Matches \"\(keyword)\"")
            }

            return ScoredSpot(spot: spot, score: score, reasons: reasons, distanceKm: km, plan: plan, isOpenNow: open)
        }

        // Highest score first; equal scores fall back to the closer spot, then the name, so order is stable.
        return scored.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.distanceKm != rhs.distanceKm { return lhs.distanceKm < rhs.distanceKm }
            return (lhs.spot.name ?? "") < (rhs.spot.name ?? "")
        }
    }

    /// Opening-hours check using whole hours 0...24.
    /// - open == close, or 0...24, means open all day.
    /// - open < close is a normal day (8 to 22 -> open from 8:00 until 21:59).
    /// - open > close crosses midnight (18 to 2 -> open from 18:00 until 1:59).
    static func isOpen(openHour: Int, closeHour: Int, at date: Date, calendar: Calendar = .current) -> Bool {
        if openHour == closeHour || (openHour <= 0 && closeHour >= 24) {
            return true
        }
        let hour = calendar.component(.hour, from: date)
        if openHour < closeHour {
            return hour >= openHour && hour < closeHour
        }
        return hour >= openHour || hour < closeHour
    }
}
