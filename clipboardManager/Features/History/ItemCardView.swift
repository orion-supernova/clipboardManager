//
//  ItemCardView.swift
//  clipboardManager
//
//  A card is glass plus content plus an AppKit interaction overlay. Hover and
//  press feedback are purely visual (tint/dim) — nothing changes geometry, so the
//  overlay's tracking area never churns and hover can't flicker.
//

import ComposableArchitecture
import SwiftUI

struct ItemCardView: View {
    struct Actions {
        var tap: @MainActor () -> Void
        var pastePlain: @MainActor () -> Void
        var pasteTransformed: @MainActor (TextTransform) -> Void
        var copyOnly: @MainActor () -> Void
        var copyColor: @MainActor (ColorFormat) -> Void
        var delete: @MainActor () -> Void
        var togglePin: @MainActor () -> Void
        var reveal: @MainActor () -> Void
        var copyPath: @MainActor () -> Void
        var open: @MainActor () -> Void
        var preview: @MainActor () -> Void
        var moveToFolder: @MainActor (UUID?) -> Void
        var newFolder: @MainActor () -> Void
        var openPrivacySettings: @MainActor () -> Void
        var payload: @Sendable () async -> ClipboardPayload?
        var thumbnailURL: URL?
        var iconURL: URL?
    }

    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let isFlashing: Bool
    let isRecent: Bool
    let showShortcutHint: Bool
    let highlight: String
    let dragMode: DragMode
    let reduceMotion: Bool
    let staggered: Bool
    let interactionEnabled: Bool
    let sensitiveLifetime: TimeInterval?
    let folders: [ClipboardFolder]
    let actions: Actions

    @Environment(\.marketingRender) private var marketingRender
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var hasAppeared = false

