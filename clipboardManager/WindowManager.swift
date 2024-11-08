//
//  WindowManager.swift
//  clipboardManager
//
//  Created by muratcankoc on 08/11/2024.
//

import SwiftUI
import AppKit

final class WindowManager: NSObject {
    static let shared = WindowManager()
    private var windows: [String: NSWindow] = [:]
    
    private override init() {
        super.init()
    }
    
    func showWindow(id: String, title: String, view: some View, width: CGFloat, height: CGFloat) {
        if let existingWindow = windows[id] {
            NSApplication.shared.activate(ignoringOtherApps: true)
            existingWindow.makeKeyAndOrderFront(nil)
            
            // Re-center the window
            if let screen = NSScreen.main {
                let centerX = screen.frame.midX - (existingWindow.frame.width / 2)
                let topY = screen.frame.maxY - 50
                existingWindow.setFrameTopLeftPoint(NSPoint(x: centerX, y: topY))
            }
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = title
        window.contentView = NSHostingView(rootView: view)
        window.level = .floating
        
        // Position window at the top-center of the screen
        if let screen = NSScreen.main {
            let centerX = screen.frame.midX - (window.frame.width / 2)
            let topY = screen.frame.maxY - 50
            window.setFrameTopLeftPoint(NSPoint(x: centerX, y: topY))
        }
        
        window.delegate = self
        windows[id] = window
        
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

extension WindowManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        // Remove window from dictionary when closed
        windows = windows.filter { $0.value != window }
    }
}
