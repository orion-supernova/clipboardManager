//
//  HistoryFeature.swift
//  clipboardManager
//
//  The floating panel: presentation, capture, search & filtering, folders,
//  selection, quick preview, paste (with transforms), pinning and retention.
//  Every side effect goes through a dependency client.
//

import ComposableArchitecture
import Foundation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.walhallaa.clipboardManager", category: "History")

@Reducer
struct HistoryFeature {
    @ObservableState
    struct State: Equatable {
        var items: IdentifiedArrayOf<ClipboardItem> = []
        var folders: IdentifiedArrayOf<ClipboardFolder> = []
        var activeScope: HistoryScope = .history
        var selectedID: UUID?
        /// Whether the selection ring should glide (navigation) or snap (reloads).
        var selectionAnimated = true
        var searchText = ""
        var isSearchFocused = false
        var isPresented = false
        /// True for a short moment after presentation; cards stagger in only then.
        var isEntering = false
        var hasLoaded = false
        var flashID: UUID?
        var recentID: UUID?
        var flashHintKey: String?
        var toast: Toast?
        /// Set by keyboard navigation so the strip centres the selection.
        var scrollTarget: UUID?
        var kindFilter: KindFilter = .all
        var previewID: UUID?
        var previewPayload: ClipboardPayload?
        var previewRevealed = false
        var dialog: Dialog?
        var dialogText = ""

        @Shared(.retainCount) var retainCount
        @Shared(.maxAgeHours) var maxAgeHours
        @Shared(.sensitiveMaxAgeMinutes) var sensitiveMaxAgeMinutes
        @Shared(.keyboardNavigation) var keyboardNavigation
        @Shared(.ignoreConcealed) var ignoreConcealed
        @Shared(.recordSensitive) var recordSensitive
        @Shared(.recognizeImageText) var recognizeImageText
        @Shared(.fetchLinkTitles) var fetchLinkTitles
        @Shared(.dragMode) var dragMode
        @Shared(.showShortcutHints) var showShortcutHints
        @Shared(.capturePaused) var capturePaused
        @Shared(.availableUpdate) var availableUpdate

        var isSearchExpanded: Bool { isSearchFocused || !searchText.isEmpty }
        var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var isPreviewOpen: Bool { previewID != nil }
        var selectedIndex: Int? { selectedID.flatMap { items.index(id: $0) } }
        var selectedItem: ClipboardItem? { selectedID.flatMap { items[id: $0] } }
        var currentFolder: ClipboardFolder? { activeScope.folderID.flatMap { folders[id: $0] } }
        var scopeTitle: String { currentFolder?.name ?? "History" }
        var sensitiveLifetime: TimeInterval? { sensitiveMaxAgeMinutes > 0 ? TimeInterval(sensitiveMaxAgeMinutes) * 60 : nil }

        var retention: RetentionPolicy {
            RetentionPolicy(retainCount: retainCount, maxAgeHours: maxAgeHours, sensitiveMaxAgeMinutes: sensitiveMaxAgeMinutes)
        }

        var query: ItemQuery { ItemQuery(search: searchText, kinds: kindFilter.kinds, scope: activeScope) }

        /// Options presented by chooser dialogs (folders, paste transforms, color formats).
        var dialogOptions: [DialogOption] {
            switch dialog {
            case let .chooseFolder(itemID):
                var options = folders.enumerated().map { index, folder in
                    DialogOption(id: index, title: folder.name, symbol: folder.symbol, isDisabled: folder.id == items[id: itemID]?.folderID)
                }
                if items[id: itemID]?.folderID != nil {
                    options.append(DialogOption(id: options.count, title: "Move to History", symbol: "clock.arrow.circlepath"))
                }
                options.append(DialogOption(id: options.count, title: "New Folder…", symbol: "folder.badge.plus"))
                return options
            case .pasteAs:
                return [DialogOption(id: 0, title: "Plain Text", symbol: "textformat")]
                    + TextTransform.allCases.enumerated().map { DialogOption(id: $0.offset + 1, title: $0.element.title, symbol: $0.element.symbol) }
            case .copyAs:
                return ColorFormat.allCases.enumerated().map { DialogOption(id: $0.offset, title: $0.element.title, symbol: "swatchpalette") }
            default:
                return []
            }
        }

        /// Keeps the in-memory list consistent with the retention policy without a round trip.
        mutating func applyRetention() {
            guard activeScope == .history, let maxCount = retention.maxCount else { return }
            let unpinned = items.filter { !$0.isPinned }
            guard unpinned.count > maxCount else { return }
            let doomed = Set(unpinned.suffix(unpinned.count - maxCount).map(\.id))
            items.removeAll { doomed.contains($0.id) }
            if let selectedID, doomed.contains(selectedID) { self.selectedID = items.first?.id }
        }

        mutating func resort() {
            items.sort { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.timestamp > rhs.timestamp
            }
        }

        mutating func remove(_ id: UUID) {
            guard let index = items.index(id: id) else { return }
            items.remove(at: index)
            if selectedID == id { selectNeighbor(after: index) }
        }

