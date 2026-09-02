//
//  SettingsWindowController.swift
//  clipboardManager
//

import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
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
        window.delegate = self
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
        // Mahmut is an LSUIElement app, so it normally has no Dock icon and no
        // ⌘-Tab entry. That is right for the panel and wrong for a settings
        // window: click away from an accessory window and there is no way back
        // to it. Become a regular app for as long as the window is open.
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        // The clipboard panel is a floating-level window and may still be on
        // screen for another frame or two, which would leave Settings behind it.
        window.level = .normal
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        // Back to a menu bar utility.
        NSApp.setActivationPolicy(.accessory)
    }
}
