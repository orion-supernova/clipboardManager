//
//  WorkspaceClient.swift
//  clipboardManager
//
//  Small system side effects: Finder, opening files/URLs, haptics, confirmations.
//

import AppKit
import ComposableArchitecture

struct WorkspaceClient: Sendable {
    var revealInFinder: @Sendable (URL) async -> Void
    var open: @Sendable (URL) async -> Void
    var openAccessibilitySettings: @Sendable () async -> Void
    var openAccessibilityDisplaySettings: @Sendable () async -> Void
    var haptic: @Sendable (NSHapticFeedbackManager.FeedbackPattern) async -> Void
    var confirm: @Sendable (_ title: String, _ message: String, _ confirmTitle: String) async -> Bool
    var terminate: @Sendable () async -> Void
}

extension WorkspaceClient: DependencyKey {
    static let liveValue = WorkspaceClient(
        revealInFinder: { url in
            await MainActor.run { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        },
        open: { url in
            await MainActor.run { _ = NSWorkspace.shared.open(url) }
        },
        openAccessibilitySettings: {
            await MainActor.run {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                _ = NSWorkspace.shared.open(url)
            }
        },
        openAccessibilityDisplaySettings: {
            await MainActor.run {
                // The Accessibility pane itself, where Reduce Transparency,
                // Reduce Motion and Differentiate Without Color live.
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess")!
                _ = NSWorkspace.shared.open(url)
            }
        },
        haptic: { pattern in
            await MainActor.run { NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now) }
        },
        confirm: { title, message, confirmTitle in
            await MainActor.run {
                NSApp.activate()
                let alert = NSAlert()
                alert.messageText = title
                alert.informativeText = message
                alert.alertStyle = .warning
                alert.addButton(withTitle: confirmTitle)
                alert.addButton(withTitle: "Cancel")
                alert.buttons.first?.hasDestructiveAction = true
                return alert.runModal() == .alertFirstButtonReturn
            }
        },
        terminate: {
            await MainActor.run { NSApp.terminate(nil) }
        }
    )

    static let previewValue = WorkspaceClient(
        revealInFinder: { _ in }, open: { _ in }, openAccessibilitySettings: {}, openAccessibilityDisplaySettings: {},
        haptic: { _ in }, confirm: { _, _, _ in true }, terminate: {}
    )
}

extension DependencyValues {
    var workspace: WorkspaceClient {
        get { self[WorkspaceClient.self] }
        set { self[WorkspaceClient.self] = newValue }
    }
}
