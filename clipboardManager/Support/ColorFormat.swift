//
//  ColorFormat.swift
//  clipboardManager
//

import Foundation

enum ColorFormat: String, CaseIterable, Sendable, Equatable, Identifiable {
    case hex
    case rgb
    case hsl
    case swiftUI
    case nsColor
    case uiColor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hex: "Hex"
        case .rgb: "rgb()"
        case .hsl: "hsl()"
        case .swiftUI: "SwiftUI Color"
        case .nsColor: "NSColor"
        case .uiColor: "UIColor"
        }
    }

    func render(_ color: ParsedColor) -> String {
        let r = Int((color.red * 255).rounded()), g = Int((color.green * 255).rounded()), b = Int((color.blue * 255).rounded())
        let alphaSuffix = color.alpha < 0.999 ? ", \(Self.trim(color.alpha))" : ""
        switch self {
        case .hex:
            return color.hexString
        case .rgb:
            return color.alpha < 0.999 ? "rgba(\(r), \(g), \(b), \(Self.trim(color.alpha)))" : "rgb(\(r), \(g), \(b))"
        case .hsl:
            let (h, s, l) = color.hsl
            return "hsl(\(Int(h.rounded())), \(Int((s * 100).rounded()))%, \(Int((l * 100).rounded()))%)"
        case .swiftUI:
            return "Color(red: \(Self.trim(color.red)), green: \(Self.trim(color.green)), blue: \(Self.trim(color.blue))" +
                (color.alpha < 0.999 ? ", opacity: \(Self.trim(color.alpha)))" : ")")
        case .nsColor:
            return "NSColor(red: \(Self.trim(color.red)), green: \(Self.trim(color.green)), blue: \(Self.trim(color.blue)), alpha: \(color.alpha < 0.999 ? Self.trim(color.alpha) : "1"))"
        case .uiColor:
            return "UIColor(red: \(Self.trim(color.red)), green: \(Self.trim(color.green)), blue: \(Self.trim(color.blue)), alpha: \(color.alpha < 0.999 ? Self.trim(color.alpha) : "1"))" + (alphaSuffix.isEmpty ? "" : "")
        }
    }

    private static func trim(_ value: Double) -> String {
        let rounded = (value * 1000).rounded() / 1000
        var text = String(rounded)
        if text.hasSuffix(".0") { text.removeLast(2) }
        return text
    }
}

extension ParsedColor {
    /// Hue in degrees, saturation and lightness in 0…1.
    var hsl: (hue: Double, saturation: Double, lightness: Double) {
        let maxC = max(red, green, blue), minC = min(red, green, blue)
        let delta = maxC - minC
        let lightness = (maxC + minC) / 2
        guard delta > 0.0001 else { return (0, 0, lightness) }
        let saturation = lightness > 0.5 ? delta / (2 - maxC - minC) : delta / (maxC + minC)
        var hue: Double
        if maxC == red {
            hue = (green - blue) / delta + (green < blue ? 6 : 0)
        } else if maxC == green {
            hue = (blue - red) / delta + 2
        } else {
            hue = (red - green) / delta + 4
        }
        hue *= 60
        return (hue, saturation, lightness)
    }
}
