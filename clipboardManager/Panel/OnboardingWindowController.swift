//
//  OnboardingWindowController.swift
//  clipboardManager
//

import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    var onVisibilityChange: ((Bool) -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Mahmut"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func install(_ view: some View) {
        window?.contentViewController = NSHostingController(rootView: AnyView(view))
    }

    func present() {
        guard let window else { return }
        // Like Settings: a menu bar utility needs a Dock presence while a real
        // window is open, or clicking away leaves no way back to it.
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
        window.level = .normal
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        onVisibilityChange?(true)
    }

    func dismiss() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        onVisibilityChange?(false)
        let otherWindowOpen = NSApp.windows.contains { $0 !== window && $0.isVisible && $0.styleMask.contains(.titled) }
        if !otherWindowOpen { NSApp.setActivationPolicy(.accessory) }
    }
}
