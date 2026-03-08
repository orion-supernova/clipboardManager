//
//  ClipboardItem.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import AppKit

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let type: ClipboardItemType
    let content: Data
    let copiedFromApplication: CopiedFromApplication
    let timestamp: Date
    let contentDescriptionString: String
}
