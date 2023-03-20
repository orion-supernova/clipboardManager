//
//  ClipboardItem.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import Foundation

struct ClipboardItem: Identifiable, Codable {
    var id: UUID
    let text: String
    //TODO: - Images, Links
}
