//
//  clipboardManagerApp.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import SwiftUI

@main
struct clipboardManagerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
