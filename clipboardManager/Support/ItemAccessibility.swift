//
//  ItemAccessibility.swift
//  clipboardManager
//
//  Spoken descriptions for clipboard items.
//
//  A card is a dense visual thing — a header row, a body preview, a source
//  badge, a size, a shortcut hint. Read out verbatim by VoiceOver that becomes
//  a wall of fragments, so each card collapses into one element with a written
//  sentence instead: what it is, what it says, where it came from, how old it
//  is. Masked items describe themselves rather than reading their bullets, and
//  images speak the text Vision found in them.
//

import Foundation

extension ClipboardItem {
    /// One spoken sentence for the whole card.
    var accessibilityLabel: String {
        var parts: [String] = [spokenKind]
        if let body = spokenBody { parts.append(body) }
        parts.append("from \(source.name)")
        parts.append(spokenAge)
        if isPinned { parts.append("pinned") }
        return parts.joined(separator: ", ")
    }

    var accessibilityHint: String {
        isSensitive
            ? "Press Return to paste the real value. Press Command E to reveal it."
            : "Press Return to paste."
    }

    private var spokenKind: String {
        if let sensitivity {
            let detail = sensitivityDetail.map { " \($0)" } ?? ""
            return "Masked\(detail) \(sensitivity.title.lowercased())"
        }
        if let codeLanguage { return "\(codeLanguage.displayName) code" }
        switch kind {
        case .url: return "Link"
        case .color: return "Colour"
        case .image: return "Image"
        case .file: return "File"
        case .video: return "Video"
        case .text: return "Text"
        }
    }

    /// The part worth reading aloud, which is not always what is on screen.
    private var spokenBody: String? {
        if let sensitivity {
            // Never read the bullets. Read what is actually useful: the tail.
            guard let tail = preview.split(separator: " ").last, tail.allSatisfy(\.isNumber) else { return nil }
            switch sensitivity {
            case .creditCard, .iban: return "ending \(tail.map(String.init).joined(separator: " "))"
            default: return nil
            }
        }
        switch kind {
        case .url:
            return linkTitle ?? URL(string: preview)?.host() ?? preview
        case .color:
            return preview
        case .image:
            // `preview` holds the recognised text for images, which is the only
            // thing a screen reader can meaningfully say about a screenshot.
            let recognised = preview.trimmingCharacters(in: .whitespacesAndNewlines)
            if recognised.isEmpty {
                return pixelSize.map { "\($0.width) by \($0.height) pixels" }
            }
            return "containing the text, \(truncated(recognised))"
        case .file, .video:
            var text = fileName ?? preview
            if let folder = parentFolderPath { text += ", in \(folder)" }
            if !isFileAvailable { text += ", original file missing" }
            return text
        case .text:
            return truncated(preview)
        }
    }

    /// VoiceOver reads the whole string; a 400-character snippet is a monologue.
    private func truncated(_ text: String, limit: Int = 140) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > limit else { return collapsed }
        return String(collapsed.prefix(limit)) + ", and more"
    }

    private var spokenAge: String {
        let seconds = Date().timeIntervalSince(timestamp)
        switch seconds {
        case ..<60: return "just now"
        case ..<3600: return "\(Int(seconds / 60)) minutes ago"
        case ..<86_400: return "\(Int(seconds / 3600)) hours ago"
        default: return "\(Int(seconds / 86_400)) days ago"
        }
    }
}
