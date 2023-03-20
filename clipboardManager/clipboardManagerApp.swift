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
    let hotkeyForInterfaceVisibility = HotKey(key: .v, modifiers: [.command, .shift])

    let persistenceController = PersistenceController.shared

    // MARK: - Lifecycle
    init() {
        hotkeyForInterfaceVisibility.keyDownHandler = appDelegate.handleAppShortcut
    }

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            MainView()
                .fixedSize()
        }.windowResizability(.contentSize)
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var timer: Timer!
    let pasteboard: NSPasteboard = .general
    var tempClipboardItemArray: [ClipboardItem] = []
    @AppStorage("hmArray", store: UserDefaults(suiteName: "com.walhallaa.clipboardManager")) var appStorageArray: Data = Data()
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
        setupWindow()
        makeAppVisibleAction()
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
    @objc private func setupWindow() {
        let windowController = NSHostingView(rootView: MainView())
        if let window = NSApplication.shared.windows.first {
            self.window = window
            self.window.setFrameOrigin(NSPoint(x: NSScreen.main!.visibleFrame.minX, y: NSScreen.main!.visibleFrame.minY))
            self.window.contentView = windowController
            self.window.styleMask = [.borderless]
            self.window.titlebarAppearsTransparent = true
            self.window.titleVisibility = .hidden
            self.window.backgroundColor = .clear
        }
    }

    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(makeAppHiddenAction), name: NSApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(textSelectedFromClipboardAction), name: .textSelectedFromClipboardNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(makeAppVisibleAction), name: .makeAppVisibleNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(makeAppHiddenAction), name: .makeAppHiddenNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setupWindow), name: NSApplication.willBecomeActiveNotification, object: nil)
    }

    private func getAllStringsFromClipboard() {
        self.tempClipboardItemArray = StorageHelper.loadStringArray(data: appStorageArray)
        self.menu.clipboardItemArray = self.tempClipboardItemArray
        setMenuBarText(count: self.tempClipboardItemArray.count)
    }

    private func setupTimer() {
        let pasteboard = NSPasteboard.general
        var changeCount = NSPasteboard.general.changeCount

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard let copiedString = pasteboard.string(forType: .string), pasteboard.changeCount != changeCount else { return }
            guard copiedString != self.tempClipboardItemArray.last?.text else { return }

            changeCount = pasteboard.changeCount

            guard !copiedString.isEmpty else { return }

            let newItem = ClipboardItem(id: UUID(), text: copiedString)

            self.tempClipboardItemArray.append(newItem)
            self.appStorageArray = StorageHelper.archiveStringArray(object: self.tempClipboardItemArray)
            print("\(changeCount), \(copiedString)")

            self.menu.clipboardItemArray = self.tempClipboardItemArray
            self.statusBarItem.menu = self.menu.createMenu()
            self.setMenuBarText(count: self.tempClipboardItemArray.count)
            NotificationCenter.default.post(name: .clipboardArrayChangedNotification, object: copiedString)
            // TODO: - Danger Zone, be careful with setupWindow, may decrease performance ↓
            self.setupWindow()

//            self.makeAppVisibleAction()
//            self.setupWindow()
//            self.makeAppHiddenAction()

        }
    }

    private func setMenuBarText(count: Int) {
        statusBarItem.button?.title = "Count: \(count)"
    }

    // MARK: - Private Actions
    @objc private func makeAppVisibleAction() {
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
        self.tempClipboardItemArray.removeAll()
        self.menu.clipboardItemArray = []
        self.statusBarItem.menu = self.menu.createMenu()
        setMenuBarText(count: 0)
        NotificationCenter.default.post(name: .clipboardArrayClearedNotification, object: nil)
        self.setupWindow()
    }
}
