//
//  PanelTextField.swift
//  clipboardManager
//
//  The panel's text field. SwiftUI's TextField selects its whole text when it
//  takes focus, and focus arrives a beat after the field appears. Both lose
//  letters when someone types fast: keys pressed before focus land in the
//  reducer, and the next key then replaces them. This field takes focus the
//  moment it is in a window and places the caret inside becomeFirstResponder,
//  so no key can arrive between the two.
//

import AppKit
import SwiftUI

struct PanelTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Binding var isFocused: Bool
    /// Select the existing text on focus (rename) instead of putting the caret at the end.
    var selectsAllOnFocus = false
    var fontSize = NSFont.systemFontSize

    func makeNSView(context: Context) -> CaretTextField {
        let field = CaretTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.textColor = .labelColor
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.onFocus = { [coordinator = context.coordinator] in coordinator.focusChanged(true) }
        return field
    }

    func updateNSView(_ field: CaretTextField, context: Context) {
        context.coordinator.parent = self
        field.placeholderString = placeholder
        field.font = .systemFont(ofSize: fontSize)
        field.selectsAllOnFocus = selectsAllOnFocus
        field.appearance = NSAppearance(named: context.environment.colorScheme == .dark ? .darkAqua : .aqua)

        if field.stringValue != text {
            if let editor = field.currentEditor() as? NSTextView {
                // Text changed from outside while editing (keys typed before focus, a clear):
                // keep the caret at the end rather than selecting everything.
                editor.string = text
                editor.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
            } else {
                field.stringValue = text
            }
        }

        field.wantsFocus = isFocused
        if isFocused {
            field.requestFocus()
        } else if field.isEditing, let window = field.window {
            window.makeFirstResponder(window.contentView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PanelTextField

        init(_ parent: PanelTextField) { self.parent = parent }

        func focusChanged(_ focused: Bool) {
            if parent.isFocused != focused { parent.isFocused = focused }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            if parent.text != field.stringValue { parent.text = field.stringValue }
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            focusChanged(false)
        }
    }
}

final class CaretTextField: NSTextField {
    var onFocus: (() -> Void)?
    var selectsAllOnFocus = false
    /// Set while SwiftUI wants this field focused; honoured as soon as it has a window.
    var wantsFocus = false

    var isEditing: Bool {
        guard let editor = currentEditor() else { return false }
        return window?.firstResponder === editor
    }

    /// Focus on the next main-queue turn, outside SwiftUI's update. Keys pressed
    /// before then still reach the text through the reducer, and the caret lands
    /// after them.
    func requestFocus() {
        DispatchQueue.main.async { [weak self] in
            guard let self, wantsFocus, !isEditing, let window else { return }
            window.makeFirstResponder(self)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        requestFocus()
    }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        // NSTextField selects everything on focus. Undo that before any key event
        // can be delivered, so a fast typist's next letter appends instead of replacing.
        if !selectsAllOnFocus, let editor = currentEditor() {
            editor.selectedRange = NSRange(location: (stringValue as NSString).length, length: 0)
        }
        onFocus?()
        return true
    }
}
