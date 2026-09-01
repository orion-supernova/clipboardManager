//
//  PasteClient.swift
//  clipboardManager
//
//  Writes payloads back to the pasteboard (tagged with the app's own marker) and
//  simulates ⌘V in the frontmost app when Accessibility access is granted.
//

import AppKit
import ApplicationServices
import Carbon
import ComposableArchitecture

struct PasteClient: Sendable {
    var write: @Sendable (ClipboardPayload, _ markerID: UUID, _ plainText: Bool) async -> Void
    var simulatePaste: @Sendable () async -> Bool
    var isAccessibilityTrusted: @Sendable () -> Bool
    var requestAccessibility: @Sendable () -> Void
}

extension PasteClient: DependencyKey {
    static let liveValue = PasteClient(
        write: { payload, markerID, plainText in
            await MainActor.run {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                let item = NSPasteboardItem()
                item.setString(markerID.uuidString, forType: .ownMarker)

                switch payload.kind {
                case .text, .url, .color:
                    if let text = payload.text {
                        item.setString(text, forType: .string)
                        if payload.kind == .url, let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            item.setString(url.absoluteString, forType: .URL)
                        }
                    }
                    if !plainText, let rtf = payload.richText {
                        item.setData(rtf, forType: .rtf)
                    }
                case .image:
                    if let url = payload.imageFileURL, let png = try? Data(contentsOf: url) {
                        item.setData(png, forType: .png)
                        if let tiff = NSImage(data: png)?.tiffRepresentation {
                            item.setData(tiff, forType: .tiff)
                        }
                        item.setString(url.absoluteString, forType: .fileURL)
                    }
                case .file, .video:
                    if let url = payload.fileURL {
                        item.setString(url.absoluteString, forType: .fileURL)
                        item.setString(url.path, forType: .string)
                    }
                }
                pasteboard.writeObjects([item])
            }
        },
        simulatePaste: {
            await MainActor.run {
                guard AXIsProcessTrusted() else { return false }
                guard let keyCode = PasteKeyCode.shared.value else { return false }
                let source = CGEventSource(stateID: .combinedSessionState)
                guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
                      let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
                else { return false }
                down.flags = .maskCommand
                up.flags = .maskCommand
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
                return true
            }
        },
        isAccessibilityTrusted: { AXIsProcessTrusted() },
        requestAccessibility: {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    )

    static let previewValue = PasteClient(
        write: { _, _, _ in },
        simulatePaste: { true },
        isAccessibilityTrusted: { true },
        requestAccessibility: {}
    )
}

/// Resolves and caches the key code for "V" on the current keyboard layout.
@MainActor
private final class PasteKeyCode {
    static let shared = PasteKeyCode()
    private var cached: UInt16?
    private var layoutObserver: (any NSObjectProtocol)?

    private init() {
        layoutObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.cached = nil }
        }
    }

    var value: UInt16? {
        if let cached { return cached }
        let resolved = KeyboardLayout.keyCode(for: "v") ?? 0x09
        cached = resolved
        return resolved
    }
}

extension DependencyValues {
    var paste: PasteClient {
        get { self[PasteClient.self] }
        set { self[PasteClient.self] = newValue }
    }
}
