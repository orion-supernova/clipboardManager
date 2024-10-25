//
//  Constants.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 16.03.2023.
//

import AppKit

// MARK: - Global Variables
let screenWidth: CGFloat = NSScreen.main!.visibleFrame.width
let screenHeight: CGFloat = 400

// MARK: - Notification Name
extension Notification.Name {
    static let appBecomeActiveNotification           = Notification.Name("appBecomeActive")
    static let clipboardArrayChangedNotification     = Notification.Name("clipboardArrayChanged")
    static let makeAppVisibleNotification            = Notification.Name("makeAppVisible")
    static let preferencesClickedNotification        = Notification.Name("preferencesClicked")
    static let textSelectedFromClipboardNotification = Notification.Name("textSelectedFromClipboard")
    static let pasteBoardCountNotification           = Notification.Name("pasteBoardCountNotification")
    static let refreshClipboardItems                 = Notification.Name("refreshClipboardItems")
    static let isSearchFieldVisibleNotification      = Notification.Name("isSearchFieldVisibleNotification")
    static let retainCountChangedNotification        = Notification.Name("retainCountChangedNotification")
    static let launchAtLoginChangedNotification      = Notification.Name("launchAtLoginChangedNotification")
    static let clearItemsOlderThanHoursChangedNotification = Notification.Name("clearItemsOlderThanHoursChangedNotification")
}

extension String {
    static let isSearchFieldVisibleUserDefaultsKey = "isSearchFieldVisibleUserDefaultsKey"
    static let retainCountUserDefaultsKey = "retainCountUserDefaultsKey"
    static let launchAtLoginUserDefaultsKey = "launchAtLoginUserDefaultsKey"
    static let clearItemsOlderThanHoursUserDefaultsKey = "clearItemsOlderThanHoursUserDefaultsKey"
}
