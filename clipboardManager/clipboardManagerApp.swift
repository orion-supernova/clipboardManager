//
//  clipboardManagerApp.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import HotKey
import SwiftUI

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
                .environment(
                    \.managedObjectContext, appDelegate.persistenceController.container.viewContext)
        }
    }
}

let hotkeyForInterfaceVisibility = HotKey(key: .v, modifiers: [.command, .shift])
let hotkeyForEscape = HotKey(key: .escape, modifiers: [])
let hotkeyForSettings = HotKey(key: .comma, modifiers: [.command])
// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    // MARK: - Public Properties
    let persistenceController = PersistenceController.shared
    var containerView = ContainerView()
    static var windowControllers: [NSWindowController] = []
    private var preferencesWindow: NSWindow?

    // MARK: - Private Properties
    private var timer: Timer!
    private let pasteboard: NSPasteboard = .general
    private(set) var window: NSWindow!
    private var isAnimating = false
    private var shouldFetchAfterAnimation = false
    private var clipboardManager = ClipboardManager.shared

    static private(set) var instance: AppDelegate!
    private lazy var statusBarItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength)
    private let menu = ApplicationMenu()

    private var subscriptionWindow: NSWindow?

    // Add this property to AppDelegate class
    private var isHandlingVisibilityChange = false

    // In AppDelegate class, add this property
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
        menu.delegate = self
        statusBarItem.menu = menu.createMenu()
        addObservers()
        setupWindow()
        
        // Setup keyboard shortcuts
        hotkeyForInterfaceVisibility.keyDownHandler = handleAppShortcut
        hotkeyForEscape.keyDownHandler = makeAppHiddenAction
        hotkeyForSettings.keyDownHandler = { [weak self] in
            self?.preferencesClickedAction()
        }
        
        // Set up window level observer for StoreKit authentication window
        NSWindow.swizzleKeyWindow()
    }

    // MARK: - Public Methods
    func handleAppShortcut() {
        guard let window = self.window else { return }
        if window.isVisible {
            makeAppHiddenAction()
        } else {
            makeAppVisibleAction()
        }
    }

    func handleEscapeCharacter() {
        makeAppHiddenAction()
    }

    // MARK: - Private Methods
    @objc private func setupWindowWithDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.setupWindow()
        }
    }
    
    // MARK: - SETUP WINDOW
    @objc func setupWindow() {
        print("[DEBUG] setup window start")
        let windowController = NSHostingView(rootView: containerView)
        
        if let window = NSApplication.shared.windows.first {
            self.window = window
            self.window.contentView = windowController
            self.window.identifier = .init("appWindow")
            
            // Configure window with proper level and properties
            configureWindowProperties(window)
            
            // Setup event monitor
            setupEventMonitor()
            
            // Proper window activation sequence
            window.orderFrontRegardless()
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKey()
            window.makeFirstResponder(window.contentView)
            
            // Force window to maintain its level and position after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                window.level = .popUpMenu
                self.positionWindowAtBottom(window)
                
                // Ensure window is still active
                window.orderFrontRegardless()
                NSApplication.shared.activate(ignoringOtherApps: true)
                window.makeKey()
                window.makeFirstResponder(window.contentView)
            }
            
            print("[DEBUG] setup window end")
        }
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func addObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(makeAppHiddenAction),
            name: NSApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(textSelectedFromClipboardAction(_:)),
            name: .textSelectedFromClipboardNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(makeAppVisibleAction), name: .makeAppVisibleNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(preferencesClickedAction),
            name: .preferencesClickedNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateMenuBarItemCount(_:)),
            name: .pasteBoardCountNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(didBecomeActive),
            name: NSApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(showSubscriptionWindow),
            name: .showSubscriptionViewNotification, object: nil)
    }

    @objc private func didBecomeActive() {
        // Removed print statement
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

    
    
    // MARK: - MAKE APP VISIBLE
    @objc private func makeAppVisibleAction() {
        guard !isHandlingVisibilityChange else { return }
        isHandlingVisibilityChange = true
        
        guard let window = self.window,
              let contentView = window.contentView else {
            isHandlingVisibilityChange = false
            return
        }
        
        // Configure window with highest level
        window.level = .popUpMenu
        window.isMovable = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Position window
        positionWindowAtBottom(window)
        
        // Setup event monitor
        self.setupEventMonitor()
        
        // Prepare for animation
        prepareContentViewForAnimation(contentView)
        contentView.layer?.transform = CATransform3DMakeTranslation(0, -contentView.frame.height, 0)
        NotificationCenter.default.post(name: .windowDidBecomeReady, object: nil)
        // Perform animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            contentView.animator().layer?.transform = CATransform3DIdentity
        }) { [weak self] in
            guard let self = self else { return }
            
            // Force activation on main thread after animation
            DispatchQueue.main.async {
                // Ensure window is at correct position and level
                window.level = .popUpMenu
                self.positionWindowAtBottom(window)
                
                // Force app and window activation
                NSApplication.shared.activate(ignoringOtherApps: true)
                window.orderFrontRegardless()
                
                // Force key window and first responder status
                if !window.isKeyWindow {
                    window.makeKey()
                }
                if window.firstResponder != contentView {
                    window.makeFirstResponder(contentView)
                }
                
                // Re-enable hotkeys
                hotkeyForEscape.isPaused = false
                hotkeyForSettings.isPaused = false
                
                // Reset handling flag
                self.isHandlingVisibilityChange = false
                
                DispatchQueue.main.asyncAfter(deadline: .now()+0.2) {
                    // Post notification that window is ready
                    NotificationCenter.default.post(name: .windowDidBecomeReady, object: nil)
                }
            }
        }
    }

    // MARK: - Make App Hidden
    @objc func makeAppHiddenAction() {
        guard !isHandlingVisibilityChange else { return }
        isHandlingVisibilityChange = true
        
        // Disable hotkeys first
        hotkeyForEscape.isPaused = true
        hotkeyForSettings.isPaused = true
        
        // Remove event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        guard let window = self.window,
              window.isVisible,
              let contentView = window.contentView else {
            isHandlingVisibilityChange = false
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.prepareContentViewForAnimation(contentView)
            
            self?.animateContentView(contentView, isShowing: false, duration: 0.15) { [weak self] in
                NSApplication.shared.hide(nil)
                NSApp.hide(nil)
                self?.isHandlingVisibilityChange = false
            }
        }
    }

    // MARK: - Preferences Clicked
    @objc private func preferencesClickedAction() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }

            // Create the window if it doesn't exist
            if self.preferencesWindow == nil {
                self.preferencesWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                    styleMask: [.titled, .closable, .miniaturizable],
                    backing: .buffered,
                    defer: false
                )

                self.preferencesWindow?.title = "Clipboard Settings"
                self.preferencesWindow?.contentView = NSHostingView(
                    rootView: ClipboardSettingsView())
                self.preferencesWindow?.level = .screenSaver
            }

            guard let preferencesWindow = self.preferencesWindow else { return }

            // Position the window at the top-center of the screen
            if let screen = NSScreen.main {
                let centerX = screen.frame.midX - (preferencesWindow.frame.width / 2)
                let topY = screen.frame.maxY - 50  // 50 pixels from top

                preferencesWindow.setFrameTopLeftPoint(NSPoint(x: centerX, y: topY))
            }

            NSApplication.shared.activate(ignoringOtherApps: true)
            preferencesWindow.makeKeyAndOrderFront(nil)

            // Keep window from being released
            let windowController = NSWindowController(window: preferencesWindow)
            AppDelegate.windowControllers.append(windowController)
        }
    }

    // MARK: - Text selected from clipboard
    @objc private func textSelectedFromClipboardAction(_ setuptimer: NSNotification) {
        makeAppHiddenAction()
        KeyPressHelper.shared.performPasteActionWithGettingVKey()
    }

    @objc private func showSubscriptionWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }

            if let existingWindow = self.subscriptionWindow {
                existingWindow.titlebarAppearsTransparent = true
                existingWindow.titleVisibility = .hidden
                existingWindow.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
                return
            }

            self.subscriptionWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 800),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )

            guard let window = self.subscriptionWindow else { return }

            window.title = "Subscription"
            window.contentView = NSHostingView(rootView: SubscriptionView())
            window.level = .screenSaver
            window.delegate = self
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = false
            window.center()

            let windowController = NSWindowController(window: window)
            AppDelegate.windowControllers.append(windowController)

            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    // NSWindowDelegate method
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // Remove event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        // Handle specific window closures
        if window == subscriptionWindow {
            subscriptionWindow = nil
            AppDelegate.windowControllers.removeAll { controller in
                controller.window == window
            }
        } else if window == preferencesWindow {
            preferencesWindow = nil
            AppDelegate.windowControllers.removeAll { controller in
                controller.window == window
            }
        }
    }

    func applicationDidReceiveMemoryWarning(_ notification: Notification) {
        ClipboardManager.shared.handleMemoryWarning()
    }

    // Add this method to setup event monitoring
    private func setupEventMonitor() {
        // Remove existing monitor if any
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        // Create new monitor for key events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self,
                  let window = self.window,
                  window.isKeyWindow else {
                return event
            }
            
            // Handle arrow keys
            switch event.keyCode {
            case 123: // Left Arrow
                NotificationCenter.default.post(name: .arrowKeyPressedNotification, object: -1)
                return nil
            case 124: // Right Arrow
                NotificationCenter.default.post(name: .arrowKeyPressedNotification, object: 1)
                return nil
            case 53: // Escape
                self.makeAppHiddenAction()
                return nil
            case 36: // Enter
                if let selectedItem = self.clipboardManager.orderedItems.indices.contains(self.clipboardManager.selectedItemIndex) ? 
                    self.clipboardManager.orderedItems[self.clipboardManager.selectedItemIndex] : nil {
                    self.clipboardManager.handleItemTap(item: selectedItem, index: self.clipboardManager.selectedItemIndex)
                }
                return nil
            default:
                return event
            }
        }
    }
}
// MARK: - Extension App Delegate
extension AppDelegate: ApplicationMenuDelegate {

