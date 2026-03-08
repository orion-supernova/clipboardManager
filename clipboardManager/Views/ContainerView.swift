//
//  ContainerView.swift
//  clipboardManager
//
//  Created by muratcankoc on 23/07/2024.
//

import SwiftUI
import SwiftData

struct ContainerView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    @Environment(\.controlActiveState) private var controlActiveState
    
    var body: some View {
        VStack {
            MainView()
                .environmentObject(viewModel)
        }
        .onChange(of: controlActiveState) { newValue in
            switch newValue {
            case .key, .active:
                print("ACTTIIIVIA")
            case .inactive:
                print("INACTTIIIIVEEE")
            default:
                print("Unknownnnnn")
            }
        }
    }
}

#Preview {
    ContainerView()
        .environmentObject(
            ClipboardViewModel(
                repository: ClipboardRepository(context: ModelContext(try! ModelContainer(for: ClipboardEntry.self))),
                clipboardService: ClipboardService(
                    repository: ClipboardRepository(context: ModelContext(try! ModelContainer(for: ClipboardEntry.self))),
                    settings: SettingsStore()
                ),
                settings: SettingsStore()
            )
        )
}
