//
//  KeyCap.swift
//  clipboardManager
//
//  The one keycap style: buttons, color rows and the palette all show the key
//  that triggers them the same way.
//

import SwiftUI

struct KeyCap: View {
    let key: String
    /// On an accent-filled button the neutral fill disappears; use a light one.
    var onProminent = false
    /// Lit: the key was just pressed (hint bar flash) or it acts on the selection.
    var highlighted = false

    var body: some View {
        Text(key)
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(highlighted || onProminent ? Color.white : Color.primary)
            .padding(.horizontal, 4)
            .frame(minWidth: 18, minHeight: 16)
            .background(fill, in: .rect(cornerRadius: 4.5))
            .overlay {
                if !highlighted, !onProminent {
                    RoundedRectangle(cornerRadius: 4.5).strokeBorder(.primary.opacity(0.18), lineWidth: 0.5)
                }
            }
            .accessibilityHidden(true)
    }

    private var fill: AnyShapeStyle {
        if highlighted { return AnyShapeStyle(Color.accentColor) }
        if onProminent { return AnyShapeStyle(Color.white.opacity(0.25)) }
        return AnyShapeStyle(Color.primary.opacity(0.1))
    }
}
