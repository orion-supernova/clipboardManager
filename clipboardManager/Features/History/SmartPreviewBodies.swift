//
//  SmartPreviewBodies.swift
//  clipboardManager
//
//  Previews for text that *is* something: the thing itself as a hero on the
//  left, what you can do with it as key-labelled tiles on the right. Objects,
//  not documents — so no reading surface and no 720pt text measure.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SmartBody: View {
    let item: ClipboardItem
    let text: String
    let primary: SmartAction
    let onAction: @MainActor (SmartAction) -> Void
    let onPasteOriginal: @MainActor () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 32) {
            VStack(alignment: .leading, spacing: 14) {
                hero
                if let context { contextLine(context) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            actionColumn
        }
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: Hero

    @ViewBuilder
    private var hero: some View {
        switch primary.kind {
        case let .email(address): EmailHero(address: address)
        case let .call(number), let .message(number): PhoneHero(number: number)
        case let .map(address): AddressHero(address: address)
        case let .addToCalendar(start, duration, allDay, title): DateHero(start: start, duration: duration, allDay: allDay, title: title)
        case let .track(number): TrackingHero(number: number, confident: primary.isPrimary)
        case let .flight(code): FlightHero(code: code)
        case let .openPath(path), let .showPath(path): PathHero(path: path)
        case let .openLinks(urls): LinksHero(urls: urls, onOpen: { onAction(SmartAction(kind: .openLink($0))) })
        case let .openLink(url): LinksHero(urls: [url], onOpen: { onAction(SmartAction(kind: .openLink($0))) })
        case let .pasteResult(result): CalcHero(expression: text, result: result)
        }
    }

    /// The copied text, when it says more than the detected thing.
    private var context: String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch primary.kind {
        case let .email(value), let .call(value), let .message(value), let .map(value), let .openPath(value), let .showPath(value), let .track(value):
            return trimmed.count > value.count + 4 ? trimmed : nil
        case .addToCalendar, .openLinks, .flight:
            return trimmed.count > 24 ? trimmed : nil
        default:
            return nil
        }
    }

    private func contextLine(_ text: String) -> some View {
        Label {
            Text(text).lineLimit(2)
        } icon: {
            Image(systemName: "text.quote")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    // MARK: Actions

    private var actionColumn: some View {
        VStack(spacing: 8) {
            if case let .pasteResult(result) = primary.kind {
                ActionTile(symbol: "equal.circle.fill", title: "Paste \(result)", subtitle: "The answer", key: item.key(for: primary) ?? "", isPrimary: true) { onAction(primary) }
                ActionTile(symbol: "function", title: "Paste Expression", subtitle: "As copied", key: "↩", isPrimary: false, action: onPasteOriginal)
            } else {
                ForEach(tileActions, id: \.id) { action in
                    ActionTile(
                        symbol: action.symbol,
                        title: action.title,
                        subtitle: action.destination,
                        key: key(for: action),
                        isPrimary: action.isPrimary
                    ) { onAction(action) }
                }
            }
        }
        .frame(width: 240)
    }

    /// The same key the item answers to everywhere: ⌘O / ⇧⌘R for open and show,
    /// the joker keys ⌘D / ⇧⌘D for the item's own actions.
    private func key(for action: SmartAction) -> String {
        item.key(for: action) ?? ""
    }

    /// Primary first, then the rest.
    private var tileActions: [SmartAction] {
        [primary] + item.smartActions.filter { $0 != primary && !Self.isSingleLink($0, in: primary) }.prefix(3)
    }

    /// With "Open All", the individual links are rows in the hero, not tiles.
    private static func isSingleLink(_ action: SmartAction, in primary: SmartAction) -> Bool {
        if case .openLinks = primary.kind, case .openLink = action.kind { return true }
        return false
    }
}

/// Digits open the individual rows of a several-links preview; every other
/// action has a fixed or joker key instead.
enum SmartPreviewKeys {
    static func action(forDigit digit: Int, in item: ClipboardItem) -> SmartAction? {
        guard digit >= 1, case let .openLinks(urls)? = item.primarySmartAction?.kind else { return nil }
        return urls.indices.contains(digit - 1) ? SmartAction(kind: .openLink(urls[digit - 1])) : nil
    }
}

// MARK: - Tiles

struct ActionTile: View {
    let symbol: String
    let title: String
    let subtitle: String?
    let key: String
    let isPrimary: Bool
    let action: @MainActor () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isPrimary ? Color.white : Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(isPrimary ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.accentColor.opacity(0.14)), in: .circle)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                KeyCap(key: key)
            }
            .padding(.horizontal, 12)
            .frame(height: 60)
            .background(background, in: .rect(cornerRadius: 14))
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle.map { "Opens \($0). Shortcut \(key)" } ?? "Shortcut \(key)")
    }

    private var background: AnyShapeStyle {
        if isPrimary { return AnyShapeStyle(Color.accentColor.opacity(hovering ? 0.26 : 0.18)) }
        return AnyShapeStyle(Color.primary.opacity(hovering ? 0.1 : 0.06))
    }
}

