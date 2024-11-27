//
//  ClipboardSettingsView.swift
//  clipboardManager
//
//  Created by muratcankoc on 24/10/2024.
//

import SwiftUI
import ServiceManagement
import Carbon

// Add these declarations
private let kTISPropertyUnicodeKeyLayoutData: CFString = ("TISPropertyUnicodeKeyLayoutData" as CFString)

struct ClipboardSettingsView: View {
    @Environment(\.controlActiveState) private var controlActiveState
    @StateObject private var settings = ClipboardSettings.shared
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            GeneralSettingsSection(settings: settings)
            SubscriptionStatusSection(subscriptionManager: subscriptionManager)
            AutopasteSection()
            KeyboardShortcutsSection()
        }
        .onChange(of: settings.retainCount) { newCount in
            if newCount == -1 {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now()+0.2) {
                    showSimpleCustomAlert(title: "Caution!", message: "This may lead to performance issues and more CPU usage if you have a lot of items.")
                }
            } else {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now()+0.2) {
                    showSimpleCustomAlert(title: "Okay!", message: "Your extra items will be removed when you restart the app.")
                }
            }
        }
        .padding()
        .frame(width: 400)
    }
}

// Break down into separate components
struct GeneralSettingsSection: View {
    @ObservedObject var settings: ClipboardSettings
    
    var body: some View {
        GroupBox(label: Text("General Settings").bold()) {
            VStack(alignment: .leading, spacing: 12) {
//                Toggle("Launch at login", isOn: $settings.launchAtLogin)
//                    .onChange(of: settings.launchAtLogin) { newValue in
//                        if newValue {
//                            addToLaunchItems()
//                        } else {
//                            removeFromLaunchItems()
//                        }
//                    }
//                Divider()
                
                RetainClipsSection(settings: settings)
                KeyboardNavigationSection(settings: settings)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}

struct SubscriptionStatusSection: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        GroupBox(label: Text("Subscription Status").bold()) {
            VStack(alignment: .leading, spacing: 12) {
                // ... subscription status content ...
                StatusContent(subscriptionManager: subscriptionManager)
                
                #if DEBUG
                DebugControls(subscriptionManager: subscriptionManager)
                #endif
            }
            .padding()
        }
    }
}

struct StatusContent: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Status:")
                Text(subscriptionManager.isSubscribed ? "Active" : "Free")
                    .foregroundColor(subscriptionManager.isSubscribed ? .green : .secondary)
            }
            
            if subscriptionManager.isSubscribed {
                SubscriptionDetails(subscriptionManager: subscriptionManager)
            } else {
                UpgradeButton()
            }
        }
    }
}

struct SubscriptionDetails: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Plan:")
                Text(subscriptionManager.currentTier?.displayName ?? "Unknown")
            }
            
            if let expirationDate = subscriptionManager.subscriptionExpirationDate {
                HStack {
                    Text("Expires:")
                    Text(expirationDate, style: .date)
                }
            }
        }
    }
}

struct UpgradeButton: View {
    var body: some View {
        Button("Upgrade to Pro") {
            NotificationCenter.default.post(
                name: .showSubscriptionViewNotification,
                object: nil
            )
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .padding(.top, 8)
    }
}

#if DEBUG
struct DebugControls: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("Debug Controls")
                .font(.headline)
            
            HStack(spacing: 16) {
                Button("Set Monthly") {
                    subscriptionManager.setDebugSubscriptionStatus(
                        isSubscribed: true,
                        tier: .monthly
                    )
                }
                
                Button("Set Weekly") {
                    subscriptionManager.setDebugSubscriptionStatus(
                        isSubscribed: true,
                        tier: .weekly
                    )
                }
                
                Button("Cancel") {
                    subscriptionManager.cancelDebugSubscription()
                }
                .foregroundColor(.red)
            }
        }
    }
}
#endif

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
//class ClipboardSettingsViewWrapper: ObservableObject {
//    // MARK: - Properties
//    @Published var launchOnLogin: Bool = false
//    @Published var retainClips: Int = 20
//    @Published var clearItemsOlderThanHours: Int = 24
//    
//    // MARK: - Lifecycle
//    init () {
//        NotificationCenter.default.addObserver(self, selector: #selector(launchAtLoginChangedNotificationAction(_:)), name: .launchAtLoginChangedNotification, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(retainCountChangedNotificationAction(_:)), name: .retainCountChangedNotification, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(clearItemsOlderThanHoursChangedNotificationAction(_:)), name: .clearItemsOlderThanHoursChangedNotification, object: nil)
//    }
//    
//    deinit {
//        NotificationCenter.default.removeObserver(self)
//    }
//    
//    // MARK: - Private Methods
//    @objc private func launchAtLoginChangedNotificationAction (_ notification: NSNotification) {
//        if let object = notification.object as? Bool {
//            print(object)
//            launchOnLogin = object
//            if object == true {
//                addToLaunchItems()
//            } else {
//                removeFromLaunchItems()
//            }
//        }
//    }
//    @objc private func retainCountChangedNotificationAction (_ notification: NSNotification) {
//        if let object = notification.object as? Int {
//            print(object)
//            retainClips = object
//        }
//    }
//    @objc private func clearItemsOlderThanHoursChangedNotificationAction (_ notification: NSNotification) {
//        if let object = notification.object as? Int {
//            print(object)
//            clearItemsOlderThanHours = object
//        }
//    }
//    
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
//
//
//
//
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
//
//
//
//}