    private var cornerRadius: CGFloat { PanelMetrics.cardCornerRadius }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius) }

    private var glassTint: Color? {
        if isSelected { return .accentColor.opacity(0.45) }
        if item.isSensitive { return .red.opacity(isHovered ? 0.22 : 0.16) }
        return isHovered ? .white.opacity(0.12) : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            ItemPreviewView(item: item, thumbnailURL: actions.thumbnailURL, iconURL: actions.iconURL, highlight: highlight, sensitiveLifetime: sensitiveLifetime)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .padding(14)
        .frame(width: PanelMetrics.cardWidth, height: PanelMetrics.cardHeight)
        .panelGlass(tint: glassTint, interactive: true, in: shape)
        .overlay { shape.fill(.black.opacity(isPressed ? 0.08 : 0)).allowsHitTesting(false) }
        .overlay { recentGlow }
        .overlay { flashOverlay }
        .overlay {
            // ImageRenderer draws NSViewRepresentables as placeholders; skip it offline.
            if !marketingRender {
            CardInteractionOverlay(
                item: item,
                dragMode: dragMode,
                controlsVisible: isHovered,
                isEnabled: interactionEnabled,
                payloadProvider: actions.payload,
                dragPreview: { [item, thumbnailURL = actions.thumbnailURL] in
                    DragPreviewRenderer.image(for: item, thumbnailURL: thumbnailURL)
                },
                onTap: actions.tap,
                onControl: handleControl,
                onHover: { isHovered = $0 },
                onPress: { isPressed = $0 },
                contextMenu: contextMenuEntries,
                folderMenu: folderMenuEntries
            )
            }
        }
        .overlay(alignment: .topTrailing) { hoverControls }
        .opacity(hasAppeared || marketingRender ? 1 : 0)
        .offset(y: hasAppeared || marketingRender || reduceMotion ? 0 : 18)
        .animation(.easeOut(duration: 0.12), value: isPressed)
        .animation(.easeOut(duration: 0.18), value: isHovered)
        .animation(.easeOut(duration: 0.35), value: isRecent)
        .anchorPreference(key: CardAnchorKey.self, value: .bounds) { [item.id: $0] }
        .onAppear {
            if reduceMotion || !staggered {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { hasAppeared = true }
            } else {
                let delay = index < 8 ? Double(index) * 0.035 : 0
                withAnimation(.spring(duration: 0.4, bounce: 0.12).delay(delay)) { hasAppeared = true }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.headerTitle): \(item.preview)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func handleControl(_ control: CardControl) {
        switch control {
        case .preview: actions.preview()
        case .pin: actions.togglePin()
        case .delete: actions.delete()
        case .folder: break // handled by the overlay's popup menu
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: item.headerSymbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.isSensitive ? Color.red : Color.accentColor)
            Text(item.headerTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }
            Spacer(minLength: 4)
            Text(item.timestamp, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if showShortcutHint {
                Text("⌘\(index + 1)")
                    .font(.caption2.weight(.semibold).monospaced())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.primary.opacity(0.08), in: .rect(cornerRadius: 4))
                    .opacity(isHovered ? 0 : 1)
            }
        }
        .animation(.easeOut(duration: 0.18), value: item.isPinned)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            AppIconView(source: item.source)
                .frame(width: 16, height: 16)
            Text(item.source.name)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(metaLabel)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    private var metaLabel: String {
        switch item.kind {
        case .text: item.isSensitive ? "Masked" : Formatting.characterCount(Int(item.byteCount))
        case .url: URL(string: item.preview)?.host() ?? ""
        case .color: item.preview
        case .image: item.pixelSize?.label ?? Formatting.bytes(item.byteCount)
        case .file, .video: item.isFileAvailable ? Formatting.bytes(item.byteCount) : "Missing"
        }
    }

    @ViewBuilder
    private var recentGlow: some View {
        if isRecent {
            shape
                .strokeBorder(Color.accentColor.opacity(0.9), lineWidth: 3)
                .blur(radius: 6)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var flashOverlay: some View {
        if isFlashing {
            ZStack {
                shape.fill(Color.accentColor.opacity(0.28))
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white, Color.accentColor)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    /// Drawn by SwiftUI, hit-tested by the AppKit overlay (see `CardControl`).
    @ViewBuilder
    private var hoverControls: some View {
        if isHovered && interactionEnabled {
            HStack(spacing: CardControl.spacing) {
                controlLabel("eye", tint: .primary)
                controlLabel("folder.badge.plus", tint: .primary)
                controlLabel(item.isPinned ? "pin.slash.fill" : "pin.fill", tint: .primary)
                controlLabel("trash.fill", tint: .red)
            }
            .padding(CardControl.padding)
            .transition(.opacity)
            .allowsHitTesting(false)
        }
    }

    /// Solid (not glass) so it stays legible on top of the glass card.
    private func controlLabel(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: CardControl.size, height: CardControl.size)
            .background(Circle().fill(.background).shadow(color: .black.opacity(0.28), radius: 3, y: 1))
            .overlay(Circle().strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Menus

    private func folderMenuEntries() -> [ContextMenuEntry] {
        var entries: [ContextMenuEntry] = folders.map { folder in
            .item(title: folder.name + (folder.id == item.folderID ? "  ✓" : ""), symbol: folder.symbol) { actions.moveToFolder(folder.id) }
        }
        if !entries.isEmpty { entries.append(.separator) }
        if item.folderID != nil {
            entries.append(.item(title: "Move to History", symbol: "clock.arrow.circlepath") { actions.moveToFolder(nil) })
        }
        entries.append(.item(title: "New Folder…", symbol: "folder.badge.plus", action: actions.newFolder))
        return entries
    }

    private func contextMenuEntries() -> [ContextMenuEntry] {
        var entries: [ContextMenuEntry] = [
            .item(title: "Paste\t↩", symbol: "arrow.down.doc", action: actions.tap),
        ]
        if item.kind == .text || item.kind == .url {
            entries.append(.submenu(
                title: "Paste As\t⌘T",
                symbol: "text.badge.checkmark",
                entries: [.item(title: "Plain Text\t⇧↩", symbol: "textformat", action: actions.pastePlain), .separator]
                    + TextTransform.allCases.map { transform in
                        .item(title: transform.title, symbol: transform.symbol) { actions.pasteTransformed(transform) }
                    }
            ))
        }
        entries.append(.item(title: "Copy Without Pasting\t⌘C", symbol: "doc.on.doc", action: actions.copyOnly))
        if item.kind == .color {
            entries.append(.submenu(
                title: "Copy As\t⌘⇧C",
                symbol: "paintpalette",
                entries: ColorFormat.allCases.map { format in
                    .item(title: format.title, symbol: "swatchpalette") { actions.copyColor(format) }
                }
            ))
        }
        entries.append(.item(title: item.isSensitive ? "Quick Look (masked)\tspace" : "Quick Look\tspace", symbol: "eye", action: actions.preview))
        entries.append(.item(title: item.isPinned ? "Unpin\t⌘P" : "Pin\t⌘P", symbol: item.isPinned ? "pin.slash" : "pin", action: actions.togglePin))
        entries.append(.submenu(title: item.folderID == nil ? "Add to Folder\t⌘S" : "Move to Folder\t⌘S", symbol: "folder", entries: folderMenuEntries()))
        entries.append(.separator)
        switch item.kind {
        case .file, .video, .image:
            entries.append(.item(title: "Reveal in Finder\t⌘⇧R", symbol: "folder", action: actions.reveal))
            entries.append(.item(title: "Open\t⌘O", symbol: "arrow.up.forward.app", action: actions.open))
            entries.append(.item(title: "Copy Path\t⌥⌘C", symbol: "link", action: actions.copyPath))
            entries.append(.separator)
        case .url:
            entries.append(.item(title: "Open Link\t⌘O", symbol: "safari", action: actions.open))
            entries.append(.separator)
        default:
            break
        }
        if item.isSensitive {
            entries.append(.item(title: "Sensitive Content Settings…", symbol: "lock.shield", action: actions.openPrivacySettings))
            entries.append(.separator)
        }
        entries.append(.item(title: "Delete\t⌫", symbol: "trash", isDestructive: true, action: actions.delete))
        return entries
    }
}
