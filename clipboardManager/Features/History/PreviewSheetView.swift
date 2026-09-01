//
//  PreviewSheetView.swift
//  clipboardManager
//
//  The quick-preview sheet (Space). It sits above the toolbar so nothing else
//  moves when it opens. Shows full text (with code colouring), a large image
//  with any recognised text, a rich link card, color formats, or Quick Look.
//

import ComposableArchitecture
import Quartz
import SwiftUI

struct PreviewSheetView: View {
    let item: ClipboardItem
    let payload: ClipboardPayload?
    let revealed: Bool
    let thumbnailURL: URL?
    let iconURL: URL?
    let imageURL: URL?
    let onPaste: @MainActor () -> Void
    let onOpen: @MainActor () -> Void
    let onToggleReveal: @MainActor () -> Void
    let onCopyColor: @MainActor (ColorFormat) -> Void
    let onCopyText: @MainActor (String) -> Void
    let onClose: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            Divider()
                .opacity(0.4)
            body(for: item.kind)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .panelGlass(prominent: true, in: .rect(cornerRadius: PanelMetrics.cardCornerRadius))
        .padding(.horizontal, 10)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: item.headerSymbol)
                .font(.headline)
                .foregroundStyle(item.isSensitive ? Color.red : Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.isSensitive ? item.headerTitle : item.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    AppIconView(source: item.source).frame(width: 12, height: 12)
                    Text(item.source.name)
                    Text("·")
                    Text(item.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                    if let meta { Text("·"); Text(meta) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 12)
            if item.isSensitive {
                keyedButton(revealed ? "Hide" : "Reveal", symbol: revealed ? "eye.slash" : "eye", key: "⌘E", action: onToggleReveal)
                    .panelButtonStyle()
            }
            if item.kind.isFileBacked || item.kind == .url || item.kind == .image {
                keyedButton(item.kind == .url ? "Open Link" : "Open", symbol: "arrow.up.forward.app", key: "⌘O", action: onOpen)
                    .panelButtonStyle()
            }
            keyedButton("Paste", symbol: "arrow.down.doc", key: "↩", action: onPaste)
                .panelButtonStyle(prominent: true)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 26, height: 26)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .panelGlass(interactive: true, in: .circle)
            .help("Close (space / esc)")
        }
        .controlSize(.small)
    }

    private func keyedButton(_ title: String, symbol: String, key: String, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                Text(title)
                Text(key)
                    .font(.caption2.weight(.semibold).monospaced())
                    .opacity(0.6)
            }
        }
    }

    private var meta: String? {
        switch item.kind {
        case .text: payload?.text.map { Formatting.characterCount($0.count) } ?? Formatting.characterCount(Int(item.byteCount))
        case .image: item.pixelSize.map { "\($0.label) · \(Formatting.bytes(item.byteCount))" }
        case .file, .video: item.isFileAvailable ? Formatting.bytes(item.byteCount) : "Original file not found"
        default: nil
        }
    }

    @ViewBuilder
    private func body(for kind: ClipboardKind) -> some View {
        switch kind {
        case .text:
            if item.isSensitive, !revealed {
                MaskedBody(masked: item.preview, kind: item.sensitivity ?? .credential, detail: item.sensitivityDetail)
            } else {
                TextBody(id: item.id, text: payload?.text ?? item.preview, language: item.codeLanguage, isLoading: payload == nil)
            }
        case .url:
            LinkBody(
                urlString: payload?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? item.preview,
                title: item.linkTitle,
                heroURL: thumbnailURL,
                iconURL: iconURL
            )
        case .color:
            ColorBody(hex: item.preview, onCopy: onCopyColor)
        case .image:
            ImageBody(
                imageURL: imageURL ?? payload?.imageFileURL,
                fallbackThumbnailURL: thumbnailURL,
                recognizedText: payload?.text,
                onCopyText: onCopyText
            )
        case .file, .video:
            if item.isFileAvailable, let url = payload?.fileURL {
                QuickLookFilePreview(url: url, bookmark: payload?.bookmark)
                    .clipShape(.rect(cornerRadius: 14))
                    .padding(12)
            } else if payload == nil {
                ProgressView().controlSize(.small)
            } else {
                ContentUnavailableView("File not available", systemImage: "doc.questionmark", description: Text("The original file was moved or deleted."))
            }
        }
    }
}

// MARK: - Bodies

private struct TextBody: View {
    let id: UUID
    let text: String
    let language: CodeLanguage?
    let isLoading: Bool
    @Environment(\.marketingRender) private var marketingRender

