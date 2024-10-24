//
//  ClipboardSettingsView.swift
//  clipboardManager
//
//  Created by muratcankoc on 24/10/2024.
//

import SwiftUI

struct ClipboardSettingsView: View {
    @State private var retainCount: Int = 50
    @State private var launchAtLogin: Bool = true
    @State private var showNotifications: Bool = true
    @State private var clearInterval: Int = 24
    
    var body: some View {
        VStack(spacing: 20) {
            GroupBox(label: Text("General Settings").bold()) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch at login", isOn: $launchAtLogin)
//                    Toggle("Show notifications", isOn: $showNotifications)
                    
                    Divider()
                    
                    HStack {
                        Text("Retain clips:")
                        Picker("", selection: $retainCount) {
                            ForEach([20, 50, 100, 200, 500], id: \.self) { count in
                                Text("\(count) items").tag(count)
                            }
                        }
                        .frame(width: 120)
                    }
                    
                    HStack {
                        Text("Clear items older than:")
                        Picker("", selection: $clearInterval) {
                            Text("Never clear items automatically").tag(0)
                            Text("24 hours").tag(24)
                            Text("48 hours").tag(48)
                            Text("7 days").tag(168)
                        }
                        .frame(width: 120)
                    }
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
