//
//  AppDelegate.swift
//  clipboardManager
//
//  Builds the store with live AppKit-backed dependencies and hosts the two
//  windows (floating panel, settings). No business logic lives here.
//

import AppKit
import ComposableArchitecture
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store: StoreOf<AppFeature>
    private let panelController: PanelController
    private let settingsWindowController: SettingsWindowController

    override init() {
        let panelController = PanelController()
        let settingsWindowController = SettingsWindowController()
        self.panelController = panelController
        self.settingsWindowController = settingsWindowController

        store = Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: { dependencies in
            dependencies.panel = PanelClient(
                show: { await panelController.show() },
                hide: { await panelController.hide() },
                resize: { await panelController.resize(to: $0) },
                events: { panelController.makeEventStream() }
            )
            dependencies.settingsWindow = SettingsWindowClient(
                open: { await settingsWindowController.present() }
            )
        }
        super.init()

        panelController.install(
            HistoryView(store: store.scope(state: \.history, action: \.history))
        )
        settingsWindowController.install(
            SettingsView(store: store.scope(state: \.settings, action: \.settings))
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.send(.appLaunched)
        #if DEBUG
        // Developer conveniences: preview the panel or settings without the hotkey.
        let environment = ProcessInfo.processInfo.environment
        if environment["MAHMUT_SHOW_PANEL"] == "1" {
            Task { @MainActor [store] in
                try? await Task.sleep(for: .seconds(1))
                store.send(.menuShowPanel)
            }
        }
        if environment["MAHMUT_SHOW_SETTINGS"] == "1" { store.send(.menuOpenSettings) }
        if environment["MAHMUT_RENDER_MARKETING"] == "1" {
            Task { @MainActor in
                let directory = FileManager.default.temporaryDirectory.appending(path: "marketing", directoryHint: .isDirectory)
                await MarketingRenderer.renderAll(to: directory)
                NSApp.terminate(nil)
            }
        }
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        store.send(.menuShowPanel)
        return false
    }
}
