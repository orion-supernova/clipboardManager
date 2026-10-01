//
//  HistoryView.swift
//  clipboardManager
//
//  The panel's SwiftUI root. Everything floats as Liquid Glass over the desktop:
//  an optional quick-preview sheet on top, the hint tray, the toolbar and the
//  card strip. The card strip never moves when the preview opens.
//

import ComposableArchitecture
import SwiftUI

struct HistoryView: View {
    @Bindable var store: StoreOf<HistoryFeature>
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var systemDifferentiateWithoutColor
    @Environment(\.marketingRender) private var marketingRender
    @Environment(\.marketingSheetProgress) private var marketingSheetProgress
    @Namespace private var filterNamespace
    @FocusState private var searchFocused: Bool
    @State private var scrollID: UUID?
    @Dependency(\.clipboardStore) private var clipboardStore

    /// Precomputed so the lazy card list never indexes back into `store.items`
    /// (stale indices during a filter switch crashed an earlier build).
    private struct CardRow: Identifiable, Equatable {
        let item: ClipboardItem
        let index: Int
        let showsPinnedDivider: Bool
        var id: UUID { item.id }
    }

    private var rows: [CardRow] {
        var previousPinned = false
        return store.items.enumerated().map { index, item in
            let row = CardRow(item: item, index: index, showsPinnedDivider: index > 0 && previousPinned && !item.isPinned)
            previousPinned = item.isPinned
            return row
        }
    }

    /// System settings with the user's per-panel overrides applied.
    private var appearance: ResolvedAppearance {
        ResolvedAppearance(
            solidSurface: store.panelSurface.resolved(system: systemReduceTransparency),
            reduceMotion: store.panelMotion.resolved(system: systemReduceMotion),
            borderSelection: store.selectionStyle.resolved(system: systemDifferentiateWithoutColor)
        )
    }

    private var reduceMotion: Bool { store.panelMotion.resolved(system: systemReduceMotion) }

