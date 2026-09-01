//
//  AttributedTextCache.swift
//  clipboardManager
//
//  Highlighted/colourised previews are regex work; cards re-render on hover and
//  selection, so the result is memoised per (item, query).
//

import Foundation
import SwiftUI

enum AttributedTextCache {
    private final class Box: NSObject {
        let value: AttributedString
        init(_ value: AttributedString) { self.value = value }
    }

    nonisolated(unsafe) private static let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.countLimit = 600
        return cache
    }()

    static func preview(id: UUID, text: String, language: CodeLanguage?, highlight: String) -> AttributedString {
        let key = "\(id.uuidString)|\(text.hashValue)|\(language?.rawValue ?? "-")|\(highlight)" as NSString
        if let hit = cache.object(forKey: key) { return hit.value }
        let rendered: AttributedString
        if let language {
            rendered = CodeHighlighter.attributed(text, language: language, highlight: highlight)
        } else {
            rendered = Highlighter.attributed(text, matching: highlight)
        }
        cache.setObject(Box(rendered), forKey: key)
        return rendered
    }
}
