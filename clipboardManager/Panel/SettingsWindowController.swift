//
//  SettingsWindowController.swift
//  clipboardManager
//

import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private static let autosaveName = "MahmutSettingsWindow"
    private static let initialSize = NSSize(width: 800, height: 580)
    private var hasBeenShown = false

    init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.initialSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 720, height: 480)
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func install(_ view: some View) {
        guard let window else { return }
        // A hosting *controller* lets SwiftUI manage the toolbar and split view chrome.
        let controller = NSHostingController(rootView: AnyView(view))
        controller.sizingOptions = []
        window.contentViewController = controller
        window.setContentSize(Self.initialSize)
    }

    func present() {
        guard let window else { return }
        if !hasBeenShown {
            if !window.setFrameUsingName(Self.autosaveName) { window.center() }
            window.setFrameAutosaveName(Self.autosaveName)
            hasBeenShown = true
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