extension SmartAction {
    /// Where the action lands, as a tile subtitle.
    var destination: String? {
        switch kind {
        case .email: "Mail"
        case .call: "FaceTime"
        case .message: "Messages"
        case .map: "Apple Maps"
        case let .openLink(url): url.host()
        case .openLinks: "Browser"
        case .addToCalendar: "Calendar"
        case .openPath: "Default app"
        case .showPath: "Finder"
        case .track: "17TRACK"
        case .flight: "Web search"
        case .pasteResult: "The answer"
        }
    }

    /// What the copied text is, for card headers.
    var shortSubject: String {
        switch kind {
        case .email: "Email"
        case .call, .message: "Phone"
        case .map: "Address"
        case .openLink: "Link"
        case let .openLinks(urls): "\(urls.count) Links"
        case .addToCalendar: "Event"
        case .openPath, .showPath: "Path"
        case .track: "Tracking"
        case .flight: "Flight"
        case .pasteResult: "Sum"
        }
    }

    /// The thing itself, as opposed to `symbol` (what the action does).
    var subjectSymbol: String {
        switch kind {
        case .email: "envelope.fill"
        case .call, .message: "phone.fill"
        case .map: "mappin.and.ellipse"
        case .openLink: "link"
        case .openLinks: "link"
        case .addToCalendar: "calendar"
        case .openPath, .showPath: "folder.fill"
        case .track: "shippingbox.fill"
        case .flight: "airplane"
        case .pasteResult: "plus.forwardslash.minus"
        }
    }

    /// What the copied text is, for the preview header.
    var subjectTitle: String {
        switch kind {
        case .email: "Email address"
        case .call, .message: "Phone number"
        case .map: "Address"
        case .openLink: "Link"
        case let .openLinks(urls): "\(urls.count) links"
        case .addToCalendar: "Event"
        case .openPath, .showPath: "File path"
        case .track: "Tracking number"
        case .flight: "Flight"
        case .pasteResult: "Calculation"
        }
    }
}

// MARK: - Heroes

private struct EmailHero: View {
    let address: String

