//
//  StorageHelper.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import AppKit

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

    static func saveImageToDisk(image: NSImage, appName: String) {

        // Convert to Data
        if let data = image.tiffRepresentation {
            // Create URL
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documents.appendingPathComponent("\(appName).png")
            getImageFromDisk(for: appName) { alreayExists, image in
                if alreayExists {
                    // Do Nothing...
                } else {
                    do {
                        // Write to Disk
                        try data.write(to: url)

                    } catch {
                        print("Unable to Write Data to Disk (\(error))")
                    }
                }
            }
        }
    }

    static func getImageFromDisk(for appName: String, completion: @escaping ((alreadyExist: Bool, image: NSImage?)) -> Void) {
        guard !appName.isEmpty else { return }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documents.appendingPathComponent("\(appName).png")
        var urlString = url.absoluteString

        // Remove the "file://" prefix
        if urlString.localizedStandardContains("file://") {
            urlString = String(urlString.dropFirst(7))
        }
        let image = NSImage(contentsOfFile: urlString)
        if let image {
            completion((true, image))
        } else {
            completion((false, nil))
        }
    }
}
