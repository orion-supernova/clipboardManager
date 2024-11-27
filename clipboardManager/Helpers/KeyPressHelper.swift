//
//  KeyPressHelper.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 21.03.2023.
//

import AppKit
import ServiceManagement
import Carbon


class KeyPressHelper {
    static let shared = KeyPressHelper()
    
    func simulateKeyPressWithCommand(keyCode: UInt16) {

        let eventSource = CGEventSource(stateID: .combinedSessionState)
        let eventDown = CGEvent(keyboardEventSource: eventSource, virtualKey: CGKeyCode(keyCode), keyDown: true)!
        let eventUp = CGEvent(keyboardEventSource: eventSource, virtualKey: CGKeyCode(keyCode), keyDown: false)!

        eventDown.flags = .maskCommand
        eventDown.post(tap: .cgAnnotatedSessionEventTap)
        eventUp.post(tap: .cgAnnotatedSessionEventTap)
    }
    
    func performPasteActionWithGettingVKey() {
            // Iterate through known key codes to find the one matching "V"
        let targetCharacter = "v" // The desired key for paste action
        var keyCodeForCharacter: UInt16?
        
        for keyCode in 0..<128 { // Iterate through possible key codes
            if getKeyboardCharacter(for: UInt16(keyCode)).lowercased() == targetCharacter {
                keyCodeForCharacter = UInt16(keyCode)
                break
            }
        }
        
        guard let keyCode = keyCodeForCharacter else {
            print("Could not find the key code for character \(targetCharacter).")
            return
        }
        
        // Simulate Command+V key press
        DispatchQueue.main.asyncAfter(deadline: .now()+0.2) {
            self.simulateKeyPressWithCommand(keyCode: keyCode)
        }

    }

    func getKeyboardCharacter(for keyCode: UInt16) -> String {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData),
              let keyboardLayout = unsafeBitCast(layoutData, to: CFData.self) as Data? else {
            return ","
        }
        
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        
        return keyboardLayout.withUnsafeBytes { ptr -> String in
            guard let baseAddress = ptr.baseAddress else { return "," }
            
            let status = UCKeyTranslate(
                baseAddress.assumingMemoryBound(to: UCKeyboardLayout.self),
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                4,
                &length,
                &chars
            )
            
            if status == noErr {
                return String(utf16CodeUnits: chars, count: length)
            }
            
            return ","
        }
    }
}


