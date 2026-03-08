//
//  LegacyCoreDataMigrator.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 08.03.2026.
//

import CoreData
import Foundation

@MainActor
final class LegacyCoreDataMigrator {
    private static let migrationKey = "swiftdata_migration_complete"

    static func migrateIfNeeded(into repository: ClipboardRepository) {
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return
        }

        let container = NSPersistentContainer(name: "ClipboardModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Legacy CoreData store load failed: \(error)")
                return
            }
        }

        let context = container.viewContext
        let fetch = NSFetchRequest<NSManagedObject>(entityName: "ClipboardEntity")
        fetch.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            let results = try context.fetch(fetch)
            guard !results.isEmpty else {
                UserDefaults.standard.set(true, forKey: migrationKey)
                return
            }

            for item in results {
                let content = item.value(forKey: "content") as? Data ?? Data()
                let contentDescription = item.value(forKey: "contentDescriptionString") as? String ?? ""
                let timestamp = item.value(forKey: "timestamp") as? Date ?? Date()
                let typeRaw = item.value(forKey: "type") as? String ?? ClipboardItemType.text.rawValue
                let type = ClipboardItemType(rawValue: typeRaw) ?? .text

                var appTitle: String? = nil
                var appPID: Int32? = nil
                if let appData = item.value(forKey: "copiedFromApplication") as? Data,
                   let copiedApp = try? CopiedFromApplication.fromData(appData) {
                    appTitle = copiedApp.applicationTitle
                    appPID = copiedApp.applicationProcessIdentifier
                }

                let entry = ClipboardEntry(
                    type: type,
                    content: content,
                    contentDescriptionString: contentDescription,
                    timestamp: timestamp,
                    copiedFromApplicationTitle: appTitle,
                    copiedFromApplicationPID: appPID
                )
                repository.add(entry)
            }

            UserDefaults.standard.set(true, forKey: migrationKey)
        } catch {
            print("Legacy migration failed: \(error)")
        }
    }
}
