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
    @Environment(\.managedObjectContext) var managedObjectContext
    
    var containerView: ContainerView!
    
    // MARK: - Lifecycle
    init() {
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

let hotkeyForInterfaceVisibility = HotKey(key: .v, modifiers: [.command, .shift])
var hotkeyForEscape = HotKey(key: .escape, modifiers: [])
// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Public Properties
    let persistenceController = PersistenceController.shared
    var containerView = ContainerView()
    static var windowControllers: [NSWindowController] = []
    private var preferencesWindow: NSWindow?
    
    // MARK: - Private Properties
    private var timer: Timer!
    private let pasteboard: NSPasteboard = .general
    private(set) var window: NSWindow!
    
    static private(set) var instance: AppDelegate!
    private lazy var statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = ApplicationMenu()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
        menu.delegate = self
        statusBarItem.menu = menu.createMenu()
        addObservers()
        setupWindow()
        hotkeyForInterfaceVisibility.keyDownHandler = handleAppShortcut
        hotkeyForEscape.keyDownHandler = makeAppHiddenAction
    }
    
    // MARK: - Public Methods
    func handleAppShortcut() {
        guard let window = self.window else { return }
        if window.isVisible {
            makeAppHiddenAction()
        } else {
            makeAppVisibleAction()
//            setupWindow()
        }
    }
    
    func handleEscapeCharacter() {
        makeAppHiddenAction()
    }
    
    // MARK: - Private Methods
    @objc private func setupWindowWithDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {[weak self] in
            guard let self else { return }
            self.setupWindow()
        }
    }
    @objc func setupWindow() {
        print("[DEBUG] setup window start")
        let windowController = NSHostingView(rootView: containerView)
        if let window = NSApplication.shared.windows.first {
            self.window = window
            self.window.contentView = windowController
            self.window.identifier = .init("appWindow")
            self.window.styleMask = [.titled, .docModalWindow]
            self.window.isMovable = false
            self.window.titlebarAppearsTransparent = true
            self.window.titleVisibility = .hidden
            self.window.level = .popUpMenu
            
            // Make sure window appears in full screen
            self.window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            
            if let screen = NSScreen.main {
                self.window.setFrameOrigin(NSPoint(x: screen.visibleFrame.minX, y: screen.frame.minY))
            }
            
            self.window.makeKey()
            self.window.orderFrontRegardless()
            NSApplication.shared.activate(ignoringOtherApps: true)
            
            
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
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesClickedAction), name: .preferencesClickedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateMenuBarItemCount(_:)), name: .pasteBoardCountNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: NSApplication.didBecomeActiveNotification, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(setupWindowWithDelay), name: .setupWindowNotification, object: nil)
    }
    
    @objc private func didBecomeActive() {
//                setupWindow()
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
    
    
    
    // MARK: - Make App Visible
    @objc private func makeAppVisibleAction() {
        let app = NSRunningApplication.current
        guard !app.isActive else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        guard let window = self.window else { return }
        
        window.styleMask = [.titled]
        window.titleVisibility = .hidden
        window.level = .popUpMenu
        window.identifier = .init("appWindow")
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Start the window off-screen at the bottom
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let offScreenY = -window.frame.height // Move the window off-screen
        window.setFrameOrigin(NSPoint(x: window.frame.origin.x, y: offScreenY))
        
        // Make the window key and order it front
        DispatchQueue.main.async {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(window.contentView)  // Ensure content view is first responder

            // Animate the window's position
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5 // Duration of the animation
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut) // Animation timing

                // Set the final position of the window
                window.animator().setFrameOrigin(NSPoint(x: window.frame.origin.x, y: screenHeight - window.frame.height - 50)) // Adjust to your desired position
            }, completionHandler: nil)

            // Ensure the window is positioned correctly on the screen
            if let screen = NSScreen.main {
                window.setFrameOrigin(NSPoint(x: screen.visibleFrame.minX, y: screen.frame.minY))
            }
        }

        app.activate(options: [.activateIgnoringOtherApps])
        print("DEBUG: ----- makeAppVisibleAction")
    }



    
    // MARK: - Make App Hidden
    @objc private func makeAppHiddenAction() {
        hotkeyForEscape.isPaused = true
        guard let window, window.isVisible else { return }
//        window.close()
        NSApplication.shared.deactivate()
        NSApplication.shared.hide(self)
        print("DEBUG: ----- makeAppHiddenAction")
    }
    
    // MARK: - Preferences Clicked
    @objc private func preferencesClickedAction() {
//        makeAppHiddenAction()
        
        DispatchQueue.main.asyncAfter(deadline: .now()+0.2) { [weak self] in
            guard let self else { return }
            
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            guard let preferencesWindow else { return }
            
            preferencesWindow.title = "Clipboard Settings"
            preferencesWindow.center()
            preferencesWindow.contentView = NSHostingView(rootView: ClipboardSettingsView())
            
            NSApplication.shared.activate(ignoringOtherApps: true)
            preferencesWindow.makeKeyAndOrderFront(nil)
            
            // Keep window from being released
            let windowController = NSWindowController(window: preferencesWindow)
//            windowController.showWindow(nil)settings
            
            // Store reference to prevent deallocation
            let windowNumber = preferencesWindow.windowNumber
            AppDelegate.windowControllers.append(windowController)
        }
        
    }
    
    // MARK: - Text selected from clipboard
    @objc private func textSelectedFromClipboardAction(_ setuptimer: NSNotification) {
        makeAppHiddenAction()
        KeyPressHelper.simulateKeyPressWithCommand(keyCode: KeyCode.v)
    }
}

// MARK: - Extension App Delegate
extension AppDelegate: ApplicationMenuDelegate {
    
    
    // MARK: - DidTap Clear All Items
    func didTapClearAllButton() {
        showCustomAlertWithTwoButtons(title: "Warning", message: "Are you sure you want to delete all items inside your clipboard?\n This action can NOT be reversed or undone.") { [weak self] in
            guard let self else { return }
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ClipboardEntity.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try persistenceController.container.viewContext.execute(deleteRequest)
                try persistenceController.container.viewContext.save()
            } catch {
                print("Error deleting clipboard items: \(error)")
            }
            setMenuBarText(count: 0)
            NotificationCenter.default.post(name: .allItemsClearedNotification, object: nil)
        }
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
