//
//  AppFeature.swift
//  clipboardManager
//
//  Root reducer: composes the panel and settings features and owns app-level
//  concerns (global hotkey, update checks, menu bar commands, settings window, quitting).
//

import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var history = HistoryFeature.State()
        var settings = SettingsFeature.State()
        @Shared(.toggleShortcut) var toggleShortcut
        @Shared(.availableUpdate) var availableUpdate
        @Shared(.skippedUpdateVersion) var skippedUpdateVersion
    }

    enum Action {
        case appLaunched
        case hotKeyPressed
        case shortcutChanged(KeyboardShortcutSpec)
        case updateChecked(AppStoreListing?)
        case menuShowPanel
        case menuOpenSettings
        case menuClearHistory
        case menuOpenUpdate
        case menuQuit
        case history(HistoryFeature.Action)
        case settings(SettingsFeature.Action)
    }

    private enum CancelID { case hotKey, updates }

    @Dependency(\.hotKeys) var hotKeys
    @Dependency(\.settingsWindow) var settingsWindow
    @Dependency(\.workspace) var workspace
    @Dependency(\.updates) var updates
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Scope(state: \.history, action: \.history) { HistoryFeature() }
        Scope(state: \.settings, action: \.settings) { SettingsFeature() }

        Reduce { state, action in
            switch action {
            case .appLaunched:
                let shortcut = state.$toggleShortcut
                return .merge(
                    .send(.history(.task)),
                    hotKeyEffect(state.toggleShortcut),
                    .run { send in
                        for await spec in shortcut.publisher.values.dropFirst() { await send(.shortcutChanged(spec)) }
                    },
                    .run { send in
                        try await clock.sleep(for: .seconds(15))
                        await send(.updateChecked(try? await updates.check()))
                        for await _ in clock.timer(interval: .seconds(24 * 3600)) {
                            await send(.updateChecked(try? await updates.check()))
                        }
                    }
                    .cancellable(id: CancelID.updates)
                )

            case .hotKeyPressed, .menuShowPanel:
                return .send(.history(.togglePresentation))

            case let .shortcutChanged(spec):
                return hotKeyEffect(spec)

            case let .updateChecked(listing):
                guard let listing,
                      AppVersion.isNewer(listing.version, than: AppVersion.current),
                      listing.version != state.skippedUpdateVersion
                else { return .none }
                state.$availableUpdate.withLock { $0 = AvailableUpdate(listing: listing, foundAt: Date()) }
                return .none

            case let .settings(.delegate(.shortcutRecording(recording))):
                // Don't let the current shortcut fire while the user is recording a new one.
                return recording ? .cancel(id: CancelID.hotKey) : hotKeyEffect(state.toggleShortcut)

            case .menuOpenSettings:
                return .merge(
                    .send(.history(.dismiss(.lostFocus))),
                    .run { _ in await settingsWindow.open() }
                )

            case let .history(.delegate(.openSettings(section))):
                if let section { state.settings.section = section }
                return .merge(
                    .send(.history(.dismiss(.lostFocus))),
                    .run { _ in await settingsWindow.open() }
                )

            case .menuClearHistory, .settings(.delegate(.clearHistory)):
                return .send(.history(.clearAllTapped))

            case .menuOpenUpdate:
                guard let update = state.availableUpdate else { return .none }
                return .run { _ in await workspace.open(update.listing.storeURL) }

            case .menuQuit, .history(.delegate(.quit)):
                return .run { _ in await workspace.terminate() }

            case .history, .settings:
                return .none
            }
        }
    }

    private func hotKeyEffect(_ spec: KeyboardShortcutSpec) -> Effect<Action> {
        .run { send in
            for await _ in hotKeys.presses(spec) { await send(.hotKeyPressed) }
        }
        .cancellable(id: CancelID.hotKey, cancelInFlight: true)
    }
}
