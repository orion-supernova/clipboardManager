//
//  ClipboardSettings.swift
//  clipboardManager
//
//  Created by muratcankoc on 26/10/2024.
//

import SwiftUI

class ClipboardSettings: ObservableObject {
    static let shared = ClipboardSettings()
    
    @AppStorage(.launchAtLoginUserDefaultsKey) var launchAtLogin: Bool = false
    @AppStorage(.retainCountUserDefaultsKey) var retainCount: Int = 20
    @AppStorage(.clearItemsOlderThanHoursUserDefaultsKey) var clearItemsOlderThanHours: Int = 48
    @AppStorage(.enableKeyboardNavigationUserDefaultsKey) var enableKeyboardNavigation: Bool = true {
        willSet {
            objectWillChange.send()
        }
    }
    
    private init() {}
}


