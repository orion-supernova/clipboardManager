//
//  ClipboardManager.swift
//  clipboardManager
//
//  Created by muratcankoc on 23/07/2024.
//

import CoreData
import SwiftUI
import AppKit
import AVFoundation

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager(persistenceController: .shared) // Singleton instance

    // MARK: - Properties
    @Published private(set) var clipboardItems: [String: ClipboardItem] = [:]
    @Published private(set) var itemOrder: [String] = []
    @Published var isSearchFieldVisible = false
    @Published var launchAtLogin: Bool!
    @Published var retainCount: Int!
    @Published var clearItemsOlderThanHours: Int!
    
    private let persistenceController: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
    private var lastItemContentDescriptionString = ""
    var initCount = 0
    private var pasteboardTimer: Timer?
    private var cleanupTimer: Timer?
    private var isProcessingClipboard = false
    private var updatesPaused = false
    private var fetchDebouncer: Timer?
    private var lastFetchTime: Date = .distantPast
    private let minimumFetchInterval: TimeInterval = 0.3

    // MARK: - Lifecycle
    private init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        setDefaultValuesIfNeeded()
        removeExtraItemsIfNeeded()
        
        print("[DEBUG] Initializing ClipboardManager")
        
        // Setup initial state
        fetchClipboardItems()
        
        // Start monitoring clipboard
        DispatchQueue.main.async { [weak self] in
            self?.setupTimer()
            self?.setupCleanupTimer()
        }
        
        initCount += 1
    }

    // MARK: - Private Methods
    private func setupTimer() {
        pasteboardTimer?.invalidate()
        
        let pasteboard = NSPasteboard.general
        var changeCount = pasteboard.changeCount
        
        print("[DEBUG] Setting up clipboard monitoring timer")
        
        pasteboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self,
                  !self.isProcessingClipboard else { return }
            
            // Check if pasteboard has changed
            guard pasteboard.changeCount != changeCount else { return }
            
            // Set processing flag
            self.isProcessingClipboard = true
            
            autoreleasepool {
                print("[DEBUG] Pasteboard change detected: \(pasteboard.changeCount) (was \(changeCount))")
                changeCount = pasteboard.changeCount
                
                // Get the new content immediately
                if let newItem = self.createClipboardItem() {
                    if newItem.contentDescriptionString != self.lastItemContentDescriptionString {
                        // Use background context for saving
                        let backgroundContext = self.persistenceController.container.newBackgroundContext()
                        backgroundContext.perform {
                            self.addClipboardItem(newItem, in: backgroundContext)
                            self.lastItemContentDescriptionString = newItem.contentDescriptionString
                        }
                    }
                }
                
                // Reset processing flag
                self.isProcessingClipboard = false
            }
        }
        
        RunLoop.main.add(pasteboardTimer!, forMode: .common)
    }
    private func setDefaultValuesIfNeeded() {
        if let hm = UserDefaults.standard.value(forKey: .launchAtLoginUserDefaultsKey) {
            launchAtLogin = hm as? Bool ?? false
        } else {
            UserDefaults.standard.set(false, forKey: .clearItemsOlderThanHoursUserDefaultsKey)
        }
        if let hm2 = UserDefaults.standard.value(forKey: .retainCountUserDefaultsKey) {
            retainCount = hm2 as? Int ?? -1
        } else {
            UserDefaults.standard.set(20, forKey: .retainCountUserDefaultsKey)
        }
        if let hm3 = UserDefaults.standard.value(forKey: .clearItemsOlderThanHoursUserDefaultsKey) {
            clearItemsOlderThanHours = hm3 as? Int ?? 48
        } else {
            UserDefaults.standard.set(48, forKey: .clearItemsOlderThanHoursUserDefaultsKey)
        }
    }
    private func removeExtraItemsIfNeeded() {
        guard retainCount != -1 else { return }
        
        let fetchRequest: NSFetchRequest<ClipboardEntity> = ClipboardEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        viewContext.perform { [weak self] in
            guard let self = self else { return }
            do {
                let allItems = try self.viewContext.fetch(fetchRequest)
                if allItems.count > self.retainCount {
                    let itemsToDelete = Array(allItems[self.retainCount...])
                    
                    // Batch delete instead of individual deletes
                    let objectIDs = itemsToDelete.map { $0.objectID }
                    let batchDelete = NSBatchDeleteRequest(objectIDs: objectIDs)
                    
                    try self.viewContext.execute(batchDelete)
                    try self.viewContext.save()
                }
            } catch {
                print("Failed to remove extra items: \(error)")
            }
        }
    }

    // MARK: - Create Item
    private func createClipboardItem() -> ClipboardItem? {
        return autoreleasepool { () -> ClipboardItem? in
            let pasteboard = NSPasteboard.general
            let contentDescription = pasteboard.string(forType: .string) ?? ""
            let copiedFromApp = getCopiedFromApplication()
            
            // Capture all pasteboard items
            var pasteboardItems: [(NSPasteboard.PasteboardType, Data)] = []
            for type in pasteboard.types ?? [] {
                if let data = pasteboard.data(forType: type) {
                    pasteboardItems.append((type, data))
                }
            }
            
            // Handle file-based items and images
            if let (fileURL, type, content) = FileHandler.shared.handlePasteboardItem(pasteboard) {
                var thumbnailURL: URL? = nil
                
                if type == .video, let url = fileURL {
                    thumbnailURL = generateVideoThumbnail(from: url)
                }
                
                let finalDescription = fileURL?.lastPathComponent ?? contentDescription
                
                return ClipboardItem(
                    id: UUID(),
                    type: type,
                    content: content ?? Data(),
                    copiedFromApplication: copiedFromApp,
                    timestamp: Date(),
                    contentDescriptionString: finalDescription,
                    fileURL: fileURL,
                    thumbnailURL: thumbnailURL,
                    pasteboardItems: pasteboardItems
                )
            }
            
            // Handle other types
            let type = getClipboardItemType()
            var content = Data()
            
            switch type {
            case .text, .url, .color:
                if let data = pasteboard.data(forType: .string) {
                    content = data
                }
            default:
                return nil
            }
            
            return ClipboardItem(
                id: UUID(),
                type: type,
                content: content,
                copiedFromApplication: copiedFromApp,
                timestamp: Date(),
                contentDescriptionString: contentDescription,
                fileURL: nil,
                thumbnailURL: nil,
                pasteboardItems: pasteboardItems
            )
        }
    }

    private func generateVideoThumbnail(from url: URL) -> URL? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let time = CMTime(seconds: 1, preferredTimescale: 1)  // Take thumbnail at 1 second
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: 180, height: 180))
            
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("thumbnails")
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("png")
            
            try? FileManager.default.createDirectory(
                at: tempURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            if let data = thumbnail.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: data),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try pngData.write(to: tempURL)
                print("[DEBUG] Successfully wrote thumbnail to: \(tempURL)")
                return tempURL
            }
        } catch {
            print("[ERROR] Failed to generate video thumbnail: \(error)")
        }
        
        return nil
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
    private func addClipboardItem(_ item: ClipboardItem, in context: NSManagedObjectContext) {
        print("[DEBUG] Adding clipboard item to CoreData")
        
        let key = item.contentDescriptionString
        
        // Check if item already exists
        if clipboardItems[key] != nil {
            // Move existing item to front
            moveItemToFront(key)
            return
        }
        
        let newItem = ClipboardEntity(context: context)
        newItem.id = item.id
        newItem.content = item.content
        newItem.timestamp = item.timestamp
        newItem.type = item.type.rawValue
        newItem.copiedFromApplication = try? item.copiedFromApplication.toData()
        newItem.contentDescriptionString = item.contentDescriptionString
        newItem.fileURL = item.fileURL
        newItem.thumbnailURL = item.thumbnailURL
        
        // Encode pasteboardItems
        do {
            let itemsToArchive = item.pasteboardItems.map { type, data in
                ["type": type.rawValue, "data": data]
            }
            let archivedData = try NSKeyedArchiver.archivedData(
                withRootObject: itemsToArchive,
                requiringSecureCoding: true
            )
            newItem.setValue(archivedData, forKey: "pasteboardItemsData")
        } catch {
            print("Error encoding pasteboard items: \(error)")
        }
        
        do {
            try context.save()
            print("[DEBUG] Successfully saved clipboard item")
            
            DispatchQueue.main.async { [weak self] in
                self?.fetchClipboardItems()
            }
        } catch {
            print("[ERROR] Failed to save clipboard item: \(error)")
            context.rollback()
        }
    }

    // Add helper methods for duplicate checking
    private func findDuplicateItem(for newItem: ClipboardItem) -> ClipboardItem? {
        return orderedItems.first { item in
            switch newItem.type {
            case .file, .video:
                return item.fileURL == newItem.fileURL
            case .text, .url:
                return item.content == newItem.content
            case .image:
                return item.content == newItem.content
            case .color:
                return item.content == newItem.content
            }
        }
    }

    private func moveItemToFront(_ contentDescription: String) {
        guard clipboardItems[contentDescription] != nil else { return }
        
        // Remove from current position
        itemOrder.removeAll { $0 == contentDescription }
        // Add to front
        itemOrder.insert(contentDescription, at: 0)
        
        // Update Core Data order
        updateItemOrder()
    }

    private func updateItemOrder() {
        let backgroundContext = persistenceController.container.newBackgroundContext()
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            // Update timestamps to reflect new order
            for (index, key) in self.itemOrder.enumerated() {
                let request: NSFetchRequest<ClipboardEntity> = ClipboardEntity.fetchRequest()
                request.predicate = NSPredicate(format: "contentDescriptionString == %@", key)
                
                do {
                    if let entity = try backgroundContext.fetch(request).first {
                        // Use current time plus index to maintain order
                        entity.timestamp = Date().addingTimeInterval(Double(-index))
                    }
                } catch {
                    print("Error updating item order: \(error)")
                }
            }
            
            try? backgroundContext.save()
        }
    }

    // MARK: - Fetch All Items
    func fetchClipboardItems() {
        // Cancel any pending fetch
        fetchDebouncer?.invalidate()
        
        // Check if we're within the minimum interval
        let now = Date()
        if now.timeIntervalSince(lastFetchTime) < minimumFetchInterval {
            // Schedule a delayed fetch
            fetchDebouncer = Timer.scheduledTimer(withTimeInterval: minimumFetchInterval, repeats: false) { [weak self] _ in
                self?.performFetch()
            }
            return
        }
        
        performFetch()
    }
    
    private func performFetch() {
        // Update last fetch time
        lastFetchTime = Date()
        
        let request: NSFetchRequest<ClipboardEntity> = ClipboardEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipboardEntity.timestamp, ascending: false)
        ]
        
        let backgroundContext = persistenceController.container.newBackgroundContext()
        backgroundContext.perform { [weak self] in
            autoreleasepool {
                do {
                    let results = try backgroundContext.fetch(request)
                    var newItems: [String: ClipboardItem] = [:]
                    var newOrder: [String] = []
                    
                    for entity in results {
                        let item = self?.mapEntityToClipboardItem(entity)
                        if let item = item {
                            let key = item.contentDescriptionString
                            newItems[key] = item
                            if !newOrder.contains(key) {
                                newOrder.append(key)
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self?.clipboardItems = newItems
                        self?.itemOrder = newOrder
                        NotificationCenter.default.post(
                            name: .pasteBoardCountNotification,
                            object: newOrder.count
                        )
                    }
                    
                    backgroundContext.reset()
                } catch {
                    print("Error fetching clipboard items: \(error)")
                }
            }
        }
    }

    // Add a helper method to map entities
    private func mapEntityToClipboardItem(_ entity: ClipboardEntity) -> ClipboardItem {
        let id = entity.id ?? UUID()
        let typeRawValue = entity.type ?? ClipboardItemType.text.rawValue
        let content = entity.content ?? Data()
        let timestamp = entity.timestamp ?? Date()
        let contentDescriptionString = entity.contentDescriptionString ?? "Unknown"
        let fileURL = entity.fileURL
        let thumbnailURL = entity.thumbnailURL

        let type = ClipboardItemType(rawValue: typeRawValue) ?? .text

        let copiedFromApp: CopiedFromApplication
        do {
            copiedFromApp = try CopiedFromApplication.fromData(
                entity.copiedFromApplication ?? Data())
        } catch {
            copiedFromApp = CopiedFromApplication(
                withApplication: NSRunningApplication())
        }
        
        // Decode pasteboardItems with nil check
        var pasteboardItems: [(NSPasteboard.PasteboardType, Data)] = []
        if let itemsData = entity.value(forKey: "pasteboardItemsData") as? Data {
            do {
                let decoded = try NSKeyedUnarchiver.unarchivedObject(
                    ofClasses: [NSArray.self, NSString.self, NSData.self],
                    from: itemsData
                ) as? [[String: Any]]
                
                pasteboardItems = decoded?.compactMap {
                    guard let typeString = $0["type"] as? String,
                          let data = $0["data"] as? Data else { return nil }
                    return (NSPasteboard.PasteboardType(typeString), data)
                } ?? []
            } catch {
                print("Error decoding pasteboard items: \(error)")
            }
        }

        return ClipboardItem(
            id: id,
            type: type,
            content: content,
            copiedFromApplication: copiedFromApp,
            timestamp: timestamp,
            contentDescriptionString: contentDescriptionString,
            fileURL: fileURL,
            thumbnailURL: thumbnailURL,
            pasteboardItems: pasteboardItems
        )
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
            var newItems: [String: ClipboardItem] = [:]
            var newOrder: [String] = []
            
            for entity in results {
                let item = mapEntityToClipboardItem(entity)
                let key = item.contentDescriptionString
                newItems[key] = item
                if !newOrder.contains(key) {
                    newOrder.append(key)
                }
            }
            
            clipboardItems = newItems
            itemOrder = newOrder
            
            NotificationCenter.default.post(
                name: .pasteBoardCountNotification,
                object: newOrder.count)
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

    // MARK: - Delete Item
    func deleteClipboardItem(withId id: UUID) {
        let request: NSFetchRequest<ClipboardEntity> = ClipboardEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try viewContext.fetch(request)
            if let itemToDelete = results.first {
                let contentDescription = itemToDelete.contentDescriptionString ?? ""
                viewContext.delete(itemToDelete)
                try viewContext.save()
                
                // Remove from dictionary and order array
                clipboardItems.removeValue(forKey: contentDescription)
                itemOrder.removeAll { $0 == contentDescription }
                
                // Post notification to update count
                NotificationCenter.default.post(
                    name: .pasteBoardCountNotification,
                    object: clipboardItems.count
                )
            }
        } catch {
            print("Error deleting clipboard item: \(error)")
        }
    }

    // MARK: - Cleanup
    func cleanup() {
        // Invalidate timers
        pasteboardTimer?.invalidate()
        pasteboardTimer = nil
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        
        // Clear data
        autoreleasepool {
            // Reset all contexts
            viewContext.reset()
            persistenceController.container.viewContext.reset()
            
            // Clear temporary data
            clearTemporaryData()
            
            // Clear array
            clipboardItems.removeAll()
            
            // Reset other properties
            lastItemContentDescriptionString = ""
            isProcessingClipboard = false
            
            // Clear thumbnail cache
//            ThumbnailService.shared.clearCache()
        }
    }

    // Add this method
    private func cleanupOldItems() {
        guard clearItemsOlderThanHours > 0 else { return }
        
        let fetchRequest: NSFetchRequest<ClipboardEntity> = ClipboardEntity.fetchRequest()
        let cutoffDate = Date().addingTimeInterval(-Double(clearItemsOlderThanHours) * 3600)
        fetchRequest.predicate = NSPredicate(format: "timestamp < %@", cutoffDate as NSDate)
        
        viewContext.perform { [weak self] in
            guard let self = self else { return }
            do {
                let oldItems = try self.viewContext.fetch(fetchRequest)
                let batchDelete = NSBatchDeleteRequest(objectIDs: oldItems.map { $0.objectID })
                try self.viewContext.execute(batchDelete)
                try self.viewContext.save()
            } catch {
                print("Failed to cleanup old items: \(error)")
            }
        }
    }

    private func setupCleanupTimer() {
        cleanupTimer?.invalidate()
        
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.performMemoryCleanup()
            
            // Clear thumbnail cache periodically
            if let count = self?.clipboardItems.count, count > 20 {
//                ThumbnailService.shared.clearCache()
            }
        }
        RunLoop.main.add(cleanupTimer!, forMode: .common)
    }

    private func performMemoryCleanup() {
        autoreleasepool {
            // Reset the view context
            viewContext.reset()
            
            // Create a new background context for cleanup
            let backgroundContext = persistenceController.container.newBackgroundContext()
            backgroundContext.perform { [weak self] in
                autoreleasepool {
                    self?.cleanupOldItems()
                    self?.removeExtraItemsIfNeeded()
                }
                backgroundContext.reset()
            }
            
            // Clear temporary files
            FileHandler.shared.cleanupOldFiles()
        }
    }

    private func clearTemporaryData() {
        autoreleasepool {
            // Don't reset the view context, just refresh it
            viewContext.refreshAllObjects()
            
            // Suggest memory cleanup to the system
            #if DEBUG
            print("Requesting memory cleanup")
            #endif
            
            // Force a memory cleanup using Swift-friendly approach
            autoreleasepool {
                if #available(macOS 10.13, *) {
                    Task { @MainActor in
                        await Task.yield()
                    }
                }
            }
        }
    }

    func handleMemoryWarning() {
        autoreleasepool {
            viewContext.refreshAllObjects()
            clearTemporaryData()
            
            let request: NSFetchRequest<ClipboardEntity> = ClipboardEntity.fetchRequest()
            request.fetchLimit = 20
            request.fetchBatchSize = 5
            
            let backgroundContext = persistenceController.container.newBackgroundContext()
            backgroundContext.perform { [weak self] in
                guard let self = self else { return }
                
                autoreleasepool {
                    do {
                        let results = try backgroundContext.fetch(request)
                        var newItems: [String: ClipboardItem] = [:]
                        var newOrder: [String] = []
                        
                        for entity in results {
                            let item = self.mapEntityToClipboardItem(entity)
                            let key = item.contentDescriptionString
                            newItems[key] = item
                            if !newOrder.contains(key) {
                                newOrder.append(key)
                            }
                        }
                        
                        DispatchQueue.main.async {
                            self.clipboardItems = newItems
                            self.itemOrder = newOrder
                        }
                    } catch {
                        print("Error handling memory warning: \(error)")
                    }
                    
                    backgroundContext.reset()
                }
            }
        }
    }

    // Add this helper method
    private func compressImageData(_ image: NSImage) -> Data? {
        return autoreleasepool { () -> Data? in
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else {
                return nil
            }
            
            // Resize if image is too large
            let maxDimension: CGFloat = 1200
            if image.size.width > maxDimension || image.size.height > maxDimension {
                let scale = maxDimension / max(image.size.width, image.size.height)
                bitmap.size = NSSize(
                    width: image.size.width * scale,
                    height: image.size.height * scale
                )
            }
            
            return bitmap.representation(using: .png, properties: [
                .compressionFactor: 0.7
            ])
        }
    }

    // Add this helper method near other private methods
    private func basicClipboardItem(copiedFromApp: CopiedFromApplication, description: String) -> ClipboardItem {
        return ClipboardItem(
            id: UUID(),
            type: .text,
            content: Data(),
            copiedFromApplication: copiedFromApp,
            timestamp: Date(),
            contentDescriptionString: description,
            fileURL: nil,
            thumbnailURL: nil,
            pasteboardItems: []  // Empty array since this is just a basic item
        )
    }

    // Add a method to get ordered items
    var orderedItems: [ClipboardItem] {
        return itemOrder.compactMap { clipboardItems[$0] }
    }

    func pauseUpdates() {
        updatesPaused = true
        pasteboardTimer?.invalidate()
        cleanupTimer?.invalidate()
        fetchDebouncer?.invalidate()
    }
    
    func resumeUpdates() {
        updatesPaused = false
        setupTimer()
        setupCleanupTimer()
    }

    // Modify the visibility handling
    private func handleVisibilityChange(isVisible: Bool) {
        if isVisible {
            resumeUpdates()
        } else {
            pauseUpdates()
        }
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}
