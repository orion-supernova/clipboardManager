//
//  ClipboardEntry.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 08.03.2026.
//

import Foundation
import AppKit

struct ClipboardEntry: Identifiable, Codable {
    let id: UUID
    let type: ClipboardItemType
    let content: Data
    let contentDescriptionString: String
    let timestamp: Date
    let copiedFromApplicationTitle: String?
    let copiedFromApplicationPID: Int32?

    var copiedFromApplication: CopiedFromApplication {
        CopiedFromApplication(
            applicationTitle: copiedFromApplicationTitle,
            applicationProcessIdentifier: copiedFromApplicationPID
        )
    }
}
