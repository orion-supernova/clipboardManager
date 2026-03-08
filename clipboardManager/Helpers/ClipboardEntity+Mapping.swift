//
//  ClipboardEntity+Mapping.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 08.03.2026.
//

import CoreData

extension ClipboardEntity {
    func toClipboardEntry() -> ClipboardEntry {
        let id = self.id ?? UUID()
        let typeRaw = self.type ?? ClipboardItemType.text.rawValue
        let type = ClipboardItemType(rawValue: typeRaw) ?? .text
        let content = self.content ?? Data()
        let timestamp = self.timestamp ?? Date()
        let contentDescriptionString = self.contentDescriptionString ?? ""

        var appTitle: String? = nil
        var appPID: Int32? = nil
        if let appData = self.copiedFromApplication,
           let copiedApp = try? CopiedFromApplication.fromData(appData) {
            appTitle = copiedApp.applicationTitle
            appPID = copiedApp.applicationProcessIdentifier
        }

        return ClipboardEntry(
            id: id,
            type: type,
            content: content,
            contentDescriptionString: contentDescriptionString,
            timestamp: timestamp,
            copiedFromApplicationTitle: appTitle,
            copiedFromApplicationPID: appPID
        )
    }
}
