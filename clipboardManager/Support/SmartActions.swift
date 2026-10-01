//
//  SmartActions.swift
//  clipboardManager
//
//  Recognises what a copied text *is* — an email address, a phone number, an
//  address, a date, a path, a tracking or flight number, a sum, a handful of
//  links — and offers the obvious thing to do with it. Runs once per item, off
//  the main thread, on the stored preview (≤ 400 characters).
//

import Foundation

struct SmartAction: Equatable, Hashable, Sendable, Identifiable {
    enum Kind: Equatable, Hashable, Sendable {
        case email(String)
        case call(String)
        case message(String)
        case map(String)
        case openLink(URL)
        case openLinks([URL])
        case addToCalendar(start: Date, duration: TimeInterval, allDay: Bool, title: String)
        case openPath(String)
        case showPath(String)
        case track(String)
        case flight(String)
        case pasteResult(String)
    }

    let kind: Kind
    /// The one action ⌘O runs: the text is essentially this thing.
    var isPrimary = false

    var id: String { "\(kind)" }

    /// Actions that mean the same thing as an app-wide shortcut answer to that
    /// shortcut everywhere, never to a per-item digit: muscle memory holds.
    var fixedKey: String? {
        switch kind {
        case .showPath: "⇧⌘R"
        default: nil
        }
    }

    var title: String {
        switch kind {
        case .email: "Write Email"
        case .call: "Call"
        case .message: "Send Message"
        case .map: "Open in Maps"
        case let .openLink(url): url.host().map { "Open \($0)" } ?? "Open Link"
        case let .openLinks(urls): "Open All \(urls.count) Links"
        case .addToCalendar: "Add to Calendar"
        case .openPath: "Open"
        case .showPath: "Show in Finder"
        case .track: "Track Package"
        case .flight: "Flight Status"
        case let .pasteResult(result): "Paste \(result)"
        }
    }

    var symbol: String {
        switch kind {
        case .email: "envelope"
        case .call: "phone"
        case .message: "message"
        case .map: "map"
        case .openLink: "safari"
        case .openLinks: "square.stack.3d.up"
        case .addToCalendar: "calendar.badge.plus"
        case .openPath: "arrow.up.forward.app"
        case .showPath: "folder"
        case .track: "shippingbox"
        case .flight: "airplane"
        case .pasteResult: "equal.circle"
        }
    }

    /// Where opening the action goes, for the kinds that are just a URL.
    var url: URL? {
        switch kind {
        case let .email(address):
            return URL(string: "mailto:\(address)")
        case let .call(number):
            return URL(string: "tel:\(Self.dialable(number))")
        case let .message(number):
            return URL(string: "sms:\(Self.dialable(number))")
        case let .map(address):
            return Self.query("https://maps.apple.com/", ["q": address])
        case let .openLink(url):
            return url
        case let .track(number):
            return Self.query("https://t.17track.net/en", [:]).flatMap { URL(string: "\($0.absoluteString)#nums=\(number)") }
        case let .flight(code):
            return Self.query("https://www.google.com/search", ["q": "\(code) flight status"])
        case .openLinks, .addToCalendar, .openPath, .showPath, .pasteResult:
            return nil
        }
    }

    private static func dialable(_ number: String) -> String {
        number.filter { $0.isNumber || $0 == "+" }
    }

    private static func query(_ base: String, _ items: [String: String]) -> URL? {
        var components = URLComponents(string: base)
        if !items.isEmpty { components?.queryItems = items.map { URLQueryItem(name: $0.key, value: $0.value) } }
        return components?.url
    }
}

enum SmartDetector {
    /// Short text with a single recognisable thing in it is "about" that thing.
    private static let shortText = 160
    /// …and so is longer text that is mostly that thing.
    private static let dominantShare = 0.7

