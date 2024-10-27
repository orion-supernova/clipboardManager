//
//  AlertWindowController.swift
//  clipboardManager
//
//  Created by muratcankoc on 25/10/2024.
//

import SwiftUI

class AlertWindowController: NSWindowController {
    private let alertView: NSView
    private var completion: (() -> Void)?
    private let alertTitle: String
    private let alertMessage: String
    private var eventMonitor: Any?
    private let isSimpleAlert: Bool
    
    init(title: String, message: String, isSimpleAlert: Bool, completion: @escaping () -> Void) {
        self.alertTitle = title
        self.alertMessage = message
        self.isSimpleAlert = isSimpleAlert
        
        let window = NSWindow(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        window.isOpaque = false
        window.level = .modalPanel
        window.ignoresMouseEvents = false
        
        alertView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 150))
        
        super.init(window: window)
        
        self.completion = completion
        if isSimpleAlert {
            setupSimpleAlertView()
        } else {
            setupAlertViewTwoButtons()
        }
        
        setupEventMonitor()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self,
                  let window = self.window,
                  window.isVisible else { return event }
            
            let screenPoint = event.locationInWindow
            let windowPoint = window.convertPoint(fromScreen: screenPoint)
            
            if !self.alertView.frame.contains(windowPoint) {
                self.shakeWindow()
                return nil
            }
            
