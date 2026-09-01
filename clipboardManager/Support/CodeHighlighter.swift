//
//  CodeHighlighter.swift
//  clipboardManager
//
//  Cheap, regex-based language detection and token colouring — enough to make
//  code snippets instantly recognisable in cards and the quick preview.
//

import Foundation
import SwiftUI

enum CodeLanguage: String, Sendable, CaseIterable, Equatable {
    case swift, javascript, typescript, python, json, shell, html, css, sql, go, rust, ruby, java, kotlin, yaml, generic

    var displayName: String {
        switch self {
        case .swift: "Swift"
        case .javascript: "JavaScript"
        case .typescript: "TypeScript"
        case .python: "Python"
        case .json: "JSON"
        case .shell: "Shell"
        case .html: "HTML"
        case .css: "CSS"
        case .sql: "SQL"
        case .go: "Go"
        case .rust: "Rust"
        case .ruby: "Ruby"
        case .java: "Java"
        case .kotlin: "Kotlin"
        case .yaml: "YAML"
        case .generic: "Code"
        }
    }

    /// Returns `nil` when the text doesn't look like code at all.
    static func detect(_ rawText: String) -> CodeLanguage? {
        let text = String(rawText.prefix(1200))
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 12 else { return nil }

        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            if let data = rawText.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil {
                return .json
            }
        }
        if contains(text, #"^#!\s*/(?:usr/)?bin/(?:env\s+)?(?:ba|z|fi|da)?sh"#) || contains(text, #"(?m)^\s*(?:\$ |sudo |brew |git |npm |yarn |pnpm |cd |ls |echo |export |chmod |curl |xcodebuild |swift )"#) {
            return .shell
        }
        if contains(text, #"<(?:!DOCTYPE|html|div|span|body|head|section|p|a|ul|li)\b"#) && text.contains(">") { return .html }
        if contains(text, #"\b(?:func|let|var)\b"#) && (contains(text, #"->|@State|@Observable|import (?:Foundation|SwiftUI|UIKit|AppKit)|\bguard\b|\bsome View\b"#)) { return .swift }
        if contains(text, #"(?m)^\s*(?:def|class)\s+\w+.*:\s*$"#) || contains(text, #"\bimport \w+\s*$"#) && text.contains("self") || contains(text, #"\b(?:elif|None|print\()"#) { return .python }
        if contains(text, #"\binterface\s+\w+|:\s*(?:string|number|boolean)\b|<[A-Z]\w*>"#) && contains(text, #"\b(?:const|let|function|=>)\b"#) { return .typescript }
        if contains(text, #"\b(?:const|let|var)\b.*=|=>|\bfunction\b|console\.log|require\("#) { return .javascript }
        if contains(text, #"(?i)\b(?:select\s.+\sfrom|insert\s+into|update\s+\w+\s+set|create\s+table|delete\s+from)\b"#) { return .sql }
        if contains(text, #"\bfn\s+\w+|\blet\s+mut\b|\bimpl\b|::\w+"#) { return .rust }
        if contains(text, #"\bfunc\s+(?:\(\w+ \*?\w+\)\s*)?\w+\(|\bpackage\s+\w+|:="#) { return .go }
        if contains(text, #"\b(?:fun|val)\s+\w+|\bdata class\b"#) { return .kotlin }
        if contains(text, #"public\s+(?:static\s+)?(?:void|class)|System\.out|@Override"#) { return .java }
        if contains(text, #"(?m)^\s*(?:def|end)\b|\bputs\b|\bdo \|"#) { return .ruby }
        if contains(text, #"(?m)^\s*[.#]?[\w-]+\s*\{[^}]*(?:color|margin|padding|font|display|width)\s*:"#) { return .css }
        if contains(text, #"(?m)^\s*[\w-]+:\s+\S"#) && !text.contains("{") && lines(text) >= 3 { return .yaml }
        return TextClassifier.looksLikeCode(rawText) ? .generic : nil
    }

    private static func contains(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func lines(_ text: String) -> Int {
        text.split(whereSeparator: \.isNewline).count
    }

    var keywords: Set<String> {
        switch self {
        case .swift:
            ["func", "let", "var", "if", "else", "guard", "return", "struct", "class", "enum", "protocol", "extension", "import", "for", "in", "while", "switch", "case", "default", "where", "self", "Self", "true", "false", "nil", "throws", "throw", "try", "await", "async", "some", "any", "private", "public", "internal", "static", "final", "init", "defer", "break", "continue", "override", "mutating", "typealias", "associatedtype", "inout", "do", "catch", "as", "is"]
        case .javascript, .typescript:
            ["const", "let", "var", "function", "return", "if", "else", "for", "while", "switch", "case", "default", "break", "continue", "new", "class", "extends", "import", "export", "from", "async", "await", "try", "catch", "finally", "throw", "typeof", "instanceof", "this", "null", "undefined", "true", "false", "interface", "type", "enum", "implements", "public", "private", "readonly", "of", "in", "yield", "delete"]
        case .python:
            ["def", "class", "return", "if", "elif", "else", "for", "while", "in", "import", "from", "as", "try", "except", "finally", "with", "lambda", "yield", "pass", "break", "continue", "None", "True", "False", "and", "or", "not", "is", "raise", "async", "await", "global", "self", "del"]
        case .shell:
            ["if", "then", "else", "fi", "for", "do", "done", "while", "case", "esac", "in", "function", "return", "export", "local", "echo", "sudo", "exit", "set"]
        case .sql:
            ["select", "from", "where", "insert", "into", "values", "update", "set", "delete", "create", "table", "drop", "alter", "join", "left", "right", "inner", "outer", "on", "and", "or", "not", "null", "order", "by", "group", "having", "limit", "as", "distinct", "primary", "key", "index", "SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "TABLE", "DROP", "ALTER", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "AND", "OR", "NOT", "NULL", "ORDER", "BY", "GROUP", "HAVING", "LIMIT", "AS", "DISTINCT", "PRIMARY", "KEY", "INDEX"]
        case .go:
            ["func", "package", "import", "return", "if", "else", "for", "range", "var", "const", "type", "struct", "interface", "map", "chan", "go", "defer", "select", "case", "switch", "default", "nil", "true", "false", "break", "continue", "fallthrough"]
        case .rust:
            ["fn", "let", "mut", "impl", "struct", "enum", "trait", "pub", "use", "mod", "return", "if", "else", "match", "for", "in", "while", "loop", "self", "Self", "true", "false", "async", "await", "move", "ref", "where", "unsafe", "const", "static", "dyn", "as", "crate", "super"]
        case .ruby:
            ["def", "end", "class", "module", "if", "elsif", "else", "unless", "return", "do", "while", "until", "for", "in", "yield", "begin", "rescue", "ensure", "self", "nil", "true", "false", "puts", "require", "attr_accessor", "and", "or", "not"]
        case .java, .kotlin:
            ["public", "private", "protected", "class", "interface", "static", "final", "void", "return", "if", "else", "for", "while", "new", "this", "null", "true", "false", "import", "package", "try", "catch", "finally", "throw", "throws", "extends", "implements", "fun", "val", "var", "when", "object", "data", "override", "suspend", "in", "is", "as"]
        case .css:
            ["important", "media", "import", "keyframes", "font-face"]
        case .yaml, .json, .html, .generic:
            ["true", "false", "null", "yes", "no"]
        }
    }

    var usesHashComments: Bool {
        switch self {
        case .python, .shell, .ruby, .yaml: true
        default: false
        }
    }
}

enum CodeHighlighter {
    private static let keywordColor = Color(red: 0.68, green: 0.30, blue: 0.75)
    private static let stringColor = Color(red: 0.84, green: 0.40, blue: 0.25)
    private static let numberColor = Color(red: 0.20, green: 0.50, blue: 0.85)
    private static let commentColor = Color(red: 0.45, green: 0.55, blue: 0.45)
    private static let maxLength = 20_000

    private static func tokenRegex(hashComments: Bool) -> NSRegularExpression? {
        let comment = hashComments
            ? #"#[^\n]*|//[^\n]*|/\*[\s\S]*?\*/"#
            : #"//[^\n]*|/\*[\s\S]*?\*/|<!--[\s\S]*?-->"#
        let pattern = "(?<comment>\(comment))|(?<string>\"(?:\\\\.|[^\"\\\\\\n])*\"|'(?:\\\\.|[^'\\\\\\n])*'|`(?:\\\\.|[^`\\\\])*`)|(?<number>\\b\\d+(?:\\.\\d+)?\\b)|(?<word>\\b[A-Za-z_][A-Za-z0-9_-]*\\b)"
        return try? NSRegularExpression(pattern: pattern)
    }

    static func attributed(_ rawText: String, language: CodeLanguage, highlight query: String = "") -> AttributedString {
        let text = rawText.count > maxLength ? String(rawText.prefix(maxLength)) : rawText
        var result = query.isEmpty ? AttributedString(text) : Highlighter.attributed(text, matching: query)
        guard let regex = tokenRegex(hashComments: language.usesHashComments) else { return result }
        let keywords = language.keywords
        let nsRange = NSRange(text.startIndex..., in: text)

        regex.enumerateMatches(in: text, range: nsRange) { match, _, _ in
            guard let match else { return }
            let color: Color?
            let group: String
            if match.range(withName: "comment").location != NSNotFound {
                color = commentColor; group = "comment"
            } else if match.range(withName: "string").location != NSNotFound {
                color = stringColor; group = "string"
            } else if match.range(withName: "number").location != NSNotFound {
                color = numberColor; group = "number"
            } else if match.range(withName: "word").location != NSNotFound,
                      let range = Range(match.range(withName: "word"), in: text),
                      keywords.contains(String(text[range])) {
                color = keywordColor; group = "word"
            } else {
                return
            }
            guard let color,
                  let range = Range(match.range(withName: group), in: text),
                  let lower = AttributedString.Index(range.lowerBound, within: result),
                  let upper = AttributedString.Index(range.upperBound, within: result)
            else { return }
            result[lower..<upper].foregroundColor = color
            if group == "comment" { result[lower..<upper].inlinePresentationIntent = .emphasized }
            if group == "word" { result[lower..<upper].inlinePresentationIntent = .stronglyEmphasized }
        }
        return result
    }
}
