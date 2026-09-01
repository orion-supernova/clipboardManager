//
//  FileBookmark.swift
//  clipboardManager
//
//  Security-scoped bookmarks keep file-backed items reachable across launches
//  inside the sandbox. Access is opened only for the duration of a closure.
//

import Foundation

enum FileBookmark {
    static func make(for url: URL) -> Data? {
        try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    struct Resolved {
        var url: URL
        var isStale: Bool
    }

    static func resolve(_ data: Data) -> Resolved? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        return Resolved(url: url, isStale: isStale)
    }

    /// Runs `body` with security-scoped access to the bookmarked file.
    /// Falls back to `fallbackURL` (the stored path) when no bookmark is available.
    static func withAccess<T>(bookmark: Data?, fallbackURL: URL?, _ body: (URL) throws -> T) rethrows -> T? {
        if let bookmark, let resolved = resolve(bookmark) {
            let granted = resolved.url.startAccessingSecurityScopedResource()
            defer { if granted { resolved.url.stopAccessingSecurityScopedResource() } }
            return try body(resolved.url)
        }
        if let fallbackURL {
            return try body(fallbackURL)
        }
        return nil
    }

    static func isReachable(bookmark: Data?, fallbackURL: URL?) -> Bool {
        withAccess(bookmark: bookmark, fallbackURL: fallbackURL) { url in
            (try? url.checkResourceIsReachable()) ?? false
        } ?? false
    }
}
