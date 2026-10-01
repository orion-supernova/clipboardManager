//
//  OnboardingView.swift
//  clipboardManager
//
//  Five short steps. Each permission says what it is for, what happens without
//  it, and whether it matters — so nothing reads like a wall of system prompts.
//

import AppKit
import ComposableArchitecture
import SwiftUI

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                stepContent
                    .id(store.step)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(x: 24)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 44)
            .padding(.top, 36)
            footer
        }
        .frame(width: 600, height: 520)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .smooth(duration: 0.3), value: store.step)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch store.step {
        case .welcome: welcome
        case .autoPaste: autoPaste
        case .files: files
        case .startup: startup
        case .done: done
        }
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text("Welcome to Mahmut")
                .font(.largeTitle.weight(.bold))
            Text("Everything you copy, one keystroke away.")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 14) {
                feature("keyboard", "Press \(store.toggleShortcut.display) anywhere", "The panel slides up over whatever you're doing. Arrow to an item, press ↩, and it's pasted.")
                feature("lock.shield", "Private by design", "Your history never leaves this Mac. Card numbers, keys and passwords are masked.")
                feature("checklist", "Two quick choices", "One permission makes pasting instant; one is optional. About 30 seconds.")
            }
            .padding(.top, 8)
        }
    }

    private var autoPaste: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader(symbol: "arrow.down.doc.fill", badge: .recommended, title: "Paste in one step")
            Text("When you pick an item, Mahmut presses ⌘V for you in the app you were using. macOS calls that **Accessibility** access. Mahmut uses it for that single keystroke. It never reads your screen or what you type.")
                .fixedSize(horizontal: false, vertical: true)
            statusCard(
                granted: store.isAccessibilityTrusted,
                grantedText: "Allowed. Pasting is one step.",
                missingText: "Not allowed yet"
            ) {
                Button("Allow…") { store.send(.requestAccessibility) }
                    .buttonStyle(.borderedProminent)
                Button("Open System Settings") { store.send(.openAccessibilitySettings) }
            }
            note("Skip it and Mahmut still works: it copies the item, then you press ⌘V yourself.")
        }
    }

    private var files: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader(symbol: "folder.fill", badge: .optional, title: "Copy files without prompts")
            Text("The first time you copy a file from Desktop, Documents or Downloads, macOS asks whether Mahmut may read that folder, so it can show a thumbnail and paste or drag the file later. It asks once per folder.")
                .fixedSize(horizontal: false, vertical: true)
            Text("To skip those prompts entirely, give Mahmut **Full Disk Access**:")
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    numbered(1, "Open Full Disk Access in System Settings")
                    numbered(2, "Drag this icon into the list")
                    numbered(3, "Make sure its switch is on")
                    Button("Open Full Disk Access") { store.send(.openFullDiskAccessSettings) }
                        .padding(.top, 4)
                }
                Spacer(minLength: 0)
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .draggable(Bundle.main.bundleURL)
                    .help("Drag into the Full Disk Access list")
                    .accessibilityLabel("Mahmut app icon. Drag into the Full Disk Access list.")
            }
            .padding(16)
            .background(.primary.opacity(0.05), in: .rect(cornerRadius: 14))
            note("macOS doesn't tell apps whether Full Disk Access is on, so there's no checkmark here. The prompts simply stop appearing.")
        }
    }

    private var startup: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader(symbol: "power", badge: .recommended, title: "Always ready")
            Text("Mahmut can only remember what you copy while it's running. Start it at login and it's there from the first copy of the day.")
                .fixedSize(horizontal: false, vertical: true)
            Toggle(isOn: Binding(get: { store.launchAtLogin }, set: { store.send(.launchAtLoginToggled($0)) })) {
                Text("Launch Mahmut at login").font(.headline)
            }
            .toggleStyle(.switch)
            .padding(16)
            .background(.primary.opacity(0.05), in: .rect(cornerRadius: 14))
            HStack(spacing: 8) {
                Text("Open the panel with")
                keycap(store.toggleShortcut.display)
                Text("· you can change it in Settings → Shortcuts.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var done: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: store.step)
                .accessibilityHidden(true)
            Text("You're set")
                .font(.largeTitle.weight(.bold))
            HStack(spacing: 8) {
                Text("Copy something, then press")
                keycap(store.toggleShortcut.display)
            }
            .font(.title3)
            VStack(alignment: .leading, spacing: 10) {
                tip("Hold ⌘ in the panel to see every shortcut, or press ⌘K for all commands.")
                tip("Press ⌘L to mask anything you copied that is secret.")
                tip("Replay this guide any time from Settings → General.")
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(OnboardingFeature.State.Step.allCases, id: \.self) { step in
                    Capsule()
                        .fill(step == store.step ? Color.accentColor : Color.primary.opacity(0.18))
                        .frame(width: step == store.step ? 18 : 6, height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Step \(store.step.rawValue + 1) of \(OnboardingFeature.State.Step.allCases.count)")
            Spacer()
            if !store.isFirstStep && !store.isLastStep {
                Button("Back") { store.send(.back) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
            }
            if store.isLastStep {
                Button("Done") { store.send(.finish(openPanel: false)) }
                Button("Open Mahmut") { store.send(.finish(openPanel: true)) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            } else {
                if store.step == .welcome {
                    Button("Skip Setup") { store.send(.finish(openPanel: false)) }
                }
                Button(continueTitle) { store.send(.next) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var continueTitle: String {
        switch store.step {
        case .welcome: "Get Started"
        case .autoPaste: store.isAccessibilityTrusted ? "Continue" : "Not Now"
        case .files: "Continue"
        default: "Continue"
        }
    }

    // MARK: - Pieces

    private enum Badge {
        case recommended, optional
        var title: String { self == .recommended ? "Recommended" : "Optional" }
        var tint: Color { self == .recommended ? .accentColor : .secondary }
    }

    private func stepHeader(symbol: String, badge: Badge, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 48, height: 48)
                .background(.tint.opacity(0.14), in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(badge.title.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(badge.tint)
                Text(title)
                    .font(.title.weight(.bold))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func statusCard(granted: Bool, grantedText: String, missingText: String, @ViewBuilder actions: () -> some View) -> some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
                .font(.title2)
                .foregroundStyle(granted ? Color.green : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
            Text(granted ? grantedText : missingText)
                .font(.headline)
            Spacer(minLength: 8)
            if !granted { actions() }
        }
        .padding(16)
        .background((granted ? Color.green : Color.primary).opacity(granted ? 0.1 : 0.05), in: .rect(cornerRadius: 14))
        .animation(.smooth(duration: 0.25), value: granted)
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func numbered(_ number: Int, _ text: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold).monospacedDigit())
                .frame(width: 20, height: 20)
                .background(.tint.opacity(0.16), in: .circle)
            Text(text)
        }
    }

    private func note(_ text: String) -> some View {
        Label(text, systemImage: "info.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func tip(_ text: String) -> some View {
        Label(text, systemImage: "sparkles")
            .foregroundStyle(.secondary)
    }

    private func keycap(_ key: String) -> some View {
        Text(key)
            .font(.body.weight(.semibold).monospaced())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.primary.opacity(0.08), in: .rect(cornerRadius: 6))
    }
}
