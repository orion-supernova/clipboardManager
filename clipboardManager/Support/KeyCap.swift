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

    var body: some View {
        Text(key)
            .font(.caption2.weight(.semibold).monospaced())
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(onProminent ? Color.white.opacity(0.25) : Color.primary.opacity(0.08), in: .rect(cornerRadius: 4))
            .accessibilityHidden(true)
    }
}
