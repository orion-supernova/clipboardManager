//
//  HotKeyClient.swift
//  clipboardManager
//

import AppKit
import ComposableArchitecture
import HotKey

struct HotKeyClient: Sendable {
    /// Emits whenever the given shortcut is pressed anywhere in the system.
    var presses: @Sendable (KeyboardShortcutSpec) -> AsyncStream<Void>
}

extension HotKeyClient: DependencyKey {
    static let liveValue = HotKeyClient { spec in
        AsyncStream { continuation in
            let holder = HotKeyHolder()
            Task { @MainActor in
                guard let key = Key(carbonKeyCode: UInt32(spec.keyCode)) else {
                    continuation.finish()
                    return
                }
                let hotKey = HotKey(keyCombo: KeyCombo(key: key, modifiers: spec.modifierFlags))
                hotKey.keyDownHandler = { continuation.yield(()) }
                holder.hotKey = hotKey
            }
            continuation.onTermination = { _ in
                Task { @MainActor in holder.hotKey = nil }
            }
        }
    }

    static let previewValue = HotKeyClient { _ in AsyncStream { _ in } }
}

@MainActor
private final class HotKeyHolder: Sendable {
    nonisolated(unsafe) var hotKey: HotKey?
    nonisolated init() {}
}

extension DependencyValues {
    var hotKeys: HotKeyClient {
        get { self[HotKeyClient.self] }
        set { self[HotKeyClient.self] = newValue }
    }
}
