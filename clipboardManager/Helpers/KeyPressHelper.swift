//
//  KeyPressHelper.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 21.03.2023.
//

import AppKit

class KeyPressHelper {
    static func simulateKeyPressWithCommand(keyCode: UInt16) {

        let eventSource = CGEventSource(stateID: .combinedSessionState)
        let eventDown = CGEvent(keyboardEventSource: eventSource, virtualKey: CGKeyCode(keyCode), keyDown: true)!
        let eventUp = CGEvent(keyboardEventSource: eventSource, virtualKey: CGKeyCode(keyCode), keyDown: false)!

        eventDown.flags = CGEventFlags.maskCommand
        eventDown.post(tap: .cgAnnotatedSessionEventTap)
        eventUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}
