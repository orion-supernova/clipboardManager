//
//  ImageLoaderClient.swift
//  clipboardManager
//
//  Decodes thumbnails, larger previews and app icons off the main thread into a
//  cost-bounded `NSCache`, so scrolling never decodes and memory stays capped.
//

import AppKit
import ComposableArchitecture
import Foundation

struct ImageLoaderClient: Sendable {
    /// Card-sized decode of a file (thumbnails or the stored PNG).
    var thumbnail: @Sendable (URL) async -> CGImage?
    /// Decode bounded by `maxPixelSize`, used by the quick preview.
    var image: @Sendable (URL, Int) async -> CGImage?
    var appIcon: @Sendable (SourceApp) async -> CGImage?
}

extension ImageLoaderClient: DependencyKey {
    static let liveValue: ImageLoaderClient = {
        let cache = ImageCache()

        @Sendable func decode(_ url: URL, maxPixelSize: Int) async -> CGImage? {
            let key = "\(url.path)@\(maxPixelSize)"
            if let hit = cache.image(for: key) { return hit }
            let decoded = await Task.detached(priority: .userInitiated) {
                ImageCoding.thumbnail(fromFileAt: url, maxPixelSize: maxPixelSize)
            }.value
            if let decoded { cache.store(decoded, for: key) }
            return decoded
        }

        return ImageLoaderClient(
            thumbnail: { url in await decode(url, maxPixelSize: PanelMetrics.thumbnailMaxPixelSize) },
            image: { url, size in await decode(url, maxPixelSize: size) },
            appIcon: { app in
                let key = "app:" + (app.bundleID ?? app.name)
                if let hit = cache.image(for: key) { return hit }
                let icon = await MainActor.run { () -> CGImage? in
                    let workspace = NSWorkspace.shared
                    let image: NSImage
                    if let bundleID = app.bundleID, let url = workspace.urlForApplication(withBundleIdentifier: bundleID) {
                        image = workspace.icon(forFile: url.path)
                    } else {
                        image = workspace.icon(for: .application)
                    }
                    var rect = CGRect(x: 0, y: 0, width: 64, height: 64)
                    return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
                }
                if let icon { cache.store(icon, for: key) }
                return icon
            }
        )
    }()

    static let previewValue = ImageLoaderClient(thumbnail: { _ in nil }, image: { _, _ in nil }, appIcon: { _ in nil })
}

private final class ImageCache: @unchecked Sendable {
    private final class Box { let image: CGImage; init(_ image: CGImage) { self.image = image } }
    private let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.totalCostLimit = 64 * 1024 * 1024
        cache.countLimit = 500
        return cache
    }()

    func image(for key: String) -> CGImage? { cache.object(forKey: key as NSString)?.image }

    func store(_ image: CGImage, for key: String) {
        cache.setObject(Box(image), forKey: key as NSString, cost: image.bytesPerRow * image.height)
    }
}

extension DependencyValues {
    var imageLoader: ImageLoaderClient {
        get { self[ImageLoaderClient.self] }
        set { self[ImageLoaderClient.self] = newValue }
    }
}
