//
//  ClipboardEntry.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 08.03.2026.
//

import SwiftData
import AppKit

@Model
final class ClipboardEntry {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var content: Data
    var contentDescriptionString: String
    var timestamp: Date
    var copiedFromApplicationTitle: String?
    var copiedFromApplicationPID: Int32?

    init(
        id: UUID = UUID(),
        type: ClipboardItemType,
        content: Data,
        contentDescriptionString: String,
        timestamp: Date = Date(),
        copiedFromApplicationTitle: String?,
        copiedFromApplicationPID: Int32?
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.content = content
        self.contentDescriptionString = contentDescriptionString
        self.timestamp = timestamp
        self.copiedFromApplicationTitle = copiedFromApplicationTitle
        self.copiedFromApplicationPID = copiedFromApplicationPID
    }

    var type: ClipboardItemType {
        get { ClipboardItemType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
    }

    var copiedFromApplication: CopiedFromApplication {
        CopiedFromApplication(
            applicationTitle: copiedFromApplicationTitle,
            applicationProcessIdentifier: copiedFromApplicationPID
        )
    }
}
