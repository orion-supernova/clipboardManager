//
//  PersistenceController.swift
//  clipboardManager
//
//  Owns the Core Data stack. The store is opened once, migrated automatically
//  (v1 → v2 is purely additive, so lightweight migration applies) and, if it is
//  irrecoverably corrupt, rebuilt instead of crashing the app in a loop.
//

import CoreData
import Foundation
import OSLog

final class PersistenceController: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.walhallaa.clipboardManager", category: "Persistence")

    let container: NSPersistentContainer
    private let loadTask: Task<NSManagedObjectContext, any Error>
    /// One long-lived background context; every operation is serialized through `perform`.
    /// Only valid after `ready()` has returned, which every caller awaits first.
    nonisolated(unsafe) private var loadedContext: NSManagedObjectContext?
    var context: NSManagedObjectContext { loadedContext! }

    init(inMemory: Bool = false) {
        let container = NSPersistentContainer(name: "ClipboardModel")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        for description in container.persistentStoreDescriptions {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            description.shouldAddStoreAsynchronously = false
        }
        self.container = container
        loadTask = Task.detached(priority: .userInitiated) {
            try await Self.load(container)
            let context = container.newBackgroundContext()
            context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            context.undoManager = nil
            return context
        }
    }

    /// Suspends until the persistent store is available.
    func ready() async throws {
        let context = try await loadTask.value
        if loadedContext == nil { loadedContext = context }
    }

    private static func load(_ container: NSPersistentContainer) async throws {
        do {
            try await loadStores(container)
        } catch {
            logger.error("Store failed to load (\(error.localizedDescription)); rebuilding.")
            guard let description = container.persistentStoreDescriptions.first, let url = description.url else { throw error }
            try? container.persistentStoreCoordinator.destroyPersistentStore(at: url, type: .sqlite, options: nil)
            try await loadStores(container)
        }
    }

    private static func loadStores(_ container: NSPersistentContainer) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            container.loadPersistentStores { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    var storeFileSize: Int64 {
        guard let url = container.persistentStoreDescriptions.first?.url else { return 0 }
        // Core Data names the sidecars "ClipboardModel.sqlite-wal" / "-shm".
        let candidates = [url.path, url.path + "-wal", url.path + "-shm"]
        return candidates.reduce(into: Int64(0)) { total, path in
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
            total += size
        }
    }
}
