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
    private let supportedImageTypes = ["public.image", "public.png", "public.jpeg", "public.tiff"]
    private let supportedVideoTypes = ["public.movie", "public.video", "com.apple.quicktime-movie"]
    private let tempDirectory: URL
    
    private init() {
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent("ClipboardCache")
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    func handlePasteboardItem(_ pasteboard: NSPasteboard) -> (url: URL?, type: ClipboardItemType, content: Data?)? {
            // First check for raw image data
            if let pngData = pasteboard.data(forType: .png) {
                return (nil, .image, pngData)
            } else if let tiffData = pasteboard.data(forType: .tiff) {
                if let image = NSImage(data: tiffData),
                   let pngData = image.pngRepresentation() {
                    return (nil, .image, pngData)
                }
            }
            
            // Then check for file URLs
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
               let url = urls.first {
                return handleFileURL(url)
            }
            
            return nil
        }
        
        private func handleFileURL(_ url: URL) -> (url: URL?, type: ClipboardItemType, content: Data?)? {
            // Get UTType of file
            guard let uti = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
                  let utType = UTType(uti) else { return nil }
            
            if utType.conforms(to: .image) {
                // For images, load the actual content
                if let imageData = try? Data(contentsOf: url) {
                    return (url, .image, imageData)
                }
            } else if utType.conforms(to: .movie) {
                return (url, .video, nil)
            } else if utType.conforms(to: .archive) || utType.conforms(to: .data) {
                return (url, .file, nil)
            }
            
            return nil
        }
    
    private func handleData(_ data: Data, type: NSPasteboard.PasteboardType) -> (url: URL?, type: ClipboardItemType)? {
        let tempURL = tempDirectory.appendingPathComponent(UUID().uuidString)
        
        if type == .tiff || type == .png {
            let fileURL = tempURL.appendingPathExtension("png")
            try? data.write(to: fileURL)
            return (fileURL, .image)
        } else if type.rawValue.contains("video") {
            let fileURL = tempURL.appendingPathExtension("mov")
            try? data.write(to: fileURL)
            return (fileURL, .video)
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

// Add this helper extension
private extension NSImage {
    func pngRepresentation() -> Data? {
        guard let tiffRepresentation = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}

