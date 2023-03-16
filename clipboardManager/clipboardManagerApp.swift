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

    // MARK: - Public Properties
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let hotkeyForInterfaceVisibility = HotKey(key: .return, modifiers: [.command, .control, .option])
    let hotkeyForEscapeCharacter     = HotKey(key: .escape, modifiers: [])

    let persistenceController = PersistenceController.shared
    @State var currentNumber: String = "1"
    @State var isShowingAppOnScreen = false

    // MARK: - Lifecycle
    init() {
        hotkeyForInterfaceVisibility.keyDownHandler = appDelegate.handleAppShortcut
        hotkeyForEscapeCharacter.keyDownHandler     = appDelegate.handleEscapeCharacter
    }

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            ContentView()
                .fixedSize()
        }.windowResizability(.contentSize)
    }
}

// MARK: - AppDelegate
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
        getAllStringsFromClipboard()
        setupTimer()
        statusBarItem.menu = menu.createMenu()
        addObservers()

        let windowController = NSHostingView(rootView: ContentView())
        if let window = NSApplication.shared.windows.first {
            let width = (NSScreen.main?.frame.width)!
            let heigth = (NSScreen.main?.frame.height)!
            let resWidth: CGFloat = (width / 2) - (screenWidth / 2)
            let resHeigt: CGFloat = (heigth / 2) - (screenHeight / 2)

            self.window = window
            self.window.setFrameOrigin(NSPoint(x: resWidth, y: resHeigt))
            self.window.contentView = windowController
            self.window.styleMask = [.borderless]
            self.window.titlebarAppearsTransparent = true
            self.window.titleVisibility = .hidden
            self.window.backgroundColor = .clear
            self.window.close()
        }
    }

    // MARK: - Public Methods
    func handleAppShortcut() {
        if self.window.isVisible {
            makeAppHiddenAction()
        } else {
            makeAppVisibleAction()
        }
    }

    func handleEscapeCharacter() {
        makeAppHiddenAction()
    }

    // MARK: - Private Methods
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(makeAppHiddenAction), name: NSApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(textSelectedFromClipboardAction), name: .textSelectedFromClipboardNotification, object: nil)
    }

    private func getAllStringsFromClipboard() {
        self.tempTextArray = StorageHelper.loadStringArray(data: appStorageArray)
        self.menu.textArray = self.tempTextArray
        setMenuBarText(count: self.tempTextArray.count)
    }

    private func setupTimer() {
        let pasteboard = NSPasteboard.general
        var changeCount = NSPasteboard.general.changeCount

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            guard let copiedString = pasteboard.string(forType: .string), pasteboard.changeCount != changeCount else { return }
            guard copiedString != self.tempTextArray.last else { return }

            changeCount = pasteboard.changeCount

            self.tempTextArray.append(copiedString)
            self.appStorageArray = StorageHelper.archiveStringArray(object: self.tempTextArray)
            print("\(changeCount), \(copiedString)")
            for item in self.tempTextArray {
                print(item)
            }
            self.menu.textArray = self.tempTextArray
            self.statusBarItem.menu = self.menu.createMenu()
            self.setMenuBarText(count: self.tempTextArray.count)
            NotificationCenter.default.post(name: .clipboardArrayChangedNotification, object: self.tempTextArray)
        }
    }

    private func setMenuBarText(count: Int) {
        statusBarItem.button?.title = "Count: \(count)"
    }

    // MARK: - Private Actions
    private func makeAppVisibleAction() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.window.orderFrontRegardless()
        NotificationCenter.default.post(name: .scrollToLastIndexNotification, object: nil)
    }

    @objc private func makeAppHiddenAction() {
        self.window.close()
        NSApplication.shared.deactivate()
        NSApplication.shared.hide(self)
    }

    @objc private func textSelectedFromClipboardAction() {
        makeAppHiddenAction()
        let eventSource = CGEventSource(stateID: .combinedSessionState)
        let eventDown = CGEvent(keyboardEventSource: eventSource, virtualKey: CGKeyCode(9), keyDown: true)!
        let eventUp = CGEvent(keyboardEventSource: eventSource, virtualKey: CGKeyCode(9), keyDown: false)!

        eventDown.flags = CGEventFlags.maskCommand
        eventDown.post(tap: .cgAnnotatedSessionEventTap)
        eventUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}

// MARK: - Extension ApplicationMenu Delegate
extension AppDelegate: ApplicationMenuDelegate {
    func didTapClearAllButton() {
        self.tempTextArray.removeAll()
        self.menu.textArray = []
        self.statusBarItem.menu = self.menu.createMenu()
        setMenuBarText(count: 0)
        NotificationCenter.default.post(name: .clipboardArrayChangedNotification, object: self.tempTextArray)
    }
}