    var body: some View {
        let parts = address.split(separator: "@", maxSplits: 1).map(String.init)
        let local = parts.first ?? address
        let domain = parts.count > 1 ? "@" + parts[1] : ""
        HStack(spacing: 18) {
            Text(String(local.prefix(1)).uppercased())
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Hue.gradient(for: domain), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                (Text(local).foregroundStyle(.primary) + Text(domain).foregroundStyle(.secondary))
                    .font(.system(size: 28, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .textSelection(.enabled)
                Text("Email address").font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PhoneHero: View {
    let number: String

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "phone.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Color.green.gradient, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(number)
                    .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .textSelection(.enabled)
                Text(number.hasPrefix("+") ? "Phone number · international" : "Phone number")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AddressHero: View {
    let address: String

    var body: some View {
        let lines = address
            .split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        HStack(spacing: 20) {
            MapCard()
                .frame(width: 180, height: 140)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(lines.first ?? address)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                ForEach(Array(lines.dropFirst().enumerated()), id: \.offset) { _, line in
                    Text(line).font(.title3).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .textSelection(.enabled)
        }
    }
}

/// Reads as "a map" without MapKit or the network: a faint street grid and a pin.
private struct MapCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.06))
            Canvas { context, size in
                var streets = Path()
                for index in 0..<7 {
                    let offset = CGFloat(index) * size.width / 6
                    streets.move(to: CGPoint(x: offset, y: 0))
                    streets.addLine(to: CGPoint(x: offset - size.height * 0.35, y: size.height))
                }
                for index in 0..<5 {
                    let y = CGFloat(index) * size.height / 4 + 8
                    streets.move(to: CGPoint(x: 0, y: y))
                    streets.addLine(to: CGPoint(x: size.width, y: y - 18))
                }
                context.stroke(streets, with: .color(.primary.opacity(0.1)), lineWidth: 3)
                var avenue = Path()
                avenue.move(to: CGPoint(x: 0, y: size.height * 0.62))
                avenue.addCurve(to: CGPoint(x: size.width, y: size.height * 0.4),
                                control1: CGPoint(x: size.width * 0.35, y: size.height * 0.75),
                                control2: CGPoint(x: size.width * 0.6, y: size.height * 0.3))
                context.stroke(avenue, with: .color(.primary.opacity(0.16)), lineWidth: 6)
            }
            .clipShape(.rect(cornerRadius: 16))
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white, .red)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        }
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.08)))
    }
}

private struct DateHero: View {
    let start: Date
    let duration: TimeInterval
    let allDay: Bool
    let title: String

    var body: some View {
        HStack(spacing: 22) {
            VStack(spacing: 0) {
                Text(start.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(Color.red)
                Text(start.formatted(.dateTime.day()))
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .frame(maxHeight: .infinity)
                Text(start.formatted(.dateTime.weekday(.wide)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 10)
            }
            .frame(width: 120, height: 136)
            .background(Color.primary.opacity(0.06))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.08)))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                Text(when)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(relative)
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background((isPast ? Color.orange : Color.accentColor).opacity(0.16), in: .capsule)
                    .foregroundStyle(isPast ? Color.orange : Color.accentColor)
            }
        }
    }

    private var isPast: Bool { start < Date() && !Calendar.current.isDateInToday(start) }

    private var when: String {
        let day = start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        if allDay { return "\(day) · All day" }
        let end = start.addingTimeInterval(duration)
        return "\(day) · \(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
    }

    private var relative: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(start) { return "Today" }
        if calendar.isDateInTomorrow(start) { return "Tomorrow" }
        if calendar.isDateInYesterday(start) { return "Yesterday" }
        return start.formatted(.relative(presentation: .named, unitsStyle: .wide))
    }
}

private struct TrackingHero: View {
    let number: String
    let confident: Bool

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Color.brown.gradient, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(carrier)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08), in: .capsule)
                Text(grouped)
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .textSelection(.enabled)
                    .accessibilityLabel(number)
                if !confident {
                    Text("Might also be an order number")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var carrier: String {
        if number.hasPrefix("1Z") { return "UPS" }
        if number.hasPrefix("JD") || number.hasPrefix("JJD") { return "DHL" }
        if number.range(of: #"^[A-Z]{2}\d{9}[A-Z]{2}$"#, options: .regularExpression) != nil {
            return "Postal · \(number.suffix(2))"
        }
        return "Parcel"
    }

    /// Groups of four, the way carriers print them. Paste uses the raw value.
    private var grouped: String {
        stride(from: 0, to: number.count, by: 4).map { offset in
            let start = number.index(number.startIndex, offsetBy: offset)
            let end = number.index(start, offsetBy: 4, limitedBy: number.endIndex) ?? number.endIndex
            return String(number[start..<end])
        }.joined(separator: " ")
    }
}

