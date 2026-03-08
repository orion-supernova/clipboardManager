//
//  ClipboardEntity.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 08.03.2026.
//

import CoreData
import Foundation

@objc(ClipboardEntity)
final class ClipboardEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ClipboardEntity> {
        NSFetchRequest<ClipboardEntity>(entityName: "ClipboardEntity")
    }

    @NSManaged var id: UUID?
    @NSManaged var content: Data?
    @NSManaged var timestamp: Date?
    @NSManaged var type: String?
    @NSManaged var contentDescriptionString: String?
    @NSManaged var copiedFromApplication: Data?
}
