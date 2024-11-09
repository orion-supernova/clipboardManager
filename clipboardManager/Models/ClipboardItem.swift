//
//  ClipboardItem.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import AppKit

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let type: ClipboardItemType
    let content: Data
    let copiedFromApplication: CopiedFromApplication
    let timestamp: Date
    let contentDescriptionString: String
    let fileURL: URL?
    let thumbnailURL: URL?
    let pasteboardItems: [(NSPasteboard.PasteboardType, Data)]
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.contentDescriptionString == rhs.contentDescriptionString
    }
}

enum ClipboardItemType: String {
    case text
    case image
    case color
    case url
    case video
    case file
}
