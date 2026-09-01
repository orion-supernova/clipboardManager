//
//  ClipboardItem.swift
//  clipboardManager
//
//  Lightweight, list-safe value model. It deliberately never carries blobs:
//  full content is loaded on demand through `ClipboardPayload`.
//

import Foundation

enum ClipboardKind: String, Codable, Sendable, CaseIterable, Hashable {
    // Raw values intentionally match the legacy `type` column so v1 rows map 1:1.
    case text
    case url
    case color
    case image
    case file
    case video

    var isFileBacked: Bool { self == .file || self == .video }

    var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .url: "link"
        case .color: "paintpalette"
        case .image: "photo"
        case .file: "doc"
        case .video: "film"
        }
    }

    var title: String {
        switch self {
        case .text: "Text"
        case .url: "Link"
        case .color: "Color"
        case .image: "Image"
        case .file: "File"
        case .video: "Video"
        }
    }
}

struct SourceApp: Equatable, Hashable, Sendable, Codable {
    var name: String
    var bundleID: String?

    static let unknown = SourceApp(name: "Unknown", bundleID: nil)
}

struct PixelSize: Equatable, Hashable, Sendable {
    var width: Int
    var height: Int

    var label: String { "\(width) × \(height)" }
}

struct ClipboardItem: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var kind: ClipboardKind
    var timestamp: Date
    var isPinned: Bool
    /// First few hundred characters of text (masked for sensitive content), the file
    /// name, the normalized hex for colors, the URL, or recognised text for images.
    var preview: String
    var source: SourceApp
    var byteCount: Int64
    var fileName: String?
    /// Absolute path of the original file (path tracking for file-backed items).
    var filePath: String?
    /// File name inside the blob store's `Images` directory.
    var imagePath: String?
    /// File name inside the blob store's `Thumbnails` directory.
    var thumbnailPath: String?
    var pixelSize: PixelSize?
    var contentHash: String
    /// `false` when a file-backed item's original file can no longer be reached.
    var isFileAvailable: Bool
    var folderID: UUID?
    var sensitivity: SensitiveKind?
    /// e.g. the card brand or the token issuer.
    var sensitivityDetail: String?
    var linkTitle: String?
    /// Favicon file name inside the thumbnails directory (link items).
    var linkIconPath: String?
    /// Detected once when the item is loaded, never in view bodies.
    var codeLanguage: CodeLanguage?

    var isSensitive: Bool { sensitivity != nil }

    /// Pinning or filing an item takes it out of every retention rule — count,
    /// age and the sensitive-content timer alike. `ClipboardStore.prune` fetches
    /// with exactly this predicate, so anything reading it stays in step with
    /// what actually gets deleted.
    var isRetentionExempt: Bool { isPinned || folderID != nil }

    var displayTitle: String {
        switch kind {
        case .file, .video: fileName ?? preview
        case .url: linkTitle ?? URL(string: preview)?.host() ?? preview
        default: preview
        }
    }

    /// Header label: a sensitive kind, a detected code language, or the plain kind.
    var headerTitle: String {
        if let sensitivity { return sensitivityDetail.map { "\(sensitivity.title) · \($0)" } ?? sensitivity.title }
        if let codeLanguage { return codeLanguage.displayName }
        return kind.title
    }

    var headerSymbol: String {
        if let sensitivity { return sensitivity.symbol }
        if codeLanguage != nil { return "chevron.left.forwardslash.chevron.right" }
        return kind.symbolName
    }

    var parentFolderPath: String? {
        guard let filePath else { return nil }
        return (filePath as NSString).deletingLastPathComponent
            .replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

/// Full content of an item, loaded only when pasting, previewing or dragging.
struct ClipboardPayload: Sendable, Equatable {
    var kind: ClipboardKind
    var text: String?
    var richText: Data?
    /// Absolute URL of the stored PNG for image items.
    var imageFileURL: URL?
    /// Resolved URL for file-backed items (may need security scope; see `bookmark`).
    var fileURL: URL?
    var bookmark: Data?
    var fileName: String?
}

/// A user-created collection. Items in a folder leave the history timeline and
/// are never removed by retention.
struct ClipboardFolder: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var symbol: String
    var createdAt: Date
    var itemCount: Int
}

enum HistoryScope: Equatable, Hashable, Sendable {
    case history
    case folder(UUID)

    var folderID: UUID? {
        if case let .folder(id) = self { return id }
        return nil
    }
}

/// Toolbar filter for the card strip.
enum KindFilter: String, CaseIterable, Sendable, Equatable, Identifiable {
    case all
    case text
    case links
    case images
    case files
    case colors

    var id: String { rawValue }

    var kinds: [ClipboardKind]? {
        switch self {
        case .all: nil
        case .text: [.text]
        case .links: [.url]
        case .images: [.image]
        case .files: [.file, .video]
        case .colors: [.color]
        }
    }

    var title: String {
        switch self {
        case .all: "Everything"
        case .text: "Text"
        case .links: "Links"
        case .images: "Images"
        case .files: "Files"
        case .colors: "Colors"
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.grid.2x2"
        case .text: "text.alignleft"
        case .links: "link"
        case .images: "photo"
        case .files: "doc"
        case .colors: "paintpalette"
        }
    }

    func matches(_ kind: ClipboardKind) -> Bool {
        kinds?.contains(kind) ?? true
    }
}
