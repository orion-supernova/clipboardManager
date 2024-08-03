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
    @Environment(\.managedObjectContext) var managedObjectContext
    
    var containerView: ContainerView!
    
    // MARK: - Lifecycle
    init() {
        hotkeyForInterfaceVisibility.keyDownHandler = appDelegate.handleAppShortcut
        self.containerView = appDelegate.containerView
    }
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            self.containerView
                .fixedSize()
                .environment(\.managedObjectContext, appDelegate.persistenceController.container.viewContext)
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Public Properties
    let persistenceController = PersistenceController.shared
    var containerView = ContainerView()
    
    // MARK: - Private Properties
    private var timer: Timer!
    private let pasteboard: NSPasteboard = .general
    private var window: NSWindow!
    
    static private(set) var instance: AppDelegate!
    private lazy var statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = ApplicationMenu()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
        menu.delegate = self
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
        let windowController = NSHostingView(rootView: containerView)
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
        NotificationCenter.default.addObserver(self, selector: #selector(updateMenuBarItemCount(_:)), name: .pasteBoardCountNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hmm), name: NSApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc private func hmm() {
        NotificationCenter.default.post(name: .refreshClipboardItems, object: nil)
    }
    
    @objc private func updateMenuBarItemCount(_ notification: NSNotification) {
        let fetchRequest: NSFetchRequest<ClipboardEntity> = ClipboardEntity.fetchRequest()
        do {
            let count = try persistenceController.container.viewContext.count(for: fetchRequest)
            setMenuBarText(count: count)
        } catch {
            print("Error fetching clipboard item count: \(error)")
        }
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
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ClipboardEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try persistenceController.container.viewContext.execute(deleteRequest)
            try persistenceController.container.viewContext.save()
        } catch {
            print("Error deleting clipboard items: \(error)")
        }
        setMenuBarText(count: 0)
        NotificationCenter.default.post(name: .refreshClipboardItems, object: nil)
    }
}

// MARK: - PersistenceController
class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "ClipboardModel")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }
}

