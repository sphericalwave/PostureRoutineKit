//
//  FuzzySearch.swift
//  PostureRoutineKit
//
//  Searching that survives a dropped letter.
//
//  The exercise list matched on exact substrings, so "medtation" found
//  nothing at all while "meditation" found a whole family. A search that
//  returns an empty screen for one missing character is a search you have to
//  spell for, and the whole point is to find something you half-remember.
//
//  Exact matches are unchanged and always win. This only decides what to
//  show when there would otherwise be nothing.
//
//  It lives here because both apps search the same exercises — one its own
//  rows, the other the published catalog — and a search that behaves
//  differently in each would be its own small betrayal.
//

import Foundation

public enum FuzzySearch {

    /// Lowercased with everything but letters and digits removed, so
    /// "Pull-Up", "pull up" and "pullup" are one thing.
    public static func normalized(_ text: String) -> String {
        text.lowercased().unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .reduce(into: "") { $0.unicodeScalars.append($1) }
    }

    /// A straightforward match: the query appears in the text once both are
    /// normalised. This is what nearly every search is.
    public static func contains(_ text: String, query: String) -> Bool {
        let needle = normalized(query)
        guard !needle.isEmpty else { return true }
        return normalized(text).contains(needle)
    }

    /// How many single-character edits are tolerated for a query of this
    /// length. Short words get one at most — at three characters, two edits
    /// would match almost anything.
    public static func allowance(for query: String) -> Int {
        let count = normalized(query).count
        switch count {
        case 0...3: return 0
        case 4...6: return 1
        case 7...10: return 2
        default: return 3
        }
    }

    /// Whether the text contains something close enough to the query, within
    /// `allowance` edits. Compared against windows of the text the length of
    /// the query, so a typo in one word of a longer name still matches.
    public static func isClose(_ text: String, query: String) -> Bool {
        let needle = Array(normalized(query))
        let hay = Array(normalized(text))
        guard !needle.isEmpty, !hay.isEmpty else { return false }

        let budget = allowance(for: query)
        guard budget > 0 else { return false }
        // A window can be shorter or longer than the query by the budget, so
        // an insertion or deletion is caught as well as a substitution.
        let lower = max(1, needle.count - budget)
        let upper = min(hay.count, needle.count + budget)
        guard lower <= upper else { return false }

        for length in lower...upper {
            guard hay.count >= length else { continue }
            for start in 0...(hay.count - length) {
                let window = Array(hay[start..<(start + length)])
                if distance(needle, window, limit: budget) <= budget { return true }
            }
        }
        return false
    }

    /// Levenshtein distance, abandoned as soon as every cell in a row exceeds
    /// `limit` — the answer beyond that is "too far" and the exact number
    /// doesn't matter.
    public static func distance(_ a: [Character], _ b: [Character], limit: Int) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = previous

        for i in 1...a.count {
            current[0] = i
            var rowBest = current[0]
            for j in 1...b.count {
                let substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
                rowBest = min(rowBest, current[j])
            }
            if rowBest > limit { return limit + 1 }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}
