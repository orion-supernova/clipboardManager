//
//  ColorParsing.swift
//  clipboardManager
//

import AppKit
import SwiftUI

struct ParsedColor: Equatable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    var hexString: String {
        let r = Int((red * 255).rounded()), g = Int((green * 255).rounded()), b = Int((blue * 255).rounded())
        if alpha < 0.999 {
            return String(format: "#%02X%02X%02X%02X", r, g, b, Int((alpha * 255).rounded()))
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    var swiftUIColor: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }

    /// Relative luminance, used to pick a readable label color over the swatch.
    var isLight: Bool { (0.2126 * red + 0.7152 * green + 0.0722 * blue) > 0.6 }

    /// Accepts `#RGB`, `#RRGGBB`, `#RRGGBBAA`, `rgb(r, g, b)` and `rgba(r, g, b, a)`.
    /// The *entire* trimmed string must be a color; text that merely contains one stays text.
    static func parse(_ raw: String) -> ParsedColor? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 40 else { return nil }

        if text.hasPrefix("#") {
            let hex = String(text.dropFirst())
            guard hex.allSatisfy(\.isHexDigit) else { return nil }
            var value: UInt64 = 0
            guard Scanner(string: hex).scanHexInt64(&value) else { return nil }
            switch hex.count {
            case 3:
                return ParsedColor(
                    red: Double((value >> 8) & 0xF) * 17 / 255,
                    green: Double((value >> 4) & 0xF) * 17 / 255,
                    blue: Double(value & 0xF) * 17 / 255,
                    alpha: 1
                )
            case 6:
                return ParsedColor(
                    red: Double((value >> 16) & 0xFF) / 255,
                    green: Double((value >> 8) & 0xFF) / 255,
                    blue: Double(value & 0xFF) / 255,
                    alpha: 1
                )
            case 8:
                return ParsedColor(
                    red: Double((value >> 24) & 0xFF) / 255,
                    green: Double((value >> 16) & 0xFF) / 255,
                    blue: Double((value >> 8) & 0xFF) / 255,
                    alpha: Double(value & 0xFF) / 255
                )
            default:
                return nil
            }
        }

        let lower = text.lowercased()
        guard lower.hasPrefix("rgb"), lower.hasSuffix(")"), let open = lower.firstIndex(of: "(") else { return nil }
        let inner = lower[lower.index(after: open)..<lower.index(before: lower.endIndex)]
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 3 || parts.count == 4 else { return nil }
        let channels = parts.prefix(3).compactMap { part -> Double? in
            if part.hasSuffix("%") { return Double(part.dropLast()).map { $0 / 100 } }
            return Double(part).map { $0 / 255 }
        }
        guard channels.count == 3, channels.allSatisfy({ (0...1).contains($0) }) else { return nil }
        var alpha = 1.0
        if parts.count == 4 {
            guard let a = Double(parts[3]), (0...1).contains(a) else { return nil }
            alpha = a
        }
        return ParsedColor(red: channels[0], green: channels[1], blue: channels[2], alpha: alpha)
    }
}

extension NSColor {
    var hexString: String? {
        guard let rgb = usingColorSpace(.sRGB) else { return nil }
        return ParsedColor(
            red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent, alpha: rgb.alphaComponent
        ).hexString
    }
}