            return event
        }
    }
    
    private func shakeWindow() {
        guard let window = window else { return }
        
        let numberOfShakes = 3
        let durationOfShake = 0.2
        let vigourOfShake: CGFloat = 5
        
        let frame = window.frame
        let shakeAnimation = CAKeyframeAnimation()
        
        let shakePath = CGMutablePath()
        shakePath.move(to: CGPoint(x: frame.minX, y: frame.minY))
        
        for _ in 0...numberOfShakes-1 {
            shakePath.addLine(to: CGPoint(x: frame.minX - vigourOfShake, y: frame.minY))
            shakePath.addLine(to: CGPoint(x: frame.minX + vigourOfShake, y: frame.minY))
        }
        
        shakePath.closeSubpath()
        shakeAnimation.path = shakePath
        shakeAnimation.duration = durationOfShake
        
        window.animations = ["frameOrigin": shakeAnimation]
        window.animator().setFrameOrigin(frame.origin)
    }
    
    // MARK: - AlertView Setup
    private func setupSimpleAlertView() {
        alertView.wantsLayer = true
        if let color = NSColor.fromHex("#401B51") {  // Example for a shade of purple
            // Use the color
            alertView.layer?.backgroundColor = color.cgColor
        }
        alertView.layer?.cornerRadius = 12
        alertView.layer?.shadowColor = NSColor.black.cgColor
        alertView.layer?.shadowOpacity = 0.2
        alertView.layer?.shadowRadius = 10
        alertView.layer?.shadowOffset = CGSize(width: 0, height: 2)
        
        let titleLabel = createTitleLabel()
        let messageLabel = createMessageLabel()
        
        let okButton = createButton(title: "OK",
                                        color: .purple,
                                        action: #selector(cancelButtonClicked))
        alertView.addSubview(titleLabel)
        alertView.addSubview(messageLabel)
        alertView.addSubview(okButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: alertView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: alertView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: alertView.trailingAnchor, constant: -20),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: alertView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: alertView.trailingAnchor, constant: -20),

            okButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 20),
            okButton.centerXAnchor.constraint(equalTo: alertView.centerXAnchor, constant: 0),
            okButton.widthAnchor.constraint(equalToConstant: 80),
            okButton.heightAnchor.constraint(equalToConstant: 30),

        ])
        
        alertView.frame.size = NSSize(width: 600, height: 150)
        centerAlertView()
        window?.contentView?.addSubview(alertView)
    }
    private func setupAlertViewTwoButtons() {
        configureAlertView()
        let titleLabel = createTitleLabel()
        let messageLabel = createMessageLabel()
        let okButton = createButton(title: "OK",
                                    color: NSColor(red: 52/255, green: 152/255, blue: 219/255, alpha: 1.0),
                                    action: #selector(okButtonClicked))
        let cancelButton = createButton(title: "Cancel",
                                        color: NSColor(red: 231/255, green: 76/255, blue: 60/255, alpha: 1.0),
                                        action: #selector(cancelButtonClicked))

        alertView.addSubview(titleLabel)
        alertView.addSubview(messageLabel)
        alertView.addSubview(okButton)
        alertView.addSubview(cancelButton)

        setupConstraints(for: titleLabel, messageLabel: messageLabel, okButton: okButton, cancelButton: cancelButton)
        alertView.frame.size = NSSize(width: 450, height: 170)
        centerAlertView()
        window?.contentView?.addSubview(alertView)
    }

    // Configures the appearance of the alert view
    private func configureAlertView() {
        alertView.wantsLayer = true
        if let color = NSColor.fromHex("#401B51") {  // Example for a shade of purple
            // Use the color
            alertView.layer?.backgroundColor = color.cgColor
        }
        alertView.layer?.cornerRadius = 12
        alertView.layer?.shadowColor = NSColor.black.cgColor
        alertView.layer?.shadowOpacity = 0.2
        alertView.layer?.shadowRadius = 10
        alertView.layer?.shadowOffset = CGSize(width: 0, height: 2)
    }

    // Creates and returns the title label
    private func createTitleLabel() -> NSTextField {
        let titleLabel = NSTextField(labelWithString: alertTitle)
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        return titleLabel
    }

    // Creates and returns the message label
    private func createMessageLabel() -> NSTextField {
        let messageLabel = NSTextField(labelWithString: alertMessage)
        messageLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        messageLabel.alignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        return messageLabel
    }

    // Creates and returns a button with the specified title, color, and action
    private func createButton(title: String, color: NSColor, action: Selector) -> CustomButton {
        let button = CustomButton(frame: .zero)
        button.title = title
        button.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.layer?.masksToBounds = true
        button.isBordered = false
        
        button.originalColor = color
        button.hoverColor = color.lighter()
        button.pressedColor = color.darker()
        button.contentTintColor = .white

        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        
        return button
    }

    // Sets up layout constraints for the labels and buttons
    private func setupConstraints(for titleLabel: NSTextField, messageLabel: NSTextField, okButton: CustomButton, cancelButton: CustomButton) {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: alertView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: alertView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: alertView.trailingAnchor, constant: -20),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: alertView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: alertView.trailingAnchor, constant: -20),

            okButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 20),
            okButton.leadingAnchor.constraint(equalTo: alertView.centerXAnchor, constant: 20),
            okButton.widthAnchor.constraint(equalToConstant: 80),
            okButton.heightAnchor.constraint(equalToConstant: 30),

            cancelButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: alertView.centerXAnchor, constant: -20),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            cancelButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    // Centers the alert view on the screen
    private func centerAlertView() {
        if let screenFrame = NSScreen.main?.frame {
            let x = (screenFrame.width - alertView.frame.width) / 2
            let y = (screenFrame.height + screenHeight - alertView.frame.height) / 2
            alertView.frame.origin = CGPoint(x: x, y: y)
        }
    }

    
    // MARK: - Actions
    @objc func okButtonClicked() {
        hotkeyForInterfaceVisibility.isPaused = false
        // First, remove the event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        // Re-enable all windows before closing
        NSApplication.shared.windows.forEach { window in
            window.ignoresMouseEvents = false
        }
        
        // Close window and call completion
        window?.close()
        
        // Remove self from alerts array
        if let index = NSApp.alerts?.firstIndex(where: { $0 === self }) {
            NSApp.alerts?.remove(at: index)
        }
        
        // Call completion handler
        completion?()
    }
    
    @objc func cancelButtonClicked() {
        hotkeyForInterfaceVisibility.isPaused = false
        // First, remove the event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        // Re-enable all windows before closing
        NSApplication.shared.windows.forEach { window in
            window.ignoresMouseEvents = false
        }
        
        // Close window and call completion
        window?.close()
        
        // Remove self from alerts array
        if let index = NSApp.alerts?.firstIndex(where: { $0 === self }) {
            NSApp.alerts?.remove(at: index)
        }
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// Extension to store alert controllers
extension NSApplication {
    private static var alertsKey = "alertsKey"
    
    var alerts: [AlertWindowController]? {
        get {
            return objc_getAssociatedObject(self, &NSApplication.alertsKey) as? [AlertWindowController]
        }
        set {
            objc_setAssociatedObject(self, &NSApplication.alertsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// Show alert function
func showCustomAlertWithTwoButtons(title: String, message: String, completion: @escaping () -> Void = {}) {
    let alertController = AlertWindowController(title: title, message: message, isSimpleAlert: false) {
        completion()
    }
    
    // Disable all other windows
    NSApplication.shared.windows.forEach { window in
        if window != alertController.window {
            window.ignoresMouseEvents = true
            if window.identifier == .init("appWindow") {
                window.close()
            }
        }
    }
    
    alertController.showWindow(nil)
    hotkeyForInterfaceVisibility.isPaused = true
        
    // Keep a reference to prevent deallocation
    NSApp.alerts = (NSApp.alerts ?? []) + [alertController]
}

func showSimpleCustomAlert(title: String, message: String) {
    let alertController = AlertWindowController(title: title, message: message, isSimpleAlert: true) {
        //
    }
    
    // Disable all other windows
    NSApplication.shared.windows.forEach { window in
        if window != alertController.window {
            window.ignoresMouseEvents = true
            if window.identifier == .init("appWindow") {
                window.close()
            }
        }
    }
    
    alertController.showWindow(nil)
    hotkeyForInterfaceVisibility.isPaused = true
        
    // Keep a reference to prevent deallocation
    NSApp.alerts = (NSApp.alerts ?? []) + [alertController]
}
