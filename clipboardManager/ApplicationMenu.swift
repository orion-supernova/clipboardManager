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
    @AppStorage("hmArray", store: UserDefaults(suiteName: "com.walhallaa.clipboardManager")) var appStorageArrayData: Data = Data()
    weak var delegate: ApplicationMenuDelegate?
    var clipboardItemArray: [ClipboardItem] = []
    @State var menuItemsArray: [NSMenuItem] = []

    // MARK: - Public Methods
    func createMenu() -> NSMenu {
        let menu = NSMenu()
        let preferencesMenuItem = NSMenuItem(title: "Open App Interface",
                                             action: #selector(openAppInterfaceAction),
                                             keyEquivalent: "")
        preferencesMenuItem.target = self
        menu.addItem(preferencesMenuItem)

        menu.addItem(NSMenuItem.separator())
        loadOtherButtons(to: menu)
        return menu
    }

    // MARK: - Private Methods
    private func loadClipboardStrings(to menu: NSMenu) {
        let stringArray = self.clipboardItemArray
        for item in stringArray.reversed() {
            let item = NSMenuItem(title: "\(item)",
                                              action: #selector(copyToClipboardAction),
                                              keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
    }

    private func loadOtherButtons(to menu: NSMenu) {
        let clearAllMenuItem = NSMenuItem(title: "Clear All",
                                          action: #selector(clearAction),
                                          keyEquivalent: "")
        clearAllMenuItem.target = self
        menu.addItem(clearAllMenuItem)

        let preferencesMenuItem = NSMenuItem(title: "Preferences",
                                             action: #selector(comingSoonAction),
                                             keyEquivalent: "")
        preferencesMenuItem.target = self
        menu.addItem(preferencesMenuItem)

        let aboutMenuItem = NSMenuItem(title: "About",
                                       action: #selector(aboutAction),
                                       keyEquivalent: "")
        aboutMenuItem.target = self
        aboutMenuItem.representedObject = "https://walhallaa.com"
        menu.addItem(aboutMenuItem)

        let quitMenuItem = NSMenuItem(title: "Quit",
                                      action: #selector(quitAction),
                                      keyEquivalent: "")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
    }

    private func handleEmptyButton(with menu: NSMenu) {
        let array = clipboardItemArray
        guard !array.isEmpty else { menu.addItem(NSMenuItem(title: "<None>", action: nil, keyEquivalent: "")); return }
        guard array.count < 2 else { return }
        menu.items.removeAll(where: { $0.action == nil })
    }

    // MARK: - Actions
    @objc func copyToClipboardAction(sender: NSMenuItem) {
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(sender.title,forType :.string)
        KeyPressHelper.simulateKeyPressWithCommand(keyCode: KeyCode.v)
    }

    @objc func comingSoonAction(sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "Coming Soon!"
        alert.informativeText = "Lorem ipsum dolor sit amet bla bla"
        alert.alertStyle = NSAlert.Style.warning
        alert.addButton(withTitle: "OK")
        alert.runModal()//== NSApplication.ModalResponse.alertFirstButtonReturn
    }

    @objc func clearAction(sender: NSMenuItem) {
        appStorageArrayData = StorageHelper.archiveStringArray(object: [])
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