    private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType([.link, .phoneNumber, .address, .date, .transitInformation]).rawValue
    )

    static func actions(for rawText: String) -> [SmartAction] {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 400 else { return [] }

        // Whole-text shapes first: these are unambiguous when they match.
        if let result = Calculator.evaluate(text) {
            return [SmartAction(kind: .pasteResult(result), isPrimary: true)]
        }
        if let path = path(in: text) {
            // Same keys as a copied file: ⌘O opens it, ⇧⌘R shows it in Finder.
            return [SmartAction(kind: .openPath(path), isPrimary: true), SmartAction(kind: .showPath(path))]
        }
        if let tracking = trackingNumber(in: text) {
            return [SmartAction(kind: .track(tracking.number), isPrimary: tracking.confident)]
        }
        if let code = flightCode(in: text) {
            return [SmartAction(kind: .flight(code), isPrimary: true)]
        }

        guard let detector else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, range: range)
        guard !matches.isEmpty else { return [] }

        let length = Double((text as NSString).length)
        let single = matches.count == 1 && text.count <= shortText
        func dominates(_ match: NSTextCheckingResult) -> Bool {
            single || Double(match.range.length) / length >= dominantShare
        }

        var actions: [SmartAction] = []
        var webLinks: [URL] = []
        var linkLength = 0
        for match in matches {
            let primary = dominates(match)
            switch match.resultType {
            case .link:
                guard let url = match.url else { continue }
                if url.scheme?.lowercased() == "mailto" {
                    let address = url.absoluteString.dropFirst("mailto:".count)
                    actions.append(SmartAction(kind: .email(String(address)), isPrimary: primary))
                } else if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                    webLinks.append(url)
                    linkLength += match.range.length
                    actions.append(SmartAction(kind: .openLink(url), isPrimary: primary))
                }
            case .phoneNumber:
                guard let number = match.phoneNumber else { continue }
                actions.append(SmartAction(kind: .call(number), isPrimary: primary))
                actions.append(SmartAction(kind: .message(number)))
            case .address:
                guard let matched = Range(match.range, in: text) else { continue }
                actions.append(SmartAction(kind: .map(String(text[matched])), isPrimary: primary))
            case .date:
                guard let date = match.date, let matched = Range(match.range, in: text) else { continue }
                let dateText = String(text[matched])
                // "12 Oct" or "2026-10-01" with no time is a day, not midnight.
                let hasTime = dateText.range(of: #"\d[:.]\d{2}|\d\s?(?:am|pm|a\.m\.|p\.m\.)|noon|midnight|öğlen|akşam|sabah"#, options: [.regularExpression, .caseInsensitive]) != nil
                var title = text
                title.removeSubrange(matched)
                title = title.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                actions.append(SmartAction(
                    kind: .addToCalendar(
                        start: date,
                        duration: match.duration > 0 ? match.duration : 3600,
                        allDay: !hasTime,
                        title: title.isEmpty ? "Event" : String(title.prefix(80))
                    ),
                    isPrimary: primary
                ))
            case .transitInformation:
                guard let components = match.components,
                      let flight = components[.flight]
                else { continue }
                let code = (components[.airline].map { "\($0) " } ?? "") + flight
                actions.append(SmartAction(kind: .flight(code), isPrimary: primary))
            default:
                continue
            }
        }

        // Several links: one action to open them all, primary when they are the text.
        if webLinks.count >= 2 {
            let primary = Double(linkLength) / length >= dominantShare
            if primary { actions = actions.map { var action = $0; action.isPrimary = false; return action } }
            actions.insert(SmartAction(kind: .openLinks(webLinks), isPrimary: primary), at: 0)
        }

        // At most one primary, and it comes first.
        var seen = Set<SmartAction.Kind>()
        var result: [SmartAction] = []
        var hasPrimary = false
        for var action in actions.sorted(by: { $0.isPrimary && !$1.isPrimary }) where seen.insert(action.kind).inserted {
            if action.isPrimary {
                if hasPrimary { action.isPrimary = false } else { hasPrimary = true }
            }
            result.append(action)
        }
        return result
    }

    // MARK: Paths

    /// One line starting at the root or the home folder: `/Users/x/a.txt`, `~/Documents`.
    private static func path(in text: String) -> String? {
        guard text.count <= 1024, !text.contains("\n"), !text.contains("://"),
              text.hasPrefix("/") || text.hasPrefix("~/"),
              text.count > 2, text.dropFirst().contains(where: { $0.isLetter })
        else { return nil }
        return text
    }

    // MARK: Tracking numbers

    private static let trackingPatterns = [
        #"^1Z[0-9A-Z]{16}$"#,           // UPS
        #"^[A-Z]{2}\d{9}[A-Z]{2}$"#,    // UPU S10: postal services incl. PTT, Royal Mail, USPS international
        #"^J{1,2}D\d{9,18}$"#,          // DHL eCommerce / Express
        #"^\d{12}$|^\d{15}$|^\d{20}$|^\d{22}$"#, // FedEx, USPS: only when the text is nothing else
    ]

    /// Digits-only matches are offered but never primary: a 12-digit number is
    /// as likely an order ID as a FedEx parcel.
    private static func trackingNumber(in text: String) -> (number: String, confident: Bool)? {
        let compact = text.uppercased().replacingOccurrences(of: " ", with: "")
        guard compact.count <= 34 else { return nil }
        for pattern in trackingPatterns where compact.range(of: pattern, options: .regularExpression) != nil {
            return (compact, !compact.allSatisfy(\.isNumber))
        }
        return nil
    }

    // MARK: Flights

    /// "TK1", "LH 400", or a code next to the word flight / uçuş. Never a bare
    /// code inside other text: "PR 123 merged" is not a flight.
    private static func flightCode(in text: String) -> String? {
        let code = #"([A-Z][A-Z0-9])\s?(\d{1,4})"#
        if let match = text.range(of: "^" + code + "$", options: .regularExpression) {
            return String(text[match]).replacingOccurrences(of: " ", with: "")
        }
        guard text.count <= 80,
              let keyword = try? NSRegularExpression(pattern: #"(?i)\b(?:flight|uçuş|ucus|sefer)\b\W{0,3}"# + code + #"\b|\b"# + code + #"\W{0,3}(?i:flight|uçuş|ucus|sefer)\b"#),
              let match = keyword.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        let groups = match.range(at: 1).location != NSNotFound ? (1, 2) : (3, 4)
        guard let airline = Range(match.range(at: groups.0), in: text), let number = Range(match.range(at: groups.1), in: text) else { return nil }
        return String(text[airline]) + String(text[number])
    }
}

