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
        
        // Create a unique filename while preserving the original filename
        let originalFilename = url.lastPathComponent
        let uniqueFilename = "\(UUID().uuidString)-\(originalFilename)"
        var tempURL = tempDirectory.appendingPathComponent(uniqueFilename)
        
        if utType.conforms(to: .image) {
            // For images, create an optimized copy
            if let image = NSImage(contentsOf: url) {
                return autoreleasepool { () -> (URL?, ClipboardItemType, Data?)? in
                    if let optimizedData = image.optimizedData(maxSize: CGSize(width: 1200, height: 1200)) {
                        try? optimizedData.write(to: tempURL)
                        return (tempURL, ClipboardItemType.image, nil as Data?)
                    }
                    return nil
                }
            }
        } else if utType.conforms(to: .movie) {
            do {
                try fileManager.copyItem(at: url, to: tempURL)
                return (tempURL, ClipboardItemType.video, nil as Data?)
            } catch {
                print("[ERROR] Failed to copy video file: \(error)")
                return nil
            }
        } else {
            // Handle any other file type
            do {
                // Copy the file with its metadata
                try fileManager.copyItem(at: url, to: tempURL)
                
                // Preserve file attributes
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                try fileManager.setAttributes(attributes, ofItemAtPath: tempURL.path)
                
                print("[DEBUG] Copied file: \(originalFilename) to \(tempURL.path)")
                return (tempURL, ClipboardItemType.file, nil as Data?)
            } catch {
                print("[ERROR] Failed to copy file: \(error)")
                return nil
            }
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

// Add these helper extensions
private extension NSImage {
    func optimizedData(maxSize: CGSize) -> Data? {
        return autoreleasepool { () -> Data? in
            let resized = self.resized(to: maxSize)
            guard let tiffData = resized.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else {
                return nil
            }
            
            return bitmap.representation(using: .png, properties: [
                .compressionFactor: 0.7,
                .interlaced: false
            ])
        }
    }
    
    func resized(to maxSize: CGSize) -> NSImage {
        let ratio = min(maxSize.width / size.width, maxSize.height / size.height, 1)
        let newSize = NSSize(width: size.width * ratio, height: size.height * ratio)
        
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: newSize),
             from: NSRect(origin: .zero, size: size),
             operation: .copy,
             fraction: 1.0)
        newImage.unlockFocus()
        
        return newImage
    }
}

