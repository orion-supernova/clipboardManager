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
    @AppStorage("textArray", store: UserDefaults(suiteName: "com.walhallaa.clipboardManager")) var appStorageArrayData: Data = Data()
    weak var delegate: ApplicationMenuDelegate?
    var textArray: [String] = []
    @State var menuItemsArray: [NSMenuItem] = []

    func createMenu() -> NSMenu {
//        let menuBarView = VStack {
//            List(menuItemsArray, id: \.self) { item in
//                Menu("hm") {
//                    Text("hede")
//                }.frame(width: 200, height: 200, alignment: .center)
//            }
//        }
//        let topView = NSHostingController(rootView: menuBarView)
//        topView.view.frame.size = CGSize(width: 225, height: 225)
//        customMenuItem.view = topView.view
//        let customMenuItem = NSMenuItem()
//        menu.addItem(customMenuItem)


        let menu = NSMenu()
        handleEmptyButton(with: menu)
        loadClipboardStrings(to: menu)
        menu.addItem(NSMenuItem.separator())
        loadOtherButtons(to: menu)
        return menu
    }

    private func loadClipboardStrings(to menu: NSMenu) {
        let stringArray = self.textArray //Storage.loadStringArray(data: appStorageArrayData)
        for item in stringArray.reversed() {
            let clearAllMenuItem = NSMenuItem(title: "\(item)",
                                              action: #selector(copyToClipboardAction),
                                              keyEquivalent: "")
            clearAllMenuItem.target = self
            menu.addItem(clearAllMenuItem)
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

    @objc func copyToClipboardAction(sender: NSMenuItem) {
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(sender.title,forType :.string)
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
        appStorageArrayData = Storage.archiveStringArray(object: [])
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

    @objc func quitAction(sender: NSMenuItem) {
        NSApp.terminate(self)
    }

    private func handleEmptyButton(with menu: NSMenu) {
        let array = textArray//Storage.loadStringArray(data: appStorageArrayData)
        guard !array.isEmpty else { menu.addItem(NSMenuItem(title: "<None>", action: nil, keyEquivalent: "")); return }
        guard array.count < 2 else { return }
        menu.items.removeAll(where: { $0.action == nil })
    }
}