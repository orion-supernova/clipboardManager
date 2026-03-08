//
//  ClipboardViewModel.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 08.03.2026.
//

import SwiftUI
import AppKit
import Combine
import CoreData

@MainActor
final class ClipboardViewModel: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
    @Published var items: [ClipboardEntry] = []
    @Published var isSearchFieldVisible: Bool = false
    @Published var searchText: String = ""

    private let repository: ClipboardRepository
    private let clipboardService: ClipboardService
    private let settings: SettingsStore
    private var cancellables = Set<AnyCancellable>()
    private var frc: NSFetchedResultsController<ClipboardEntity>?

    init(repository: ClipboardRepository, clipboardService: ClipboardService, settings: SettingsStore) {
        self.repository = repository
        self.clipboardService = clipboardService
        self.settings = settings
        super.init()
        bindSettings()
        setupFetchedResultsController()
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
                self?.refreshFromController()
            }
            .store(in: &cancellables)
    }

    private func setupFetchedResultsController(predicate: NSPredicate? = nil) {
        frc = repository.makeFetchedResultsController(predicate: predicate)
        frc?.delegate = self
        do {
            try frc?.performFetch()
            refreshFromController()
        } catch {
            print("FRC fetch error: \(error)")
        }
    }

    private func refreshFromController() {
        let objects = frc?.fetchedObjects ?? []
        items = objects.map { $0.toClipboardEntry() }
        NotificationCenter.default.post(name: .pasteBoardCountNotification, object: items.count)
    }

    func refresh() {
        refreshFromController()
    }

    func search(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            setupFetchedResultsController(predicate: nil)
        } else {
            let predicate = NSPredicate(format: "contentDescriptionString CONTAINS[c] %@", trimmed)
            setupFetchedResultsController(predicate: predicate)
        }
    }

    func clearAll() {
        repository.clearAll()
        refreshFromController()
    }

    func selectItem(_ item: ClipboardEntry) {
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(item.contentDescriptionString, forType: .string)
        NotificationCenter.default.post(name: .textSelectedFromClipboardNotification, object: item)
    }

    func updateRetainCount() {
        repository.trimRetainCount(settings.retainCount)
        refreshFromController()
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        refreshFromController()
    }
}
