//
//  OnboardingFeature.swift
//  clipboardManager
//
//  The welcome guide: what Mahmut does, and the two permissions worth granting.
//  Shown once on first launch; replayable from Settings and the menu bar.
//

import ComposableArchitecture
import Foundation

@Reducer
struct OnboardingFeature {
    @ObservableState
    struct State: Equatable {
        enum Step: Int, CaseIterable, Equatable, Sendable {
            case welcome, autoPaste, files, startup, done
        }

        var step: Step = .welcome
        var isAccessibilityTrusted = false
        var launchAtLogin = false
        @Shared(.toggleShortcut) var toggleShortcut
        @Shared(.hasCompletedOnboarding) var hasCompletedOnboarding

        var isFirstStep: Bool { step == .welcome }
        var isLastStep: Bool { step == .done }
    }

    enum Action {
        case windowVisibilityChanged(Bool)
        case statusLoaded(accessibility: Bool, launchAtLogin: Bool)
        case next
        case back
        case requestAccessibility
        case openAccessibilitySettings
        case openFullDiskAccessSettings
        case launchAtLoginToggled(Bool)
        case finish(openPanel: Bool)
        case delegate(Delegate)

        enum Delegate: Equatable {
            case finished(openPanel: Bool)
        }
    }

    private enum CancelID { case statusPolling }

    @Dependency(\.paste) var paste
    @Dependency(\.launchAtLogin) var launchAtLogin
    @Dependency(\.workspace) var workspace
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .windowVisibilityChanged(visible):
                guard visible else { return .cancel(id: CancelID.statusPolling) }
                state.step = .welcome
                // Accessibility is granted in System Settings while this is open,
                // so keep checking; the step flips to a checkmark on its own.
                return .run { send in
                    await send(.statusLoaded(accessibility: paste.isAccessibilityTrusted(), launchAtLogin: launchAtLogin.isEnabled()))
                    for await _ in clock.timer(interval: .seconds(1)) {
                        await send(.statusLoaded(accessibility: paste.isAccessibilityTrusted(), launchAtLogin: launchAtLogin.isEnabled()))
                    }
                }
                .cancellable(id: CancelID.statusPolling, cancelInFlight: true)

            case let .statusLoaded(accessibility, launch):
                state.isAccessibilityTrusted = accessibility
                state.launchAtLogin = launch
                return .none

            case .next:
                guard let next = State.Step(rawValue: state.step.rawValue + 1) else { return .none }
                state.step = next
                return .none

            case .back:
                guard let previous = State.Step(rawValue: state.step.rawValue - 1) else { return .none }
                state.step = previous
                return .none

            case .requestAccessibility:
                return .run { _ in
                    paste.requestAccessibility()
                    try await clock.sleep(for: .milliseconds(500))
                    // macOS shows its prompt only once per app; after that the call
                    // is silent, so take the user to the switch instead.
                    if !paste.isAccessibilityTrusted() { await workspace.openAccessibilitySettings() }
                }

            case .openAccessibilitySettings:
                return .run { _ in await workspace.openAccessibilitySettings() }

            case .openFullDiskAccessSettings:
                return .run { _ in await workspace.openFullDiskAccessSettings() }

            case let .launchAtLoginToggled(enabled):
                state.launchAtLogin = enabled
                return .run { send in
                    try? launchAtLogin.setEnabled(enabled)
                    await send(.statusLoaded(accessibility: paste.isAccessibilityTrusted(), launchAtLogin: launchAtLogin.isEnabled()))
                }

            case let .finish(openPanel):
                state.$hasCompletedOnboarding.withLock { $0 = true }
                return .send(.delegate(.finished(openPanel: openPanel)))

            case .delegate:
                return .none
            }
        }
    }
}
