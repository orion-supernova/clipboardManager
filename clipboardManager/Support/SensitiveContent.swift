//
//  SensitiveContent.swift
//  clipboardManager
//
//  Detects payment cards (Luhn), IBANs (mod-97), well-known API key/token
//  shapes, private keys and credential lines, and produces masked previews so
//  the raw value never appears in the list.
//

import Foundation

enum SensitiveKind: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case creditCard
    case iban
    case apiKey
    case privateKey
    case credential

    var title: String {
        switch self {
        case .creditCard: "Card"
        case .iban: "IBAN"
        case .apiKey: "Secret Key"
        case .privateKey: "Private Key"
        case .credential: "Credential"
        }
    }

    var symbol: String {
        switch self {
        case .creditCard: "creditcard.fill"
        case .iban: "building.columns.fill"
        case .apiKey: "key.fill"
        case .privateKey: "lock.doc.fill"
        case .credential: "person.badge.key.fill"
        }
    }
}

struct SensitiveMatch: Sendable, Equatable {
    var kind: SensitiveKind
    /// Preview-safe text with the secret replaced by bullets.
    var masked: String
    /// Extra label, e.g. the card brand.
    var detail: String?
}

enum SensitiveContent {
    private static let scanLimit = 8000

    static func detect(in rawText: String) -> SensitiveMatch? {
        let text = String(rawText.prefix(scanLimit))
        if let match = detectPrivateKey(text) { return match }
        if let match = detectAPIKey(text) { return match }
        if let match = detectCard(text) { return match }
        if let match = detectIBAN(text) { return match }
        if let match = detectCredential(text) { return match }
        return nil
    }

    // MARK: - Private keys

    private static func detectPrivateKey(_ text: String) -> SensitiveMatch? {
        guard text.contains("-----BEGIN"), text.contains("PRIVATE KEY-----") else { return nil }
        let lines = text.split(whereSeparator: \.isNewline).count
        return SensitiveMatch(kind: .privateKey, masked: "Private key · \(lines) lines", detail: nil)
    }

    // MARK: - API keys & tokens

    private static let apiKeyPatterns: [(pattern: String, label: String)] = [
        (#"\bsk-(?:proj-)?[A-Za-z0-9_-]{16,}"#, "OpenAI"),
        (#"\bAKIA[0-9A-Z]{16}\b"#, "AWS"),
        (#"\bgh[pousr]_[A-Za-z0-9]{30,}\b"#, "GitHub"),
        (#"\bgithub_pat_[A-Za-z0-9_]{40,}\b"#, "GitHub"),
        (#"\bxox[baprs]-[A-Za-z0-9-]{10,}"#, "Slack"),
        (#"\bAIza[0-9A-Za-z_-]{35}\b"#, "Google"),
        (#"\bsk_(?:live|test)_[A-Za-z0-9]{16,}\b"#, "Stripe"),
        (#"\bpk_(?:live|test)_[A-Za-z0-9]{16,}\b"#, "Stripe"),
        (#"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"#, "JWT"),
        (#"\bBearer\s+[A-Za-z0-9._~+/-]{20,}=*"#, "Bearer token"),
    ]

    private static func detectAPIKey(_ text: String) -> SensitiveMatch? {
        for entry in apiKeyPatterns {
            guard let regex = try? NSRegularExpression(pattern: entry.pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range, in: text)
            else { continue }
            let token = String(text[range])
            let masked = text.replacingCharacters(in: range, with: maskToken(token))
            return SensitiveMatch(kind: .apiKey, masked: TextClassifier.preview(for: masked), detail: entry.label)
        }
        return nil
    }

    private static func maskToken(_ token: String) -> String {
        guard token.count > 10 else { return String(repeating: "•", count: token.count) }
        let head = token.prefix(token.hasPrefix("Bearer ") ? 7 : 4)
        let tail = token.suffix(4)
        return "\(head)••••••••\(tail)"
    }

    // MARK: - Payment cards

    private static func detectCard(_ text: String) -> SensitiveMatch? {
        guard let regex = try? NSRegularExpression(pattern: #"(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)"#) else { return nil }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            let raw = String(text[range])
            let digits = raw.filter(\.isNumber)
            guard (13...19).contains(digits.count), luhnValid(digits), let brand = cardBrand(digits) else { continue }
            let masked = text.replacingCharacters(in: range, with: "•••• •••• •••• \(digits.suffix(4))")
            return SensitiveMatch(kind: .creditCard, masked: TextClassifier.preview(for: masked), detail: brand)
        }
        return nil
    }

    static func luhnValid(_ digits: String) -> Bool {
        var sum = 0
        for (offset, char) in digits.reversed().enumerated() {
            guard var value = char.wholeNumberValue else { return false }
            if offset % 2 == 1 {
                value *= 2
                if value > 9 { value -= 9 }
            }
            sum += value
        }
        return sum % 10 == 0
    }

    static func cardBrand(_ digits: String) -> String? {
        if digits.hasPrefix("4") { return "Visa" }
        if let two = Int(digits.prefix(2)), (51...55).contains(two) { return "Mastercard" }
        if let four = Int(digits.prefix(4)), (2221...2720).contains(four) { return "Mastercard" }
        if digits.hasPrefix("34") || digits.hasPrefix("37") { return "American Express" }
        if digits.hasPrefix("6011") || digits.hasPrefix("65") { return "Discover" }
        if digits.hasPrefix("35") { return "JCB" }
        if digits.hasPrefix("36") || digits.hasPrefix("38") { return "Diners Club" }
        if digits.hasPrefix("9792") { return "Troy" }
        return digits.count >= 15 ? "Card" : nil
    }

    // MARK: - IBAN

    private static func detectIBAN(_ text: String) -> SensitiveMatch? {
        guard let regex = try? NSRegularExpression(pattern: #"\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]{4}){2,7}(?:[ ]?[A-Z0-9]{1,4})?\b"#) else { return nil }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            let raw = String(text[range])
            let compact = raw.replacingOccurrences(of: " ", with: "")
            guard (15...34).contains(compact.count), ibanValid(compact) else { continue }
            let masked = text.replacingCharacters(in: range, with: "\(compact.prefix(2))•• •••• •••• \(compact.suffix(4))")
            return SensitiveMatch(kind: .iban, masked: TextClassifier.preview(for: masked), detail: String(compact.prefix(2)))
        }
        return nil
    }

    static func ibanValid(_ iban: String) -> Bool {
        let rearranged = iban.dropFirst(4) + iban.prefix(4)
        var remainder = 0
        for char in rearranged {
            let value: Int
            if let digit = char.wholeNumberValue {
                value = digit
            } else if let ascii = char.asciiValue, char.isLetter {
                value = Int(ascii) - 55 // A = 10
            } else {
                return false
            }
            let digits = value >= 10 ? 2 : 1
            remainder = (remainder * (digits == 2 ? 100 : 10) + value) % 97
        }
        return remainder == 1
    }

    // MARK: - Credential lines

    private static func detectCredential(_ text: String) -> SensitiveMatch? {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?im)^\s*(?:[\w.-]*(?:password|passwd|pwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token|private[_-]?key)[\w.-]*)\s*[:=]\s*["']?(\S+)"#
        ) else { return nil }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !matches.isEmpty else { return nil }
        var masked = text
        for match in matches.reversed() {
            guard match.numberOfRanges > 1, let valueRange = Range(match.range(at: 1), in: masked) else { continue }
            masked.replaceSubrange(valueRange, with: "••••••••")
        }
        return SensitiveMatch(kind: .credential, masked: TextClassifier.preview(for: masked), detail: nil)
    }
}
