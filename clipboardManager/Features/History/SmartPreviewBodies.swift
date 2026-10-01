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

    /// The thing itself, centred in the sheet. The actions live in the header
    /// (with the same keys everywhere), so the body doesn't repeat them.
    var body: some View {
        VStack(spacing: 18) {
            hero
            // The copied text is the header title now, so no context line repeating it.
            if case let .pasteResult(result) = primary.kind {
                keyLine(result)
            }
        }
        .frame(maxWidth: 820)
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func keyLine(_ result: String) -> some View {
        HStack(spacing: 6) {
            KeyCap(key: item.key(for: primary) ?? "")
            Text("pastes \(result) ·")
            KeyCap(key: "↩")
            Text("pastes the expression")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
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

}


extension SmartAction {
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
        case .pasteResult: "Calculation"
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
            EmailAvatar(address: address, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                (Text(local).foregroundStyle(.primary) + Text(domain).foregroundStyle(.secondary))
                    .font(.system(size: 28, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct PhoneHero: View {
    let number: String

    var body: some View {
        HStack(spacing: 18) {
            TypeTile(style: SmartAction(kind: .call("")).style, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(number)
                    .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .textSelection(.enabled)
                if let region = PhoneRegion.name(for: number) {
                    Text(region).font(.callout).foregroundStyle(.secondary)
                }
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
struct MapCard: View {
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
            CalendarPage(date: start, width: 112)
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
            TypeTile(style: SmartAction(kind: .track("")).style, size: 72)
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
            TypeTile(style: SmartAction(kind: .flight("")).style, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(spaced)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .textSelection(.enabled)
                if let airline = Airline.name(for: code) {
                    Text(airline).font(.callout).foregroundStyle(.secondary)
                }
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
                LinkRow(url: url) { onOpen(url) }
            }
            if urls.count > 5 {
                Text("+\(urls.count - 5) more · ⌘O lists them all")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 46)
            }
        }
        .frame(width: 460)
    }
}

private struct LinkRow: View {
    let url: URL
    let action: @MainActor () -> Void
    @State private var hovering = false

    var body: some View {
        let host = url.host() ?? url.absoluteString
        Button(action: action) {
            HStack(spacing: 12) {
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
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .opacity(hovering ? 1 : 0.5)
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

/// A file type's icon from its name alone: no file access, so it works in the sandbox.
enum FileTypeIcon {
    static func icon(forName name: String) -> NSImage {
        let ext = (name as NSString).pathExtension
        let type = ext.isEmpty ? UTType.folder : (UTType(filenameExtension: ext) ?? .data)
        return NSWorkspace.shared.icon(for: type)
    }
}

/// A stable, pleasant hue per string (domain or host), for avatar placeholders.
enum Hue {
    /// Top and bottom of the same hue's gradient, for tiles.
    static func pair(for key: String) -> (Color, Color) {
        let hash = key.unicodeScalars.reduce(UInt32(5381)) { ($0 &* 33) &+ $1.value }
        let hue = Double(hash % 360) / 360
        return (Color(hue: hue, saturation: 0.55, brightness: 0.85), Color(hue: hue, saturation: 0.7, brightness: 0.6))
    }

    static func color(for key: String) -> Color {
        let hash = key.unicodeScalars.reduce(UInt32(5381)) { ($0 &* 33) &+ $1.value }
        return Color(hue: Double(hash % 360) / 360, saturation: 0.55, brightness: 0.85)
    }

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