/// A small, safe arithmetic evaluator: numbers, + − × ÷ ^ %, parentheses.
/// Deliberately not NSExpression, which can call arbitrary selectors.
enum Calculator {
    /// A plain character set, not a `CharacterSet` passed as `allowed.contains`: in the
    /// optimised app build that method reference rejected every character.
    private static let allowed: Set<Character> = Set("0123456789.,+-*/×÷x^%() \t")

    static func evaluate(_ text: String) -> String? {
        guard text.count <= 120,
              text.allSatisfy({ allowed.contains($0) }),
              text.contains(where: \.isNumber),
              // Dates and version-like strings are not sums.
              text.range(of: #"^\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}$"#, options: .regularExpression) == nil
        else { return nil }
        var expression = text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\t", with: "")
        // 7,5 is a decimal in most of the world; 1,000.5 has a thousands comma.
        expression = expression.contains(".") ? expression.replacingOccurrences(of: ",", with: "") : expression.replacingOccurrences(of: ",", with: ".")
        expression = expression.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "x", with: "*").replacingOccurrences(of: "÷", with: "/")
        // Needs a real operator between operands, not just a sign: "-5" is a number.
        guard expression.dropFirst().contains(where: { "+-*/^%".contains($0) }) else { return nil }
        // "3-4" and "12-34" are ranges or IDs; a minus counts only with spaces ("10 - 3")
        // or alongside another operator.
        if text.range(of: #"^\d+-\d+$"#, options: .regularExpression) != nil { return nil }

        var parser = Parser(Array(expression))
        guard let value = parser.parseExpression(), parser.isAtEnd, value.isFinite else { return nil }
        return format(value)
    }

    private static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 10
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private struct Parser {
        let chars: [Character]
        var index = 0

        init(_ chars: [Character]) { self.chars = chars }

        var isAtEnd: Bool { index == chars.count }

        mutating func parseExpression() -> Double? {
            guard var value = parseTerm() else { return nil }
            while let op = peek(), op == "+" || op == "-" {
                index += 1
                guard let rhs = parseTerm() else { return nil }
                value = op == "+" ? value + rhs : value - rhs
            }
            return value
        }

        mutating func parseTerm() -> Double? {
            guard var value = parsePower() else { return nil }
            while let op = peek(), op == "*" || op == "/" {
                index += 1
                guard let rhs = parsePower() else { return nil }
                if op == "/" { guard rhs != 0 else { return nil }; value /= rhs } else { value *= rhs }
            }
            return value
        }

        mutating func parsePower() -> Double? {
            guard let base = parseUnary() else { return nil }
            if peek() == "^" {
                index += 1
                guard let exponent = parsePower() else { return nil }
                return pow(base, exponent)
            }
            return base
        }

        mutating func parseUnary() -> Double? {
            if peek() == "-" { index += 1; return parseUnary().map { -$0 } }
            if peek() == "+" { index += 1; return parseUnary() }
            return parsePercent()
        }

        mutating func parsePercent() -> Double? {
            guard var value = parsePrimary() else { return nil }
            while peek() == "%" { index += 1; value /= 100 }
            return value
        }

        mutating func parsePrimary() -> Double? {
            if peek() == "(" {
                index += 1
                guard let value = parseExpression(), peek() == ")" else { return nil }
                index += 1
                return value
            }
            let start = index
            while let char = peek(), char.isNumber || char == "." { index += 1 }
            guard index > start else { return nil }
            return Double(String(chars[start..<index]))
        }

        func peek() -> Character? { index < chars.count ? chars[index] : nil }
    }
}
