//
//  ImageCoding.swift
//  clipboardManager
//
//  Memory-frugal image helpers built on ImageIO. Thumbnails are produced from
//  the encoded source without decoding the full bitmap.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageCoding {
    struct Encoded: Sendable {
        var png: Data
        var pixelSize: PixelSize
    }

    static func pixelSize(of source: CGImageSource) -> PixelSize? {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return PixelSize(width: w, height: h)
    }

    /// Normalises arbitrary image data to PNG. PNG input is passed through untouched.
    static func normalizeToPNG(_ data: Data) -> Encoded? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let size = pixelSize(of: source)
        else { return nil }
        if let type = CGImageSourceGetType(source), UTType(type as String) == .png {
            return Encoded(png: data, pixelSize: size)
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary),
              let png = encodePNG(image)
        else { return nil }
        return Encoded(png: png, pixelSize: size)
    }

    static func encodePNG(_ image: CGImage) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    static func thumbnail(from data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return thumbnail(from: source, maxPixelSize: maxPixelSize)
    }

    static func thumbnail(fromFileAt url: URL, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return thumbnail(from: source, maxPixelSize: maxPixelSize)
    }

    private static func thumbnail(from source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func decode(fileAt url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }
}
