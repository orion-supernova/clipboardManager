//
//  SettingsWindowClient.swift
//  clipboardManager
//

import ComposableArchitecture

struct SettingsWindowClient: Sendable {
    var open: @Sendable () async -> Void
}

extension SettingsWindowClient: TestDependencyKey {
    static let previewValue = SettingsWindowClient(open: {})
    static let testValue: SettingsWindowClient = previewValue
}

extension DependencyValues {
    var settingsWindow: SettingsWindowClient {
        get { self[SettingsWindowClient.self] }
        set { self[SettingsWindowClient.self] = newValue }
    }
}
