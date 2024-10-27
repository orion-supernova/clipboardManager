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

        eventDown.flags = .maskCommand
        eventDown.post(tap: .cgAnnotatedSessionEventTap)
        eventUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}

func simulatePasteAction() {
    // Get the current pasteboard
    let pasteboard = NSPasteboard.general
    
    // Create a new event for Command+V
    guard let pasteEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true) else {
        print("Failed to create paste event")
        return
    }
    
    // Set the Command modifier flag
    pasteEvent.flags = .maskCommand
    
    // Post the event
    pasteEvent.post(tap: .cghidEventTap)
    
    // Create and post the key up event
    pasteEvent.type = .keyUp
    pasteEvent.post(tap: .cghidEventTap)
}

func performPasteAction() {
//    // Get the current pasteboard
//    let pasteboard = NSPasteboard.general
//    
//    // Check if there's a string on the pasteboard
//    if let string = pasteboard.string(forType: .string) {
//        // Get the current app's keyWindow
//        if let keyWindow = NSApplication.shared.keyWindow {
//            // Get the first responder (the control that has focus)
//            if let firstResponder = keyWindow.firstResponder as? NSTextInputClient {
//                // Insert the string at the current insertion point
//                firstResponder.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0))
//            } else {
//                print("No suitable text input client found")
//            }
//        } else {
//            print("No key window found")
//        }
//    } else {
//        print("No string found on pasteboard")
//    }
    DispatchQueue.main.async {
        NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
    }
}
