//
//  Constants.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 16.03.2023.
//

import AppKit

// MARK: - Global Variables
let screenWidth: CGFloat = NSScreen.main!.visibleFrame.width
let screenHeight: CGFloat = 310

// MARK: - Notification Name
extension Notification.Name {
    static let appBecomeActiveNotification       = Notification.Name("appBecomeActive")
    static let clipboardArrayChangedNotification = Notification.Name("clipboardArrayChanged")
    static let clipboardArrayClearedNotification = Notification.Name("clipboardArrayCleared")
    static let scrollToLastIndexNotification     = Notification.Name("scrollToLastIndex")
    static let makeAppVisibleNotification        = Notification.Name("makeAppVisible")
    static let makeAppHiddenNotification         = Notification.Name("makeAppHiddenNotification")
    static let textSelectedFromClipboardNotification = Notification.Name("textSelectedFromClipboard")
}
