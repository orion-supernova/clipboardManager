//
//  Color+HexColor.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 17.03.2023.
//

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
            case 3: // RGB (12-bit)
                (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
            case 6: // RGB (24-bit)
                (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
            case 8: // ARGB (32-bit)
                (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
            default:
                (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension NSColor {
    // Convert a hex string to a NSColor
    static func fromHexString(_ hex: String) -> NSColor? {
        var cString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // Check for hash and remove the hash
        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }

        // Check if the remaining string is of correct length
        if cString.count != 6 {
            return nil
        }

        // Split the string into its components
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        return NSColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }

    // Convert a RGB string to a NSColor
    static func fromRGBString(_ rgb: String) -> NSColor? {
        let components = rgb
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .dropFirst(4)
            .dropLast()
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }

        guard components.count == 3 else {
            return nil
        }

        return NSColor(
            red: CGFloat(components[0]) / 255.0,
            green: CGFloat(components[1]) / 255.0,
            blue: CGFloat(components[2]) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}

func detectColor(from text: String) -> NSColor? {
    // Hex color regex: #RRGGBB
    let hexColorRegex = "#([A-Fa-f0-9]{6})"
    // RGB color regex: rgb(R, G, B)
    let rgbColorRegex = "rgb\\(\\s*([0-9]{1,3})\\s*,\\s*([0-9]{1,3})\\s*,\\s*([0-9]{1,3})\\s*\\)"

    if let hexMatch = text.range(of: hexColorRegex, options: .regularExpression) {
        let hexString = String(text[hexMatch])
        return NSColor.fromHexString(hexString)
    }

    if let rgbMatch = text.range(of: rgbColorRegex, options: .regularExpression) {
        let rgbString = String(text[rgbMatch])
        return NSColor.fromRGBString(rgbString)
    }

    return nil
}
