//
//  ClipboardItem.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import AppKit

struct ClipboardItem: Identifiable {
    let id: UUID
    let type: ClipboardItemType
    let content: Data
    let copiedFromApplication: CopiedFromApplication
    let timestamp: Date
    let contentDescriptionString: String
    let fileURL: URL?
    let thumbnailURL: URL?
}


enum ClipboardItemType: String, Codable {
    case text
    case image
    case video
    case url
    case color
    case file
}
