//
//  CommandPalette.swift
//  clipboardManager
//
//  ⌘K: every panel action and folder, fuzzy-matched by name. The catalog is
//  built from current state so it only offers what would actually work now.
//

import SwiftUI

struct PaletteCommand: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case key(KeyCommand)
        case scope(HistoryScope)
        case saveTo(UUID)
        case smart(SmartAction)
    }

    let id: String
    let title: String
    let symbol: String
    var shortcut: String?
    /// Extra words that should find this command ("remove" finds Delete).
    var keywords = ""
    let kind: Kind
}

enum CommandCatalog {
    static func commands(for state: HistoryFeature.State) -> [PaletteCommand] {
        var commands: [PaletteCommand] = []

        if let item = state.selectedItem {
            commands += [
                .init(id: "paste", title: "Paste", symbol: "arrow.down.doc", shortcut: "↩", keywords: "insert", kind: .key(.confirm(plainText: false))),
                .init(id: "paste-plain", title: "Paste as Plain Text", symbol: "textformat", shortcut: "⇧↩", keywords: "unformatted", kind: .key(.confirm(plainText: true))),
                .init(id: "paste-as", title: "Paste As…", symbol: "wand.and.stars", shortcut: "⌘T", keywords: "transform uppercase lowercase case", kind: .key(.pasteAs)),
                .init(id: "copy", title: "Copy Without Pasting", symbol: "doc.on.doc", shortcut: "⌘C", kind: .key(.copyOnly)),
                .init(id: "pin", title: item.isPinned ? "Unpin" : "Pin", symbol: item.isPinned ? "pin.slash" : "pin", shortcut: "⌘P", keywords: "favorite keep", kind: .key(.togglePin)),
                .init(id: "preview", title: "Quick Look", symbol: "eye", shortcut: "space", keywords: "preview", kind: .key(.togglePreview)),
                .init(id: "save", title: "Save to Folder…", symbol: "folder.badge.plus", shortcut: "⌘S", keywords: "move", kind: .key(.saveToFolder)),
            ]
            for folder in state.folders where folder.id != item.folderID {
                commands.append(.init(id: "save-\(folder.id)", title: "Save to “\(folder.name)”", symbol: folder.symbol, keywords: "move folder", kind: .saveTo(folder.id)))
            }
            for action in item.smartActions where !item.isSensitive {
                commands.append(.init(
                    id: "smart-\(action.id)",
                    title: action.title,
                    symbol: action.symbol,
                    shortcut: action.isPrimary ? "⌘O" : nil,
                    keywords: "smart action",
                    kind: .smart(action)
                ))
            }
            if item.kind != .text, item.kind != .color {
                commands.append(.init(id: "open", title: "Open", symbol: "arrow.up.forward.app", shortcut: "⌘O", keywords: "launch browser", kind: .key(.open)))
            }
            if item.kind.isFileBacked || item.kind == .image {
                commands += [
                    .init(id: "finder", title: "Show in Finder", symbol: "folder", shortcut: "⇧⌘R", keywords: "reveal", kind: .key(.revealInFinder)),
                    .init(id: "path", title: "Copy Path", symbol: "link", shortcut: "⌥⌘C", kind: .key(.copyPath)),
                ]
            }
            if item.kind == .text {
                commands.append(.init(
                    id: "sensitive",
                    title: item.isSensitive ? "Not Sensitive" : "Mark as Sensitive",
                    symbol: item.isSensitive ? "lock.open" : "lock",
                    shortcut: "⌘L",
                    keywords: "password secret hide mask private",
                    kind: .key(.toggleSensitive)
                ))
            }
            if item.isSensitive {
                commands.append(.init(id: "reveal", title: "Reveal Hidden Value", symbol: "eye.slash", shortcut: "⌘E", keywords: "password secret show", kind: .key(.reveal)))
            }
            commands.append(.init(id: "delete", title: "Delete Item", symbol: "trash", shortcut: "⌫", keywords: "remove", kind: .key(.deleteSelected)))
        }

        commands.append(.init(id: "search", title: "Search", symbol: "magnifyingglass", shortcut: "⌘F", keywords: "find", kind: .key(.focusSearch)))

        let scopes = [(HistoryScope.history, "History", "clock")] + state.folders.map { (HistoryScope.folder($0.id), $0.name, $0.symbol) }
        for (index, scope) in scopes.enumerated() where scope.0 != state.activeScope {
            commands.append(.init(
                id: "go-\(index)-\(scope.1)",
                title: "Go to \(scope.1)",
                symbol: scope.2,
                shortcut: index < 9 ? "⌥⌘\(index + 1)" : nil,
                keywords: "folder switch open",
                kind: .scope(scope.0)
            ))
        }

        for (index, filter) in KindFilter.allCases.enumerated() where filter != state.kindFilter {
            commands.append(.init(id: "filter-\(filter.rawValue)", title: "Show \(filter.title)", symbol: filter.symbol, shortcut: "⌥\(index + 1)", keywords: "filter only", kind: .key(.setFilter(index))))
        }

        commands.append(.init(id: "new-folder", title: "New Folder…", symbol: "folder.badge.plus", shortcut: "⌘N", keywords: "create", kind: .key(.newFolder)))
        if state.currentFolder != nil {
            commands += [
                .init(id: "rename-folder", title: "Rename Folder…", symbol: "pencil", shortcut: "⌘R", kind: .key(.renameFolder)),
                .init(id: "delete-folder", title: "Delete Folder…", symbol: "trash", shortcut: "⌘⌫", keywords: "remove", kind: .key(.deleteFolder)),
            ]
        }
        commands += [
            .init(id: "pause", title: state.capturePaused ? "Resume Capturing" : "Pause Capturing", symbol: state.capturePaused ? "record.circle" : "pause.circle", shortcut: "⇧⌘P", keywords: "stop record history", kind: .key(.togglePause)),
            .init(id: "settings", title: "Settings", symbol: "gearshape", shortcut: "⌘,", keywords: "preferences options", kind: .key(.openSettings)),
            .init(id: "quit", title: "Quit Mahmut", symbol: "power", shortcut: "⌘Q", keywords: "exit", kind: .key(.quit)),
        ]
        return commands
    }

