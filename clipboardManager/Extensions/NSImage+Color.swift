//
//  NSImage+Color.swift
//  clipboardManager
//
//  Created by muratcankoc on 02/08/2024.
//

import AppKit
import CoreImage

extension NSImage {
    func dominantColor() -> NSColor {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .clear
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height
        
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return .clear
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else {
            return .clear
        }
        
        let data = pixelData.bindMemory(to: UInt8.self, capacity: totalPixels * 4)
        
        var colorCounts: [Int: Int] = [:]
        let samplingInterval = max(1, totalPixels / 10000) // Sample at most 10,000 pixels
        
        for i in stride(from: 0, to: totalPixels * 4, by: samplingInterval * 4) {
            let red = Int(data[i])
            let green = Int(data[i + 1])
            let blue = Int(data[i + 2])
            
            // Skip fully transparent or very dark pixels
            guard red + green + blue > 20 else { continue }
            
            let color = (red << 16) | (green << 8) | blue
            colorCounts[color, default: 0] += 1
        }
        
        let dominantColorInt = colorCounts.max(by: { $0.value < $1.value })?.key ?? 0
        
        let red = CGFloat((dominantColorInt >> 16) & 0xFF) / 255.0
        let green = CGFloat((dominantColorInt >> 8) & 0xFF) / 255.0
        let blue = CGFloat(dominantColorInt & 0xFF) / 255.0
        
        return NSColor(red: red, green: green, blue: blue, alpha: 1.0)
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
}
