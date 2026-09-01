//
//  DialogView.swift
//  clipboardManager
//
//  An inline glass dialog for the panel: text prompts, destructive choices and
//  option choosers. Inline rather than NSAlert so the app never has to activate
//  itself. Every button shows the key that triggers it.
//

import SwiftUI

struct DialogView: View {
    struct Action {
        var title: String
        var isDestructive = false
        var perform: @MainActor () -> Void
    }

    let title: String
    let message: String?
    let symbol: String
    var text: Binding<String>?
    var placeholder = ""
    var options: [HistoryFeature.DialogOption] = []
    var onOption: @MainActor (Int) -> Void = { _ in }
    var primary: Action?
    var secondary: Action?
    let onCancel: @MainActor () -> Void

    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .background(.tint.opacity(0.12), in: .rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    if let message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let text {
                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.primary.opacity(0.07), in: .rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.tint.opacity(fieldFocused ? 0.6 : 0), lineWidth: 1.5))
                    .focused($fieldFocused)
                    .animation(.easeOut(duration: 0.15), value: fieldFocused)
            }
            if !options.isEmpty {
                optionGrid
            }
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                keyedButton("Cancel", key: "esc", action: onCancel)
                    .panelButtonStyle()
                if let secondary {
                    keyedButton(secondary.title, key: "⇧↩", action: secondary.perform)
                        .panelButtonStyle()
                        .foregroundStyle(secondary.isDestructive ? .red : .primary)
                }
                if let primary {
                    keyedButton(primary.title, key: "↩", action: primary.perform)
                        .panelButtonStyle(prominent: true)
                        .tint(primary.isDestructive ? .red : .accentColor)
                        .disabled(text.map { $0.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty } ?? false)
                }
            }
        }
        .padding(20)
        .frame(width: options.isEmpty ? 420 : 520)
        .panelGlass(prominent: true, in: .rect(cornerRadius: PanelMetrics.cardCornerRadius))
        .shadow(color: .black.opacity(0.22), radius: 24, y: 12)
        .task {
            guard text != nil else { return }
            try? await Task.sleep(for: .milliseconds(60))
            fieldFocused = true
        }
    }

    private var optionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(options) { option in
                Button {
                    onOption(option.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: option.symbol)
                            .frame(width: 18)
                            .foregroundStyle(.tint)
                        Text(option.title)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if option.id < 9 {
                            Text("\(option.id + 1)")
                                .font(.caption2.weight(.semibold).monospaced())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.primary.opacity(0.08), in: .rect(cornerRadius: 4))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.primary.opacity(0.06), in: .rect(cornerRadius: 10))
                    .contentShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(option.isDisabled)
                .opacity(option.isDisabled ? 0.45 : 1)
            }
        }
    }

    private func keyedButton(_ title: String, key: String, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Text(key)
                    .font(.caption2.weight(.semibold).monospaced())
                    .opacity(0.6)
            }
        }
    }
}
