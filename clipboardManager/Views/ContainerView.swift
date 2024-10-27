//
//  ContainerView.swift
//  clipboardManager
//
//  Created by muratcankoc on 23/07/2024.
//

import SwiftUI

struct ContainerView: View {
    @StateObject var clipboardManager = ClipboardManager.shared
    @Environment(\.controlActiveState) private var controlActiveState
    
    var body: some View {
        VStack {
            MainView()
                .environmentObject(clipboardManager)
        }
        .onChange(of: controlActiveState) { newValue in
            switch newValue {
            case .key, .active:
                print("ACTTIIIVIA")
            case .inactive:
                print("INACTTIIIIVEEE")
                break
            default:
                print("Unknownnnnn")
            }
        }
    }
}

#Preview {
    ContainerView()
}
