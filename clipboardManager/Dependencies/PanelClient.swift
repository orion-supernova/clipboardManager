//
//  PanelClient.swift
//  clipboardManager
//
//  The floating panel is AppKit; the reducer talks to it only through this client.
//

import ComposableArchitecture
import Foundation

enum KeyCommand: Equatable, Sendable {
    case escape
    case confirm(plainText: Bool)
    case previous
    case next
    case first
    case last
    case deleteSelected
    case focusSearch
    case typeToSearch(String)
    case pasteIndex(Int)
    case copyOnly
    case togglePin
    case togglePreview
    case openSettings
    case quit
    case toggleFocus
    case previousScope
    case nextScope
    case newFolder
    case renameFolder
    case deleteFolder
    case setFilter(Int)
    case togglePause
    case openUpdate
    case saveToFolder
    case pasteAs
    case secondaryCopy
    case reveal
    case open
    case revealInFinder
    case copyPath
}

enum PanelEvent: Equatable, Sendable {
    case didResignKey
    case clickedOutside
    case key(KeyCommand)
}

struct PanelClient: Sendable {
    var show: @Sendable () async -> Void
    var hide: @Sendable () async -> Void
    /// Animates the panel to a new height, keeping its bottom edge in place.
    var resize: @Sendable (CGFloat) async -> Void
    var events: @Sendable () -> AsyncStream<PanelEvent>
}

extension PanelClient: TestDependencyKey {
    static let previewValue = PanelClient(show: {}, hide: {}, resize: { _ in }, events: { AsyncStream { _ in } })
    static let testValue: PanelClient = previewValue
}

extension DependencyValues {
    var panel: PanelClient {
        get { self[PanelClient.self] }
        set { self[PanelClient.self] = newValue }
    }
}