struct AutopasteSection: View {
    var body: some View {
        GroupBox(label: Text("Don't Forget to Enable Autopaste").bold()) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Enable Autopaste by adding / enabling this app in System Preferences > Privacy & Security > Accessibility")
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("If you can't still auto-paste, remove completely with minus sign (-) and add it with plus sign (+) again.")
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button("Open Accessibility Preferences") {
                    openAccessibilityPreferences()
                }
            }
            .padding()
        }
    }
    
    private func openAccessibilityPreferences() -> Bool {
        let prefpaneURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        if NSWorkspace.shared.open(prefpaneURL) {
            return true
        }
        return NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
    }
}

struct KeyboardShortcutsSection: View {
    var body: some View {
        GroupBox(label: Text("Keyboard Shortcuts").bold()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Show / Hide clipboard:")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    KeyboardShortcutView(shortcut: "⌘ + Shift + V")
                    Spacer()
                }
                
                HStack {
                    Text("Open Settings:")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    KeyboardShortcutView(
                        shortcut: "⌘ + \(getKeyboardCharacter(for: KeyCode.comma).uppercased())"
                    )
                    Spacer()
                }
            }
            .padding()
        }
    }
    
    private func getKeyboardCharacter(for keyCode: UInt16) -> String {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData),
              let keyboardLayout = unsafeBitCast(layoutData, to: CFData.self) as Data? else {
            return ","
        }
        
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        
        return keyboardLayout.withUnsafeBytes { ptr -> String in
            guard let baseAddress = ptr.baseAddress else { return "," }
            
            let status = UCKeyTranslate(
                baseAddress.assumingMemoryBound(to: UCKeyboardLayout.self),
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                4,
                &length,
                &chars
            )
            
            if status == noErr {
                return String(utf16CodeUnits: chars, count: length)
            }
            
            return ","
        }
    }
}

// Update the key code conversion extension
extension NSEvent {
    static func keyEquivalent(from keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData),
              let keyLayout = unsafeBitCast(layoutData, to: CFData.self) as Data? else {
            return nil
        }
        
        var deadKeyState: UInt32 = 0
        var stringLength = 0
        var chars = [UniChar](repeating: 0, count: 4)
        
        let result = withUnsafePointer(to: keyLayout.withUnsafeBytes { $0.load(as: UCKeyboardLayout.self) }) { ptr in
            UCKeyTranslate(
                ptr,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0,  // No modifiers
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                4,
                &stringLength,
                &chars
            )
        }
        
        guard result == noErr else { return nil }
        return String(utf16CodeUnits: chars, count: stringLength)
    }
}

struct RetainClipsSection: View {
    @ObservedObject var settings: ClipboardSettings
    
    var body: some View {
        HStack {
            Text("Retain clips:")
            Picker("", selection: $settings.retainCount) {
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
    }
}

struct KeyboardNavigationSection: View {
    @ObservedObject var settings: ClipboardSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Enable keyboard navigation", isOn: $settings.enableKeyboardNavigation)
                .help("Use left/right arrow keys to navigate and Enter to select")
            
            if settings.enableKeyboardNavigation {
                HStack(spacing: 16) {
                    Text("Shortcuts:")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .foregroundColor(.blue)
                            Text("Previous")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.blue)
                            Text("Next")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        
                        HStack(spacing: 4) {
                            Text("↵")
                                .foregroundColor(.blue)
                            Text("Select")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.leading, 20)
            }
        }
    }
}
