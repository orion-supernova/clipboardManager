//
//  StorageHelper.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import Foundation

class StorageHelper: NSObject {
    static func archiveStringArray(object : [ClipboardItem]) -> Data {
        do {
            let data = try JSONEncoder().encode(object)
//            let data = try NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: false)
            return data
        } catch {
            fatalError("Can't encode data: \(error)")
        }
    }
    static func loadStringArray(data: Data) -> [ClipboardItem] {
        guard !data.isEmpty else { return []}
//        UserDefaults.standard.removePersistentDomain(forName: "com.walhallaa.clipboardManager") // USE WHEN ADDING NEW KEY :)
        do {
            let array = try JSONDecoder().decode([ClipboardItem].self, from: data)
//            guard let array = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [ClipboardItem] else {
//                return []
//            }
            return array
        } catch {
            fatalError("loadWStringArray - Can't encode data: \(error)")
        }
    }
}