    private var presentAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.18) : .spring(duration: 0.36, bounce: 0.14)
    }

    private var quickAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.28, bounce: 0.12)
    }

    private var ringAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.3, bounce: 0.18)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
            if store.isPresented {
                content
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity.combined(with: .offset(y: 24))
                            )
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.resolvedAppearance, appearance)
        .animation(presentAnimation, value: store.isPresented)
        .onChange(of: store.isSearchFocused) { _, focused in
            if focused {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(40))
                    searchFocused = true
                }
            } else {
                searchFocused = false
            }
        }
        .onChange(of: searchFocused) { _, focused in
            if store.isSearchFocused != focused {
                store.send(.binding(.set(\.isSearchFocused, focused)))
            }
        }
        .onChange(of: store.scrollTarget) { _, target in
            guard let target else { return }
            withAnimation(quickAnimation) { scrollID = target }
        }
        .onChange(of: store.isPresented) { _, presented in
            if presented { scrollID = store.selectedID }
        }
    }

    // MARK: - Layout

    private var content: some View {
        VStack(spacing: PanelMetrics.rowSpacing) {
            if let previewID = store.previewID, let item = store.items[id: previewID] {
                // Marketing scenes set a payload without an id; treat that as current.
                let payloadIsCurrent = store.previewPayloadID == nil || store.previewPayloadID == previewID
                PreviewSheetView(
                    item: item,
                    payload: payloadIsCurrent ? store.previewPayload : nil,
                    stalePayload: store.previewPayload,
                    failed: store.previewFailed,
                    scrollRequest: store.previewScroll,
                    zoomed: store.previewZoomed,
                    onToggleZoom: { store.send(.toggleImageZoom, animation: .smooth(duration: 0.25)) },
                    revealed: store.previewRevealed,
                    sensitiveLifetime: store.sensitiveLifetime,
                    thumbnailURL: item.thumbnailPath.map(clipboardStore.thumbnailURL),
                    iconURL: item.linkIconPath.map(clipboardStore.thumbnailURL),
                    imageURL: item.imagePath.map(clipboardStore.imageURL),
                    onPaste: { store.send(.paste(item.id, .standard)) },
                    onOpen: { store.send(.openItem(item.id)) },
                    onRevealInFinder: { store.send(.revealInFinder(item.id)) },
                    onSmartAction: { store.send(.performSmartAction(item.id, $0)) },
                    onToggleReveal: { store.send(.toggleReveal) },
                    onCopyColor: { store.send(.copyColor(item.id, $0)) },
                    onCopyText: { store.send(.copyText($0, toast: "Text copied")) },
                    onClose: { store.send(.closePreview) }
                )
                .frame(height: PanelMetrics.previewHeight)
                .opacity(marketingRender ? marketingSheetProgress : 1)
                .offset(y: marketingRender ? (1 - marketingSheetProgress) * 16 : 0)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 16)))
                // No `.id(previewID)`: arrowing through items with the sheet open
                // must swap its content, not tear down and rebuild a glass sheet
                // per keypress while the previous ones are still transitioning out.
            }
            hintBar
                .frame(height: PanelMetrics.hintBarHeight)
            toolbar
                .frame(height: PanelMetrics.toolbarHeight)
            cardStrip
                .frame(height: PanelMetrics.stripHeight)
                .opacity(store.dialog == nil && !store.isPaletteOpen ? 1 : 0.3)
                .allowsHitTesting(store.dialog == nil && !store.isPaletteOpen)
                .overlay { dialogOverlay }
                .overlay { paletteOverlay }
        }
        .padding(.top, PanelMetrics.topInset)
        .padding(.bottom, PanelMetrics.bottomInset)
        // One gutter for every row: toolbar, sheet and cards share a left edge.
        .padding(.horizontal, 16)
        .animation(.easeOut(duration: 0.22), value: store.previewID != nil)
        .animation(quickAnimation, value: store.dialog)
        .animation(quickAnimation, value: store.isPaletteOpen)
        // The panel is a transient window with no title bar, so nothing tells a
        // screen reader it opened or what changed inside it. These do.
        .onChange(of: store.isPresented) { _, presented in
            guard presented else { return }
            announce("Clipboard history, \(store.items.count) \(store.items.count == 1 ? "item" : "items")")
        }
        .onChange(of: store.toast?.id) { _, _ in
            if let toast = store.toast { announce(toast.text) }
        }
        .onChange(of: store.searchText) { _, query in
            guard !query.isEmpty else { return }
            let count = store.items.count
            announce("\(count) \(count == 1 ? "result" : "results") for \(query)")
        }
    }

    /// VoiceOver only, and only when the user leaves announcements on.
    private func announce(_ message: String) {
        guard store.spokenAnnouncements else { return }
        var announcement = AttributedString(message)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }

    // MARK: - Hint tray

    private var hintBar: some View {
        Group {
            switch store.modifierHint {
            case .none: defaultHints
            case .command: commandHints
            case .commandOption: folderHints
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: PanelMetrics.hintBarHeight)
        .panelGlass(in: .capsule)
        .animation(.easeOut(duration: 0.16), value: store.flashHintKey)
        .animation(.easeOut(duration: 0.1), value: store.modifierHint)
        .accessibilityHidden(true)
    }

    /// Holding ⌘ lists everything it unlocks; the longest row that fits wins.
    private var commandHints: some View {
        ViewThatFits(in: .horizontal) {
            commandHintRow(Self.commandHints)
            commandHintRow(Array(Self.commandHints.prefix(10)))
            commandHintRow(Array(Self.commandHints.prefix(6)))
        }
        .transition(.opacity)
    }

    private static var commandHints: [(key: String, label: String)] { [
        ("⌘K", "Commands"), ("⌘1–9", "Paste #"), ("⌘C", "Copy"), ("⌘T", "Paste As"), ("⌘P", "Pin"), ("⌘L", "Sensitive"),
        ("⌘S", "Save to Folder"), ("⌘F", "Search"), (KeyboardLayout.scopeKeysLabel, "Folders"), ("⌘O", "Open"),
        ("⌘E", "Reveal"), ("⌘N", "New Folder"), ("⌥⌘C", "Copy Path"), ("⇧⌘R", "Show in Finder"),
        ("⇧⌘P", "Pause"), ("⌘\(KeyboardLayout.settingsKeyCharacter)", "Settings"),
    ] }

    private func commandHintRow(_ hints: [(key: String, label: String)]) -> some View {
        HStack(spacing: 12) {
            ForEach(hints, id: \.key) { hint($0.key, $0.label) }
            hint("+⌥", "Folders")
        }
        .fixedSize()
    }

    /// Holding ⌥⌘ lists the folders by number, the current one highlighted.
    private var folderHints: some View {
        let scopes = [(HistoryScope.history, "History")]
            + store.folders.prefix(8).map { (HistoryScope.folder($0.id), $0.name) }
        return HStack(spacing: 12) {
            ForEach(Array(scopes.enumerated()), id: \.offset) { index, scope in
                hint("⌥⌘\(index + 1)", scope.1, active: scope.0 == store.activeScope)
            }
            if store.folders.isEmpty { hint("⌘N", "New Folder") }
        }
        .lineLimit(1)
        .transition(.opacity)
    }

    /// While the sheet is open the useful keys change: show those instead.
    private var previewHints: some View {
        HStack(spacing: 12) {
            hint("← →", "Item")
            if store.previewScrollsText { hint("↑ ↓", "Scroll") }
            hint("↩", "Paste")
            if let item = store.selectedItem {
                if item.isSensitive { hint("⌘E", "Reveal") }
                if item.kind == .color { hint("1–\(ColorFormat.allCases.count)", "Copy format") }
                if item.kind == .image { hint("Z", store.previewZoomed ? "Fit" : "Zoom") }
                if let action = item.primarySmartAction { hint("⌘O", action.title) }
                else if item.kind.isFileBacked || item.kind == .url || item.kind == .image { hint("⌘O", "Open") }
                if item.kind == .text { hint("⌘L", item.isSensitive ? "Not Sensitive" : "Sensitive") }
            }
            hint("⌘K", "Commands")
            hint("space", "Close")
        }
        .transition(.opacity)
    }

    private var defaultHints: some View {
        if store.isPreviewOpen && store.keyboardNavigation {
            return AnyView(previewHints)
        }
        return AnyView(regularHints)
    }

    private var regularHints: some View {
        HStack(spacing: 12) {
            // The essentials only; every other key is one ⌘ hold or ⌘K away.
            if store.keyboardNavigation {
                hint("↩", "Paste")
                hint("space", "Preview")
                hint("⌘C", "Copy")
                hint("⌘F", "Search")
                hint("⌘K", "Commands")
                hint("hold ⌘", "All Keys")
            }
            hint("esc", "Close")
        }
        .transition(.opacity)
    }

    private func hint(_ key: String, _ label: String, active: Bool = false) -> some View {
        let isFlashing = store.flashHintKey == key || active
        return HStack(spacing: 5) {
            KeyCap(key: key, highlighted: isFlashing)
            Text(label)
                .foregroundStyle(isFlashing ? Color.primary : Color.secondary)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                scopeMenu
                filterControl

                if let toast = store.toast {
                    toastCapsule(toast)
                }

                Spacer(minLength: 0)

                if let update = store.availableUpdate {
                    updatePill(update)
                }
                pauseButton
                searchControl
                settingsButton
            }
        }
        .animation(quickAnimation, value: store.toast)
        .animation(quickAnimation, value: store.isSearchExpanded)
        .animation(quickAnimation, value: store.capturePaused)
        .animation(quickAnimation, value: store.availableUpdate)
    }

    private var scopeMenu: some View {
        Menu {
            Button {
                store.send(.setScope(.history), animation: quickAnimation)
            } label: {
                Label("History  ⌥⌘1", systemImage: "clock")
            }
            if !store.folders.isEmpty {
                Divider()
                ForEach(Array(store.folders.enumerated()), id: \.element.id) { index, folder in
                    Button {
                        store.send(.setScope(.folder(folder.id)), animation: quickAnimation)
                    } label: {
                        // ⌥⌘1 is History, so folders start at 2 and stop at 9.
                        let shortcut = index < 8 ? "  ⌥⌘\(index + 2)" : ""
                        Label("\(folder.name)  (\(folder.itemCount))\(shortcut)", systemImage: folder.symbol)
                    }
                }
            }
            Divider()
            Button {
                store.send(.newFolderTapped(thenAdd: nil))
            } label: {
                Label("New Folder…  ⌘N", systemImage: "folder.badge.plus")
            }
            if store.activeScope != .history {
                Button {
                    store.send(.renameFolderTapped)
                } label: {
                    Label("Rename Folder…  ⌘R", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    store.send(.deleteFolderTapped)
                } label: {
                    Label("Delete Folder…  ⌘⌫", systemImage: "trash")
                }
            }
        } label: {
            HStack(spacing: 8) {
                // Accent is reserved for selection, the primary action and the
                // active filter; everything else stays neutral so those read.
                Image(systemName: store.activeScope == .history ? "clipboard.fill" : (store.currentFolder?.symbol ?? "folder.fill"))
                    .foregroundStyle(.secondary)
                    .contentTransition(.symbolEffect(.replace))
                Text(store.scopeTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .contentTransition(.interpolate)
                Text("\(store.items.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.primary.opacity(0.1), in: .capsule)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.25), value: store.items.count)
                if store.capturePaused {
                    Text("Paused")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.18), in: .capsule)
                        .transition(.scale.combined(with: .opacity))
                }
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(height: PanelMetrics.toolbarHeight)
            .contentShape(.capsule)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .panelGlass(interactive: true, in: .capsule)
        .animation(quickAnimation, value: store.activeScope)
        .help("Switch between History and your folders (\(KeyboardLayout.scopeKeysLabel), ⌃⇥, or ⌥⌘1–9)")
    }

    private var filterControl: some View {
        HStack(spacing: 2) {
            ForEach(Array(KindFilter.allCases.enumerated()), id: \.element) { index, filter in
                let isActive = store.kindFilter == filter
                Button {
                    store.send(.setKindFilter(filter), animation: quickAnimation)
                } label: {
                    Image(systemName: filter.symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isActive ? Color.primary : Color.secondary)
                        .frame(width: 32, height: PanelMetrics.toolbarHeight - 12)
                        .background {
                            if isActive {
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.28))
                                    .matchedGeometryEffect(id: "filter", in: filterNamespace)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .help("\(filter.title) (⌥\(index + 1))")
                .accessibilityLabel(filter.title)
            }
        }
        .padding(6)
        .panelGlass(in: .capsule)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .snappy(duration: 0.2), value: store.kindFilter)
    }

    private func toastCapsule(_ toast: HistoryFeature.Toast) -> some View {
        HStack(spacing: 6) {
            Image(systemName: toast.symbol)
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: toast.id)
            Text(toast.text)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(height: PanelMetrics.toolbarHeight)
        .panelGlass(tint: .accentColor.opacity(0.25), in: .capsule)
        .transition(.move(edge: .leading).combined(with: .opacity))
        .id(toast.id)
    }

    private func updatePill(_ update: AvailableUpdate) -> some View {
        Button {
            store.send(.openUpdate)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                Text("Update \(update.listing.version)")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.green)
            .padding(.horizontal, 14)
            .frame(height: PanelMetrics.toolbarHeight)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .panelGlass(tint: .green.opacity(0.22), interactive: true, in: .capsule)
        .transition(.opacity)
        .help("A new version is on the App Store (⌘U)")
    }

    private var pauseButton: some View {
        Button {
            store.send(.toggleCapturePaused, animation: quickAnimation)
        } label: {
            Image(systemName: store.capturePaused ? "play.fill" : "pause.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(store.capturePaused ? Color.orange : Color.primary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: PanelMetrics.toolbarHeight, height: PanelMetrics.toolbarHeight)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .panelGlass(tint: store.capturePaused ? .orange.opacity(0.3) : nil, interactive: true, in: .circle)
        .help(store.capturePaused ? "Resume capturing (⇧⌘P)" : "Pause capturing (⇧⌘P)")
        .accessibilityLabel(store.capturePaused ? "Resume capturing" : "Pause capturing")
        .accessibilityValue(store.capturePaused ? "Paused" : "Recording")
    }

    /// One glass capsule that grows from a circle into the field. Don't swap a
    /// button and the field under a shared `glassEffectID`: once the field is
    /// focused, AppKit asks for the key-view loop, and SwiftUI's walk of the
    /// morphing pair never returns, which hangs the app.
    private var searchControl: some View {
        let expanded = store.isSearchExpanded
        return HStack(spacing: 8) {
            if expanded {
                searchField
            } else {
                Button {
                    store.send(.keyCommand(.focusSearch))
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: PanelMetrics.toolbarHeight, height: PanelMetrics.toolbarHeight)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .help("Search (⌘F)")
            }
        }
        .padding(.horizontal, expanded ? 14 : 0)
        .frame(width: expanded ? 280 : PanelMetrics.toolbarHeight, height: PanelMetrics.toolbarHeight)
        .panelGlass(interactive: !expanded, in: .capsule)
        .animation(.easeOut(duration: 0.15), value: store.searchText.isEmpty)
    }

    @ViewBuilder
    private var searchField: some View {
        Image(systemName: "magnifyingglass")
            .foregroundStyle(.secondary)
        if marketingRender {
            // Text fields are AppKit-backed and don't render offline.
            HStack(spacing: 1) {
                Text(store.searchText)
                Rectangle().fill(Color.accentColor).frame(width: 1.5, height: 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TextField(store.activeScope == .history ? "Search history and folders" : "Search \(store.scopeTitle.lowercased())", text: $store.searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit {
                    if let id = store.selectedID { store.send(.itemTapped(id)) }
                }
        }
        if !store.searchText.isEmpty {
            Button {
                store.send(.binding(.set(\.searchText, "")))
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .transition(.opacity)
            .help("Clear (esc)")
        }
    }

    private var settingsButton: some View {
        Button {
            store.send(.delegate(.openSettings(nil)))
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 15, weight: .medium))
                .frame(width: PanelMetrics.toolbarHeight, height: PanelMetrics.toolbarHeight)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .panelGlass(interactive: true, in: .circle)
        .help("Settings (⌘\(String(KeyboardLayout.settingsKeyCharacter).uppercased()))")
        .accessibilityLabel("Settings")
    }

    // MARK: - Cards

    private var emptyMode: EmptyStateView.Mode {
        if store.isSearching { return .search(store.searchText) }
        if store.kindFilter != .all { return .filter(store.kindFilter.title) }
        if let folder = store.currentFolder { return .folder(folder.name) }
        return .history
    }

    @ViewBuilder
    private var cardStrip: some View {
        if store.items.isEmpty {
            EmptyStateView(mode: emptyMode)
                .frame(maxWidth: .infinity)
                .frame(height: PanelMetrics.stripHeight)
                .transition(.opacity)
        } else if marketingRender {
            // ImageRenderer has no scroll viewport (lazy stacks and scroll views lay out
            // nothing offline), so size the row explicitly and clip it.
            GeometryReader { proxy in
                cardsRow(lazy: false)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
                    .clipped()
            }
            .frame(height: PanelMetrics.stripHeight)
        } else {
            ScrollView(.horizontal) {
                cardsRow(lazy: true)
            }
            .scrollPosition(id: $scrollID, anchor: .center)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .frame(height: PanelMetrics.stripHeight)
            .animation(store.selectionAnimated ? quickAnimation : .easeOut(duration: 0.16), value: store.items)
        }
    }

    @ViewBuilder
    private func cardsRow(lazy: Bool) -> some View {
        GlassEffectContainer(spacing: PanelMetrics.cardSpacing) {
            Group {
                if lazy {
                    LazyHStack(spacing: PanelMetrics.cardSpacing) { cards }
                } else {
                    HStack(spacing: PanelMetrics.cardSpacing) { cards }
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, PanelMetrics.stripVerticalPadding)
            .overlayPreferenceValue(CardAnchorKey.self) { anchors in
                GeometryReader { proxy in
                    let rect = store.selectedID.flatMap { anchors[$0] }.map { proxy[$0] }
                    SelectionRingOverlay(rect: rect, animated: store.selectionAnimated, animation: ringAnimation)
                }
                .allowsHitTesting(false)
            }
        }
    }

    private var cards: some View {
        // Read the store once per update, not once per card: these go through
        // TCA's observation (and @Shared settings) on every access.
        let selectedID = store.selectedID
        let flashID = store.flashID
        let recentID = store.recentID
        let showsHints = (store.showShortcutHints && store.keyboardNavigation) || store.modifierHint == .command
        let highlight = store.searchText
        let dragMode = store.dragMode
        let reduceMotion = reduceMotion
        let staggered = store.isEntering
        let interactionEnabled = store.dialog == nil
        let sensitiveLifetime = store.sensitiveLifetime
        let folders = Array(store.folders)
        // Only History mixes in folder items (as search results), so only it badges them.
        let foldersByID = store.activeScope == .history
            ? Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
            : [:]
        return ForEach(rows) { row in
            HStack(spacing: PanelMetrics.cardSpacing) {
                if row.showsPinnedDivider {
                    pinnedDivider
                }
                ItemCardView(
                    item: row.item,
                    index: row.index,
                    isSelected: row.item.id == selectedID,
                    isFlashing: row.item.id == flashID,
                    isRecent: row.item.id == recentID,
                    showShortcutHint: showsHints && row.index < 9,
                    highlight: highlight,
                    dragMode: dragMode,
                    reduceMotion: reduceMotion,
                    staggered: staggered,
                    interactionEnabled: interactionEnabled,
                    sensitiveLifetime: sensitiveLifetime,
                    folders: folders,
                    folderBadge: row.item.folderID.flatMap { foldersByID[$0] },
                    actions: cardActions(for: row.item)
                )
            }
            .id(row.item.id)
            .transition(.opacity.combined(with: .scale(scale: 0.94)))
        }
    }

    private var pinnedDivider: some View {
        VStack(spacing: 6) {
            Image(systemName: "pin.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.orange)
            Capsule()
                .fill(.secondary.opacity(0.35))
                .frame(width: 3)
        }
        .frame(height: PanelMetrics.cardHeight * 0.55)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var paletteOverlay: some View {
        if store.isPaletteOpen, store.dialog == nil {
            CommandPaletteView(
                query: $store.paletteQuery,
                results: store.paletteResults,
                selection: store.paletteSelection,
                onRun: { store.send(.paletteRun($0)) }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    @ViewBuilder
    private var dialogOverlay: some View {
        if let dialog = store.dialog {
            dialogView(for: dialog)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    @ViewBuilder
    private func dialogView(for dialog: HistoryFeature.Dialog) -> some View {
        switch dialog {
        case let .newFolder(thenAdd):
            DialogView(
                title: "New Folder",
                message: thenAdd == nil
                    ? "Folders keep items out of the history timeline. They never expire."
                    : "The item will be saved into the new folder.",
                symbol: "folder.badge.plus",
                text: $store.dialogText,
                placeholder: "Folder name",
                primary: .init(title: "Create") { store.send(.dialogConfirmed(.primary)) },
                onCancel: { store.send(.dialogCancelled) }
            )
        case .renameFolder:
            DialogView(
                title: "Rename Folder",
                message: nil,
                symbol: "pencil",
                text: $store.dialogText,
                placeholder: "Folder name",
                primary: .init(title: "Rename") { store.send(.dialogConfirmed(.primary)) },
                onCancel: { store.send(.dialogCancelled) }
            )
        case let .deleteFolder(id):
            let folder = store.folders[id: id]
            let count = folder?.itemCount ?? 0
            DialogView(
                title: "Delete “\(folder?.name ?? "Folder")”?",
                message: count == 0
                    ? "The folder is empty."
                    : "It holds \(count) item\(count == 1 ? "" : "s"). Move them back to History, or delete them together with the folder.",
                symbol: "trash",
                primary: .init(title: count == 0 ? "Delete Folder" : "Move to History", isDestructive: count == 0) {
                    store.send(.dialogConfirmed(.primary))
                },
                secondary: count == 0 ? nil : .init(title: "Delete Items", isDestructive: true) {
                    store.send(.dialogConfirmed(.secondary))
                },
                onCancel: { store.send(.dialogCancelled) }
            )
        case let .chooseFolder(itemID):
            DialogView(
                title: "Save to Folder",
                message: store.items[id: itemID].map { "“\($0.displayTitle.prefix(48))”" },
                symbol: "folder",
                options: store.dialogOptions,
                onOption: { store.send(.dialogOptionChosen($0)) },
                onCancel: { store.send(.dialogCancelled) }
            )
        case .pasteAs:
            DialogView(
                title: "Paste As",
                message: "Transforms are applied to a copy; the stored item stays untouched.",
                symbol: "text.badge.checkmark",
                options: store.dialogOptions,
                onOption: { store.send(.dialogOptionChosen($0)) },
                onCancel: { store.send(.dialogCancelled) }
            )
        case .copyAs:
            DialogView(
                title: "Copy Color As",
                message: nil,
                symbol: "paintpalette",
                options: store.dialogOptions,
                onOption: { store.send(.dialogOptionChosen($0)) },
                onCancel: { store.send(.dialogCancelled) }
            )
        }
    }

    private func cardActions(for item: ClipboardItem) -> ItemCardView.Actions {
        let id = item.id
        return ItemCardView.Actions(
            tap: { store.send(.itemTapped(id)) },
            pastePlain: { store.send(.paste(id, .plain)) },
            pasteTransformed: { store.send(.paste(id, HistoryFeature.PasteOptions(transform: $0))) },
            copyOnly: { store.send(.copyOnly(id)) },
            copyColor: { store.send(.copyColor(id, $0)) },
            delete: { store.send(.delete(id), animation: .smooth(duration: 0.25)) },
            togglePin: { store.send(.togglePin(id), animation: .smooth(duration: 0.25)) },
            toggleSensitive: { store.send(.toggleSensitive(id)) },
            smartAction: { store.send(.performSmartAction(id, $0)) },
            reveal: { store.send(.revealInFinder(id)) },
            copyPath: { store.send(.copyPath(id)) },
            open: { store.send(.openItem(id)) },
            preview: { store.send(.previewItem(id)) },
            moveToFolder: { store.send(.moveItem(id, toFolder: $0), animation: .smooth(duration: 0.25)) },
            newFolder: { store.send(.newFolderTapped(thenAdd: id)) },
            openPrivacySettings: { store.send(.delegate(.openSettings(.privacy))) },
            payload: { [clipboardStore] in try? await clipboardStore.payload(id) },
            thumbnailURL: item.thumbnailPath.map(clipboardStore.thumbnailURL),
            iconURL: item.linkIconPath.map(clipboardStore.thumbnailURL)
        )
    }
}

struct CardAnchorKey: PreferenceKey {
    static let defaultValue: [UUID: Anchor<CGRect>] = [:]

    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// One ring that glides between cards on navigation and snaps on reloads.
/// It never animates from off-screen: the first placement is always instant.
struct SelectionRingOverlay: View {
    let rect: CGRect?
    let animated: Bool
    let animation: Animation
    @Environment(\.marketingRingOffset) private var marketingOffset
    @State private var displayed: CGRect?

    var body: some View {
        let target = displayed ?? rect
        SelectionRingView()
            .frame(width: target?.width ?? PanelMetrics.cardWidth, height: target?.height ?? PanelMetrics.cardHeight)
            .position(x: (target?.midX ?? -4000) + marketingOffset, y: target?.midY ?? -4000)
            .opacity(rect == nil ? 0 : 1)
            .onChange(of: rect, initial: true) { _, new in
                guard let new else { return }
                if displayed == nil || !animated {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { displayed = new }
                } else {
                    withAnimation(animation) { displayed = new }
                }
            }
    }
}

struct SelectionRingView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: PanelMetrics.cardCornerRadius)
            .strokeBorder(Color.accentColor, lineWidth: 2.5)
            .overlay {
                RoundedRectangle(cornerRadius: PanelMetrics.cardCornerRadius - 3)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    .padding(3)
            }
            .shadow(color: Color.accentColor.opacity(0.5), radius: 10)
    }
}
