//
//  ClipboardApp.swift
//  clipboardManager
//

import ComposableArchitecture
import SwiftUI

@main
struct ClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu(store: appDelegate.store)
        } label: {
            MenuBarLabel(store: appDelegate.store)
        }
    }
}

private struct MenuBarLabel: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        if store.history.capturePaused {
            Image(systemName: "pause.circle")
        } else if store.availableUpdate != nil {
            Image(systemName: "list.clipboard.fill")
        } else {
            Image(systemName: "list.clipboard")
        }
    }
}

private struct MenuBarMenu: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        showButton
        if let update = store.availableUpdate {
            Button("Update to \(update.listing.version)…") { store.send(.menuOpenUpdate) }
        }
        Divider()
        Toggle("Pause Capturing", isOn: Binding(store.history.$capturePaused))
        Button("Settings…") { store.send(.menuOpenSettings) }
            .keyboardShortcut(",")
        Button("Clear History…") { store.send(.menuClearHistory) }
        Divider()
        Button("Quit Mahmut") { store.send(.menuQuit) }
            .keyboardShortcut("q")
    }

    @ViewBuilder
    private var showButton: some View {
        let shortcut = store.toggleShortcut
        if let character = shortcut.keyCharacter {
            Button("Show Clipboard") { store.send(.menuShowPanel) }
                .keyboardShortcut(KeyEquivalent(character), modifiers: EventModifiers(shortcut.modifierFlags))
        } else {
            Button("Show Clipboard  \(shortcut.display)") { store.send(.menuShowPanel) }
        }
    }
}

private extension EventModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        var modifiers: EventModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        self = modifiers
    }
}
