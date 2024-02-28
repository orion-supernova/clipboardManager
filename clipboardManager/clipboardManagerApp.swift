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
    let hotkeyForEscape = HotKey(key: .escape, modifiers: .init())

    let persistenceController = PersistenceController.shared
    var mainView: MainView!

    // MARK: - Lifecycle
    init() {
        hotkeyForInterfaceVisibility.keyDownHandler = appDelegate.handleAppShortcut
        hotkeyForEscape.keyDownHandler = appDelegate.handleEscapeCharacter
        self.mainView = appDelegate.mainView
    }

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            self.mainView
                .fixedSize()
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Public Properties
    @AppStorage("hmArray", store: UserDefaults(suiteName: "com.walhallaa.clipboardManager")) var appStorageArray: Data = Data()
    var mainView = MainView()

    // MARK: - Private Properties
    private var timer: Timer!
    private let pasteboard: NSPasteboard = .general
    private var tempClipboardItemArray: [ClipboardItem] = []
    private var window: NSWindow!

    static private(set) var instance: AppDelegate!
    private lazy var statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = ApplicationMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
        menu.delegate = self
        getAllStringsFromClipboard()
        setupTimer()
        statusBarItem.menu = menu.createMenu()
        addObservers()
        setupWindow()
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
    @objc func setupWindow() {
        print("[DEBUG] setup window start")
        let windowController = NSHostingView(rootView: mainView)
        if let window = NSApplication.shared.windows.first {
            self.window = window
            self.window.setFrameOrigin(NSPoint(x: NSScreen.main!.visibleFrame.minX, y: NSScreen.main!.frame.minY))
            self.window.contentView = windowController
            self.window.styleMask = [.docModalWindow]
            self.window.titlebarAppearsTransparent = true
            self.window.titleVisibility = .hidden
            self.window.backgroundColor = .clear
            self.window.level = .popUpMenu
        }
        print("[DEBUG] setup window end")
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(makeAppHiddenAction), name: NSApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(textSelectedFromClipboardAction(_:)), name: .textSelectedFromClipboardNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(makeAppVisibleAction), name: .makeAppVisibleNotification, object: nil)
    }

    private func getAllStringsFromClipboard() {
        self.tempClipboardItemArray = StorageHelper.loadStringArray(data: appStorageArray)
        setMenuBarText(count: self.tempClipboardItemArray.count)
    }

    private func setupTimer() {
        let pasteboard = NSPasteboard.general
        var changeCount = NSPasteboard.general.changeCount

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard let copiedString = pasteboard.string(forType: .string), pasteboard.changeCount != changeCount else { return }
            guard copiedString != self.tempClipboardItemArray.last?.text else { return }

            for item in self.tempClipboardItemArray {
                if item.text == copiedString {
                    self.tempClipboardItemArray.removeAll(where: { $0.text == item.text })
                }
            }

            changeCount = pasteboard.changeCount
            guard !copiedString.isEmpty else { return }

            let newItem = ClipboardItem(id: UUID(), text: copiedString, copiedFromApplication: self.getCopiedFromApplication())

            self.tempClipboardItemArray.append(newItem)
            self.appStorageArray = StorageHelper.archiveStringArray(object: self.tempClipboardItemArray)
            print("\(changeCount), \(copiedString)")

            self.statusBarItem.menu = self.menu.createMenu()
            self.setMenuBarText(count: self.tempClipboardItemArray.count)
            NotificationCenter.default.post(name: .clipboardArrayChangedNotification, object: newItem)
        }
    }

    private func getCopiedFromApplication() -> CopiedFromApplication {
        guard let tempApplication = NSWorkspace().frontmostApplication else {
            let emptyApp = NSRunningApplication()
            return CopiedFromApplication(withApplication: emptyApp)
        }
        let application = CopiedFromApplication(withApplication: tempApplication)
        print("[DEBUG] copied from \(application.applicationTitle ?? "Unknown"))")
        return application
    }

    private func setMenuBarText(count: Int) {
        statusBarItem.button?.title = "Count: \(count)"
    }

    // MARK: - Private Actions
    @objc private func makeAppVisibleAction() {
        guard let window, !window.isVisible else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.window.orderFrontRegardless()
    }

    @objc private func makeAppHiddenAction() {
        guard let window, window.isVisible else { return }
        window.close()
        NSApplication.shared.deactivate()
        NSApplication.shared.hide(self)
    }

    @objc private func textSelectedFromClipboardAction(_ notification: NSNotification) {
        makeAppHiddenAction()
        KeyPressHelper.simulateKeyPressWithCommand(keyCode: KeyCode.v)
    }
}

// MARK: - Extension ApplicationMenu Delegate
extension AppDelegate: ApplicationMenuDelegate {
    func didTapClearAllButton() {
        self.tempClipboardItemArray.removeAll()
        self.statusBarItem.menu = self.menu.createMenu()
        setMenuBarText(count: 0)
        NotificationCenter.default.post(name: .clipboardArrayClearedNotification, object: nil)
    }
}
