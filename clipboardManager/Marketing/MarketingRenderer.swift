//
//  MarketingRenderer.swift
//  clipboardManager
//
//  DEBUG-only. Renders the real panel views with sample data to PNG stills and
//  animated GIFs (via ImageIO). Liquid Glass can't be sampled offline, so the
//  views draw a frosted stand-in (see `PanelGlass`). Triggered by
//  MAHMUT_RENDER_MARKETING=1; output lands in the app's tmp/marketing folder.
//

#if DEBUG
import AppKit
import ComposableArchitecture
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

@MainActor
enum MarketingRenderer {
    struct Still {
        var name: String
        var size: CGSize
        var scale: CGFloat
        var view: AnyView
    }

    struct Frame {
        var view: AnyView
        var delay: Double
    }

    struct Animation {
        var name: String
        var size: CGSize
        var frames: [Frame]
    }

    static func renderAll(to directory: URL) async {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scenes = MarketingScenes()
        var manifest: [String] = []
        for still in scenes.stills() {
            if write(still, to: directory) { manifest.append("\(still.name).png  \(Int(still.size.width * still.scale))×\(Int(still.size.height * still.scale))") }
        }
        for animation in scenes.animations() {
            if writeGIF(animation, to: directory) { manifest.append("\(animation.name).gif  \(Int(animation.size.width))×\(Int(animation.size.height))  \(animation.frames.count) frames") }
        }
        try? manifest.joined(separator: "\n").write(to: directory.appending(path: "manifest.txt"), atomically: true, encoding: .utf8)
    }

    private static func write(_ still: Still, to directory: URL) -> Bool {
        guard let image = render(still.view, size: still.size, scale: still.scale),
              let data = ImageCoding.encodePNG(image)
        else { return false }
        do {
            try data.write(to: directory.appending(path: still.name + ".png"), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static func writeGIF(_ animation: Animation, to directory: URL) -> Bool {
        let url = directory.appending(path: animation.name + ".gif")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, animation.frames.count, nil) else {
            return false
        }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in animation.frames {
            guard let image = render(frame.view, size: animation.size, scale: 1) else { continue }
            let properties = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: frame.delay,
                    kCGImagePropertyGIFUnclampedDelayTime: frame.delay,
                ],
            ] as CFDictionary
            CGImageDestinationAddImage(destination, image, properties)
        }
        return CGImageDestinationFinalize(destination)
    }

    private static func render(_ view: AnyView, size: CGSize, scale: CGFloat) -> CGImage? {
        withDependencies {
            $0.clipboardStore = MarketingScenes.storeClient
            $0.imageLoader = .previewValue
        } operation: {
            let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
            renderer.proposedSize = ProposedViewSize(size)
            renderer.scale = scale
            renderer.isOpaque = true
            return renderer.cgImage
        }
    }
}
#endif
