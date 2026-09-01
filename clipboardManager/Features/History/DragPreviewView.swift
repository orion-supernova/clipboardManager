//
//  DragPreviewView.swift
//  clipboardManager
//
//  The little card that travels with the cursor while dragging an item out.
//  Rendered once per drag with `ImageRenderer`; deliberately opaque (no glass),
//  since drag images are composited by the window server, not by SwiftUI.
//

import AppKit
import SwiftUI

struct DragPreviewView: View {
    let item: ClipboardItem
    let thumbnail: CGImage?
    let isDark: Bool

    private var foreground: Color { isDark ? .white : .black }
    private var secondary: Color { foreground.opacity(0.6) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: item.kind.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(item.kind.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(foreground)
                Spacer(minLength: 0)
                Text(meta)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(secondary)
            }
            content
        }
        .padding(12)
        .frame(width: 220, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isDark ? Color(white: 0.16) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(foreground.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 10, y: 5)
        .padding(16)
    }

    private var meta: String {
        switch item.kind {
        case .text: Formatting.characterCount(Int(item.byteCount))
        case .url: URL(string: item.preview)?.host() ?? ""
        case .color: ""
        case .image: item.pixelSize?.label ?? ""
        case .file, .video: Formatting.bytes(item.byteCount)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text:
            Text(item.preview)
                .font(TextClassifier.looksLikeCode(item.preview) ? .system(.caption, design: .monospaced) : .caption)
                .foregroundStyle(foreground)
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .url:
            VStack(alignment: .leading, spacing: 3) {
                Label(URL(string: item.preview)?.host() ?? "Link", systemImage: "globe")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(foreground)
                Text(item.preview)
                    .font(.caption2)
                    .foregroundStyle(secondary)
                    .lineLimit(2)
            }
        case .color:
            let parsed = ParsedColor.parse(item.preview)
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(parsed?.swiftUIColor ?? .gray)
                    .frame(width: 44, height: 44)
                Text(item.preview.uppercased())
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(foreground)
            }
        case .image:
            if let thumbnail {
                Image(decorative: thumbnail, scale: 2)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        case .file, .video:
            HStack(spacing: 10) {
                if let thumbnail {
                    Image(decorative: thumbnail, scale: 2)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.fileName ?? item.preview)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(foreground)
                        .lineLimit(2)
                    if let folder = item.parentFolderPath {
                        Text(folder)
                            .font(.caption2)
                            .foregroundStyle(secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }
            }
        }
    }
}

@MainActor
enum DragPreviewRenderer {
    static func image(for item: ClipboardItem, thumbnailURL: URL?) -> NSImage? {
        var thumbnail = thumbnailURL.flatMap { ImageCoding.thumbnail(fromFileAt: $0, maxPixelSize: 480) }
        if thumbnail == nil, item.kind.isFileBacked, let path = item.filePath {
            var rect = CGRect(x: 0, y: 0, width: 96, height: 96)
            thumbnail = NSWorkspace.shared.icon(forFile: path).cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let renderer = ImageRenderer(content: DragPreviewView(item: item, thumbnail: thumbnail, isDark: isDark))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        return renderer.nsImage
    }
}
