//
//  ContainerView.swift
//  clipboardManager
//
//  Created by muratcankoc on 23/07/2024.
//

import SwiftUI

struct ContainerView: View {
//    @StateObject var clipboardManager = ClipboardManager(persistenceController: PersistenceController.shared)
    
    var body: some View {
        VStack {
            MainView()
//                .environmentObject(clipboardManager)
        }
    }
}

#Preview {
    ContainerView()
}
