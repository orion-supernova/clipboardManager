//
//  ClipboardManager.swift
//  clipboardManager
//
//  Created by muratcankoc on 23/07/2024.
//

import CoreData
import SwiftUI

class ClipboardManager: ObservableObject {
    // MARK: - Properties
    @Published var clipboardItems: [ClipboardItem] = []
    @Published var isSearchFieldVisible = false
    @Published var retainCount: Int = 50
    @Published var launchAtLogin: Bool = false
    @Published var clearOlderItemsInHours: Int = 48
    
    private let persistenceController: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
    private var lastItemContentDescriptionString = ""

    // MARK: - Lifecycle
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        fetchClipboardItems()  // Load existing items
        setupTimer()
    }

    // MARK: - Private Methods
    private func setupTimer() {
        let pasteboard = NSPasteboard.general
        var changeCount = NSPasteboard.general.changeCount

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard pasteboard.changeCount != changeCount else { return }

            changeCount = pasteboard.changeCount
            print(changeCount)

            let newItem = self.createClipboardItem()
            //            guard newItem?.content != clipboardItems.first?.content else { return }
            guard newItem?.contentDescriptionString != lastItemContentDescriptionString else {
                return
            }
            print("Last Item Description: \(lastItemContentDescriptionString)")
            print("New Item Description: \(newItem?.contentDescriptionString)")
            print("2", changeCount)
            self.addClipboardItem(
                newItem
                    ?? .init(
                        id: UUID(), type: .text, content: Data(),
                        copiedFromApplication: .init(withApplication: NSRunningApplication()),
                        timestamp: Date(), contentDescriptionString: "#error#"))
        }
    }

    // MARK: - Create Item
    private func createClipboardItem() -> ClipboardItem? {
        let pasteboard = NSPasteboard.general
        let type = getClipboardItemType()

        let content: Data
        let copiedFromApp = getCopiedFromApplication()
        let contentDescription = pasteboard.string(forType: .string) ?? ""

        let basicClipboardItem = ClipboardItem(
            id: UUID(), type: .text, content: contentDescription.data(using: .utf8) ?? Data(),
            copiedFromApplication: copiedFromApp, timestamp: Date(),
            contentDescriptionString: contentDescription)

        switch type {
        case .text:
            if let string = pasteboard.string(forType: .string) {
                content = Data(string.utf8)
            } else {
                return basicClipboardItem
            }
        case .image:
            if let pngData = pasteboard.data(forType: .png) {
                content = pngData
            } else if let tiffData = pasteboard.data(forType: .tiff) {
                content = tiffData
            } else if let jpegData = pasteboard.data(
                forType: NSPasteboard.PasteboardType("public.jpeg"))
            {
                content = jpegData
            } else if let fileURLs = pasteboard.propertyList(forType: .fileURL) as? [String],
                let firstURL = fileURLs.first,
                let imageData = try? Data(contentsOf: URL(fileURLWithPath: firstURL))
            {
                content = imageData
            } else {
                return basicClipboardItem
            }
        case .url:
            if let url = pasteboard.string(forType: .URL), let urlData = url.data(using: .utf8) {
                content = urlData
            } else {
                return basicClipboardItem
            }
        case .color:
            if let color = detectColor(from: pasteboard.string(forType: .string) ?? "") {
                do {
                    content = try NSKeyedArchiver.archivedData(
                        withRootObject: color, requiringSecureCoding: true)
                } catch {
                    return basicClipboardItem
                }
            } else {
                return basicClipboardItem
            }
        }

        return ClipboardItem(
            id: UUID(),
            type: type,
            content: content,
            copiedFromApplication: copiedFromApp,
            timestamp: Date(),
            contentDescriptionString: contentDescription
        )
    }

    private func getCopiedFromApplication() -> CopiedFromApplication {
        guard let tempApplication = NSWorkspace().frontmostApplication else {
            let emptyApp = NSRunningApplication()
            return CopiedFromApplication(withApplication: emptyApp)
        }
        let application = CopiedFromApplication(withApplication: tempApplication)
        print("[DEBUG] copied from \(application.applicationTitle ?? "Unknown"))")
        return application
    }

    private func getClipboardItemType() -> ClipboardItemType {
        let pasteboard = NSPasteboard.general

        if pasteboard.canReadObject(forClasses: [NSColor.self], options: nil) {
            return .color
        }

        if detectColor(from: pasteboard.string(forType: .string) ?? "") != nil {
            return .color
        }

        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) {
            return .image
        }

        if pasteboard.canReadObject(forClasses: [NSURL.self], options: nil) {
            return .url
        }

        return .text
    }

    // MARK: - Add Item
    func addClipboardItem(_ item: ClipboardItem) {
        let newItem = ClipboardEntity(context: viewContext)
        newItem.id = item.id
        newItem.content = item.content
        newItem.timestamp = item.timestamp
        newItem.type = item.type.rawValue
        newItem.copiedFromApplication = try? item.copiedFromApplication.toData()
        newItem.contentDescriptionString = item.contentDescriptionString

        do {
            try viewContext.save()
            fetchClipboardItems()
        } catch {
            print("Error saving context: \(error)")
        }
    }

    // MARK: - Fetch All Items
    func fetchClipboardItems() {
        let request: NSFetchRequest<ClipboardEntity> = ClipboardEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipboardEntity.timestamp, ascending: false)
        ]

        do {
            let results = try viewContext.fetch(request)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                clipboardItems = results.map { entity in
                    let id = entity.id ?? UUID()  // Provide a default UUID if nil
                    let typeRawValue = entity.type ?? ClipboardItemType.text.rawValue  // Default to .text if nil
                    let content = entity.content ?? Data()  // Default to empty Data if nil
                    let timestamp = entity.timestamp ?? Date()  // Default to current date if nil
                    let contentDescriptionString = entity.contentDescriptionString ?? "Unknown"  // Default to "Unknown" if nil

                    let type = ClipboardItemType(rawValue: typeRawValue) ?? .text

                    let copiedFromApp: CopiedFromApplication
                    do {
                        copiedFromApp = try CopiedFromApplication.fromData(
                            entity.copiedFromApplication ?? Data())
                    } catch {
                        print("Error decoding copiedFromApplication: \(error)")
                        copiedFromApp = CopiedFromApplication(
                            withApplication: NSRunningApplication())  // Provide a default value
                    }

                    return ClipboardItem(
                        id: id,
                        type: type,
                        content: content,
                        copiedFromApplication: copiedFromApp,
                        timestamp: timestamp,
                        contentDescriptionString: contentDescriptionString
                    )
                }

                NotificationCenter.default.post(
                    name: .pasteBoardCountNotification, object: results.count)
            }
        } catch {
            print("Error fetching clipboard items: \(error)")
        }
    }

    // MARK: - Fetch Searched Items
    func fetchClipboardItems(withSearchText searchText: String) {
        let request: NSFetchRequest<ClipboardEntity> = ClipboardEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipboardEntity.timestamp, ascending: false)
        ]

        let predicate = NSPredicate(format: "contentDescriptionString CONTAINS[c] %@", searchText)
        request.predicate = predicate

        do {
            let results = try viewContext.fetch(request)
            clipboardItems = results.map { entity in
                let id = entity.id ?? UUID()  // Provide a default UUID if nil
                let typeRawValue = entity.type ?? ClipboardItemType.text.rawValue  // Default to .text if nil
                let content = entity.content ?? Data()  // Default to empty Data if nil
                let timestamp = entity.timestamp ?? Date()  // Default to current date if nil
                let contentDescriptionString = entity.contentDescriptionString ?? "Unknown"  // Default to "Unknown" if nil

                let type = ClipboardItemType(rawValue: typeRawValue) ?? .text

                let copiedFromApp: CopiedFromApplication
                do {
                    copiedFromApp = try CopiedFromApplication.fromData(
                        entity.copiedFromApplication ?? Data())
                } catch {
                    print("Error decoding copiedFromApplication: \(error)")
                    copiedFromApp = CopiedFromApplication(withApplication: NSRunningApplication())  // Provide a default value
                }

                return ClipboardItem(
                    id: id,
                    type: type,
                    content: content,
                    copiedFromApplication: copiedFromApp,
                    timestamp: timestamp,
                    contentDescriptionString: contentDescriptionString
                )
            }
            NotificationCenter.default.post(
                name: .pasteBoardCountNotification, object: results.count)
        } catch {
            print("Error fetching clipboard items: \(error)")
        }
    }

    // MARK: - Clear All Items
    func clearAllItems() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
            entityName: "ClipboardEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try viewContext.execute(deleteRequest)
            try viewContext.save()
            clipboardItems.removeAll()
        } catch {
            print("Failed to clear items: \(error)")
        }
    }
}
