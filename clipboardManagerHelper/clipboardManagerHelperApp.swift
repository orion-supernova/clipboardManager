//
//  clipboardManagerHelperApp.swift
//  clipboardManagerHelper
//
//  Created by muratcankoc on 25/10/2024.
//

import SwiftUI

@main
struct clipboardManagerHelperApp: App {
    init() {
        let mainAppIdentifier = "com.walhallaa.clipboardManager" // Change this to your main app's identifier

        // Launch the main application
        if let mainAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mainAppIdentifier) {
            NSWorkspace.shared.open(mainAppURL)
        } else {
            print("Main application not found.")
        }

        // Terminate the helper application
        NSApp.terminate(nil)
    }

    var body: some Scene {
        // No UI needed for the helper app
        EmptyView()
    }
}

