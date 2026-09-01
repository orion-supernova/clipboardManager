//
//  BlobStore.swift
//  clipboardManager
//
//  Files live in Application Support (inside the sandbox container), never in
//  the temporary directory, so items survive relaunches. Images are stored once
//  as PNG plus a small thumbnail that is the only thing the list ever decodes.
//

import AppKit
import Foundation
import OSLog
import QuickLookThumbnailing
import UniformTypeIdentifiers

struct BlobStore: Sendable {
    private static let logger = Logger(subsystem: "com.walhallaa.clipboardManager", category: "BlobStore")

    let imagesDirectory: URL
    let thumbnailsDirectory: URL

    init(root: URL? = nil) {
        let base = root ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "ClipboardData", directoryHint: .isDirectory)
        imagesDirectory = base.appending(path: "Images", directoryHint: .isDirectory)
        thumbnailsDirectory = base.appending(path: "Thumbnails", directoryHint: .isDirectory)
        for directory in [imagesDirectory, thumbnailsDirectory] {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    func imageURL(for name: String) -> URL { imagesDirectory.appending(path: name) }
    func thumbnailURL(for name: String) -> URL { thumbnailsDirectory.appending(path: name) }

    struct StoredImage: Sendable {
        var imageName: String
        var thumbnailName: String?
        var pixelSize: PixelSize
        var byteCount: Int64
    }

    /// Normalises to PNG, writes it, and derives a thumbnail from the encoded bytes.
    func storeImage(_ data: Data, id: UUID) throws -> StoredImage? {
        try autoreleasepool {
            guard let encoded = ImageCoding.normalizeToPNG(data) else { return nil }
            let imageName = "\(id.uuidString).png"
            try encoded.png.write(to: imageURL(for: imageName), options: .atomic)
            let thumbnailName = writeThumbnail(from: encoded.png, id: id)
            return StoredImage(
                imageName: imageName,
                thumbnailName: thumbnailName,
                pixelSize: encoded.pixelSize,
                byteCount: Int64(encoded.png.count)
            )
        }
    }

    private func writeThumbnail(from png: Data, id: UUID) -> String? {
        guard let thumb = ImageCoding.thumbnail(from: png, maxPixelSize: PanelMetrics.thumbnailMaxPixelSize),
              let thumbData = ImageCoding.encodePNG(thumb)
        else { return nil }
        let name = "\(id.uuidString).png"
        do {
            try thumbData.write(to: thumbnailURL(for: name), options: .atomic)
            return name
        } catch {
            Self.logger.error("Thumbnail write failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Quick Look thumbnail for any file (PDF, documents, videos, images…).
    func storeFileThumbnail(for fileURL: URL, id: UUID) async -> String? {
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: CGSize(width: 320, height: 320),
            scale: 2,
            representationTypes: .thumbnail
        )
        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            guard let data = ImageCoding.encodePNG(representation.cgImage) else { return nil }
            let name = "\(id.uuidString).png"
            try data.write(to: thumbnailURL(for: name), options: .atomic)
            return name
        } catch {
            Self.logger.debug("Quick Look thumbnail unavailable for \(fileURL.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    /// Writes already-encoded PNG bytes into the thumbnails directory.
    func writeThumbnail(_ data: Data, name: String) -> String? {
        do {
            try data.write(to: thumbnailURL(for: name), options: .atomic)
            return name
        } catch {
            Self.logger.error("Thumbnail write failed: \(error.localizedDescription)")
            return nil
        }
    }

    func remove(imageName: String?, thumbnailName: String?) {
        if let imageName { try? FileManager.default.removeItem(at: imageURL(for: imageName)) }
        if let thumbnailName { try? FileManager.default.removeItem(at: thumbnailURL(for: thumbnailName)) }
    }

    func removeAll() {
        for directory in [imagesDirectory, thumbnailsDirectory] {
            let contents = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            for url in contents { try? FileManager.default.removeItem(at: url) }
        }
    }

    /// Deletes files no row references any more (e.g. after a crash mid-delete).
    func removeOrphans(keepingImages images: Set<String>, thumbnails: Set<String>) {
        let fm = FileManager.default
        for url in (try? fm.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil)) ?? []
        where !images.contains(url.lastPathComponent) {
            try? fm.removeItem(at: url)
        }
        for url in (try? fm.contentsOfDirectory(at: thumbnailsDirectory, includingPropertiesForKeys: nil)) ?? []
        where !thumbnails.contains(url.lastPathComponent) {
            try? fm.removeItem(at: url)
        }
    }

    var footprint: Int64 {
        let fm = FileManager.default
        var total: Int64 = 0
        for directory in [imagesDirectory, thumbnailsDirectory] {
            let urls = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            for url in urls {
                total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
        }
        return total
    }
}
