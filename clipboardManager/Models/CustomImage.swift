//
//  CustomImage.swift
//  clipboardManager
//
//  Created by muratcankoc on 23/07/2024.
//

import AppKit

struct CustomImage: Codable {
    // MARK: - Properties
    let imageData: Data?
    
    // MARK: - Lifecycle
    init(withImage image: NSImage) {
        self.imageData = image.tiffRepresentation
    }
    
    // MARK: - Public Methods
    func getImage() -> NSImage? {
        guard let imageData = self.imageData else {
            return nil
        }
        let image = NSImage(data: imageData)
        return image
    }
}
