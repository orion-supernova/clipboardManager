//
//  ItemPreviewViews.swift
//  clipboardManager
//
//  Per-kind card bodies. They render only what the light item carries, plus a
//  cached thumbnail — never the full payload. Text colouring is memoised.
//

import ComposableArchitecture
import SwiftUI

struct ItemPreviewView: View {
    let item: ClipboardItem
    let thumbnailURL: URL?
    var iconURL: URL?
    var highlight: String = ""
    var sensitiveLifetime: TimeInterval?

    var body: some View {
        if let sensitivity = item.sensitivity {
            // A pinned or filed item is never pruned, so it has no expiry to count down to.
            SensitivePreview(item: item, kind: sensitivity, lifetime: item.isRetentionExempt ? nil : sensitiveLifetime)
        } else {
            switch item.kind {
            case .text:
                if let action = item.primarySmartAction {
                    SmartCardContent(item: item, action: action, highlight: highlight)
                } else {
                    TextPreview(id: item.id, text: item.preview, language: item.codeLanguage, highlight: highlight)
                }
            case .url: LinkPreview(item: item, heroURL: thumbnailURL, iconURL: iconURL, highlight: highlight)
            case .color: ColorPreview(hex: item.preview)
            case .image: ImagePreview(thumbnailURL: thumbnailURL, recognizedText: item.preview, highlight: highlight)
            case .file, .video: FilePreview(item: item, thumbnailURL: thumbnailURL)
            }
        }
    }
}

private struct TextPreview: View {
    let id: UUID
    let text: String
    let language: CodeLanguage?
    let highlight: String

