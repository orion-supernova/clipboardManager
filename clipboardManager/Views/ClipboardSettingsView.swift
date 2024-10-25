//
//  ClipboardSettingsView.swift
//  clipboardManager
//
//  Created by muratcankoc on 24/10/2024.
//

import SwiftUI
import ServiceManagement

struct ClipboardSettingsView: View {
//    @EnvironmentObject var clipboardManager: ClipboardManager
    let clipboardManager = ClipboardManager.shared
    @StateObject var wrapper =  ClipboardSettingsViewWrapper() // Only calling this function is enough since everytime it changes, the UI redraws itself.
                                                               //No need to call its variables somewhere.

    var body: some View {
        VStack(spacing: 20) {
            GroupBox(label: Text("General Settings").bold()) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch at login", isOn: Binding(get: { clipboardManager.launchAtLogin }, set: { clipboardManager.launchAtLogin = $0 }))
                    Divider()
                    
                    HStack {
                        Text("Retain clips:")
                        Picker("", selection: Binding(get: { clipboardManager.retainCount }, set: { clipboardManager.retainCount = $0 })) {
                            ForEach([20, 50, 100, 200, 500, -1], id: \.self) { count in
                                if count == -1 {
                                    Text("Infinite").tag(count)
                                } else {
                                    Text("\(count) items").tag(count)
                                }
                            }
                        }
                        .frame(width: 120)
                    }
                    
//                    HStack {
//                        Text("Clear items older than:")
//                        Picker("", selection: Binding(get: { clipboardManager.clearItemsOlderThanHours }, set: { clipboardManager.clearItemsOlderThanHours = $0 })) {
//                            Text("Never clear items automatically").tag(0)
//                            Text("24 hours").tag(24)
//                            Text("48 hours").tag(48)
//                            Text("7 days").tag(168)
//                        }
//                        .frame(width: 120)
//                    }
                }
                .padding()
            }
            
            GroupBox(label: Text("Keyboard Shortcuts").bold()) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Show / Hide clipboard:")
                            .frame(width: 100, alignment: .leading)
                        KeyboardShortcutView(shortcut: "⌘ + Shift + V")
                    }
//                    HStack {
//                        Text("Clear history:")
//                            .frame(width: 100, alignment: .leading)
//                        KeyboardShortcutView(shortcut: "⌘ + Shift + X")
//                    }
                }
                .padding()
            }
            
//            HStack {
//                Spacer()
//                Button("Restore Defaults") {
//                    // Add reset logic here
//                }
//                Button("Save") {
//                    // Add save logic here
//                }
//            }
        }
        .padding()
        .frame(width: 400)
    }
}

struct KeyboardShortcutView: View {
    let shortcut: String
    
    var body: some View {
        Text(shortcut)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(6)
    }
}

#Preview {
    ClipboardSettingsView()
}

// MARK: - Wrapper
class ClipboardSettingsViewWrapper: ObservableObject {
    // MARK: - Properties
    @Published var launchOnLogin: Bool = false
    @Published var retainClips: Int = 20
    @Published var clearItemsOlderThanHours: Int = 24
    
    // MARK: - Lifecycle
    init () {
        NotificationCenter.default.addObserver(self, selector: #selector(launchAtLoginChangedNotificationAction(_:)), name: .launchAtLoginChangedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(retainCountChangedNotificationAction(_:)), name: .retainCountChangedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(clearItemsOlderThanHoursChangedNotificationAction(_:)), name: .clearItemsOlderThanHoursChangedNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Private Methods
    @objc private func launchAtLoginChangedNotificationAction (_ notification: NSNotification) {
        if let object = notification.object as? Bool {
            print(object)
            launchOnLogin = object
            if object == true {
                addToLaunchItems()
            } else {
                removeFromLaunchItems()
            }
        }
    }
    @objc private func retainCountChangedNotificationAction (_ notification: NSNotification) {
        if let object = notification.object as? Int {
            print(object)
            retainClips = object
        }
    }
    @objc private func clearItemsOlderThanHoursChangedNotificationAction (_ notification: NSNotification) {
        if let object = notification.object as? Int {
            print(object)
            clearItemsOlderThanHours = object
        }
    }
    
    func addToLaunchItems() {
        let helperBundleIdentifier = "com.walhallaa.clipboardManagerHelper"

        // Assuming the helper app is located in the Applications folder
        let helperAppPath = "\(NSHomeDirectory())/Applications/ClipboardManagerHelper.app" // Adjust this path as necessary

        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/\(helperBundleIdentifier).plist"

        // Create the Launch Agent dictionary
        let launchAgentDict: [String: Any] = [
            "Label": helperBundleIdentifier,
            "Program": helperAppPath,
            "RunAtLoad": true,
            "KeepAlive": true,
        ]

        do {
            // Convert the dictionary to plist data
            let plistData = try PropertyListSerialization.data(fromPropertyList: launchAgentDict, format: .xml, options: 0)
            
            // Ensure the path exists before writing the plist
            let launchAgentsDir = "\(NSHomeDirectory())/Library/LaunchAgents"
            let fileManager = FileManager.default
            
            // Create LaunchAgents directory if it doesn't exist
            if !fileManager.fileExists(atPath: launchAgentsDir) {
                try fileManager.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true, attributes: nil)
            }

            // Write the plist data to the Launch Agents directory
            try plistData.write(to: URL(fileURLWithPath: launchAgentPath))
            print("Successfully added to Launch Items.")
        } catch {
            print("Failed to write Launch Agent plist: \(error)")
        }
    }




    func removeFromLaunchItems() {
        let helperBundleIdentifier = "com.walhallaa.clipboardManagerHelper"
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/\(helperBundleIdentifier).plist"
        
        do {
            try FileManager.default.removeItem(atPath: launchAgentPath)
            print("Successfully removed from Launch Items.")
        } catch {
            print("Failed to remove Launch Agent: \(error)")
        }
    }



}
