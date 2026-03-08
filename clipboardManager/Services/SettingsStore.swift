//
//  SettingsStore.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 08.03.2026.
//

import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: .launchAtLoginUserDefaultsKey) }
    }
    @Published var retainCount: Int {
        didSet { UserDefaults.standard.set(retainCount, forKey: .retainCountUserDefaultsKey) }
    }
    @Published var clearItemsOlderThanHours: Int {
        didSet { UserDefaults.standard.set(clearItemsOlderThanHours, forKey: .clearItemsOlderThanHoursUserDefaultsKey) }
    }

    init() {
        let storedLaunch = UserDefaults.standard.object(forKey: .launchAtLoginUserDefaultsKey) as? Bool
        self.launchAtLogin = storedLaunch ?? false

        let storedRetain = UserDefaults.standard.object(forKey: .retainCountUserDefaultsKey) as? Int
        self.retainCount = storedRetain ?? 20

        let storedClear = UserDefaults.standard.object(forKey: .clearItemsOlderThanHoursUserDefaultsKey) as? Int
        self.clearItemsOlderThanHours = storedClear ?? 48
    }
}
