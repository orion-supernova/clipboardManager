//
//  FileHandler.swift
//  clipboardManager
//
//  Created by muratcankoc on 08/11/2024.
//

import AppKit
import UniformTypeIdentifiers
import AVFoundation

class FileHandler {
    static let shared = FileHandler()
    private let fileManager = FileManager.default
    private let tempDirectory: URL
    
    private init() {
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent("ClipboardCache")
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    func handlePasteboardItem(_ pasteboard: NSPasteboard) -> (url: URL?, type: ClipboardItemType, content: Data?)? {
        // Check for file URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first {  // Only handle the first file
            return handleFileURL(url)
        }
        
        // Handle image data if no files
        return handleImageData(from: pasteboard)
    }
    
    private func handleImageData(from pasteboard: NSPasteboard) -> (url: URL?, type: ClipboardItemType, content: Data?)? {
        // Create a temporary file for the image data
        let tempURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        
        if let image = NSImage(pasteboard: pasteboard) {
            // Resize and compress the image before saving
            return autoreleasepool { () -> (URL?, ClipboardItemType, Data?)? in
                if let optimizedData = image.optimizedData(maxSize: CGSize(width: 1200, height: 1200)) {
                    try? optimizedData.write(to: tempURL)
                    return (tempURL, ClipboardItemType.image, nil as Data?)
                }
                return nil
            }
        }
        
        return nil
    }
    
    private func handleFileURL(_ url: URL) -> (url: URL?, type: ClipboardItemType, content: Data?)? {
        guard let uti = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
              let utType = UTType(uti) else { return nil }
        
        if utType.conforms(to: .image) {
            // For images, we still want to optimize and store them
            if let image = NSImage(contentsOf: url) {
                return autoreleasepool { () -> (URL?, ClipboardItemType, Data?)? in
                    if let optimizedData = image.optimizedData(maxSize: CGSize(width: 1200, height: 1200)) {
                        let tempURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
                        try? optimizedData.write(to: tempURL)
                        return (tempURL, ClipboardItemType.image, nil as Data?)
                    }
                    return nil
                }
            }
        } else if utType.conforms(to: .movie) {
            // For videos, just store the original URL
            return (url, ClipboardItemType.video, nil as Data?)
        } else {
            // For other files, just store the original URL
            return (url, ClipboardItemType.file, nil as Data?)
        }
        
        return nil
    }
    
    func cleanupOldFiles() {
        let thirtyMinutesAgo = Date().addingTimeInterval(-1800)
        let resourceKeys: [URLResourceKey] = [.creationDateKey, .isDirectoryKey]
        
        guard let enumerator = fileManager.enumerator(
            at: tempDirectory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else { return }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                  let creationDate = resourceValues.creationDate,
                  !resourceValues.isDirectory! else { continue }
            
            if creationDate < thirtyMinutesAgo {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}

