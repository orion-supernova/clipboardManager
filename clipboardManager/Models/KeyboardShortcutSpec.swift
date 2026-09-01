//
//  KeyboardShortcutSpec.swift
//  clipboardManager
//
//  A user-configurable global shortcut, persisted as JSON in UserDefaults.
//

import AppKit

struct KeyboardShortcutSpec: Codable, Equatable, Hashable, Sendable {
    var keyCode: UInt16
    /// `NSEvent.ModifierFlags.rawValue`, device-independent flags only.
    var modifiers: UInt

    static let `default` = KeyboardShortcutSpec(
        keyCode: 0x09, // V on ANSI layouts; resolved through the layout for display
        modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue
    )

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers).intersection(.deviceIndependentFlagsMask)
    }

    /// At least one of ⌘ ⌃ ⌥ so the shortcut can't swallow plain typing.
    var hasRequiredModifier: Bool {
        !modifierFlags.intersection([.command, .control, .option]).isEmpty
    }

    var modifierSymbols: String {
        var symbols = ""
        if modifierFlags.contains(.control) { symbols += "⌃" }
        if modifierFlags.contains(.option) { symbols += "⌥" }
        if modifierFlags.contains(.shift) { symbols += "⇧" }
        if modifierFlags.contains(.command) { symbols += "⌘" }
        return symbols
    }

    var keyLabel: String { KeyboardLayout.displayName(for: keyCode) }
    var display: String { modifierSymbols + keyLabel }

    /// The printable character for the key, if it has one (used for menu key equivalents).
    var keyCharacter: Character? {
        guard let text = KeyboardLayout.character(for: keyCode), text.count == 1,
              let char = text.first, !char.isWhitespace, !char.isNewline
        else { return nil }
        return Character(char.lowercased())
    }
}
