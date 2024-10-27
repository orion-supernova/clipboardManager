//
//  ClipboardSettings.swift
//  clipboardManager
//
//  Created by muratcankoc on 26/10/2024.
//

//import SwiftUI
//
//struct ClipboardSettings {
//    @AppStorage(.launchAtLoginUserDefaultsKey) var launchAtLogin: Bool = false
//    @AppStorage(.retainCountUserDefaultsKey) var retainCount: Int = 20
//    @AppStorage(.clearItemsOlderThanHoursUserDefaultsKey) var clearItemsOlderThanHours: Int = 48
//
//    // Shared instance
//    static let shared = ClipboardSettings()
//}


//import Foundation
import SwiftUI

class ClipboardSettings: ObservableObject {
    static let shared = ClipboardSettings()
    
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: .launchAtLoginUserDefaultsKey)
        }
    }
    @Published var retainCount: Int {
        didSet {
            UserDefaults.standard.set(retainCount, forKey: .retainCountUserDefaultsKey)
        }
    }
    @Published var clearItemsOlderThanHours: Int {
        didSet {
            UserDefaults.standard.set(clearItemsOlderThanHours, forKey: .clearItemsOlderThanHoursUserDefaultsKey)
        }
    }
    
    private init() {
        // Check if the value exists in UserDefaults, otherwise use the default value
        self.launchAtLogin = UserDefaults.standard.bool(forKey: .launchAtLoginUserDefaultsKey) ? UserDefaults.standard.bool(forKey: .launchAtLoginUserDefaultsKey) : false // Default value is false
        
        self.retainCount = UserDefaults.standard.integer(forKey: .retainCountUserDefaultsKey)
            != 0 ? UserDefaults.standard.integer(forKey: .retainCountUserDefaultsKey) : 20 // Default value is 20
        
        self.clearItemsOlderThanHours = UserDefaults.standard.integer(forKey: .clearItemsOlderThanHoursUserDefaultsKey)
            != 0 ? UserDefaults.standard.integer(forKey: .clearItemsOlderThanHoursUserDefaultsKey) : 48 // Default value is 48
    }
}