    private var content: some View {
        Group {
            if let language {
                Text(CodeHighlighter.attributed(text, language: language))
                    .font(.system(.body, design: .monospaced))
            } else {
                Text(text)
                    .font(.body)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
    }

    var body: some View {
        Group {
            if marketingRender {
                // Scroll views don't render under ImageRenderer.
                content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).clipped()
            } else {
                ScrollView { content }
            }
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                if let language {
                    Text(language.displayName)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.tint.opacity(0.14), in: .capsule)
                }
                if isLoading {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(12)
        }
    }
}

private struct MaskedBody: View {
    let masked: String
    let kind: SensitiveKind
    let detail: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(.red)
            Text(masked)
                .font(.system(.title2, design: .monospaced).weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(4)
            Text("\(kind.title)\(detail.map { " · \($0)" } ?? "") — stored masked. Press ⌘E to reveal; Paste always inserts the real value.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LinkBody: View {
    let urlString: String
    let title: String?
    let heroURL: URL?
    let iconURL: URL?

    var body: some View {
        let url = URL(string: urlString)
        HStack(alignment: .top, spacing: 16) {
            if let heroURL {
                ThumbnailImage(url: heroURL, placeholderSymbol: "photo", contentMode: .fill)
                    .frame(width: 300)
                    .frame(maxHeight: .infinity)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.08), lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Group {
                        if let iconURL {
                            ThumbnailImage(url: iconURL, placeholderSymbol: "globe").clipShape(.rect(cornerRadius: 10))
                        } else {
                            Image(systemName: "globe").font(.system(size: 26)).foregroundStyle(.tint)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .background(.tint.opacity(iconURL == nil ? 0.12 : 0), in: .rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title ?? url?.host() ?? "Link").font(.title3.weight(.semibold)).lineLimit(3)
                        if let host = url?.host() {
                            Text(host).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }
                    }
                }
                Text(urlString)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                if let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let items = components.queryItems, !items.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Query").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(items.prefix(5), id: \.name) { query in
                            HStack(spacing: 6) {
                                Text(query.name).font(.caption.monospaced().weight(.semibold))
                                Text(query.value ?? "").font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(16)
    }
}

private struct ColorBody: View {
    let hex: String
    let onCopy: @MainActor (ColorFormat) -> Void

    var body: some View {
        let parsed = ParsedColor.parse(hex)
        HStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 18)
                .fill(parsed?.swiftUIColor ?? .gray)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.25)))
                .frame(width: 180)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(ColorFormat.allCases.enumerated()), id: \.element) { index, format in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.semibold).monospaced())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.primary.opacity(0.08), in: .rect(cornerRadius: 4))
                        Text(format.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 88, alignment: .leading)
                        Text(parsed.map(format.render) ?? "—")
                            .font(.callout.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                        Button {
                            onCopy(format)
                        } label: {
                            Image(systemName: "doc.on.doc").font(.caption)
                        }
                        .panelButtonStyle()
                        .controlSize(.mini)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }
}

private struct ImageBody: View {
    let imageURL: URL?
    let fallbackThumbnailURL: URL?
    let recognizedText: String?
    let onCopyText: @MainActor (String) -> Void
    @Dependency(\.imageLoader) private var loader
    @Environment(\.staticImages) private var staticImages
    @State private var image: CGImage?

    private var resolved: CGImage? { image ?? imageURL.flatMap { staticImages[$0.path] } }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let resolved {
                    Image(decorative: resolved, scale: 2)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 12))
                        .transition(.opacity)
                } else {
                    ThumbnailImage(url: fallbackThumbnailURL)
                        .clipShape(.rect(cornerRadius: 12))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let recognizedText, !recognizedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Text in image", systemImage: "text.viewfinder")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            onCopyText(recognizedText)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy")
                                Text("⌘⇧C").font(.caption2.monospaced()).opacity(0.6)
                            }
                        }
                        .panelButtonStyle()
                        .controlSize(.mini)
                    }
                    ScrollView {
                        Text(recognizedText)
                            .font(.callout)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .padding(12)
                .frame(width: 280)
                .background(.primary.opacity(0.05), in: .rect(cornerRadius: 12))
                .transition(.opacity)
            }
        }
        .padding(12)
        .animation(.easeOut(duration: 0.2), value: resolved == nil)
        .animation(.easeOut(duration: 0.2), value: recognizedText)
        .task(id: imageURL) {
            guard let imageURL, staticImages[imageURL.path] == nil else { return }
            image = await loader.image(imageURL, PanelMetrics.previewImageMaxPixelSize)
        }
    }
}

// MARK: - Quick Look

private struct QuickLookFilePreview: NSViewRepresentable {
    let url: URL
    let bookmark: Data?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        view.autostarts = true
        view.shouldCloseWithWindow = false
        context.coordinator.beginAccess(url: url, bookmark: bookmark)
        view.previewItem = url as NSURL
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        if (nsView.previewItem as? NSURL) as URL? != url {
            context.coordinator.endAccess()
            context.coordinator.beginAccess(url: url, bookmark: bookmark)
            nsView.previewItem = url as NSURL
        }
    }

    static func dismantleNSView(_ nsView: QLPreviewView, coordinator: Coordinator) {
        nsView.close()
        coordinator.endAccess()
    }

    @MainActor
    final class Coordinator {
        private var accessedURL: URL?

        func beginAccess(url: URL, bookmark: Data?) {
            let target = bookmark.flatMap { FileBookmark.resolve($0)?.url } ?? url
            if target.startAccessingSecurityScopedResource() { accessedURL = target }
        }

        func endAccess() {
            accessedURL?.stopAccessingSecurityScopedResource()
            accessedURL = nil
        }
    }
}