private struct FlightHero: View {
    let code: String

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "airplane")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Color.blue.gradient, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(spaced)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .textSelection(.enabled)
                Text("Flight number").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    /// "TK1923" reads as "TK 1923".
    private var spaced: String {
        guard let split = code.firstIndex(where: \.isNumber), split > code.startIndex else { return code }
        return code[..<split].trimmingCharacters(in: .whitespaces) + " " + code[split...]
    }
}

private struct PathHero: View {
    let path: String

    var body: some View {
        let components = path.split(separator: "/").map(String.init)
        let name = components.last ?? path
        let folders = Array(components.dropLast())
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if folders.count > 5 { Text("…").foregroundStyle(.tertiary) }
                ForEach(Array(folders.suffix(5).enumerated()), id: \.offset) { index, folder in
                    if index > 0 || folders.count > 5 {
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                    }
                    Text(folder).foregroundStyle(.secondary)
                }
            }
            .font(.callout)
            .lineLimit(1)
            HStack(spacing: 14) {
                Image(nsImage: icon(for: name))
                    .resizable()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                Text(name)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Text(path)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.head)
                .textSelection(.enabled)
        }
    }

    /// From the extension alone: no file access, so it works in the sandbox.
    private func icon(for name: String) -> NSImage {
        let ext = (name as NSString).pathExtension
        let type = ext.isEmpty ? UTType.folder : (UTType(filenameExtension: ext) ?? .data)
        return NSWorkspace.shared.icon(for: type)
    }
}

private struct LinksHero: View {
    let urls: [URL]
    let onOpen: @MainActor (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(urls.prefix(5).enumerated()), id: \.offset) { index, url in
                LinkRow(url: url, key: "\(index + 1)") { onOpen(url) }
            }
            if urls.count > 5 {
                Text("+\(urls.count - 5) more")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 46)
            }
        }
    }
}

private struct LinkRow: View {
    let url: URL
    let key: String
    let action: @MainActor () -> Void
    @State private var hovering = false

    var body: some View {
        let host = url.host() ?? url.absoluteString
        Button(action: action) {
            HStack(spacing: 12) {
                KeyCap(key: key)
                Text(String(host.replacingOccurrences(of: "www.", with: "").prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Hue.gradient(for: host), in: .rect(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 0) {
                    Text(host).font(.callout.weight(.semibold)).lineLimit(1)
                    Text(url.path().isEmpty ? "/" : url.path())
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 40)
            .background(Color.primary.opacity(hovering ? 0.07 : 0), in: .rect(cornerRadius: 10))
            .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("Open \(host)")
    }
}

private struct CalcHero: View {
    let expression: String
    let result: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(expression.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 22, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .textSelection(.enabled)
            Text("= \(Self.grouped(result))")
                .font(.system(size: 64, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }

    /// 1234567.5 reads as 1,234,567.5; the pasted value stays raw.
    private static func grouped(_ result: String) -> String {
        guard let value = Double(result), abs(value) >= 10_000 else { return result }
        return value.formatted(.number.precision(.fractionLength(0...10)))
    }
}

/// A stable, pleasant hue per string (domain or host), for avatar placeholders.
enum Hue {
    static func gradient(for key: String) -> LinearGradient {
        let hash = key.unicodeScalars.reduce(UInt32(5381)) { ($0 &* 33) &+ $1.value }
        let hue = Double(hash % 360) / 360
        return LinearGradient(
            colors: [Color(hue: hue, saturation: 0.55, brightness: 0.85), Color(hue: hue, saturation: 0.7, brightness: 0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
