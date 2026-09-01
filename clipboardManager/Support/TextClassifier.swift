//
//  TextClassifier.swift
//  clipboardManager
//

import Foundation

enum TextClassifier {
    static let previewLimit = 400

    /// Decides whether a plain string should be presented as a link, a color, or text.
    static func kind(for text: String) -> ClipboardKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if ParsedColor.parse(trimmed) != nil { return .color }
        if isSingleURL(trimmed) { return .url }
        return .text
    }

    static func isSingleURL(_ text: String) -> Bool {
        guard !text.isEmpty, text.count <= 2048,
              text.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased()
        else { return false }
        switch scheme {
        case "http", "https", "ftp", "ftps", "sftp":
            return url.host() != nil
        case "mailto":
            return text.contains("@")
        default:
            return false
        }
    }

    static func preview(for text: String) -> String {
        var collapsed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if collapsed.count > previewLimit {
            collapsed = String(collapsed.prefix(previewLimit)) + "…"
        }
        return collapsed
    }

    /// Heuristic used to render code-looking text in a monospaced face.
    static func looksLikeCode(_ text: String) -> Bool {
        let sample = text.prefix(600)
        let lines = sample.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count >= 2 else {
            return sample.contains("{") && sample.contains("}") || sample.contains("</")
        }
        let indented = lines.filter { $0.hasPrefix("  ") || $0.hasPrefix("\t") }.count
        let symbolic = sample.filter { "{}[]();=<>/".contains($0) }.count
        return indented >= max(1, lines.count / 3) || symbolic > sample.count / 12
    }
}
