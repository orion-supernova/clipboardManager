//
//  ClipboardItem.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import AppKit

struct ClipboardItem: Identifiable, Codable {
    var id: UUID
    let text: String
    let copiedFromApplication: CopiedFromApplication
    //TODO: - Images, Links
}

struct CopiedFromApplication: Codable {
    let applicationTitle: String?
    let applicationProcessIdentifier: pid_t?

    init(withApplication application: NSRunningApplication) {
        self.applicationTitle = application.localizedName
        self.applicationProcessIdentifier = application.processIdentifier
        if let image = application.icon {
            StorageHelper.saveImageToDisk(image: image, appName: application.localizedName ?? "")
        }
    }

    func getApplication() -> NSRunningApplication? {
        guard let identifier = self.applicationProcessIdentifier else { return nil }
        let app = NSRunningApplication(processIdentifier: identifier)
        return app
    }
}

struct CustomImage: Codable {
    let imageData: Data?

    init(withImage image: NSImage) {
        self.imageData = image.tiffRepresentation
    }

    func getImage() -> NSImage? {
        guard let imageData = self.imageData else {
            return nil
        }
        let image = NSImage(data: imageData)

        return image
    }
}
