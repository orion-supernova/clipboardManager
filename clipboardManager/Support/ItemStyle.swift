//
//  ItemStyle.swift
//  clipboardManager
//
//  One source of truth for how an item looks: its icon, caption, colour and
//  tile gradient, plus the few shared pieces that draw them (type tile, email
//  avatar, calendar page). Cards, card headers, the preview header and the
//  preview heroes all go through here, so they can't drift apart.
//

import AppKit
import SwiftUI

struct ItemStyle {
    /// Small glyph for headers.
    let symbol: String
    /// Glyph inside the larger type tile.
    let tileSymbol: String
    /// Caption: "Calculation", "Email", "Card · Visa"…
    let title: String
    /// The type's colour: captions, header tiles, accents.
    let tint: Color
    /// Top and bottom of the tile gradient.
    let gradient: (Color, Color)
}

extension ClipboardItem {
    var style: ItemStyle {
        if let sensitivity {
            return ItemStyle(symbol: sensitivity.symbol, tileSymbol: sensitivity.symbol, title: headerTitle, tint: .red, gradient: (.red, .pink))
        }
        if let action = primarySmartAction {
            return action.style
        }
        if kind == .url, MapsLink.isMaps(URL(string: preview)) {
            return ItemStyle(symbol: "mappin.and.ellipse", tileSymbol: "mappin", title: "Place", tint: .red, gradient: (.red, .orange))
        }
        if let codeLanguage {
            return ItemStyle(symbol: "chevron.left.forwardslash.chevron.right", tileSymbol: "chevron.left.forwardslash.chevron.right", title: codeLanguage.displayName, tint: .purple, gradient: (.purple, .indigo))
        }
        switch kind {
        case .url: return ItemStyle(symbol: "link", tileSymbol: "link", title: "Link", tint: .blue, gradient: (.blue, .cyan))
        case .image: return ItemStyle(symbol: "photo", tileSymbol: "photo", title: "Image", tint: .teal, gradient: (.teal, .cyan))
        case .color: return ItemStyle(symbol: "paintpalette", tileSymbol: "paintpalette.fill", title: "Color", tint: .pink, gradient: (.pink, .orange))
        case .file: return ItemStyle(symbol: "doc", tileSymbol: "doc.fill", title: "File", tint: .orange, gradient: (.orange, .yellow))
        case .video: return ItemStyle(symbol: "film", tileSymbol: "film.fill", title: "Video", tint: .orange, gradient: (.orange, .red))
        case .text: return ItemStyle(symbol: "text.alignleft", tileSymbol: "text.alignleft", title: "Text", tint: .secondary, gradient: (.gray, .gray))
        }
    }
}

extension SmartAction {
    var style: ItemStyle {
        switch kind {
        case .pasteResult:
            ItemStyle(symbol: "plus.forwardslash.minus", tileSymbol: "plus.forwardslash.minus", title: "Calculation", tint: .indigo, gradient: (.indigo, .purple))
        case let .email(address):
            ItemStyle(symbol: "envelope.fill", tileSymbol: "envelope.fill", title: "Email", tint: Hue.color(for: EmailAvatar.colorKey(address)), gradient: Hue.pair(for: EmailAvatar.colorKey(address)))
        case .call, .message:
            ItemStyle(symbol: "phone.fill", tileSymbol: "phone.fill", title: "Phone", tint: .green, gradient: (.green, .mint))
        case .map:
            ItemStyle(symbol: "mappin.and.ellipse", tileSymbol: "mappin", title: "Address", tint: .red, gradient: (.red, .orange))
        case .addToCalendar:
            ItemStyle(symbol: "calendar", tileSymbol: "calendar", title: "Event", tint: .red, gradient: (.red, .orange))
        case .openLink:
            ItemStyle(symbol: "link", tileSymbol: "link", title: "Link", tint: .blue, gradient: (.blue, .cyan))
        case let .openLinks(urls):
            ItemStyle(symbol: "link", tileSymbol: "link", title: "\(urls.count) Links", tint: .blue, gradient: (.blue, .cyan))
        case .track:
            ItemStyle(symbol: "shippingbox.fill", tileSymbol: "shippingbox.fill", title: "Tracking", tint: .orange, gradient: (.orange, .brown))
        case .flight:
            ItemStyle(symbol: "airplane", tileSymbol: "airplane", title: "Flight", tint: .blue, gradient: (.blue, .cyan))
        case .openPath, .showPath:
            ItemStyle(symbol: "folder.fill", tileSymbol: "folder.fill", title: "Path", tint: .orange, gradient: (.orange, .yellow))
        }
    }
}

// MARK: - Shared pieces

/// The app-icon-style tile: rounded square, soft vertical gradient, white glyph.
/// The same at every size, so a card's 40pt tile and the preview's 72pt one match.
struct TypeTile: View {
    let style: ItemStyle
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: style.tileSymbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [style.gradient.0, style.gradient.1], startPoint: .top, endPoint: .bottom), in: .rect(cornerRadius: size * 0.25))
            .overlay(RoundedRectangle(cornerRadius: size * 0.25).strokeBorder(.white.opacity(0.22), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.15), radius: size * 0.05, y: size * 0.025)
            .accessibilityHidden(true)
    }
}

/// The small tinted tile in card and preview headers.
struct TypeBadge: View {
    let style: ItemStyle
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: style.symbol)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(style.tint)
            .frame(width: size, height: size)
            .background(style.tint.opacity(0.16), in: .rect(cornerRadius: size * 0.3))
            .accessibilityHidden(true)
    }
}

/// An initial on the colour of the address's domain — the same hue wherever it appears.
struct EmailAvatar: View {
    let address: String
    var size: CGFloat = 40

    /// The domain without "@", lowercased: one key, one hue, everywhere.
    static func colorKey(_ address: String) -> String {
        String(address.split(separator: "@").last ?? Substring(address)).lowercased()
    }

    var body: some View {
        Text(String(address.prefix(1)).uppercased())
            .font(.system(size: size * 0.44, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Hue.gradient(for: Self.colorKey(address)), in: .circle)
            .shadow(color: .black.opacity(0.15), radius: size * 0.05, y: size * 0.025)
            .accessibilityHidden(true)
    }
}

/// A white calendar page with a red month band, at any size.
struct CalendarPage: View {
    let date: Date
    var width: CGFloat = 40

    var body: some View {
        let height = width * 1.1
        VStack(spacing: 0) {
            Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.system(size: width * 0.2, weight: .bold))
                .tracking(width * 0.012)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: height * 0.28)
                .background(Color.red)
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: width * 0.48, weight: .medium))
                .foregroundStyle(.black.opacity(0.85))
                .frame(maxHeight: .infinity)
        }
        .frame(width: width, height: height)
        .background(.white)
        .clipShape(.rect(cornerRadius: width * 0.22))
        .shadow(color: .black.opacity(0.18), radius: width * 0.05, y: width * 0.025)
        .accessibilityHidden(true)
    }
}
