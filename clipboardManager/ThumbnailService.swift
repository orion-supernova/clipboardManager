//
//  ThumbnailService.swift
//  clipboardManager
//
//  Created by muratcankoc on 08/11/2024.
//

import AppKit

//public class ThumbnailService {
//    public static let shared = ThumbnailService()
//    private let thumbnailSize = NSSize(width: 180, height: 180)
//    private let cache = NSCache<NSString, NSImage>()
//    
//    private init() {
//        cache.countLimit = 50 // Limit cache size
//    }
//    
//    public func generateThumbnail(from data: Data) -> NSImage? {
//        let cacheKey = String(data.prefix(512).hashValue) as NSString
//        
//        // Check cache first
//        if let cachedImage = cache.object(forKey: cacheKey) {
//            return cachedImage
//        }
//        
//        return autoreleasepool { () -> NSImage? in
//            guard let source = NSImage(data: data) else { return nil }
//            
//            // Create thumbnail
//            let thumbnail = NSImage(size: thumbnailSize)
//            thumbnail.lockFocus()
//            
//            NSGraphicsContext.current?.imageInterpolation = .high
//            source.draw(in: NSRect(origin: .zero, size: thumbnailSize),
//                       from: NSRect(origin: .zero, size: source.size),
//                       operation: .copy,
//                       fraction: 1.0)
//            
//            thumbnail.unlockFocus()
//            
//            // Cache the thumbnail
//            cache.setObject(thumbnail, forKey: cacheKey)
//            
//            return thumbnail
//        }
//    }
//    
//    public func clearCache() {
//        cache.removeAllObjects()
//    }
//}
