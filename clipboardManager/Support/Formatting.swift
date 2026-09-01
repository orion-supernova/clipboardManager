//
//  Formatting.swift
//  clipboardManager
//

import Foundation

enum Formatting {
    nonisolated(unsafe) private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        return f
    }()

    static func bytes(_ count: Int64) -> String {
        byteFormatter.string(fromByteCount: count)
    }

    static func characterCount(_ count: Int) -> String {
        count == 1 ? "1 character" : "\(count.formatted()) characters"
    }
}
