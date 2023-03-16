//
//  Constants.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 16.03.2023.
//

import Foundation

// MARK: - Global Variables
let screenWidth: CGFloat = 500
let screenHeight: CGFloat = 500

// MARK: - Notification Name
extension Notification.Name {
    static let appBecomeActiveNotification       = Notification.Name("appBecomeActive")
    static let clipboardArrayChangedNotification = Notification.Name("clipboardArrayChanged")
    static let scrollToLastIndexNotification     = Notification.Name("scrollToLastIndex")
    static let textSelectedFromClipboardNotification = Notification.Name("textSelectedFromClipboard")
}