    var body: some View {
        Group {
            if text.isEmpty {
                Text("Empty text").foregroundStyle(.secondary)
            } else {
                Text(AttributedTextCache.preview(id: id, text: text, language: language, highlight: highlight))
                    .font(language != nil ? .system(size: 11.5, design: .monospaced) : .callout)
                    .lineSpacing(language != nil ? 1 : 2)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        // Fade out instead of ending mid-word in "re…".
        .mask {
            LinearGradient(stops: [.init(color: .black, location: 0.78), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
        }
        .textSelection(.disabled)
    }
}

private struct SensitivePreview: View {
    let item: ClipboardItem
    let kind: SensitiveKind
    let lifetime: TimeInterval?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.preview)
                .font(.system(kind == .creditCard || kind == .iban ? .title2 : .title3, design: .monospaced).weight(.semibold))
                .tracking(1.5)
                .lineLimit(kind == .creditCard || kind == .iban ? 2 : 3)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                CardPill(symbol: "eye", title: "Reveal", key: "⌘E", tint: .red)
                Spacer(minLength: 0)
                if let lifetime {
                    let expiry = item.timestamp.addingTimeInterval(lifetime)
                    Label {
                        Text(expiry, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                    } icon: {
                        Image(systemName: "timer")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .help("Forgotten automatically")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Smart cards read like a contact row: an app-icon-style tile, the thing itself
/// as a headline, one quiet line of context — and only where it adds something,
/// a small visual (a map strip, site avatars). Nothing larger than a headline.
private struct SmartCardContent: View {
    let item: ClipboardItem
    let action: SmartAction
    let highlight: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if case .map = action.kind {
                MapCard()
                    .frame(height: 60)
                    .clipShape(.rect(cornerRadius: 8))
            }
            row
            if let context { contextText(context) }
            Spacer(minLength: 0)
            if let key = item.key(for: action) {
                CardPill(symbol: action.symbol, title: action.pillTitle, key: key, tint: .accentColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Row

    @ViewBuilder
    private var row: some View {
        switch action.kind {
        case let .email(address):
            let parts = address.split(separator: "@", maxSplits: 1).map(String.init)
            line(icon: EmailAvatar(address: address),
                 title: parts.first ?? address,
                 subtitle: parts.count > 1 ? "@" + parts[1] : nil)
        case let .call(number), let .message(number):
            line(icon: TypeTile(style: action.style), title: number, subtitle: PhoneRegion.name(for: number), digits: true)
        case let .map(address):
            let lines = address.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            line(icon: EmptyView?.none, title: lines.first ?? address, subtitle: lines.dropFirst().joined(separator: ", "))
        case let .addToCalendar(start, _, allDay, title):
            line(icon: CalendarPage(date: start), title: title,
                 subtitle: allDay ? start.formatted(.dateTime.weekday(.wide).day().month()) : start.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
        case let .track(number):
            line(icon: TypeTile(style: action.style), title: number, subtitle: carrier(number), mono: true)
        case let .flight(code):
            line(icon: TypeTile(style: action.style), title: code, subtitle: Airline.name(for: code), digits: true)
        case let .openPath(path), let .showPath(path):
            line(icon: fileIcon(path), title: (path as NSString).lastPathComponent,
                 subtitle: ((path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath, middle: true)
        case let .openLinks(urls):
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(urls.prefix(3).enumerated()), id: \.offset) { _, url in
                    HStack(spacing: 8) {
                        monogram(url.host() ?? "?", size: 22)
                        Text(url.host()?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                    }
                }
                if urls.count > 3 {
                    Text("+\(urls.count - 3) more").font(.caption).foregroundStyle(.secondary).padding(.leading, 30)
                }
            }
        case let .openLink(url):
            line(icon: monogram(url.host() ?? "?", size: 40), title: url.host()?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString,
                 subtitle: url.path().count > 1 ? url.path() : nil, middle: true)
        case .pasteResult:
            line(icon: TypeTile(style: action.style), title: item.preview.trimmingCharacters(in: .whitespacesAndNewlines), subtitle: nil, mono: true)
        }
    }

    /// The copied text, when it says more than the row already does.
    private var context: String? {
        let text = item.preview.trimmingCharacters(in: .whitespacesAndNewlines)
        switch action.kind {
        case let .email(value), let .call(value), let .message(value), let .track(value):
            return text.count > value.count + 4 ? text : nil
        default:
            return nil
        }
    }

    private func contextText(_ text: String) -> some View {
        Text(Highlighter.attributed(text, matching: highlight))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineSpacing(1.5)
            .lineLimit(3)
    }

    // MARK: Pieces

    /// Content only: the subtitle carries a fact from the content (a domain, a time,
    /// a carrier, a country) and never the type, which the caption already says.
    private func line(icon: (some View)?, title: String, subtitle: String?, mono: Bool = false, digits: Bool = false, middle: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 12) {
            if let icon { icon }
            VStack(alignment: .leading, spacing: 2) {
                Text(Highlighter.attributed(title, matching: highlight))
                    .font(mono ? .system(size: 14, weight: .medium, design: .monospaced) : digits ? .system(size: 14, weight: .semibold).monospacedDigit() : .system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .truncationMode(middle ? .middle : .tail)
                    .minimumScaleFactor(0.85)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(middle ? .head : .tail)
                }
            }
        }
    }

    private func fileIcon(_ path: String) -> some View {
        Image(nsImage: FileTypeIcon.icon(forName: (path as NSString).lastPathComponent))
            .resizable()
            .frame(width: 40, height: 40)
    }

    private func monogram(_ host: String, size: CGFloat) -> some View {
        Text(String(host.replacingOccurrences(of: "www.", with: "").prefix(1)).uppercased())
            .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Hue.gradient(for: host), in: .rect(cornerRadius: size * 0.25))
    }

    private func carrier(_ number: String) -> String {
        if number.hasPrefix("1Z") { return "UPS" }
        if number.hasPrefix("JD") || number.hasPrefix("JJD") { return "DHL" }
        if number.allSatisfy(\.isNumber) { return "Parcel" }
        return "Postal · \(number.suffix(2))"
    }
}

/// The card-sized action: flat fill (no glass) so a strip of them scrolls cheaply.
struct CardPill: View {
    let symbol: String
    let title: String
    let key: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.caption.weight(.semibold))
            Text(title).font(.caption.weight(.semibold)).lineLimit(1)
            Text(key)
                .font(.caption2.weight(.semibold).monospaced())
                .padding(.horizontal, 4)
                .background(tint.opacity(0.22), in: .rect(cornerRadius: 4))
        }
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(tint.opacity(0.22), in: .capsule)
        .foregroundStyle(tint)
        .accessibilityHidden(true)
    }
}

extension SmartAction {
    /// Short enough for a card pill.
    var pillTitle: String {
        switch kind {
        case .email: "Email"
        case .call: "Call"
        case .message: "Message"
        case .map: "Maps"
        case .openLink: "Open"
        case let .openLinks(urls): "Open \(urls.count)"
        case .addToCalendar: "Add to Calendar"
        case .openPath: "Open"
        case .showPath: "Show in Finder"
        case .track: "Track"
        case .flight: "Flight Status"
        case let .pasteResult(result): "Paste \(result)"
        }
    }
}

private struct LinkPreview: View {
    let item: ClipboardItem
    let heroURL: URL?
    let iconURL: URL?
    let highlight: String

    var body: some View {
        let url = URL(string: item.preview)
        VStack(alignment: .leading, spacing: 8) {
            if let heroURL {
                ThumbnailImage(url: heroURL, placeholderSymbol: "photo", contentMode: .fill)
                    .frame(height: 92)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.08), lineWidth: 1))
                    .transition(.opacity)
            }
            HStack(alignment: .top, spacing: 8) {
                Group {
                    if let iconURL {
                        ThumbnailImage(url: iconURL, placeholderSymbol: "globe")
                            .clipShape(.rect(cornerRadius: 5))
                    } else {
                        // A monogram on a stable hue reads better than a generic globe.
                        Text(String((url?.host() ?? "?").replacingOccurrences(of: "www.", with: "").prefix(1)).uppercased())
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Hue.gradient(for: url?.host() ?? ""))
                    }
                }
                .frame(width: heroURL == nil ? 36 : 20, height: heroURL == nil ? 36 : 20)
                .clipShape(.rect(cornerRadius: heroURL == nil ? 9 : 5))
                VStack(alignment: .leading, spacing: 2) {
                    Text(Highlighter.attributed(item.linkTitle ?? Self.readableTitle(url) ?? url?.host() ?? "Link", matching: highlight))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(heroURL == nil ? 3 : 2)
                    Text(url?.host() ?? item.preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            if heroURL == nil {
                Text(item.preview)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .animation(.easeOut(duration: 0.25), value: heroURL)
        .animation(.easeOut(duration: 0.25), value: item.linkTitle)
    }

    /// "/blog/liquid-glass-design" → "Liquid glass design", so a link with no
    /// fetched title doesn't just repeat its host.
    static func readableTitle(_ url: URL?) -> String? {
        guard let last = url?.pathComponents.last(where: { $0 != "/" }), last.count > 2 else { return nil }
        // Only real slugs ("liquid-glass-design"), never IDs like "MATKngnjTPb1gwWQ7".
        let stem = (last as NSString).deletingPathExtension
        let isSlug = stem.contains("-") || stem.contains("_") || stem.allSatisfy { $0.isLowercase }
        guard isSlug, !MapsLink.isMaps(url) else { return nil }
        let words = stem
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        guard words.contains(where: \.isLetter), !words.allSatisfy({ $0.isNumber || $0 == " " }) else { return nil }
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}

private struct ColorPreview: View {
    let hex: String

    var body: some View {
        let parsed = ParsedColor.parse(hex)
        let light = parsed?.isLight ?? false
        RoundedRectangle(cornerRadius: 8)
            .fill(parsed?.swiftUIColor ?? .gray)
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.1), lineWidth: 1) }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(hex.uppercased())
                        .font(.system(.callout, design: .monospaced).weight(.bold))
                    if let parsed {
                        Text(ColorFormat.rgb.render(parsed))
                            .font(.caption2.monospaced())
                            .opacity(0.8)
                    }
                }
                .foregroundStyle(light ? Color.black : Color.white)
                .padding(10)
            }
    }
}

private struct ImagePreview: View {
    let thumbnailURL: URL?
    let recognizedText: String
    let highlight: String

    var body: some View {
        // Fill, not fit: letterboxed thumbnails left odd gutters in every card.
        // A fixed box first, so the filled image has something to clip against.
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay { ThumbnailImage(url: thumbnailURL, placeholderSymbol: "photo", contentMode: .fill) }
            .clipShape(.rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.08), lineWidth: 1)
            }
            .overlay(alignment: .bottomLeading) {
                if !recognizedText.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "text.viewfinder").font(.caption2.weight(.semibold))
                        Text(Highlighter.attributed(recognizedText, matching: highlight))
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    // A flat fill: a material on every card is expensive to scroll.
                    .background(.black.opacity(0.5), in: .capsule)
                    .padding(6)
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.25), value: recognizedText.isEmpty)
    }
}