        mutating func selectNeighbor(after removedIndex: Int) {
            guard !items.isEmpty else { selectedID = nil; return }
            selectedID = items[min(removedIndex, items.count - 1)].id
        }
    }

    struct Toast: Equatable, Sendable, Identifiable {
        var id = UUID()
        var text: String
        var symbol: String
    }

    struct DialogOption: Equatable, Sendable, Identifiable {
        var id: Int
        var title: String
        var symbol: String
        var isDisabled = false
    }

    struct PasteOptions: Equatable, Sendable {
        var plainText = false
        var transform: TextTransform?

        static let standard = PasteOptions()
        static let plain = PasteOptions(plainText: true)
    }

    enum Dialog: Equatable, Sendable {
        case newFolder(thenAdd: UUID?)
        case renameFolder(UUID)
        case deleteFolder(UUID)
        case chooseFolder(UUID)
        case pasteAs(UUID)
        case copyAs(UUID)

        var isChooser: Bool {
            switch self {
            case .chooseFolder, .pasteAs, .copyAs: true
            default: false
            }
        }
    }

    enum DialogChoice: Equatable, Sendable { case primary, secondary }
    enum Move: Equatable, Sendable { case previous, next, first, last }

    enum DismissReason: Equatable, Sendable {
        case userDismissed
        case pasted
        case lostFocus
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case task
        case togglePresentation
        case present
        case presentationDidBegin
        case entranceFinished
        case dismiss(DismissReason)
        case dismissalDidFinish
        case reload
        case reloadFolders
        case itemsLoaded([ClipboardItem])
        case foldersLoaded([ClipboardFolder])
        case ingested(IngestResult)
        case itemUpdated(ClipboardItem)
        case itemTapped(UUID)
        case paste(UUID, PasteOptions)
        case copyOnly(UUID)
        case copyText(String, toast: String)
        case copyColor(UUID, ColorFormat)
        case delete(UUID)
        case togglePin(UUID)
        case revealInFinder(UUID)
        case copyPath(UUID)
        case openItem(UUID)
        case setKindFilter(KindFilter)
        case setScope(HistoryScope)
        case cycleScope(Int)
        case newFolderTapped(thenAdd: UUID?)
        case renameFolderTapped
        case deleteFolderTapped
        case chooseFolderTapped(UUID)
        case pasteAsTapped(UUID)
        case copyAsTapped(UUID)
        case dialogConfirmed(DialogChoice)
        case dialogOptionChosen(Int)
        case dialogCancelled
        case folderCreated(ClipboardFolder, thenAdd: UUID?)
        case folderDeleted(UUID, FolderDeletion)
        case moveItem(UUID, toFolder: UUID?)
        case previewItem(UUID)
        case togglePreview
        case closePreview
        case toggleReveal
        case previewLoaded(UUID, ClipboardPayload?)
        case toggleCapturePaused
        case openUpdate
        case move(Move)
        case keyCommand(KeyCommand)
        case panelEvent(PanelEvent)
        case pruneTick
        case pruned([UUID])
        case clearAllTapped
        case cleared
        case showToast(String, symbol: String)
        case toastExpired(UUID)
        case recentExpired(UUID)
        case hintFlashExpired
        case settingsChanged
        case delegate(Delegate)

        enum Delegate: Equatable {
            case openSettings(SettingsFeature.State.Section?)
            case quit
        }
    }

    private enum CancelID { case lifecycle, search, dismissal, toast, preview, previewResize, recent, hintFlash, entrance }

