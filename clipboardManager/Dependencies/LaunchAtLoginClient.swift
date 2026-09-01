//
//  LaunchAtLoginClient.swift
//  clipboardManager
//

import ComposableArchitecture
import ServiceManagement

struct LaunchAtLoginClient: Sendable {
    var isEnabled: @Sendable () -> Bool
    var setEnabled: @Sendable (Bool) throws -> Void
}

extension LaunchAtLoginClient: DependencyKey {
    static let liveValue = LaunchAtLoginClient(
        isEnabled: { SMAppService.mainApp.status == .enabled },
        setEnabled: { enabled in
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        }
    )

    static let previewValue = LaunchAtLoginClient(isEnabled: { false }, setEnabled: { _ in })
}

extension DependencyValues {
    var launchAtLogin: LaunchAtLoginClient {
        get { self[LaunchAtLoginClient.self] }
        set { self[LaunchAtLoginClient.self] = newValue }
    }
}