    /// Best matches first; ties keep catalog order, which puts item actions first.
    static func matching(_ query: String, in commands: [PaletteCommand]) -> [PaletteCommand] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return commands }
        return commands.enumerated()
            .compactMap { offset, command -> (Int, Int, PaletteCommand)? in
                let title = FuzzyMatch.score(query, in: command.title)
                let keywords = FuzzyMatch.score(query, in: command.keywords).map { $0 - 4 }
                guard let best = [title, keywords].compactMap({ $0 }).max() else { return nil }
                return (best, offset, command)
            }
            .sorted { $0.0 != $1.0 ? $0.0 > $1.0 : $0.1 < $1.1 }
            .map(\.2)
    }
}

enum FuzzyMatch {
    /// Characters of `query` must appear in order; word starts and runs score higher.
    /// "sf" finds "Save to Folder", "gtw" finds "Go to Work".
    static func score(_ query: String, in candidate: String) -> Int? {
        let needle = Array(query.lowercased().filter { !$0.isWhitespace })
        guard !needle.isEmpty else { return 0 }
        let haystack = Array(candidate.lowercased())
        var matched = 0
        var score = 0
        var previous = -2
        for (index, character) in haystack.enumerated() where matched < needle.count {
            guard character == needle[matched] else { continue }
            var points = 1
            if index == 0 || !haystack[index - 1].isLetter { points += 8 }
            if previous == index - 1 { points += 5 }
            score += points
            previous = index
            matched += 1
        }
        return matched == needle.count ? score - haystack.count / 8 : nil
    }
}

struct CommandPaletteView: View {
    @Binding var query: String
    let results: [PaletteCommand]
    let selection: Int
    let onRun: @MainActor (PaletteCommand) -> Void

    @FocusState private var fieldFocused: Bool
    private static let rowHeight: CGFloat = 30
    private static let visibleRows = 5

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "command")
                    .foregroundStyle(.tint)
                TextField("Type a command or folder…", text: $query)
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
                keycap("esc")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.primary.opacity(0.07), in: .rect(cornerRadius: 10))

            if results.isEmpty {
                Text("No matching commands")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.rowHeight * 2)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, command in
                                row(command, isSelected: index == selection)
                                    .id(command.id)
                                    .onTapGesture { onRun(command) }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .frame(height: Self.rowHeight * CGFloat(min(results.count, Self.visibleRows)))
                    .onChange(of: selection) { _, selection in
                        guard results.indices.contains(selection) else { return }
                        proxy.scrollTo(results[selection].id)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 460)
        .panelGlass(prominent: true, in: .rect(cornerRadius: PanelMetrics.cardCornerRadius))
        .shadow(color: .black.opacity(0.22), radius: 24, y: 12)
        .task {
            try? await Task.sleep(for: .milliseconds(60))
            fieldFocused = true
        }
    }

    private func row(_ command: PaletteCommand, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: command.symbol)
                .frame(width: 18)
                .foregroundStyle(isSelected ? Color.primary : Color.accentColor)
            Text(command.title)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let shortcut = command.shortcut { keycap(shortcut) }
        }
        .padding(.horizontal, 10)
        .frame(height: Self.rowHeight)
        .background(isSelected ? Color.accentColor.opacity(0.25) : .clear, in: .rect(cornerRadius: 8))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func keycap(_ key: String) -> some View {
        KeyCap(key: key).foregroundStyle(.secondary)
    }
}
