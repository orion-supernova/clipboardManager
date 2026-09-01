//
//  TextTransform.swift
//  clipboardManager
//

import Foundation

enum TextTransform: String, CaseIterable, Sendable, Equatable, Identifiable {
    case lowercased
    case uppercased
    case capitalized
    case trimmed
    case singleLine
    case prettyJSON
    case minifiedJSON

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lowercased: "lowercase"
        case .uppercased: "UPPERCASE"
        case .capitalized: "Capitalized Words"
        case .trimmed: "Trimmed"
        case .singleLine: "Single Line"
        case .prettyJSON: "Pretty-Printed JSON"
        case .minifiedJSON: "Minified JSON"
        }
    }

    var symbol: String {
        switch self {
        case .lowercased: "characters.lowercase"
        case .uppercased: "characters.uppercase"
        case .capitalized: "textformat"
        case .trimmed: "scissors"
        case .singleLine: "text.line.first.and.arrowtriangle.forward"
        case .prettyJSON: "curlybraces"
        case .minifiedJSON: "arrow.down.right.and.arrow.up.left"
        }
    }

    /// Returns `nil` when the transform can't be applied (e.g. the text isn't JSON).
    func apply(to text: String) -> String? {
        switch self {
        case .lowercased:
            return text.lowercased()
        case .uppercased:
            return text.uppercased()
        case .capitalized:
            return text.capitalized
        case .trimmed:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .singleLine:
            return text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        case .prettyJSON:
            return Self.reserializeJSON(text, options: [.prettyPrinted, .withoutEscapingSlashes])
        case .minifiedJSON:
            return Self.reserializeJSON(text, options: [.withoutEscapingSlashes])
        }
    }

    private static func reserializeJSON(_ text: String, options: JSONSerialization.WritingOptions) -> String? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              JSONSerialization.isValidJSONObject(object) || object is NSNumber || object is NSString || object is NSNull,
              let output = try? JSONSerialization.data(withJSONObject: object, options: options.union(.fragmentsAllowed)),
              let string = String(data: output, encoding: .utf8)
        else { return nil }
        return string
    }
}
