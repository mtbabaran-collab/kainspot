//
//  QueryParser.swift
//  KainSpot
//
//  Turns free text like "cheap coffee with wifi" or "gutom, 1 hr vacant, below ₱150" into filters.
//  Feature: Smart search (offline, rule-based, English + Filipino/Taglish keywords; unit-tested).
//

import Foundation

/// Structured meaning pulled out of a free-text search. nil / false means "the user did not say".
struct ParsedQuery: Equatable {
    /// "kain", "tambay", "galaw" or "gala".
    var kind: String? = nil
    /// Peso budget per person.
    var maxSpend: Int? = nil
    var needsWifi: Bool = false
    var needsOutlets: Bool = false
    var studentDiscount: Bool = false
    var openLate: Bool = false
    var trendingOnly: Bool = false
    /// Length of the vacant in minutes ("1 hr" -> 60, "1 hr 30 mins" -> 90).
    var vacantMinutes: Int? = nil
    /// Leftover meaningful words (e.g. "isaw", "ramen") matched against names and blurbs.
    var keywords: [String] = []

    /// True when nothing at all was understood (the UI can then show every spot).
    var isEmpty: Bool {
        self == ParsedQuery()
    }
}

/// Stateless keyword rules. Order of checks matters only for `kind`: the first kind word in the text wins.
enum QueryParser {

    /// Budget used for "cheap", "mura", "budget" when no amount is typed.
    static let cheapBudget = 150

    /// Kind keywords (lowercased). Includes common Filipino and Taglish words students actually type.
    static let kindWords: [String: SpotKind] = {
        var map: [String: SpotKind] = [:]
        let kain = ["kain", "kainan", "gutom", "food", "eat", "eats", "lunch", "dinner", "breakfast",
                    "merienda", "ulam", "meal", "isaw", "silog", "tapsilog"]
        let tambay = ["kape", "coffee", "cafe", "café", "study", "aral", "tambay", "library", "milktea"]
        let galaw = ["gym", "workout", "run", "running", "takbo", "galaw", "sports", "sport", "jog",
                     "jogging", "exercise", "basketball", "badminton", "bike", "biking", "hike"]
        let gala = ["gala", "fun", "laro", "arcade", "bowling", "park", "date", "gimik", "pasyal"]
        kain.forEach { map[$0] = .kain }
        tambay.forEach { map[$0] = .tambay }
        galaw.forEach { map[$0] = .galaw }
        gala.forEach { map[$0] = .gala }
        return map
    }()

    static let cheapWords: Set<String> = ["cheap", "mura", "budget", "tipid", "affordable"]
    static let wifiWords: Set<String> = ["wifi", "internet"]
    static let outletWords: Set<String> = ["outlet", "outlets", "socket", "sockets", "saksakan", "charge", "charging"]
    static let discountWords: Set<String> = ["discount", "student"]
    static let lateWords: Set<String> = ["late", "gabi", "midnight", "overnight"]
    static let trendingWords: Set<String> = ["trending", "sikat", "viral", "popular", "hot"]

    /// Small words that carry no search meaning (English + Filipino), dropped from `keywords`.
    static let stopWords: Set<String> = [
        "a", "an", "the", "with", "and", "or", "for", "to", "in", "on", "at", "of", "near", "me", "my",
        "i", "im", "want", "need", "some", "spot", "spots", "place", "places", "where", "can", "go",
        "open", "now", "under", "below", "less", "than", "max", "php", "p", "vacant", "free", "time",
        "hr", "hrs", "hour", "hours", "min", "mins", "minute", "minutes", "oras", "h", "m",
        "ng", "na", "sa", "ang", "mga", "may", "ko", "ako", "tayo", "lang", "naman", "pa", "yung", "di",
        "saan", "gusto", "mag", "pwede", "puwede", "lugar", "wi", "fi", "only", "please", "pls", "half", "isang", "around", "nearby", "malapit"
    ]

    /// Parses one search phrase. Never throws: unknown words simply become keywords.
    static func parse(_ text: String) -> ParsedQuery {
        let lowered = text.lowercased()
        var query = ParsedQuery()

        let tokens = tokenize(lowered)
        let tokenSet = Set(tokens)

        // Kind: the first kind word in reading order wins ("coffee then gym" -> tambay).
        for token in tokens {
            if let kind = kindWords[token] {
                query.kind = kind.rawValue
                break
            }
        }

        // Budget: an explicit amount beats the generic "cheap" budget.
        if let amount = explicitBudget(in: lowered) {
            query.maxSpend = amount
        } else if !tokenSet.isDisjoint(with: cheapWords) {
            query.maxSpend = cheapBudget
        }

        // Amenities and flags.
        query.needsWifi = !tokenSet.isDisjoint(with: wifiWords) || lowered.contains("wi-fi") || lowered.contains("wi fi")
        query.needsOutlets = !tokenSet.isDisjoint(with: outletWords)
        query.studentDiscount = !tokenSet.isDisjoint(with: discountWords)
        query.openLate = !tokenSet.isDisjoint(with: lateWords) || lowered.contains("24/7")
        query.trendingOnly = !tokenSet.isDisjoint(with: trendingWords)

        query.vacantMinutes = vacantMinutes(in: lowered)

        // Keywords: what is left after removing rule words, stop words and numbers.
        var used = cheapWords.union(wifiWords).union(outletWords).union(discountWords)
            .union(lateWords).union(trendingWords).union(stopWords)
        used.formUnion(kindWords.keys)
        var seen = Set<String>()
        query.keywords = tokens.filter { token in
            guard token.count >= 3, !used.contains(token), Int(token) == nil, !seen.contains(token) else { return false }
            seen.insert(token)
            return true
        }
        return query
    }

    // MARK: - Helpers

    /// Splits on anything that is not a letter or digit, so "₱150," -> "150" and "café" stays one word.
    static func tokenize(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    /// Finds an amount after "under/below/less than/max/budget/php/p/₱".
    /// The trailing check skips numbers that are really time ("under 30 mins" is not ₱30).
    static func explicitBudget(in text: String) -> Int? {
        let pattern = #"(?:\b(?:under|below|less than|max|budget|php|p)\s*₱?\s*|₱\s*)(\d+)\b(?!\s*(?:hrs?|hours?|mins?|minutes?|oras|h|m)\b)"#
        guard let number = firstCapture(pattern: pattern, in: text) else { return nil }
        return Int(number)
    }

    /// Adds up "N hr/hour(s)/oras" and "N min(s)/minute(s)"; "an hour" / "isang oras" count as 60
    /// and "half hour" as 30. Returns nil when no length of time is mentioned.
    static func vacantMinutes(in text: String) -> Int? {
        var total = 0
        var found = false

        if let hours = firstCapture(pattern: #"(\d+(?:\.\d+)?)\s*(?:hrs?|hours?|oras|h)\b"#, in: text),
           let value = Double(hours) {
            total += Int((value * 60).rounded())
            found = true
        } else if text.contains("half hour") || text.contains("half an hour") || text.contains("kalahating oras") {
            total += 30
            found = true
        } else if text.contains("an hour") || text.contains("isang oras") {
            total += 60
            found = true
        }

        if let minutes = firstCapture(pattern: #"(\d+)\s*(?:mins?|minutes?|m)\b"#, in: text),
           let value = Int(minutes) {
            total += value
            found = true
        }

        return found && total > 0 ? total : nil
    }

    /// First capture group of a regex, or nil. Uses `try?` so a bad pattern can never crash the app.
    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }
}
