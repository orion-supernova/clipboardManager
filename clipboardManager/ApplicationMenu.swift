//
//  ApplicationMenu.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import Foundation
import SwiftUI

protocol ApplicationMenuDelegate: AnyObject {
    func didTapClearAllButton()
}

class ApplicationMenu: NSObject {
    // MARK: - Public Properties
//    @AppStorage("hmArray", store: UserDefaults(suiteName: "com.walhallaa.clipboardManager")) var appStorageArrayData: Data = Data()
    weak var delegate: ApplicationMenuDelegate?
    @State var menuItemsArray: [NSMenuItem] = []

    // MARK: - Public Methods
    func createMenu() -> NSMenu {
        let menu = NSMenu()
        let openAppMenuItem = NSMenuItem(title: "Open App Interface (cmd+shift+v)",
                                         action: #selector(openAppInterfaceAction),
                                         keyEquivalent: "")
        openAppMenuItem.target = self
        menu.addItem(openAppMenuItem)

        menu.addItem(NSMenuItem.separator())
        loadOtherButtons(to: menu)
        return menu
    }

    // MARK: - Private Methods
    private func loadOtherButtons(to menu: NSMenu) {
        let clearAllMenuItem = NSMenuItem(title: "Clear All",
                                          action: #selector(clearAction),
                                          keyEquivalent: "")
        clearAllMenuItem.target = self
        menu.addItem(clearAllMenuItem)

        let preferencesMenuItem = NSMenuItem(title: "Preferences",
                                             action: #selector(preferencesAction),
                                             keyEquivalent: "")
        preferencesMenuItem.target = self
        menu.addItem(preferencesMenuItem)

//        let aboutMenuItem = NSMenuItem(title: "About",
//                                       action: #selector(aboutAction),
//                                       keyEquivalent: "")
//        aboutMenuItem.target = self
//        aboutMenuItem.representedObject = "https://walhallaa.com"
//        menu.addItem(aboutMenuItem)

        let quitMenuItem = NSMenuItem(title: "Quit",
                                      action: #selector(quitAction),
                                      keyEquivalent: "")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
    }

    // MARK: - Actions
    @objc func copyToClipboardAction(sender: NSMenuItem) {
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(sender.title,forType :.string)
        KeyPressHelper.simulateKeyPressWithCommand(keyCode: KeyCode.v)
    }

    @objc func preferencesAction(sender: NSMenuItem) {
        NotificationCenter.default.post(name: .preferencesClickedNotification, object: nil)
    }

    @objc func clearAction(sender: NSMenuItem) {
//        appStorageArrayData = StorageHelper.archiveStringArray(object: [])
        delegate?.didTapClearAllButton()
    }

    @objc func aboutAction(sender: NSMenuItem) {
        NSApp.orderFrontStandardAboutPanel()
    }

    @objc func openLinkAction(sender: NSMenuItem) {
        let link = sender.representedObject as! String
        guard let url = URL(string: link) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func openAppInterfaceAction() {
        NotificationCenter.default.post(name: .makeAppVisibleNotification, object: nil)
    }

    @objc func quitAction(sender: NSMenuItem) {
        NSApp.terminate(self)
    }
}
