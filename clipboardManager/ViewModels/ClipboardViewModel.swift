//
//  ClipboardViewModel.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 08.03.2026.
//

import SwiftUI
import AppKit
import Combine

@MainActor
final class ClipboardViewModel: ObservableObject {
    @Published var items: [ClipboardEntry] = []
    @Published var isSearchFieldVisible: Bool = false
    @Published var searchText: String = ""

    private let repository: ClipboardRepository
    private let clipboardService: ClipboardService
    private let settings: SettingsStore
    private var cancellables = Set<AnyCancellable>()

    init(repository: ClipboardRepository, clipboardService: ClipboardService, settings: SettingsStore) {
        self.repository = repository
        self.clipboardService = clipboardService
        self.settings = settings
        bindSettings()
        refresh()
        clipboardService.startMonitoring()
    }

    private func bindSettings() {
        settings.$retainCount
            .sink { [weak self] _ in
                self?.updateRetainCount()
            }
            .store(in: &cancellables)

        settings.$clearItemsOlderThanHours
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .refreshClipboardItems)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.items = self?.repository.fetchAll() ?? []
            }
            .store(in: &cancellables)
    }

    func refresh() {
        items = repository.fetchAll()
        NotificationCenter.default.post(name: .pasteBoardCountNotification, object: items.count)
    }

    func search(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            items = repository.fetchAll()
        } else {
            items = repository.search(trimmed)
        }
    }

    func clearAll() {
        repository.clearAll()
        items.removeAll()
        NotificationCenter.default.post(name: .pasteBoardCountNotification, object: 0)
    }

    func selectItem(_ item: ClipboardEntry) {
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(item.contentDescriptionString, forType: .string)
        NotificationCenter.default.post(name: .textSelectedFromClipboardNotification, object: item)
    }

    func updateRetainCount() {
        repository.trimRetainCount(settings.retainCount)
        refresh()
    }
}
