//
//  ItemPreviewViews.swift
//  clipboardManager
//
//  Per-kind card bodies. They render only what the light item carries, plus a
//  cached thumbnail — never the full payload. Text colouring is memoised.
//

import ComposableArchitecture
import SwiftUI

struct ItemPreviewView: View {
    let item: ClipboardItem
    let thumbnailURL: URL?
    var iconURL: URL?
    var highlight: String = ""
    var sensitiveLifetime: TimeInterval?

    var body: some View {
        if let sensitivity = item.sensitivity {
            SensitivePreview(item: item, kind: sensitivity, lifetime: sensitiveLifetime)
        } else {
            switch item.kind {
            case .text: TextPreview(id: item.id, text: item.preview, language: item.codeLanguage, highlight: highlight)
            case .url: LinkPreview(item: item, heroURL: thumbnailURL, iconURL: iconURL, highlight: highlight)
            case .color: ColorPreview(hex: item.preview)
            case .image: ImagePreview(thumbnailURL: thumbnailURL, recognizedText: item.preview, highlight: highlight)
            case .file, .video: FilePreview(item: item, thumbnailURL: thumbnailURL)
            }
        }
    }
}

private struct TextPreview: View {
    let id: UUID
    let text: String
    let language: CodeLanguage?
    let highlight: String

    var body: some View {
        Group {
            if text.isEmpty {
                Text("Empty text").foregroundStyle(.secondary)
            } else {
                Text(AttributedTextCache.preview(id: id, text: text, language: language, highlight: highlight))
                    .font(language != nil ? .system(.callout, design: .monospaced) : .system(.callout))
            }
        }
        .lineLimit(8)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .textSelection(.disabled)
    }
}

private struct SensitivePreview: View {
    let item: ClipboardItem
    let kind: SensitiveKind
    let lifetime: TimeInterval?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                    .frame(width: 24, height: 24)
                    .background(.red.opacity(0.14), in: .circle)
                Text("Masked · ⌘E reveals")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(item.preview)
                .font(.system(kind == .creditCard || kind == .iban ? .title3 : .callout, design: .monospaced).weight(.semibold))
                .lineLimit(kind == .creditCard || kind == .iban ? 2 : 5)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            if let lifetime {
                let expiry = item.timestamp.addingTimeInterval(lifetime)
                Label {
                    Text("Forgets \(expiry, format: .relative(presentation: .named, unitsStyle: .abbreviated))")
                } icon: {
                    Image(systemName: "timer")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct LinkPreview: View {
    let item: ClipboardItem
    let heroURL: URL?
    let iconURL: URL?
    let highlight: String

    var body: some View {
        let url = URL(string: item.preview)
        VStack(alignment: .leading, spacing: 8) {
            if let heroURL {
                ThumbnailImage(url: heroURL, placeholderSymbol: "photo", contentMode: .fill)
                    .frame(height: 92)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.08), lineWidth: 1))
                    .transition(.opacity)
            }
            HStack(alignment: .top, spacing: 8) {
                Group {
                    if let iconURL {
                        ThumbnailImage(url: iconURL, placeholderSymbol: "globe")
                            .clipShape(.rect(cornerRadius: 5))
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.tint)
                    }
                }
                .frame(width: heroURL == nil ? 28 : 20, height: heroURL == nil ? 28 : 20)
                .padding(heroURL == nil ? 4 : 0)
                .background(heroURL == nil ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(Highlighter.attributed(item.linkTitle ?? url?.host() ?? "Link", matching: highlight))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(heroURL == nil ? 3 : 2)
                    Text(url?.host() ?? item.preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            if heroURL == nil {
                Text(item.preview)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .animation(.easeOut(duration: 0.25), value: heroURL)
        .animation(.easeOut(duration: 0.25), value: item.linkTitle)
    }
}

private struct ColorPreview: View {
    let hex: String

    var body: some View {
        let parsed = ParsedColor.parse(hex)
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(parsed?.swiftUIColor ?? .gray)
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                }
            Text(hex.uppercased())
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .foregroundStyle((parsed?.isLight ?? false) ? .black : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.black.opacity((parsed?.isLight ?? false) ? 0.08 : 0.25), in: .capsule)
        }
    }
}

private struct ImagePreview: View {
    let thumbnailURL: URL?
    let recognizedText: String
    let highlight: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ThumbnailImage(url: thumbnailURL, placeholderSymbol: "photo")
                .clipShape(.rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                }
            if !recognizedText.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "text.viewfinder")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text(Highlighter.attributed(recognizedText, matching: highlight))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: recognizedText.isEmpty)
    }
}

private struct FilePreview: View {
    let item: ClipboardItem
    let thumbnailURL: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                if let thumbnailURL {
                    ThumbnailImage(url: thumbnailURL, placeholderSymbol: item.kind.symbolName)
                        .clipShape(.rect(cornerRadius: 8))
                } else {
                    FileIconView(path: item.filePath)
                }
            }
            .frame(width: 84, height: 84)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileName ?? item.preview)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .truncationMode(.middle)
                if let folder = item.parentFolderPath {
                    Label(folder, systemImage: "folder")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.head)
                }
                if !item.isFileAvailable {
                    Label("Original file not found", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Async image helpers

struct ThumbnailImage: View {
    let url: URL?
    var placeholderSymbol: String = "photo"
    var contentMode: ContentMode = .fit
    @Dependency(\.imageLoader) private var loader
    @Environment(\.staticImages) private var staticImages
    @State private var image: CGImage?

    private var resolved: CGImage? { image ?? url.flatMap { staticImages[$0.path] } }

    var body: some View {
        ZStack {
            if let resolved {
                Image(decorative: resolved, scale: 2)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            } else {
                Image(systemName: placeholderSymbol)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: resolved == nil)
        .task(id: url) {
            guard let url, staticImages[url.path] == nil else { return }
            image = await loader.thumbnail(url)
        }
    }
}

struct AppIconView: View {
    let source: SourceApp
    @Dependency(\.imageLoader) private var loader
    @Environment(\.staticImages) private var staticImages
    @State private var image: CGImage?

    private var resolved: CGImage? { image ?? staticImages["app:" + (source.bundleID ?? source.name)] }

    var body: some View {
        ZStack {
            if let resolved {
                Image(decorative: resolved, scale: 2)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.dashed")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .task(id: source) {
            guard staticImages["app:" + (source.bundleID ?? source.name)] == nil else { return }
            image = await loader.appIcon(source)
        }
    }
}

private struct FileIconView: View {
    let path: String?

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 64, height: 64)
    }

    private var icon: NSImage {
        if let path { return NSWorkspace.shared.icon(forFile: path) }
        return NSWorkspace.shared.icon(for: .data)
    }
}
