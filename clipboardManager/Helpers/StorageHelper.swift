//
//  StorageHelper.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import Foundation

class StorageHelper: NSObject {
    static func archiveStringArray(object : [String]) -> Data {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: false)
            return data
        } catch {
            fatalError("Can't encode data: \(error)")
        }
    }
    static func loadStringArray(data: Data) -> [String] {
        do {
            guard let array = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String] else {
                return []
            }
            return array
        } catch {
            fatalError("loadWStringArray - Can't encode data: \(error)")
        }
    }
}
