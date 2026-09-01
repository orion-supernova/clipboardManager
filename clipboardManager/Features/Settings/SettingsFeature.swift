//
//  SettingsFeature.swift
//  clipboardManager
//

import ComposableArchitecture
import Foundation

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.retainCount) var retainCount
        @Shared(.maxAgeHours) var maxAgeHours
        @Shared(.sensitiveMaxAgeMinutes) var sensitiveMaxAgeMinutes
        @Shared(.keyboardNavigation) var keyboardNavigation
        @Shared(.ignoreConcealed) var ignoreConcealed
        @Shared(.recordSensitive) var recordSensitive
        @Shared(.recognizeImageText) var recognizeImageText
        @Shared(.fetchLinkTitles) var fetchLinkTitles
        @Shared(.dragMode) var dragMode
        @Shared(.showShortcutHints) var showShortcutHints
        @Shared(.capturePaused) var capturePaused
        @Shared(.toggleShortcut) var toggleShortcut
        @Shared(.availableUpdate) var availableUpdate
        @Shared(.skippedUpdateVersion) var skippedUpdateVersion

        var section: Section? = .general
        var launchAtLogin = false
        var launchAtLoginError: String?
        var storageFootprint: Int64 = 0
        var isRecordingShortcut = false
        var updateCheck: UpdateCheckState = .idle

        enum UpdateCheckState: Equatable, Sendable {
            case idle
            case checking
            case upToDate
            case available(String)
            case notListed
            case failed(String)
        }

        enum Section: String, CaseIterable, Identifiable, Equatable, Sendable {
            case general = "General"
            case capture = "Capture"
            case privacy = "Privacy"
            case dragAndPaste = "Drag & Copy"
            case shortcuts = "Shortcuts"
            case about = "About"

            var id: String { rawValue }
            var symbol: String {
                switch self {
                case .general: "gearshape"
                case .capture: "doc.on.clipboard"
                case .privacy: "lock.shield"
                case .dragAndPaste: "hand.draw"
                case .shortcuts: "keyboard"
                case .about: "info.circle"
                }
            }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case task
        case refresh
        case statusLoaded(launchAtLogin: Bool, storage: Int64)
        case launchAtLoginToggled(Bool)
        case launchAtLoginFailed(String)
        case clearHistoryTapped
        case shortcutRecordingChanged(Bool)
        case shortcutRecorded(KeyboardShortcutSpec)
        case resetShortcut
        case checkForUpdates
        case updateCheckFinished(AppStoreListing?, failure: String?)
        case openUpdate
        case skipUpdate
        case delegate(Delegate)

        enum Delegate: Equatable {
            case clearHistory
            case shortcutRecording(Bool)
        }
    }

    @Dependency(\.launchAtLogin) var launchAtLogin
    @Dependency(\.paste) var paste
    @Dependency(\.clipboardStore) var clipboardStore
    @Dependency(\.workspace) var workspace
    @Dependency(\.updates) var updates
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .task:
                return .run { send in
                    await send(.refresh)
                    // The store keeps growing while the window is open.
                    for await _ in clock.timer(interval: .seconds(5)) { await send(.refresh) }
                }

            case .refresh:
                return .run { send in
                    let storage = await clipboardStore.storageFootprint()
                    await send(
                        .statusLoaded(launchAtLogin: launchAtLogin.isEnabled(), storage: storage),
                        animation: .smooth
                    )
                }

            case let .statusLoaded(launch, storage):
                state.launchAtLogin = launch
                state.storageFootprint = storage
                return .none

            case let .launchAtLoginToggled(enabled):
                state.launchAtLogin = enabled
                state.launchAtLoginError = nil
                return .run { send in
                    do {
                        try launchAtLogin.setEnabled(enabled)
                    } catch {
                        await send(.launchAtLoginFailed(error.localizedDescription))
                    }
                    await send(.refresh)
                }

            case let .launchAtLoginFailed(message):
                state.launchAtLoginError = message
                return .none

            case .clearHistoryTapped:
                return .send(.delegate(.clearHistory))

            case let .shortcutRecordingChanged(recording):
                guard state.isRecordingShortcut != recording else { return .none }
                state.isRecordingShortcut = recording
                return .send(.delegate(.shortcutRecording(recording)))

            case let .shortcutRecorded(spec):
                state.$toggleShortcut.withLock { $0 = spec }
                state.isRecordingShortcut = false
                return .send(.delegate(.shortcutRecording(false)))

            case .resetShortcut:
                state.$toggleShortcut.withLock { $0 = .default }
                return .none

            // MARK: Updates

            case .checkForUpdates:
                guard state.updateCheck != .checking else { return .none }
                state.updateCheck = .checking
                return .run { send in
                    do {
                        let listing = try await updates.check()
                        await send(.updateCheckFinished(listing, failure: nil), animation: .smooth)
                    } catch {
                        await send(.updateCheckFinished(nil, failure: error.localizedDescription), animation: .smooth)
                    }
                }

            case let .updateCheckFinished(listing, failure):
                if let failure {
                    state.updateCheck = .failed(failure)
                    return .none
                }
                guard let listing else {
                    state.updateCheck = .notListed
                    return .none
                }
                if AppVersion.isNewer(listing.version, than: AppVersion.current) {
                    state.updateCheck = .available(listing.version)
                    state.$availableUpdate.withLock { $0 = AvailableUpdate(listing: listing, foundAt: Date()) }
                } else {
                    state.updateCheck = .upToDate
                    state.$availableUpdate.withLock { $0 = nil }
                }
                return .none

            case .openUpdate:
                guard let update = state.availableUpdate else { return .none }
                return .run { _ in await workspace.open(update.listing.storeURL) }

            case .skipUpdate:
                guard let update = state.availableUpdate else { return .none }
                state.$skippedUpdateVersion.withLock { $0 = update.listing.version }
                state.$availableUpdate.withLock { $0 = nil }
                state.updateCheck = .idle
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
