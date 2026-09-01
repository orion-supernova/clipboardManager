//
//  KeyboardLayout.swift
//  clipboardManager
//
//  Resolves the physical key that produces a character under the current
//  keyboard layout, so simulated ⌘V works on AZERTY/Dvorak/Turkish-F layouts too.
//

import Carbon
import Foundation

enum KeyboardLayout {
    static let escape: UInt16 = 0x35
    static let returnKey: UInt16 = 0x24
    static let keypadEnter: UInt16 = 0x4C
    static let tab: UInt16 = 0x30
    static let space: UInt16 = 0x31
    static let delete: UInt16 = 0x33
    static let forwardDelete: UInt16 = 0x75
    static let leftArrow: UInt16 = 0x7B
    static let rightArrow: UInt16 = 0x7C
    static let downArrow: UInt16 = 0x7D
    static let upArrow: UInt16 = 0x7E
    static let home: UInt16 = 0x73
    static let end: UInt16 = 0x77

    /// The two keys right of P on an ANSI board. They print `[` and `]` on US
    /// layouts and something else almost everywhere else — `ğ`/`ü` on Turkish,
    /// `ü`/`+` on German — so scope switching has to match the position rather
    /// than the character, or it silently does nothing outside the US.
    static let leftBracket: UInt16 = 0x21
    static let rightBracket: UInt16 = 0x1E

    static let modifierKeyCodes: Set<UInt16> = [0x37, 0x36, 0x38, 0x3C, 0x3A, 0x3D, 0x3B, 0x3E, 0x39, 0x3F]

    private static let specialNames: [UInt16: String] = [
        escape: "⎋", returnKey: "↩", keypadEnter: "⌤", tab: "⇥", space: "Space", delete: "⌫",
        forwardDelete: "⌦", leftArrow: "←", rightArrow: "→", downArrow: "↓", upArrow: "↑",
        home: "↖", end: "↘", 0x74: "⇞", 0x79: "⇟",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6", 0x62: "F7",
        0x64: "F8", 0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
    ]

    static func displayName(for keyCode: UInt16) -> String {
        if let special = specialNames[keyCode] { return special }
        return character(for: keyCode)?.uppercased() ?? "?"
    }

    static func character(for keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = unsafeBitCast(layoutPointer, to: CFData.self) as Data
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = layoutData.withUnsafeBytes { buffer -> OSStatus in
            guard let base = buffer.baseAddress else { return -1 }
            return UCKeyTranslate(
                base.assumingMemoryBound(to: UCKeyboardLayout.self),
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }

    /// Finds the key code that produces `character` (case-insensitive) on the current layout.
    static func keyCode(for character: String) -> UInt16? {
        let target = character.lowercased()
        for code in UInt16(0)..<128 where Self.character(for: code)?.lowercased() == target {
            return code
        }
        return nil
    }
}