    @Dependency(\.clipboardStore) var clipboardStore
    @Dependency(\.clipboardMonitor) var monitor
    @Dependency(\.paste) var paste
    @Dependency(\.panel) var panel
    @Dependency(\.workspace) var workspace
    @Dependency(\.linkMetadata) var linkMetadata
    @Dependency(\.textRecognition) var textRecognition
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.searchText):
                return debouncedReload()

            case .binding:
                return .none

            case .task:
                let ignoreConcealed = state.$ignoreConcealed
                let recordSensitive = state.$recordSensitive
                let capturePaused = state.$capturePaused
                let retainCount = state.$retainCount
                let maxAgeHours = state.$maxAgeHours
                let sensitiveMaxAge = state.$sensitiveMaxAgeMinutes
                return .merge(
                    .run { send in
                        try await clipboardStore.prepare()
                        await send(.reload)
                        await send(.reloadFolders)
                        await send(.pruneTick)
                    } catch: { error, _ in
                        logger.error("Store preparation failed: \(error.localizedDescription)")
                    },
                    .run { send in
                        for await snapshot in monitor.changes() {
                            // Paused: ignore everything except the app's own writes (so pasting still bumps items).
                            if capturePaused.wrappedValue, snapshot.ownMarkerID == nil { continue }
                            do {
                                let options = IngestOptions(
                                    ignoreConcealed: ignoreConcealed.wrappedValue,
                                    recordSensitive: recordSensitive.wrappedValue
                                )
                                let result = try await clipboardStore.ingest(snapshot, options)
                                await send(.ingested(result), animation: .smooth(duration: 0.28))
                            } catch {
                                logger.error("Ingest failed: \(error.localizedDescription)")
                            }
                        }
                    },
                    .run { send in
                        for await event in panel.events() { await send(.panelEvent(event)) }
                    },
                    .run { send in
                        for await _ in clock.timer(interval: .seconds(60)) { await send(.pruneTick) }
                    },
                    .run { send in
                        for await _ in retainCount.publisher.values.dropFirst() { await send(.settingsChanged) }
                    },
                    .run { send in
                        for await _ in maxAgeHours.publisher.values.dropFirst() { await send(.settingsChanged) }
                    },
                    .run { send in
                        for await _ in sensitiveMaxAge.publisher.values.dropFirst() { await send(.settingsChanged) }
                    }
                )
                .cancellable(id: CancelID.lifecycle)

            // MARK: Presentation

            case .togglePresentation:
                return state.isPresented ? .send(.dismiss(.userDismissed)) : .send(.present)

            case .present:
                state.searchText = ""
                state.isSearchFocused = false
                state.flashID = nil
                state.recentID = nil
                state.toast = nil
                state.scrollTarget = nil
                state.kindFilter = .all
                state.previewID = nil
                state.previewPayload = nil
                state.previewRevealed = false
                state.dialog = nil
                state.selectionAnimated = false
                state.selectedID = state.items.first?.id
                return .merge(
                    .cancel(id: CancelID.dismissal),
                    .run { send in
                        await panel.show()
                        await send(.presentationDidBegin)
                        await send(.reload)
                        await send(.reloadFolders)
                    }
                )

            case .presentationDidBegin:
                state.isPresented = true
                state.isEntering = true
                return .run { send in
                    try await clock.sleep(for: .milliseconds(700))
                    await send(.entranceFinished)
                }
                .cancellable(id: CancelID.entrance, cancelInFlight: true)

            case .entranceFinished:
                state.isEntering = false
                return .none

            case let .dismiss(reason):
                guard state.isPresented else { return .none }
                state.isPresented = false
                state.isEntering = false
                state.isSearchFocused = false
                state.previewID = nil
                state.previewPayload = nil
                state.previewRevealed = false
                state.dialog = nil
                return .merge(
                    .cancel(id: CancelID.previewResize),
                    .run { send in
                        try await clock.sleep(for: .milliseconds(200))
                        await panel.hide()
                        await send(.dismissalDidFinish)
                    }
                    .cancellable(id: CancelID.dismissal, cancelInFlight: true)
                )

            case .dismissalDidFinish:
                state.flashID = nil
                state.searchText = ""
                return .none

            // MARK: Loading

            case .reload:
                let query = state.query
                return .run { send in
                    let items = try await clipboardStore.load(query)
                    await send(.itemsLoaded(items), animation: .smooth(duration: 0.25))
                } catch: { error, _ in
                    logger.error("Load failed: \(error.localizedDescription)")
                }
                .cancellable(id: CancelID.search, cancelInFlight: true)

            case .reloadFolders:
                return .run { send in
                    let folders = try await clipboardStore.folders()
                    await send(.foldersLoaded(folders), animation: .smooth(duration: 0.25))
                } catch: { error, _ in
                    logger.error("Folder load failed: \(error.localizedDescription)")
                }

            case let .itemsLoaded(items):
                state.items = IdentifiedArray(uniqueElements: items)
                state.hasLoaded = true
                state.selectionAnimated = false
                if let selected = state.selectedID, state.items[id: selected] != nil {
                    return .none
                }
                state.selectedID = state.items.first?.id
                if state.isPreviewOpen {
                    if let id = state.selectedID {
                        state.previewID = id
                        state.previewRevealed = false
                        return loadPreview(id)
                    }
                    return .send(.closePreview)
                }
                return .none

            case let .foldersLoaded(folders):
                state.folders = IdentifiedArray(uniqueElements: folders)
                if let folderID = state.activeScope.folderID, state.folders[id: folderID] == nil {
                    state.activeScope = .history
                    return .send(.reload)
                }
                return .none

            case let .ingested(.inserted(item)):
                guard state.activeScope == .history else { return .send(.pruneTick) }
                if state.isSearching { return .merge(.send(.reload), enrichment(for: item)) }
                guard state.kindFilter.matches(item.kind) else { return .merge(.send(.pruneTick), enrichment(for: item)) }
                let insertIndex = state.items.firstIndex { !$0.isPinned } ?? state.items.endIndex
                state.items.insert(item, at: insertIndex)
                state.applyRetention()
                state.selectionAnimated = true
                if state.selectedID == nil || !state.isPresented { state.selectedID = state.items.first?.id }
                var effects: [Effect<Action>] = [.send(.pruneTick), enrichment(for: item)]
                if state.isPresented {
                    state.recentID = item.id
                    effects.append(
                        .run { send in
                            try await clock.sleep(for: .milliseconds(1600))
                            await send(.recentExpired(item.id), animation: .smooth)
                        }
                        .cancellable(id: CancelID.recent, cancelInFlight: true)
                    )
                }
                return .merge(effects)

            case let .ingested(.touched(id)):
                guard let index = state.items.index(id: id) else { return .send(.reload) }
                var item = state.items[index]
                item.timestamp = Date()
                state.items.remove(at: index)
                let insertIndex = item.isPinned ? 0 : (state.items.firstIndex { !$0.isPinned } ?? state.items.endIndex)
                state.items.insert(item, at: insertIndex)
                state.selectionAnimated = true
                // Older rows may predate enrichment (titles, OCR, thumbnails); catch them up.
                let needsEnrichment = (item.kind == .url && item.linkTitle == nil)
                    || (item.kind == .image && item.preview.isEmpty)
                    || (item.kind.isFileBacked && item.thumbnailPath == nil)
                return needsEnrichment ? enrichment(for: item) : .none

            case .ingested(.ignored):
                return .none

            case let .itemUpdated(item):
                if state.items[id: item.id] != nil { state.items[id: item.id] = item }
                if state.previewID == item.id { return loadPreview(item.id) }
                return .none

            // MARK: Item actions

            case let .itemTapped(id):
                return .send(.paste(id, .standard))

            case let .paste(id, options):
                guard state.items[id: id] != nil else { return .none }
                state.selectedID = id
                state.selectionAnimated = true
                state.flashID = id
                return .run { send in
                    guard var payload = try await clipboardStore.payload(id) else { return }
                    if let transform = options.transform {
                        guard let text = payload.text, let transformed = transform.apply(to: text) else {
                            await send(.showToast("Not valid JSON", symbol: "exclamationmark.triangle.fill"), animation: .bouncy)
                            await send(.binding(.set(\.flashID, nil)))
                            return
                        }
                        payload.text = transformed
                        payload.richText = nil
                    }
                    await paste.write(payload, id, options.plainText || options.transform != nil)
                    await workspace.haptic(.levelChange)
                    try await clock.sleep(for: .milliseconds(150))
                    await send(.dismiss(.pasted))
                } catch: { error, _ in
                    logger.error("Paste failed: \(error.localizedDescription)")
                }

            case let .copyOnly(id):
                guard state.items[id: id] != nil else { return .none }
                state.selectedID = id
                state.selectionAnimated = true
                return .run { send in
                    guard let payload = try await clipboardStore.payload(id) else { return }
                    await paste.write(payload, id, false)
                    await workspace.haptic(.generic)
                    await send(.showToast("Copied", symbol: "checkmark.circle.fill"), animation: .bouncy)
                } catch: { error, _ in
                    logger.error("Copy failed: \(error.localizedDescription)")
                }

            case let .copyText(text, toastText):
                return .run { send in
                    await paste.write(ClipboardPayload(kind: .text, text: text), UUID(), true)
                    await workspace.haptic(.generic)
                    await send(.showToast(toastText, symbol: "checkmark.circle.fill"), animation: .bouncy)
                }

            case let .copyColor(id, format):
                guard let item = state.items[id: id], let color = ParsedColor.parse(item.preview) else { return .none }
                return .send(.copyText(format.render(color), toast: "Copied as \(format.title)"))

            case let .delete(id):
                guard state.items[id: id] != nil else { return .none }
                state.remove(id)
                state.selectionAnimated = true
                var effects: [Effect<Action>] = [
                    .run { send in
                        try await clipboardStore.delete([id])
                        await send(.reloadFolders)
                    } catch: { error, _ in
                        logger.error("Delete failed: \(error.localizedDescription)")
                    },
                ]
                if state.previewID == id { effects.append(.send(.closePreview)) }
                return .merge(effects)

            case let .togglePin(id):
                guard var item = state.items[id: id] else { return .none }
                item.isPinned.toggle()
                state.items[id: id] = item
                state.resort()
                state.scrollTarget = id
                state.selectionAnimated = true
                let pinned = item.isPinned
                return .merge(
                    .run { _ in
                        try await clipboardStore.setPinned(id, pinned)
                        await workspace.haptic(.alignment)
                    } catch: { error, _ in
                        logger.error("Pin failed: \(error.localizedDescription)")
                    },
                    animated(.showToast(pinned ? "Pinned" : "Unpinned", symbol: pinned ? "pin.fill" : "pin.slash"), .bouncy)
                )

            case let .revealInFinder(id):
                return .run { _ in
                    guard let url = try await clipboardStore.payload(id).flatMap({ $0.fileURL ?? $0.imageFileURL }) else { return }
                    await workspace.revealInFinder(url)
                }

            case let .openItem(id):
                return .run { _ in
                    guard let payload = try await clipboardStore.payload(id) else { return }
                    if let url = payload.fileURL ?? payload.imageFileURL {
                        await workspace.open(url)
                    } else if payload.kind == .url, let text = payload.text,
                              let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        await workspace.open(url)
                    }
                }

            case let .copyPath(id):
                return .run { send in
                    guard let payload = try await clipboardStore.payload(id),
                          let path = (payload.fileURL ?? payload.imageFileURL)?.path
                    else { return }
                    await send(.copyText(path, toast: "Path copied"))
                }

            // MARK: Filter, scope, folders

            case let .setKindFilter(filter):
                guard filter != state.kindFilter else { return .none }
                state.kindFilter = filter
                state.selectedID = nil
                state.selectionAnimated = false
                return .merge(closePreviewEffect(&state), .send(.reload))

            case let .setScope(scope):
                guard scope != state.activeScope else { return .none }
                state.activeScope = scope
                state.selectedID = nil
                state.selectionAnimated = false
                state.searchText = ""
                return .merge(closePreviewEffect(&state), .send(.reload))

            case let .cycleScope(delta):
                let scopes: [HistoryScope] = [.history] + state.folders.map { .folder($0.id) }
                guard scopes.count > 1 else { return .none }
                let current = scopes.firstIndex(of: state.activeScope) ?? 0
                let next = (current + delta + scopes.count) % scopes.count
                return .send(.setScope(scopes[next]))

            case let .newFolderTapped(thenAdd):
                state.dialog = .newFolder(thenAdd: thenAdd)
                state.dialogText = ""
                state.isSearchFocused = false
                return .none

            case .renameFolderTapped:
                guard let folder = state.currentFolder else { return .none }
                state.dialog = .renameFolder(folder.id)
                state.dialogText = folder.name
                state.isSearchFocused = false
                return .none

            case .deleteFolderTapped:
                guard let folder = state.currentFolder else { return .none }
                state.dialog = .deleteFolder(folder.id)
                state.isSearchFocused = false
                return .none

            case let .chooseFolderTapped(id):
                guard state.items[id: id] != nil else { return .none }
                if state.folders.isEmpty { return .send(.newFolderTapped(thenAdd: id)) }
                state.selectedID = id
                state.dialog = .chooseFolder(id)
                state.isSearchFocused = false
                return .none

            case let .pasteAsTapped(id):
                guard let item = state.items[id: id], item.kind == .text || item.kind == .url else { return .none }
                state.selectedID = id
                state.dialog = .pasteAs(id)
                state.isSearchFocused = false
                return .none

            case let .copyAsTapped(id):
                guard let item = state.items[id: id], item.kind == .color else { return .none }
                state.selectedID = id
                state.dialog = .copyAs(id)
                state.isSearchFocused = false
                return .none

            case let .dialogConfirmed(choice):
                guard let dialog = state.dialog else { return .none }
                let text = state.dialogText.trimmingCharacters(in: .whitespacesAndNewlines)
                switch dialog {
                case let .newFolder(thenAdd):
                    guard !text.isEmpty else { return .none }
                    state.dialog = nil
                    return .run { send in
                        let folder = try await clipboardStore.createFolder(text)
                        await send(.folderCreated(folder, thenAdd: thenAdd), animation: .smooth)
                    } catch: { error, _ in
                        logger.error("Create folder failed: \(error.localizedDescription)")
                    }
                case let .renameFolder(id):
                    guard !text.isEmpty else { return .none }
                    state.dialog = nil
                    state.folders[id: id]?.name = text
                    return .run { send in
                        try await clipboardStore.renameFolder(id, text)
                        await send(.reloadFolders)
                    } catch: { error, _ in
                        logger.error("Rename folder failed: \(error.localizedDescription)")
                    }
                case let .deleteFolder(id):
                    state.dialog = nil
                    let strategy: FolderDeletion = choice == .primary ? .moveItemsToHistory : .deleteItems
                    return .run { send in
                        try await clipboardStore.deleteFolder(id, strategy)
                        await send(.folderDeleted(id, strategy), animation: .smooth)
                    } catch: { error, _ in
                        logger.error("Delete folder failed: \(error.localizedDescription)")
                    }
                case .chooseFolder, .pasteAs, .copyAs:
                    // ↩ picks the first option in chooser dialogs.
                    return .send(.dialogOptionChosen(0))
                }

            case let .dialogOptionChosen(index):
                guard let dialog = state.dialog, state.dialogOptions.indices.contains(index) else { return .none }
                switch dialog {
                case let .chooseFolder(itemID):
                    let folderCount = state.folders.count
                    if index < folderCount {
                        state.dialog = nil
                        return .send(.moveItem(itemID, toFolder: state.folders[index].id))
                    }
                    var next = folderCount
                    if state.items[id: itemID]?.folderID != nil {
                        if index == next {
                            state.dialog = nil
                            return .send(.moveItem(itemID, toFolder: nil))
                        }
                        next += 1
                    }
                    return index == next ? .send(.newFolderTapped(thenAdd: itemID)) : .none
                case let .pasteAs(itemID):
                    state.dialog = nil
                    if index == 0 { return .send(.paste(itemID, .plain)) }
                    let transforms = TextTransform.allCases
                    guard transforms.indices.contains(index - 1) else { return .none }
                    return .send(.paste(itemID, PasteOptions(transform: transforms[index - 1])))
                case let .copyAs(itemID):
                    state.dialog = nil
                    guard ColorFormat.allCases.indices.contains(index) else { return .none }
                    return .send(.copyColor(itemID, ColorFormat.allCases[index]))
                default:
                    return .none
                }

            case .dialogCancelled:
                state.dialog = nil
                return .none

            case let .folderCreated(folder, thenAdd):
                state.folders.append(folder)
                if let itemID = thenAdd {
                    return .send(.moveItem(itemID, toFolder: folder.id))
                }
                state.activeScope = .folder(folder.id)
                state.selectedID = nil
                state.selectionAnimated = false
                return .merge(
                    closePreviewEffect(&state),
                    .send(.reload),
                    animated(.showToast("Folder “\(folder.name)” created", symbol: "folder.fill.badge.plus"), .bouncy)
                )

            case let .folderDeleted(id, strategy):
                state.folders.remove(id: id)
                if state.activeScope == .folder(id) {
                    state.activeScope = .history
                    state.selectedID = nil
                    state.selectionAnimated = false
                }
                let message = strategy == .moveItemsToHistory ? "Folder deleted, items moved to History" : "Folder and items deleted"
                return .merge(
                    closePreviewEffect(&state),
                    .send(.reload),
                    .send(.reloadFolders),
                    animated(.showToast(message, symbol: "folder.badge.minus"), .bouncy)
                )

            case let .moveItem(id, folderID):
                guard state.items[id: id] != nil || state.activeScope != .history else { return .none }
                let leavesList = state.activeScope.folderID != folderID
                if leavesList {
                    state.remove(id)
                    state.selectionAnimated = true
                }
                let destination = folderID.flatMap { state.folders[id: $0]?.name }
                var effects: [Effect<Action>] = [
                    .run { send in
                        try await clipboardStore.moveItem(id, folderID)
                        await send(.reloadFolders)
                    } catch: { error, _ in
                        logger.error("Move failed: \(error.localizedDescription)")
                    },
                    animated(
                        .showToast(destination.map { "Saved to “\($0)”" } ?? "Moved to History", symbol: folderID == nil ? "clock.arrow.circlepath" : "folder.fill"),
                        .bouncy
                    ),
                ]
                if leavesList, state.previewID == id { effects.append(.send(.closePreview)) }
                return .merge(effects)

            // MARK: Preview, pause, update

            case let .previewItem(id):
                guard state.items[id: id] != nil else { return .none }
                if state.previewID == id { return .send(.closePreview) }
                state.selectedID = id
                state.scrollTarget = id
                state.selectionAnimated = true
                state.previewID = id
                state.previewRevealed = false
                return .merge(
                    .cancel(id: CancelID.previewResize),
                    .run { _ in await panel.resize(PanelMetrics.expandedHeight) },
                    loadPreview(id)
                )

            case .togglePreview:
                if state.isPreviewOpen { return .send(.closePreview) }
                guard let id = state.selectedID else { return .none }
                return .send(.previewItem(id))

            case .closePreview:
                return closePreviewEffect(&state)

            case .toggleReveal:
                guard state.isPreviewOpen else { return .none }
                state.previewRevealed.toggle()
                return .none

            case let .previewLoaded(id, payload):
                guard state.previewID == id else { return .none }
                state.previewPayload = payload
                return .none

            case .toggleCapturePaused:
                let paused = !state.capturePaused
                state.$capturePaused.withLock { $0 = paused }
                return animated(
                    .showToast(paused ? "Capture paused" : "Capture resumed", symbol: paused ? "pause.circle.fill" : "record.circle"),
                    .bouncy
                )

            case .openUpdate:
                guard let update = state.availableUpdate else { return .none }
                return .merge(
                    .send(.dismiss(.lostFocus)),
                    .run { _ in await workspace.open(update.listing.storeURL) }
                )

            // MARK: Selection & keyboard

            case let .move(move):
                guard !state.items.isEmpty else { return .none }
                let count = state.items.count
                let current = state.selectedIndex ?? -1
                let target: Int = switch move {
                case .previous: current - 1
                case .next: current + 1
                case .first: 0
                case .last: count - 1
                }
                guard (0..<count).contains(target), target != current else {
                    return .run { _ in await workspace.haptic(.generic) }
                }
                let id = state.items[target].id
                state.selectedID = id
                state.selectionAnimated = true
                state.scrollTarget = id
                if state.isPreviewOpen {
                    state.previewID = id
                    state.previewRevealed = false
                    return loadPreview(id)
                }
                return .none

            case let .keyCommand(command):
                if let dialog = state.dialog {
                    switch command {
                    case .escape:
                        return .send(.dialogCancelled)
                    case let .confirm(plainText):
                        return .send(.dialogConfirmed(plainText ? .secondary : .primary))
                    case let .typeToSearch(text):
                        if dialog.isChooser, let number = Int(text), number >= 1 {
                            return .send(.dialogOptionChosen(number - 1))
                        }
                        return .none
                    default:
                        return .none
                    }
                }
                let flash = hintFlashEffect(for: command, state: &state)
                switch command {
                case .escape:
                    if state.isSearchFocused, !state.searchText.isEmpty {
                        state.searchText = ""
                        return .merge(flash, debouncedReload())
                    }
                    if state.isSearchFocused {
                        state.isSearchFocused = false
                        return flash
                    }
                    if state.isPreviewOpen { return .merge(flash, .send(.closePreview)) }
                    return .merge(flash, .send(.dismiss(.userDismissed)))
                case let .confirm(plainText):
                    guard let id = state.selectedID else { return flash }
                    return .merge(flash, .send(.paste(id, plainText ? .plain : .standard)))
                case .previous: return .send(.move(.previous))
                case .next: return .send(.move(.next))
                case .first: return .send(.move(.first))
                case .last: return .send(.move(.last))
                case .deleteSelected:
                    guard let id = state.selectedID else { return flash }
                    return .merge(flash, animated(.delete(id), .smooth(duration: 0.25)))
                case .focusSearch:
                    state.isSearchFocused = true
                    return flash
                case let .typeToSearch(text):
                    if state.isPreviewOpen, let item = state.selectedItem, item.kind == .color,
                       let number = Int(text), ColorFormat.allCases.indices.contains(number - 1) {
                        return .send(.copyColor(item.id, ColorFormat.allCases[number - 1]))
                    }
                    state.searchText += text
                    state.isSearchFocused = true
                    return .merge(flash, debouncedReload())
                case let .pasteIndex(index):
                    guard state.items.indices.contains(index) else { return .none }
                    return .send(.paste(state.items[index].id, .standard))
                case .copyOnly:
                    guard let id = state.selectedID else { return flash }
                    return .merge(flash, .send(.copyOnly(id)))
                case .togglePin:
                    guard let id = state.selectedID else { return flash }
                    return .merge(flash, animated(.togglePin(id), .smooth(duration: 0.25)))
                case .togglePreview:
                    return .merge(flash, .send(.togglePreview))
                case .openSettings:
                    return .send(.delegate(.openSettings(nil)))
                case .quit:
                    return .send(.delegate(.quit))
                case .toggleFocus:
                    state.isSearchFocused.toggle()
                    return .none
                case .previousScope:
                    return .merge(flash, .send(.cycleScope(-1)))
                case .nextScope:
                    return .merge(flash, .send(.cycleScope(1)))
                case .newFolder:
                    return .send(.newFolderTapped(thenAdd: nil))
                case .renameFolder:
                    return .send(.renameFolderTapped)
                case .deleteFolder:
                    return .send(.deleteFolderTapped)
                case let .setFilter(index):
                    guard KindFilter.allCases.indices.contains(index) else { return .none }
                    return .merge(flash, .send(.setKindFilter(KindFilter.allCases[index])))
                case .togglePause:
                    return .send(.toggleCapturePaused)
                case .openUpdate:
                    return .send(.openUpdate)
                case .saveToFolder:
                    guard let id = state.selectedID else { return flash }
                    return .merge(flash, .send(.chooseFolderTapped(id)))
                case .pasteAs:
                    guard let id = state.selectedID else { return .none }
                    return .send(.pasteAsTapped(id))
                case .secondaryCopy:
                    guard let item = state.selectedItem else { return .none }
                    switch item.kind {
                    case .color:
                        return .send(.copyAsTapped(item.id))
                    case .file, .video:
                        return .send(.copyPath(item.id))
                    default:
                        let id = item.id
                        let toast = item.kind == .image ? "Image text copied" : "Plain text copied"
                        return .run { send in
                            guard let text = try await clipboardStore.payload(id)?.text, !text.isEmpty else { return }
                            await send(.copyText(text, toast: toast))
                        }
                    }
                case .reveal:
                    if state.isPreviewOpen { return .send(.toggleReveal) }
                    guard let item = state.selectedItem else { return .none }
                    return .concatenate(.send(.previewItem(item.id)), item.isSensitive ? .send(.toggleReveal) : .none)
                case .open:
                    guard let id = state.selectedID else { return .none }
                    return .send(.openItem(id))
                case .revealInFinder:
                    guard let item = state.selectedItem, item.kind.isFileBacked || item.kind == .image else { return .none }
                    return .send(.revealInFinder(item.id))
                case .copyPath:
                    guard let item = state.selectedItem, item.kind.isFileBacked || item.kind == .image else { return .none }
                    return .send(.copyPath(item.id))
                }

            case .panelEvent(.didResignKey), .panelEvent(.clickedOutside):
                return state.isPresented ? .send(.dismiss(.lostFocus)) : .none

            case let .panelEvent(.key(command)):
                return .send(.keyCommand(command))

            // MARK: Retention

            case .pruneTick:
                let policy = state.retention
                return .run { send in
                    let removed = try await clipboardStore.prune(policy)
                    if !removed.isEmpty { await send(.pruned(removed), animation: .smooth(duration: 0.25)) }
                } catch: { error, _ in
                    logger.error("Prune failed: \(error.localizedDescription)")
                }

            case let .pruned(ids):
                let doomed = Set(ids)
                let selectedIndex = state.selectedIndex
                state.items.removeAll { doomed.contains($0.id) }
                if let selectedID = state.selectedID, doomed.contains(selectedID) {
                    state.selectNeighbor(after: selectedIndex ?? 0)
                    state.selectionAnimated = false
                }
                if let previewID = state.previewID, doomed.contains(previewID) { return .send(.closePreview) }
                return .none

            case .settingsChanged:
                state.applyRetention()
                return .merge(.send(.pruneTick), .send(.reload))

            case .clearAllTapped:
                return .run { send in
                    let confirmed = await workspace.confirm(
                        "Clear clipboard history?",
                        "Every item — including pinned items and folders — will be removed. This can't be undone.",
                        "Clear Everything"
                    )
                    guard confirmed else { return }
                    try await clipboardStore.deleteAll()
                    await send(.cleared, animation: .smooth)
                } catch: { error, _ in
                    logger.error("Clear failed: \(error.localizedDescription)")
                }

            case .cleared:
                state.items.removeAll()
                state.folders.removeAll()
                state.activeScope = .history
                state.selectedID = nil
                return closePreviewEffect(&state)

            // MARK: Transient UI state

            case let .showToast(text, symbol):
                let toast = Toast(text: text, symbol: symbol)
                state.toast = toast
                return .run { send in
                    try await clock.sleep(for: .milliseconds(1600))
                    await send(.toastExpired(toast.id), animation: .smooth)
                }
                .cancellable(id: CancelID.toast, cancelInFlight: true)

            case let .toastExpired(id):
                if state.toast?.id == id { state.toast = nil }
                return .none

            case let .recentExpired(id):
                if state.recentID == id { state.recentID = nil }
                return .none

            case .hintFlashExpired:
                state.flashHintKey = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }

    // MARK: - Effect helpers

    private func animated(_ action: Action, _ animation: Animation) -> Effect<Action> {
        .run { send in await send(action, animation: animation) }
    }

    private func debouncedReload() -> Effect<Action> {
        .run { send in
            try await clock.sleep(for: .milliseconds(120))
            await send(.reload)
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }

    private func loadPreview(_ id: UUID) -> Effect<Action> {
        .run { send in
            let payload = try await clipboardStore.payload(id)
            await send(.previewLoaded(id, payload), animation: .smooth(duration: 0.2))
        } catch: { error, _ in
            logger.error("Preview load failed: \(error.localizedDescription)")
        }
        .cancellable(id: CancelID.preview, cancelInFlight: true)
    }

    /// Fades the sheet out first, then shrinks the window — never both at once.
    private func closePreviewEffect(_ state: inout State) -> Effect<Action> {
        guard state.isPreviewOpen else { return .none }
        state.previewID = nil
        state.previewPayload = nil
        state.previewRevealed = false
        return .merge(
            .cancel(id: CancelID.preview),
            .run { _ in
                try await clock.sleep(for: .milliseconds(170))
                await panel.resize(PanelMetrics.height)
            }
            .cancellable(id: CancelID.previewResize, cancelInFlight: true)
        )
    }

    /// Post-insert enrichment that never blocks capture: Quick Look thumbnails,
    /// link previews and on-device OCR, each surfacing as an `itemUpdated`.
    private func enrichment(for item: ClipboardItem) -> Effect<Action> {
        @Shared(.fetchLinkTitles) var fetchLinkTitles
        @Shared(.recognizeImageText) var recognizeImageText
        switch item.kind {
        case .file, .video:
            return .run { send in
                if let updated = try await clipboardStore.generateFileThumbnail(item.id) {
                    await send(.itemUpdated(updated), animation: .smooth)
                }
            } catch: { error, _ in
                logger.debug("Thumbnail generation failed: \(error.localizedDescription)")
            }
        case .url:
            guard fetchLinkTitles, let url = URL(string: item.preview) else { return .none }
            return .run { send in
                guard let metadata = await linkMetadata.fetch(url), !metadata.isEmpty,
                      let updated = try await clipboardStore.setLinkMetadata(metadata, item.id)
                else { return }
                await send(.itemUpdated(updated), animation: .smooth)
            } catch: { error, _ in
                logger.debug("Link metadata failed: \(error.localizedDescription)")
            }
        case .image:
            guard recognizeImageText, let path = item.imagePath else { return .none }
            let url = clipboardStore.imageURL(path)
            return .run { send in
                guard let text = await textRecognition.recognize(url),
                      let updated = try await clipboardStore.setRecognizedText(text, item.id)
                else { return }
                await send(.itemUpdated(updated), animation: .smooth)
            } catch: { error, _ in
                logger.debug("Text recognition failed: \(error.localizedDescription)")
            }
        default:
            return .none
        }
    }

    private func hintFlashEffect(for command: KeyCommand, state: inout State) -> Effect<Action> {
        let key: String? = switch command {
        case let .confirm(plainText): plainText ? "⇧↩" : "↩"
        case .togglePreview: "space"
        case .copyOnly: "⌘C"
        case .togglePin: "⌘P"
        case .deleteSelected: "⌫"
        case .focusSearch, .typeToSearch: "⌘F"
        case .escape: "esc"
        case .saveToFolder: "⌘S"
        case .previousScope, .nextScope: "⌘[ ]"
        case .setFilter: "⌥1–6"
        default: nil
        }
        guard let key else { return .none }
        state.flashHintKey = key
        return .run { send in
            try await clock.sleep(for: .milliseconds(280))
            await send(.hintFlashExpired, animation: .smooth)
        }
        .cancellable(id: CancelID.hintFlash, cancelInFlight: true)
    }
}
