//
//  PasteClient.swift
//  clipboardManager
//
//  Writes payloads back to the pasteboard, tagged with the app's own marker so
//  the monitor recognises the write as its own instead of recording a duplicate.
//
//  Choosing an item puts it on the clipboard; the user presses ⌘V. Synthesising
//  that keystroke would mean asking for Accessibility access, which App Review
//  rejects under guideline 2.4.5 — Accessibility APIs are for assistive
//  features, not for automating other apps.
//

import AppKit
import ComposableArchitecture

struct PasteClient: Sendable {
    var write: @Sendable (ClipboardPayload, _ markerID: UUID, _ plainText: Bool) async -> Void
}

extension PasteClient: DependencyKey {
    static let liveValue = PasteClient(
        write: { payload, markerID, plainText in
            await MainActor.run {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                let item = NSPasteboardItem()
                item.setString(markerID.uuidString, forType: .ownMarker)

                switch payload.kind {
                case .text, .url, .color:
                    if let text = payload.text {
                        item.setString(text, forType: .string)
                        if payload.kind == .url, let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            item.setString(url.absoluteString, forType: .URL)
                        }
                    }
                    if !plainText, let rtf = payload.richText {
                        item.setData(rtf, forType: .rtf)
                    }
                case .image:
                    if let url = payload.imageFileURL, let png = try? Data(contentsOf: url) {
                        item.setData(png, forType: .png)
                        if let tiff = NSImage(data: png)?.tiffRepresentation {
                            item.setData(tiff, forType: .tiff)
                        }
                        item.setString(url.absoluteString, forType: .fileURL)
                    }
                case .file, .video:
                    if let url = payload.fileURL {
                        item.setString(url.absoluteString, forType: .fileURL)
                        item.setString(url.path, forType: .string)
                    }
                }
                pasteboard.writeObjects([item])
            }
        }
    )

    static let previewValue = PasteClient(write: { _, _, _ in })
}

extension DependencyValues {
    var paste: PasteClient {
        get { self[PasteClient.self] }
        set { self[PasteClient.self] = newValue }
    }
}
