//
//  SettingsView.swift
//  clipboardManager
//
//  System Settings-style layout: a sidebar of sections and a grouped form.
//

import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationSplitView {
            List(selection: $store.section) {
                ForEach(SettingsFeature.State.Section.allCases) { section in
                    Label(section.rawValue, systemImage: section.symbol)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            Form {
                switch store.section ?? .general {
                case .general: generalSection
                case .capture: captureSection
                case .privacy: privacySection
                case .dragAndPaste: dragAndPasteSection
                case .shortcuts: shortcutsSection
                case .about: aboutSection
                }
            }
            .formStyle(.grouped)
            .navigationTitle((store.section ?? .general).rawValue)
            .id(store.section)
            .transition(.opacity)
        }
        .navigationSplitViewStyle(.balanced)
        .animation(.smooth(duration: 0.22), value: store.section)
        .frame(minWidth: 720, minHeight: 480)
        .task { await store.send(.task).finish() }
    }

    // MARK: - General

    @ViewBuilder
    private var generalSection: some View {
        Section("Startup") {
            Toggle("Launch Mahmut at login", isOn: Binding(
                get: { store.launchAtLogin },
                set: { store.send(.launchAtLoginToggled($0)) }
            ))
            if let error = store.launchAtLoginError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        Section("History") {
            Picker("Keep", selection: Binding(store.$retainCount)) {
                ForEach(RetentionOption.allCases, id: \.rawValue) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            Picker("Remove items older than", selection: Binding(store.$maxAgeHours)) {
                ForEach(MaxAgeOption.allCases, id: \.rawValue) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            Text("Pinned items and items saved in folders are never removed automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Navigation") {
            Toggle("Keyboard navigation", isOn: Binding(store.$keyboardNavigation))
            Toggle("Show ⌘1–⌘9 hints on cards", isOn: Binding(store.$showShortcutHints))
                .disabled(!store.keyboardNavigation)
        }
    }

    // MARK: - Capture

    @ViewBuilder
    private var captureSection: some View {
        Section("Recording") {
            Toggle("Pause capturing", isOn: Binding(store.$capturePaused))
            Text("While paused nothing new is recorded. You can also toggle this from the panel or the menu bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Enrichment") {
            Toggle("Recognize text in images", isOn: Binding(store.$recognizeImageText))
            Text("Runs on-device OCR on screenshots and copied images so you can search them and copy their text.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Fetch titles for links", isOn: Binding(store.$fetchLinkTitles))
            Text("Loads the page title for copied URLs so link cards read like bookmarks. Only the first 200 KB of the page is fetched.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("What gets captured") {
            LabeledContent("Text") { Text("Plain and rich text, code (with language detection), links, colors").foregroundStyle(.secondary) }
            LabeledContent("Images") { Text("Stored once as PNG with a small thumbnail").foregroundStyle(.secondary) }
            LabeledContent("Files") { Text("A reference to the original file; the file itself is never copied").foregroundStyle(.secondary) }
        }
    }

    // MARK: - Privacy

    @ViewBuilder
    private var privacySection: some View {
        Section("Sensitive content") {
            Toggle("Record card numbers, IBANs, keys and passwords", isOn: Binding(store.$recordSensitive))
            Text(store.recordSensitive
                 ? "They are stored masked (•••• 4242) and only revealed on request in Quick Look. Pasting always inserts the real value."
                 : "Anything that looks like a payment card, IBAN, API key, private key or password line is skipped entirely.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
            Picker("Forget sensitive items after", selection: Binding(store.$sensitiveMaxAgeMinutes)) {
                ForEach(SensitiveMaxAgeOption.allCases, id: \.rawValue) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            .disabled(!store.recordSensitive)
        }
        Section("Password managers") {
            Toggle("Ignore concealed and transient content", isOn: Binding(store.$ignoreConcealed))
            Text("Password managers and some apps mark clipboard contents as concealed or transient. When enabled, those copies are never recorded.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section {
            LabeledContent("Network") { Text("Only the App Store update check and optional link titles use the network. History never leaves this Mac.").foregroundStyle(.secondary) }
        }
    }

    // MARK: - Drag & Paste

    @ViewBuilder
    private var dragAndPasteSection: some View {
        Section("Dragging files out") {
            Picker("Drag behaviour", selection: Binding(store.$dragMode)) {
                ForEach(DragMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text(store.dragMode.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
            Text("Images and text are always copied. Drag any card straight into Finder, Mail, Slack or a document.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Pasting") {
            Toggle("Paste into the active app automatically", isOn: Binding(store.$autoPaste))
            Text("When off, choosing an item only copies it to the clipboard.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LabeledContent("Accessibility access") {
                HStack(spacing: 8) {
                    accessibilityBadge
                    if !store.isAccessibilityTrusted {
                        Button("Grant…") { store.send(.requestAccessibility) }
                            .buttonStyle(.glassProminent)
                            .controlSize(.small)
                        Button("System Settings") { store.send(.openAccessibilitySettings) }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                    }
                }
            }
            Text("Automatic paste sends ⌘V to the app you were using, which macOS only allows with Accessibility access. If it still doesn't paste after granting, remove Mahmut from the list and add it again.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Mahmut asks for nothing else with this access. It never reads other apps' windows, text or screen contents — it posts one key event, to the app you were already typing in, at the moment you choose an item. Turn the toggle off and the permission is never used.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Accessibility") {
            LabeledContent("VoiceOver") {
                Text("Every card reads as one sentence, with rotor actions for paste, copy, pin, folders and delete")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Reduce Transparency") {
                Text("Replaces Liquid Glass with a solid surface")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Reduce Motion") {
                Text("Cross-fades instead of sliding and springing")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Differentiate Without Color") {
                Text("Draws the selected card with a border, not just a tint")
                    .foregroundStyle(.secondary)
            }
            Text("All four follow the settings in System Settings › Accessibility. Mahmut has no switches of its own to get out of step with them.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var accessibilityBadge: some View {
        let trusted = store.isAccessibilityTrusted
        return HStack(spacing: 5) {
            Circle()
                .fill(trusted ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(trusted ? "Granted" : "Not granted")
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background((trusted ? Color.green : Color.orange).opacity(0.14), in: .capsule)
        .contentTransition(.interpolate)
        .animation(.smooth, value: trusted)
    }

    // MARK: - Shortcuts

    @ViewBuilder
    private var shortcutsSection: some View {
        Section("Global") {
            LabeledContent("Show or hide the clipboard") {
                ShortcutRecorderView(
                    shortcut: store.toggleShortcut,
                    isRecording: store.isRecordingShortcut,
                    onStart: { store.send(.shortcutRecordingChanged(true)) },
                    onCancel: { store.send(.shortcutRecordingChanged(false)) },
                    onRecord: { store.send(.shortcutRecorded($0)) },
                    onReset: { store.send(.resetShortcut) }
                )
            }
            Text("Use at least one of ⌘, ⌃ or ⌥. The default ⌘⇧V overlaps “Paste and Match Style” in some apps — pick something else if that bothers you.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Navigate") {
            shortcutRow("Move between items", "← →")
            shortcutRow("Jump to first / last", "⌘ ← / ⌘ →")
            shortcutRow("Search", "⌘ F  or just type")
            shortcutRow("Switch focus between search and list", "⇥")
            shortcutRow("Filter: all · text · links · images · files · colors", "⌥ 1 … ⌥ 6")
            shortcutRow("Previous / next folder", "⌘ [  /  ⌘ ]")
            shortcutRow("Close", "esc")
        }
        Section("Act on the selected item") {
            shortcutRow("Paste", "↩")
            shortcutRow("Paste as plain text", "⇧ ↩")
            shortcutRow("Paste as… (case, trim, JSON)", "⌘ T")
            shortcutRow("Paste item 1–9", "⌘ 1 … ⌘ 9")
            shortcutRow("Copy without pasting", "⌘ C")
            shortcutRow("Copy plain text · image text · color format · file path", "⌘ ⇧ C")
            shortcutRow("Quick Look", "space")
            shortcutRow("Reveal a masked value in Quick Look", "⌘ E")
            shortcutRow("Pin or unpin", "⌘ P")
            shortcutRow("Save to folder", "⌘ S")
            shortcutRow("Open file or link", "⌘ O")
            shortcutRow("Reveal in Finder", "⌘ ⇧ R")
            shortcutRow("Copy file path", "⌥ ⌘ C")
            shortcutRow("Delete", "⌫")
        }
        Section("Folders & capture") {
            shortcutRow("New folder", "⌘ N")
            shortcutRow("Rename current folder", "⌘ R")
            shortcutRow("Delete current folder", "⌘ ⌫")
            shortcutRow("Pause / resume capturing", "⌘ ⇧ P")
            shortcutRow("Open the App Store update", "⌘ U")
            shortcutRow("Settings", "⌘ \(String(KeyboardLayout.settingsKeyCharacter).uppercased())")
            shortcutRow("In choosers: pick option 1–9 / first option / secondary", "1 … 9  /  ↩  /  ⇧ ↩")
        }
    }

    private func shortcutRow(_ title: String, _ keys: String) -> some View {
        LabeledContent(title) {
            Text(keys)
                .font(.callout.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.primary.opacity(0.07), in: .rect(cornerRadius: 6))
        }
    }

    // MARK: - About

    @ViewBuilder
    private var aboutSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Mahmut Clipboard")
                        .font(.title3.weight(.semibold))
                    Text("Version \(AppVersion.current) (\(AppVersion.build))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Free, private, and fully on-device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        Section("Updates") {
            if let update = store.availableUpdate {
                LabeledContent("Version \(update.listing.version) is available") {
                    HStack(spacing: 8) {
                        Button("Skip This Version") { store.send(.skipUpdate) }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Open App Store", systemImage: "arrow.down.circle.fill") { store.send(.openUpdate) }
                            .buttonStyle(.glassProminent)
                            .controlSize(.small)
                    }
                }
                if let notes = update.listing.releaseNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                }
            } else {
                LabeledContent(updateStatusText) {
                    Button {
                        store.send(.checkForUpdates)
                    } label: {
                        if store.updateCheck == .checking {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Check for Updates")
                        }
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .disabled(store.updateCheck == .checking)
                }
            }
            Text("Updates are delivered through the Mac App Store. Automatic updates install them in the background; otherwise you'll see a badge here and in the panel.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Storage") {
            LabeledContent("History on disk") {
                Text(Formatting.bytes(store.storageFootprint))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Button(role: .destructive) {
                store.send(.clearHistoryTapped)
            } label: {
                Label("Clear History…", systemImage: "trash")
            }
        }
    }

    private var updateStatusText: String {
        switch store.updateCheck {
        case .idle: "Mac App Store"
        case .checking: "Checking…"
        case .upToDate: "You're on the latest version"
        case let .available(version): "Version \(version) is available"
        case .notListed: "This build isn't on the App Store yet"
        case let .failed(message): "Couldn't check: \(message)"
        }
    }
}
