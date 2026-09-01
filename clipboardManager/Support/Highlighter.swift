//
//  Highlighter.swift
//  clipboardManager
//

import SwiftUI

enum Highlighter {
    /// Marks every case-insensitive occurrence of `query` in `text`.
    static func attributed(_ text: String, matching query: String) -> AttributedString {
        var result = AttributedString(text)
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return result }

        var searchRange = text.startIndex..<text.endIndex
        var matches = 0
        while matches < 40,
              let range = text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange) {
            if let lower = AttributedString.Index(range.lowerBound, within: result),
               let upper = AttributedString.Index(range.upperBound, within: result) {
                result[lower..<upper].backgroundColor = Color.yellow.opacity(0.4)
                result[lower..<upper].font = .system(.callout).weight(.semibold)
            }
            searchRange = range.upperBound..<text.endIndex
            matches += 1
        }
        return result
    }
}
