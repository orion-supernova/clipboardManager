//
//  clipboardManagerApp.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import SwiftUI
import HotKey

@main
struct clipboardManagerApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    public var hotkeyForApp = HotKey(key: .return, modifiers: [.command, .control, .option])

    let persistenceController = PersistenceController.shared
    @State var currentNumber: String = "1"
    @State var isShowingAppOnScreen = false

    init() {
        hotkeyForApp.keyDownHandler = appDelegate.openAppAction
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .fixedSize()
                .frame(minWidth: 785, maxWidth: 785, minHeight: 212, maxHeight: 212)
        }.windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var timer: Timer!
    let pasteboard: NSPasteboard = .general
    var tempTextArray: [String] = []
    @AppStorage("textArray", store: UserDefaults(suiteName: "com.walhallaa.clipboardManager")) var appStorageArray: Data = Data()
    var window: NSWindow!

    static private(set) var instance: AppDelegate!
    lazy var statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = ApplicationMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
        menu.delegate = self
        statusBarItem.button?.imagePosition = .imageLeading
        statusBarItem.button?.imageScaling = .scaleProportionallyDown
        statusBarItem.button?.title = "Count: 22"
        getAllStringsFromClipboard()
        setupTimer()
        statusBarItem.menu = menu.createMenu()

        let windowController = NSHostingView(rootView: ContentView())
        if let window = NSApplication.shared.windows.first {
            self.window = window
            self.window.contentView = windowController
            self.window.close()
        }
    }

    func getAllStringsFromClipboard() {
        self.tempTextArray = Storage.loadStringArray(data: appStorageArray)
        self.menu.textArray = self.tempTextArray
        setMenuBarText(count: self.tempTextArray.count)
    }

    func openAppAction() {
        self.window.makeKeyAndOrderFront(nil)
    }

    private func setupTimer() {
        let pasteboard = NSPasteboard.general
        var changeCount = NSPasteboard.general.changeCount

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            guard let copiedString = pasteboard.string(forType: .string), pasteboard.changeCount != changeCount else { return }
            guard copiedString != self.tempTextArray.last else { return }

            changeCount = pasteboard.changeCount

            self.tempTextArray.append(copiedString)
            self.appStorageArray = Storage.archiveStringArray(object: self.tempTextArray)
            print("\(changeCount), \(copiedString)")
            for item in self.tempTextArray {
                print(item)
            }
            self.menu.textArray = self.tempTextArray
            self.statusBarItem.menu = self.menu.createMenu()
            self.setMenuBarText(count: self.tempTextArray.count)
        }
    }

    private func setMenuBarText(count: Int) {
        statusBarItem.button?.title = "Count: \(count)"
    }
}

extension AppDelegate: ApplicationMenuDelegate {
    func didTapClearAllButton() {
        self.tempTextArray.removeAll()
        self.menu.textArray = []
        self.statusBarItem.menu = self.menu.createMenu()
        setMenuBarText(count: 0)
    }
}
