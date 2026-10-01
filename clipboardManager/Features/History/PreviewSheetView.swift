//
//  PreviewSheetView.swift
//  clipboardManager
//
//  The quick-preview sheet (Space). It sits above the toolbar so nothing else
//  moves when it opens. Shows full text (with code colouring), a large image
//  with any recognised text, a rich link card, color formats, or Quick Look.
//

import AVKit
import ComposableArchitecture
import Quartz
import SwiftUI

struct PreviewSheetView: View {
    let item: ClipboardItem
    /// The payload for `item`, or nil while it loads.
    let payload: ClipboardPayload?
    /// Whatever was loaded last, possibly for the previous item. Files keep
    /// showing it until theirs arrives, so Quick Look swaps instead of rebuilding.
    var stalePayload: ClipboardPayload? = nil
    var failed = false
    let revealed: Bool
    var sensitiveLifetime: TimeInterval? = nil
    let thumbnailURL: URL?
    let iconURL: URL?
    let imageURL: URL?
    let onPaste: @MainActor () -> Void
    let onOpen: @MainActor () -> Void
    var onRevealInFinder: @MainActor () -> Void = {}
    var onSmartAction: @MainActor (SmartAction) -> Void = { _ in }
    let onToggleReveal: @MainActor () -> Void
    let onCopyColor: @MainActor (ColorFormat) -> Void
    let onCopyText: @MainActor (String) -> Void
    let onClose: @MainActor () -> Void

