//
//  ShortcutRecorderView.swift
//  clipboardManager
//

import AppKit
import SwiftUI

struct ShortcutRecorderView: View {
    let shortcut: KeyboardShortcutSpec
    let isRecording: Bool
    let onStart: @MainActor () -> Void
    let onCancel: @MainActor () -> Void
    let onRecord: @MainActor (KeyboardShortcutSpec) -> Void
    let onReset: @MainActor () -> Void

    @State private var monitor: Any?
    @State private var rejected = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                isRecording ? onCancel() : onStart()
            } label: {
                HStack(spacing: 6) {
                    if isRecording {
                        Image(systemName: "record.circle")
                            .foregroundStyle(.red)
                            .symbolEffect(.pulse, options: .repeating, isActive: isRecording)
                        Text("Press a shortcut…")
                    } else {
                        Text(shortcut.display)
                            .font(.body.monospaced().weight(.semibold))
                            .contentTransition(.numericText())
                    }
                }
                .frame(minWidth: 132)
            }
            .buttonStyle(.glass)
            .offset(x: rejected ? -4 : 0)
            .animation(rejected ? .spring(duration: 0.12, bounce: 0.9) : .default, value: rejected)

            if isRecording {
                Text("esc cancels")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else if shortcut != .default {
                Button("Reset", action: onReset)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: isRecording)
        .onChange(of: isRecording) { _, recording in
            recording ? installMonitor() : removeMonitor()
        }
        .onDisappear {
            removeMonitor()
            if isRecording { onCancel() }
        }
    }

    private func installMonitor() {
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == KeyboardLayout.escape {
                onCancel()
                return nil
            }
            guard !KeyboardLayout.modifierKeyCodes.contains(event.keyCode) else { return nil }
            let flags = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .subtracting([.capsLock, .function, .numericPad, .help])
            let spec = KeyboardShortcutSpec(keyCode: event.keyCode, modifiers: flags.rawValue)
            guard spec.hasRequiredModifier else {
                NSSound.beep()
                rejected = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    rejected = false
                }
                return nil
            }
            onRecord(spec)
            return nil
        }
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

