//
//  PanelController.swift
//  clipboardManager
//
//  A non-activating floating panel: it can become key (so search and keyboard
//  navigation work) without activating the app, which means the app the user
//  was working in keeps focus and receives the simulated ⌘V directly.
//

import AppKit
import SwiftUI
import Synchronization

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel
    private var localKeyMonitor: Any?
    private var globalMouseMonitor: Any?
    private let subscribers = Mutex<[UUID: AsyncStream<PanelEvent>.Continuation]>([:])

    override init() {
        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: PanelMetrics.height),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.delegate = self
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .none
        panel.becomesKeyOnlyIfNeeded = false
    }

    func install(_ view: some View) {
        let hosting = NSHostingView(rootView: AnyView(view))
        hosting.sizingOptions = []
        hosting.frame = panel.contentRect(forFrameRect: panel.frame)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
    }

    // MARK: - Presentation

    func show() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame
        let width = min(visible.width - 2 * PanelMetrics.horizontalScreenInset, PanelMetrics.maxWidth)
        let frame = NSRect(
            x: (visible.midX - width / 2).rounded(),
            y: (visible.minY + PanelMetrics.bottomScreenInset).rounded(),
            width: width,
            height: PanelMetrics.height
        )
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        if let contentView = panel.contentView { panel.makeFirstResponder(contentView) }
        installMonitors()
        // Key status can be refused while the app is still finishing a launch; retry once.
        DispatchQueue.main.async { [panel] in
            if panel.isVisible, !panel.isKeyWindow { panel.makeKeyAndOrderFront(nil) }
        }
    }

    func hide() {
        removeMonitors()
        panel.orderOut(nil)
    }

    /// Grows or shrinks the panel upward from its anchored bottom edge.
    func resize(to height: CGFloat) {
        guard panel.isVisible, abs(panel.frame.height - height) > 0.5 else { return }
        var frame = panel.frame
        frame.size.height = height
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    // MARK: - Events

    nonisolated func makeEventStream() -> AsyncStream<PanelEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: PanelEvent.self, bufferingPolicy: .bufferingNewest(16))
        subscribers.withLock { $0[id] = continuation }
        continuation.onTermination = { [weak self] _ in
            self?.subscribers.withLock { _ = $0.removeValue(forKey: id) }
        }
        return stream
    }

    private func emit(_ event: PanelEvent) {
        subscribers.withLock { continuations in
            for continuation in continuations.values { continuation.yield(event) }
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard panel.isVisible else { return }
        emit(.didResignKey)
    }

    private func installMonitors() {
        removeMonitors()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, panel.isKeyWindow else { return event }
            return handle(event) ? nil : event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.emit(.clickedOutside)
        }
    }

    private func removeMonitors() {
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        localKeyMonitor = nil
        globalMouseMonitor = nil
    }

    /// Maps a key event to a `KeyCommand`. Returns `true` when the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let shift = flags.contains(.shift)
        let option = flags.contains(.option)
        let editingText = panel.firstResponder is NSTextView

        switch event.keyCode {
        case KeyboardLayout.escape:
            emit(.key(.escape)); return true
        case KeyboardLayout.returnKey, KeyboardLayout.keypadEnter:
            emit(.key(.confirm(plainText: shift))); return true
        case KeyboardLayout.space:
            if editingText { return false }
            emit(.key(.togglePreview)); return true
        case KeyboardLayout.leftArrow:
            if editingText && !command { return false }
            emit(.key(command ? .first : .previous)); return true
        case KeyboardLayout.rightArrow:
            if editingText && !command { return false }
            emit(.key(command ? .last : .next)); return true
        case KeyboardLayout.upArrow:
            emit(.key(.previous)); return true
        case KeyboardLayout.downArrow:
            emit(.key(.next)); return true
        case KeyboardLayout.home:
            emit(.key(.first)); return true
        case KeyboardLayout.end:
            emit(.key(.last)); return true
        case KeyboardLayout.tab:
            emit(.key(.toggleFocus)); return true
        case KeyboardLayout.delete, KeyboardLayout.forwardDelete:
            if editingText { return false }
            emit(.key(command ? .deleteFolder : .deleteSelected)); return true
        default:
            break
        }

        if command {
            guard let chars = event.charactersIgnoringModifiers, chars.count == 1 else { return false }
            let key = chars.lowercased()
            switch (key, shift, option) {
            case ("f", false, false): emit(.key(.focusSearch))
            case (",", _, _): emit(.key(.openSettings))
            case ("q", _, _): emit(.key(.quit))
            case ("c", false, false): emit(.key(.copyOnly))
            case ("c", true, false): emit(.key(.secondaryCopy))
            case ("c", false, true): emit(.key(.copyPath))
            case ("p", false, false): emit(.key(.togglePin))
            case ("p", true, false): emit(.key(.togglePause))
            case ("n", false, false): emit(.key(.newFolder))
            case ("r", false, false): emit(.key(.renameFolder))
            case ("r", true, false): emit(.key(.revealInFinder))
            case ("s", false, false): emit(.key(.saveToFolder))
            case ("t", false, false): emit(.key(.pasteAs))
            case ("e", false, false): emit(.key(.reveal))
            case ("o", false, false): emit(.key(.open))
            case ("u", false, false): emit(.key(.openUpdate))
            case ("[", _, _): emit(.key(.previousScope))
            case ("]", _, _): emit(.key(.nextScope))
            case ("1"..."9", false, false): emit(.key(.pasteIndex(Int(key)! - 1)))
            default: return false
            }
            return true
        }

        if option, !editingText, let chars = event.charactersIgnoringModifiers, chars.count == 1,
           let number = Int(chars), (1...6).contains(number) {
            emit(.key(.setFilter(number - 1)))
            return true
        }

        // Type-to-search: any printable character while the list has focus.
        guard !editingText, !flags.contains(.control), !option,
              let chars = event.characters, !chars.isEmpty,
              chars.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
        else { return false }
        emit(.key(.typeToSearch(chars)))
        return true
    }
}

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