    @State private var stats: TextStats?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentTransition(.opacity)
        }
        .panelGlass(prominent: true, in: .rect(cornerRadius: PanelMetrics.cardCornerRadius))
        .padding(.horizontal, 10)
        .task(id: StatsKey(id: item.id, loaded: payload != nil)) {
            // Counting characters and lines walks the whole text: never in `body`.
            guard item.kind == .text, !item.isSensitive, let text = payload?.text else { stats = nil; return }
            let id = item.id
            let counted = await Task.detached(priority: .utility) { TextStats(id: id, text: text) }.value
            guard !Task.isCancelled else { return }
            stats = counted
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: item.headerSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(item.isSensitive ? Color.red : Color.accentColor)
                .frame(width: 28, height: 28)
                .background((item.isSensitive ? Color.red : Color.accentColor).opacity(0.14), in: .rect(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(item.kind == .text ? .tail : .middle)
                HStack(spacing: 6) {
                    AppIconView(source: item.source).frame(width: 12, height: 12)
                    Text(item.source.name)
                    Text("·")
                    Text(item.timestamp, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                        .help(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                    ForEach(metaParts, id: \.self) { part in
                        Text("·")
                        Text(part)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .layoutPriority(-1)
            Spacer(minLength: 12)
            if item.isSensitive {
                keyedButton(revealed ? "Hide" : "Reveal", symbol: revealed ? "eye.slash" : "eye", key: "⌘E", action: onToggleReveal)
                    .panelButtonStyle()
            }
            if item.kind.isFileBacked || item.kind == .image {
                keyedButton("Show in Finder", symbol: "folder", key: "⇧⌘R", action: onRevealInFinder)
                    .panelButtonStyle()
            }
            if item.kind.isFileBacked || item.kind == .url || item.kind == .image {
                keyedButton(item.kind == .url ? "Open Link" : "Open", symbol: "arrow.up.forward.app", key: "⌘O", action: onOpen)
                    .panelButtonStyle()
            }
            let secondary = item.isSensitive || bodyShowsActions ? [] : item.smartActions.filter { !$0.isPrimary }
            if !secondary.isEmpty {
                Menu {
                    ForEach(secondary) { action in
                        Button(action.title, systemImage: action.symbol) { onSmartAction(action) }
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .menuStyle(.button)
                .fixedSize()
                .panelButtonStyle()
            }
            keyedButton("Paste", symbol: "arrow.down.doc", key: "↩", prominent: true, action: onPaste)
                .panelButtonStyle(prominent: true)
                .disabled(failed)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 24, height: 24)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .panelGlass(interactive: true, in: .circle)
            .help("Close (space / esc)")
            .accessibilityLabel("Close preview")
        }
        .controlSize(.small)
    }

    /// The body shows the content, so the title says what it is: the smart
    /// type, or the first line of text — never the same paragraph twice.
    private var headerTitle: String {
        if item.isSensitive { return item.headerTitle }
        if let primary = item.primarySmartAction { return primary.subjectTitle }
        if item.kind == .text {
            let firstLine = item.preview.split(whereSeparator: \.isNewline).first.map(String.init) ?? item.preview
            return item.codeLanguage.map { "\($0.displayName) snippet" } ?? firstLine
        }
        return item.displayTitle
    }

    /// Smart text shows its actions as tiles in the body; the header keeps only Paste.
    private var bodyShowsActions: Bool { !item.isSensitive && item.primarySmartAction != nil }

    private func keyedButton(_ title: String, symbol: String, key: String, prominent: Bool = false, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                Text(title)
                KeyCap(key: key, onProminent: prominent)
            }
            .lineLimit(1)
        }
        // Buttons keep their size; the title is what truncates when space runs out.
        .fixedSize()
        .accessibilityLabel(title)
        .accessibilityHint("Shortcut \(key)")
    }

    /// Never a character count for sensitive items: the length of a secret is
    /// itself a hint about it.
    private var metaParts: [String] {
        if item.isSensitive {
            var parts = ["Masked"]
            if let sensitiveLifetime, !item.isRetentionExempt {
                let expiry = item.timestamp.addingTimeInterval(sensitiveLifetime)
                parts.append("forgets \(expiry.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))")
            }
            return parts
        }
        switch item.kind {
        case .text:
            var parts: [String] = []
            if let language = item.codeLanguage { parts.append(language.displayName) }
            if let stats, stats.id == item.id {
                parts.append(Formatting.characterCount(stats.characters))
                if stats.lines > 1 { parts.append("\(stats.lines.formatted()) lines") }
            } else {
                parts.append(Formatting.characterCount(Int(item.byteCount)))
            }
            return parts
        case .image:
            return item.pixelSize.map { ["\($0.label)", Formatting.bytes(item.byteCount)] } ?? []
        case .file, .video:
            return [item.isFileAvailable ? Formatting.bytes(item.byteCount) : "Original file not found"]
        case .url:
            return URL(string: item.preview)?.host().map { [$0] } ?? []
        default:
            return []
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if failed {
            ContentUnavailableView(
                "Couldn’t load this item",
                systemImage: "exclamationmark.triangle",
                description: Text("It may have been deleted. Close the preview and try again.")
            )
        } else {
            body(for: item.kind)
        }
    }

    @ViewBuilder
    private func body(for kind: ClipboardKind) -> some View {
        switch kind {
        case .text:
            if !item.isSensitive, let primary = item.primarySmartAction {
                SmartBody(item: item, text: payload?.text ?? item.preview, primary: primary, onAction: onSmartAction, onPasteOriginal: onPaste)
            } else if item.isSensitive, !revealed {
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
            if !item.isFileAvailable, payload != nil {
                ContentUnavailableView("File not available", systemImage: "doc.questionmark", description: Text("The original file was moved or deleted."))
                    .foregroundStyle(.orange)
            } else if let source = payload ?? stalePayload.flatMap({ $0.kind == kind ? $0 : nil }), let url = source.fileURL {
                VStack(spacing: 6) {
                    Group {
                        if kind == .video {
                            // Quick Look sizes its player inconsistently and keeps the old
                            // layout after a swap; a real player always fills and letterboxes.
                            VideoFilePreview(url: url, bookmark: source.bookmark)
                                .background(.black)
                        } else {
                            QuickLookFilePreview(url: url, bookmark: source.bookmark)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08)))
                    if let folder = item.parentFolderPath {
                        Label(folder, systemImage: "folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            } else {
                DelayedSpinner()
            }
        }
    }
}

private struct StatsKey: Equatable {
    var id: UUID
    var loaded: Bool
}

private struct TextStats: Sendable {
    let id: UUID
    let characters: Int
    let lines: Int

    nonisolated init(id: UUID, text: String) {
        self.id = id
        characters = text.count
        lines = text.reduce(into: 1) { count, character in if character.isNewline { count += 1 } }
    }
}

/// Loading is usually a few milliseconds; a spinner that flashes for one frame
/// reads as jank. Show it only if the wait is real.
private struct DelayedSpinner: View {
    @State private var visible = false

    var body: some View {
        ProgressView()
            .controlSize(.small)
            .opacity(visible ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.easeOut(duration: 0.15)) { visible = true }
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
    @State private var rendered: Rendered?

    /// SwiftUI lays out a `Text` in full, so a 200k-character clip would stall
    /// every frame the sheet is on screen. Paste still uses the whole payload.
    nonisolated private static let displayLimit = 20_000

    private struct Rendered {
        var id: UUID
        var text: AttributedString
        var totalCharacters: Int?
    }

    private struct RenderKey: Equatable {
        var id: UUID
        var isLoading: Bool
        var language: CodeLanguage?
    }

    nonisolated private static func render(_ text: String, id: UUID, language: CodeLanguage?) -> Rendered {
        let truncated = text.utf16.count > displayLimit && text.count > displayLimit
        let shown = truncated ? String(text.prefix(displayLimit)) : text
        let attributed = language.map { CodeHighlighter.attributed(shown, language: $0) } ?? AttributedString(shown)
        return Rendered(id: id, text: attributed, totalCharacters: truncated ? text.count : nil)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let rendered, rendered.id == id {
                    Text(rendered.text)
                } else {
                    // One frame's worth until the background render lands.
                    Text(String(text.prefix(2_000)))
                }
            }
            .font(language != nil ? .system(size: 12, design: .monospaced) : .body)
            .lineSpacing(language != nil ? 2 : 3)
            .textSelection(.enabled)
            if let rendered, rendered.id == id, let total = rendered.totalCharacters {
                Text("Showing the first \(Self.displayLimit.formatted()) of \(total.formatted()) characters. Paste inserts everything.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        // A readable measure: full-width lines on a wide panel run to 250+ characters.
        .frame(maxWidth: language != nil ? 1100 : 720, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    var body: some View {
        Group {
            if marketingRender {
                // Scroll views don't render under ImageRenderer.
                content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).clipped()
            } else {
                ScrollView { content }
                    .id(id) // start each item at the top
            }
        }
        // A quiet reading surface: long text straight on glass sits on top of
        // whatever wallpaper is behind the panel. One flat fill, no per-frame cost.
        .background(.background.opacity(0.45), in: .rect(cornerRadius: 14))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .task(id: RenderKey(id: id, isLoading: isLoading, language: language)) {
            let (text, id, language) = (text, id, language)
            let result = await Task.detached(priority: .userInitiated) { Self.render(text, id: id, language: language) }.value
            guard !Task.isCancelled else { return }
            rendered = result
        }
        .overlay(alignment: .topTrailing) {
            if isLoading {
                DelayedSpinner()
                    .frame(width: 20, height: 20)
                    .padding(16)
            }
        }
    }
}

private struct MaskedBody: View {
    let masked: String
    let kind: SensitiveKind
    let detail: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: kind.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 52, height: 52)
                .background(.red.opacity(0.14), in: .circle)
                .accessibilityHidden(true)
            Text(masked)
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .tracking(2)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .accessibilityLabel("\(kind.title)\(detail.map { ", \($0)" } ?? ""), hidden")
            HStack(spacing: 6) {
                KeyCap(key: "⌘E")
                Text("reveals ·")
                KeyCap(key: "↩")
                Text("pastes the real value")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
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

    private static let visibleQueryItems = 6
    @Dependency(\.linkMetadata) private var linkMetadata
    @SharedReader(.fetchLinkTitles) private var fetchLinkTitles
    @State private var details: (url: String, value: LinkDetails)?

    private var currentDetails: LinkDetails? {
        details.flatMap { $0.url == urlString ? $0.value : nil }
    }

    var body: some View {
        content
            .task(id: urlString) {
                // Respects the same privacy switch as title fetching: no request otherwise.
                guard fetchLinkTitles, let url = URL(string: urlString) else { return }
                let urlString = urlString
                guard let fetched = await linkMetadata.details(url), !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) { details = (urlString, fetched) }
            }
    }

    @ViewBuilder
    private var content: some View {
        let url = URL(string: urlString)
        HStack(alignment: .top, spacing: 20) {
            if let heroURL {
                // Open Graph images are 1.91:1; a fixed square-ish frame cropped most of them.
                ThumbnailImage(url: heroURL, placeholderSymbol: "photo", contentMode: .fill)
                    .aspectRatio(1.91, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08), lineWidth: 1))
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Group {
                        if let iconURL {
                            ThumbnailImage(url: iconURL, placeholderSymbol: "globe").clipShape(.rect(cornerRadius: 4))
                        } else {
                            Image(systemName: "globe").foregroundStyle(.tint)
                        }
                    }
                    .frame(width: 16, height: 16)
                    if let site = currentDetails?.siteName ?? url?.host() {
                        Text(site).font(.callout.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
                Text(title ?? url?.host() ?? "Link")
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                if let summary = currentDetails?.summary {
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
                Text(Self.styledURL(urlString, host: url?.host()))
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(3)
                    .truncationMode(.middle)
                if let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let items = components.queryItems, !items.isEmpty {
                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
                        ForEach(Array(items.prefix(Self.visibleQueryItems).enumerated()), id: \.offset) { _, query in
                            GridRow {
                                Text(query.name).font(.caption.monospaced().weight(.semibold))
                                Text(query.value ?? "").font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        if items.count > Self.visibleQueryItems {
                            GridRow {
                                Text("+\(items.count - Self.visibleQueryItems) more")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .gridCellColumns(2)
                            }
                        }
                    }
                    .padding(10)
                    .background(.primary.opacity(0.05), in: .rect(cornerRadius: 10))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 560, alignment: .topLeading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 14)
    }

    /// The host carries the meaning; scheme, path and query are detail.
    private static func styledURL(_ string: String, host: String?) -> AttributedString {
        var styled = AttributedString(string)
        styled.foregroundColor = .secondary
        if let host, let range = styled.range(of: host) {
            styled[range].foregroundColor = .primary
        }
        return styled
    }
}

private struct ColorBody: View {
    let hex: String
    let onCopy: @MainActor (ColorFormat) -> Void

    var body: some View {
        let parsed = ParsedColor.parse(hex)
        HStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 16)
                .fill(parsed?.swiftUIColor ?? .gray)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.1)))
                .overlay(alignment: .bottomLeading) {
                    Text(hex)
                        .font(.caption.weight(.semibold).monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: .capsule)
                        .padding(10)
                }
                .frame(width: 200)
                .accessibilityLabel("Color \(hex)")
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(ColorFormat.allCases.enumerated()), id: \.element) { index, format in
                    ColorFormatRow(index: index, title: format.title, value: parsed.map(format.render) ?? "—") {
                        onCopy(format)
                    }
                }
            }
            .frame(maxWidth: 440, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 14)
    }
}

/// The whole row copies: the button used to sit ~1,400pt from its value.
private struct ColorFormatRow: View {
    let index: Int
    let title: String
    let value: String
    let onCopy: @MainActor () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 10) {
                KeyCap(key: "\(index + 1)")
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 88, alignment: .leading)
                Text(value)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .opacity(hovering ? 1 : 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.primary.opacity(hovering ? 0.06 : 0), in: .rect(cornerRadius: 8))
            .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .accessibilityLabel("Copy \(title): \(value)")
        .accessibilityHint("Shortcut \(index + 1)")
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
                        .clipShape(.rect(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.08)))
                        .transition(.opacity)
                } else {
                    ThumbnailImage(url: fallbackThumbnailURL)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // A stage, so a small image doesn't float alone in a wide glass field.
            .background(.black.opacity(0.12), in: .rect(cornerRadius: 14))
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
        // Arrowing past a video must not start it playing.
        view.autostarts = false
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
            // Without this Quick Look keeps the previous item's layout after a swap.
            nsView.refreshPreviewItem()
        }
    }

    static func dismantleNSView(_ nsView: QLPreviewView, coordinator: Coordinator) {
        nsView.close()
        coordinator.endAccess()
    }

    typealias Coordinator = ScopedFileAccess
}

// MARK: - Video

/// A real player: fills the stage, letterboxes any aspect ratio, never autoplays.
private struct VideoFilePreview: NSViewRepresentable {
    let url: URL
    let bookmark: Data?

    func makeCoordinator() -> ScopedFileAccess { ScopedFileAccess() }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.videoGravity = .resizeAspect
        view.showsFullScreenToggleButton = false
        view.allowsPictureInPicturePlayback = false
        load(url, into: view, access: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        guard context.coordinator.sourceURL != url else { return }
        nsView.player?.pause()
        context.coordinator.endAccess()
        load(url, into: nsView, access: context.coordinator)
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ScopedFileAccess) {
        nsView.player?.pause()
        nsView.player = nil
        coordinator.endAccess()
    }

    private func load(_ url: URL, into view: AVPlayerView, access: ScopedFileAccess) {
        let playable = access.beginAccess(url: url, bookmark: bookmark)
        view.player = AVPlayer(url: playable)
    }
}

/// Holds a security-scoped grant on a copied file for as long as it's shown.
@MainActor
final class ScopedFileAccess {
    private var accessedURL: URL?
    private(set) var sourceURL: URL?

    /// Returns the URL to read: the bookmark's resolved location when it has one.
    @discardableResult
    func beginAccess(url: URL, bookmark: Data?) -> URL {
        sourceURL = url
        let target = bookmark.flatMap { FileBookmark.resolve($0)?.url } ?? url
        if target.startAccessingSecurityScopedResource() { accessedURL = target }
        return target
    }

    func endAccess() {
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil
        sourceURL = nil
    }
}