private struct FilePreview: View {
    let item: ClipboardItem
    let thumbnailURL: URL?

    private var fileExtension: String? {
        let ext = ((item.fileName ?? item.preview) as NSString).pathExtension
        return ext.isEmpty ? nil : ext.uppercased()
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                if let thumbnailURL {
                    ThumbnailImage(url: thumbnailURL, placeholderSymbol: item.kind.symbolName)
                        .clipShape(.rect(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                        .overlay {
                            if item.kind == .video {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(.black.opacity(0.45), in: .circle)
                                    .accessibilityHidden(true)
                            }
                        }
                } else {
                    FileIconView(path: item.filePath)
                }
            }
            .frame(width: 96, height: 84)
            .frame(maxWidth: .infinity)
            Text(item.fileName ?? item.preview)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.middle)
            HStack(spacing: 6) {
                if let fileExtension {
                    Text(fileExtension)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.1), in: .capsule)
                }
                if !item.isFileAvailable {
                    Label("Original missing", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                        .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Async image helpers

struct ThumbnailImage: View {
    let url: URL?
    var placeholderSymbol: String = "photo"
    var contentMode: ContentMode = .fit
    @Dependency(\.imageLoader) private var loader
    @Environment(\.staticImages) private var staticImages
    @State private var image: CGImage?

    private var resolved: CGImage? { image ?? url.flatMap { staticImages[$0.path] } }

    var body: some View {
        ZStack {
            if let resolved {
                Image(decorative: resolved, scale: 2)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            } else {
                Image(systemName: placeholderSymbol)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: resolved == nil)
        .task(id: url) {
            guard let url, staticImages[url.path] == nil else { return }
            image = await loader.thumbnail(url)
        }
    }
}

struct AppIconView: View {
    let source: SourceApp
    @Dependency(\.imageLoader) private var loader
    @Environment(\.staticImages) private var staticImages
    @State private var image: CGImage?

    private var resolved: CGImage? { image ?? staticImages["app:" + (source.bundleID ?? source.name)] }

    var body: some View {
        ZStack {
            if let resolved {
                Image(decorative: resolved, scale: 2)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.dashed")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .task(id: source) {
            guard staticImages["app:" + (source.bundleID ?? source.name)] == nil else { return }
            image = await loader.appIcon(source)
        }
    }
}

private struct FileIconView: View {
    let path: String?

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 64, height: 64)
    }

    private var icon: NSImage {
        if let path { return NSWorkspace.shared.icon(forFile: path) }
        return NSWorkspace.shared.icon(for: .data)
    }
}