    // MARK: - DidTap Clear All Items
    func didTapClearAllButton() {
        showCustomAlertWithTwoButtons(
            title: "Warning",
            message:
                "Are you sure you want to delete all items inside your clipboard?\n This action can NOT be reversed or undone."
        ) { [weak self] in
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

extension NSNotification.Name {
    // ... other notification names ...
    static let showSubscriptionViewNotification = NSNotification.Name(
        "showSubscriptionViewNotification")
    static let arrowKeyPressedNotification = NSNotification.Name("arrowKeyPressedNotification")
    static let windowDidBecomeReady = NSNotification.Name("windowDidBecomeReady")
}

extension NSWindow {
    static func swizzleKeyWindow() {
        let originalSelector = #selector(NSWindow.makeKeyAndOrderFront(_:))
        let swizzledSelector = #selector(NSWindow.swizzled_makeKeyAndOrderFront(_:))
        
        let originalMethod = class_getInstanceMethod(NSWindow.self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(NSWindow.self, swizzledSelector)
        
        if let originalMethod = originalMethod, let swizzledMethod = swizzledMethod {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    @objc func swizzled_makeKeyAndOrderFront(_ sender: Any?) {
        self.swizzled_makeKeyAndOrderFront(sender)
        
        // Check if this is a StoreKit authentication window
        if self.title.contains("Store") {
            self.level = .popUpMenu  // Highest level for modal windows
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// Add these private methods for window configuration
private extension AppDelegate {
    func configureWindowProperties(_ window: NSWindow) {
        window.styleMask = [.titled]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.level = .popUpMenu
        window.isMovable = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.acceptsMouseMovedEvents = true
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
    }
    
    func positionWindowAtBottom(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let currentFrame = window.frame
        
        // Use frame.minY instead of visibleFrame.minY to ignore the Dock
        let bottomY = screen.frame.minY
        
        // Center horizontally using frame instead of visibleFrame
        let centerX = screen.frame.midX - (currentFrame.width / 2)
        
        // Always ensure highest window level
        window.level = .popUpMenu
        
        window.setFrame(
            NSRect(
                x: centerX,
                y: bottomY,
                width: currentFrame.width,
                height: currentFrame.height
            ),
            display: true,
            animate: true
        )
    }
    
    func prepareContentViewForAnimation(_ contentView: NSView) {
        contentView.wantsLayer = true
        contentView.layer?.removeAllAnimations()
    }
    
    func animateContentView(_ contentView: NSView, 
                           isShowing: Bool, 
                           duration: TimeInterval, 
                           completion: @escaping () -> Void) {
        // Set animating flag
        isAnimating = true
        
        // Cancel any ongoing animations
        contentView.layer?.removeAllAnimations()
        
        // Optimize layer updates
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Configure animation
        let animation = CABasicAnimation(keyPath: "transform")
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: isShowing ? .easeOut : .easeIn)
        animation.fromValue = contentView.layer?.transform
        animation.toValue = isShowing ? 
            CATransform3DIdentity : 
            CATransform3DMakeTranslation(0, -contentView.frame.height, 0)
        animation.isRemovedOnCompletion = true
        
        // Set completion handler
        CATransaction.setCompletionBlock { [weak self, weak contentView] in
            contentView?.layer?.removeAllAnimations()
            self?.isAnimating = false
            
            // Check if we need to fetch after animation
            if self?.shouldFetchAfterAnimation == true {
                self?.shouldFetchAfterAnimation = false
                DispatchQueue.main.async {
                    self?.clipboardManager.fetchClipboardItems()
                }
            }
            
            completion()
        }
        
        // Apply animation
        contentView.layer?.add(animation, forKey: "transform")
        contentView.layer?.transform = animation.toValue as! CATransform3D
        
        CATransaction.commit()
    }
}
