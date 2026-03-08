//
//  ClipboardService.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 08.03.2026.
//

import AppKit
import SwiftUI

@MainActor
final class ClipboardService {
    private let repository: ClipboardRepository
    private let settings: SettingsStore
    private var timer: Timer?
    private var lastContentDescription = ""

    init(repository: ClipboardRepository, settings: SettingsStore) {
        self.repository = repository
        self.settings = settings
    }

    func startMonitoring() {
        stopMonitoring()
        let pasteboard = NSPasteboard.general
        var changeCount = pasteboard.changeCount

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard pasteboard.changeCount != changeCount else { return }
            changeCount = pasteboard.changeCount

            guard let entry = self.createClipboardEntry() else { return }
            guard entry.contentDescriptionString != self.lastContentDescription else { return }

            self.lastContentDescription = entry.contentDescriptionString
            self.repository.add(entry)
            self.repository.trimRetainCount(self.settings.retainCount)
            self.repository.removeItemsOlderThan(hours: self.settings.clearItemsOlderThanHours)

            NotificationCenter.default.post(name: .pasteBoardCountNotification, object: self.repository.count())
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func createClipboardEntry() -> ClipboardEntry? {
        let pasteboard = NSPasteboard.general
        let type = getClipboardItemType()

        let contentDescription = pasteboard.string(forType: .string) ?? ""
        let copiedFromApp = getCopiedFromApplication()

        let content: Data
        switch type {
        case .text:
            if let string = pasteboard.string(forType: .string) {
                content = Data(string.utf8)
            } else {
                return ClipboardEntry(type: .text, content: Data(), contentDescriptionString: contentDescription,
                                      copiedFromApplicationTitle: copiedFromApp.applicationTitle,
                                      copiedFromApplicationPID: copiedFromApp.applicationProcessIdentifier)
            }
        case .image:
            if let pngData = pasteboard.data(forType: .png) {
                content = pngData
            } else if let tiffData = pasteboard.data(forType: .tiff) {
                content = tiffData
            } else if let jpegData = pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")) {
                content = jpegData
            } else if let fileURLs = pasteboard.propertyList(forType: .fileURL) as? [String],
                      let firstURL = fileURLs.first,
                      let imageData = try? Data(contentsOf: URL(fileURLWithPath: firstURL)) {
                content = imageData
            } else {
                return ClipboardEntry(type: .text, content: Data(), contentDescriptionString: contentDescription,
                                      copiedFromApplicationTitle: copiedFromApp.applicationTitle,
                                      copiedFromApplicationPID: copiedFromApp.applicationProcessIdentifier)
            }
        case .url:
            if let url = pasteboard.string(forType: .URL), let urlData = url.data(using: .utf8) {
                content = urlData
            } else {
                return ClipboardEntry(type: .text, content: Data(), contentDescriptionString: contentDescription,
                                      copiedFromApplicationTitle: copiedFromApp.applicationTitle,
                                      copiedFromApplicationPID: copiedFromApp.applicationProcessIdentifier)
            }
        case .color:
            if let color = detectColor(from: pasteboard.string(forType: .string) ?? "") {
                do {
                    content = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
                } catch {
                    return nil
                }
            } else {
                return nil
            }
        }

        return ClipboardEntry(
            id: UUID(),
            type: type,
            content: content,
            contentDescriptionString: contentDescription,
            timestamp: Date(),
            copiedFromApplicationTitle: copiedFromApp.applicationTitle,
            copiedFromApplicationPID: copiedFromApp.applicationProcessIdentifier
        )
    }

    private func getClipboardItemType() -> ClipboardItemType {
        let pasteboard = NSPasteboard.general

        if pasteboard.canReadObject(forClasses: [NSColor.self], options: nil) {
            return .color
        }
        if detectColor(from: pasteboard.string(forType: .string) ?? "") != nil {
            return .color
        }
        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) {
            return .image
        }
        if pasteboard.canReadObject(forClasses: [NSURL.self], options: nil) {
            return .url
        }
        return .text
    }

    private func getCopiedFromApplication() -> CopiedFromApplication {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return CopiedFromApplication(withApplication: NSRunningApplication())
        }
        return CopiedFromApplication(withApplication: app)
    }
}
