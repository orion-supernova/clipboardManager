//
//  ClipboardRepository.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 08.03.2026.
//

import CoreData
import Foundation

@MainActor
final class ClipboardRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func makeFetchedResultsController(predicate: NSPredicate? = nil) -> NSFetchedResultsController<ClipboardEntity> {
        let request: NSFetchRequest<ClipboardEntity> = ClipboardEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.predicate = predicate
        return NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }

    func fetchAll() -> [ClipboardEntry] {
        let request: NSFetchRequest<ClipboardEntity> = ClipboardEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        let results = (try? context.fetch(request)) ?? []
        return results.map { $0.toClipboardEntry() }
    }

    func search(_ text: String) -> [ClipboardEntry] {
        guard !text.isEmpty else { return fetchAll() }
        let request: NSFetchRequest<ClipboardEntity> = ClipboardEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.predicate = NSPredicate(format: "contentDescriptionString CONTAINS[c] %@", text)
        let results = (try? context.fetch(request)) ?? []
        return results.map { $0.toClipboardEntry() }
    }

    func add(_ entry: ClipboardEntry) {
        let newItem = ClipboardEntity(context: context)
        newItem.id = entry.id
        newItem.content = entry.content
        newItem.timestamp = entry.timestamp
        newItem.type = entry.type.rawValue
        newItem.contentDescriptionString = entry.contentDescriptionString

        if let title = entry.copiedFromApplicationTitle,
           let pid = entry.copiedFromApplicationPID {
            let app = CopiedFromApplication(applicationTitle: title, applicationProcessIdentifier: pid)
            newItem.copiedFromApplication = try? app.toData()
        } else {
            newItem.copiedFromApplication = nil
        }

        save()
    }

    func delete(_ entry: ClipboardEntry) {
        let request: NSFetchRequest<ClipboardEntity> = ClipboardEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
        if let entity = try? context.fetch(request).first {
            context.delete(entity)
            save()
        }
    }

    func clearAll() {
        let fetch: NSFetchRequest<NSFetchRequestResult> = ClipboardEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetch)
        _ = try? context.execute(deleteRequest)
        save()
    }

    func count() -> Int {
        let request: NSFetchRequest<ClipboardEntity> = ClipboardEntity.fetchRequest()
        return (try? context.count(for: request)) ?? 0
    }

    func trimRetainCount(_ retainCount: Int) {
        guard retainCount != -1 else { return }
        let request: NSFetchRequest<ClipboardEntity> = ClipboardEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        if let results = try? context.fetch(request), results.count > retainCount {
            let itemsToDelete = Array(results[retainCount...])
            itemsToDelete.forEach { context.delete($0) }
            save()
        }
    }

    func removeItemsOlderThan(hours: Int) {
        guard hours > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        let request: NSFetchRequest<ClipboardEntity> = ClipboardEntity.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp < %@", cutoff as NSDate)
        if let results = try? context.fetch(request) {
            results.forEach { context.delete($0) }
            save()
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            print("CoreData save error: \(error)")
        }
    }
}
