//
//  OnboardingWindowClient.swift
//  clipboardManager
//

import ComposableArchitecture

struct OnboardingWindowClient: Sendable {
    var open: @Sendable () async -> Void
    var close: @Sendable () async -> Void
}

extension OnboardingWindowClient: TestDependencyKey {
    static let previewValue = OnboardingWindowClient(open: {}, close: {})
    static let testValue: OnboardingWindowClient = previewValue
}

extension DependencyValues {
    var onboardingWindow: OnboardingWindowClient {
        get { self[OnboardingWindowClient.self] }
        set { self[OnboardingWindowClient.self] = newValue }
    }
}
