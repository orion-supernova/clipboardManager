//
//  ClipboardRepository.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 08.03.2026.
//

import SwiftData
import Foundation

@MainActor
final class ClipboardRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() -> [ClipboardEntry] {
        let descriptor = FetchDescriptor<ClipboardEntry>(
            sortBy: [SortDescriptor(\ClipboardEntry.timestamp, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func search(_ text: String) -> [ClipboardEntry] {
        guard !text.isEmpty else { return fetchAll() }
        let lowered = text.lowercased()
        let predicate = #Predicate<ClipboardEntry> { entry in
            entry.contentDescriptionString.lowercased().contains(lowered)
        }
        let descriptor = FetchDescriptor<ClipboardEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\ClipboardEntry.timestamp, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func add(_ entry: ClipboardEntry) {
        context.insert(entry)
        save()
    }

    func delete(_ entry: ClipboardEntry) {
        context.delete(entry)
        save()
    }

    func clearAll() {
        let items = fetchAll()
        items.forEach { context.delete($0) }
        save()
    }

    func count() -> Int {
        let descriptor = FetchDescriptor<ClipboardEntry>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func trimRetainCount(_ retainCount: Int) {
        guard retainCount != -1 else { return }
        let items = fetchAll()
        guard items.count > retainCount else { return }
        let extra = items.suffix(from: retainCount)
        extra.forEach { context.delete($0) }
        save()
    }

    func removeItemsOlderThan(hours: Int) {
        guard hours > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        let predicate = #Predicate<ClipboardEntry> { entry in
            entry.timestamp < cutoff
        }
        let descriptor = FetchDescriptor<ClipboardEntry>(predicate: predicate)
        let items = (try? context.fetch(descriptor)) ?? []
        items.forEach { context.delete($0) }
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            print("SwiftData save error: \(error)")
        }
    }
}
