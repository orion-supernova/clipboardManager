//
//  Highlighter.swift
//  clipboardManager
//

import SwiftUI

enum Highlighter {
    /// Marks every case-insensitive occurrence of each word in `query`, since
    /// search matches the words in any order.
    static func attributed(_ text: String, matching query: String) -> AttributedString {
        var result = AttributedString(text)
        var matches = 0
        for needle in query.split(whereSeparator: \.isWhitespace) {
            var searchRange = text.startIndex..<text.endIndex
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
        }
        return result
    }
}
