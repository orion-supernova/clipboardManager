//
//  MainView.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import SwiftUI
import CoreData

struct MainView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager

    var body: some View {
        GeometryReader { reader in
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                    .ignoresSafeArea()
                
                if clipboardManager.clipboardItems.isEmpty {
                    ZStack {
                        RadialGradient(colors: [
                            Color.purple
                                .opacity(0.5),
                            Color.black.opacity(1)
                        ], center: .center, startRadius: 1, endRadius: 450)
                        Text("No Clipboard Items")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                    }
                } else {
                    ScrollablePasteboardItemsView()
                }
            }
        }
        .frame(width: screenWidth, height: screenHeight, alignment: .center)
        .onReceive(NotificationCenter.default.publisher(for: .refreshClipboardItems)) { _ in
            refreshClipboardItems()
        }
    }
    
    func refreshClipboardItems() {
        clipboardManager.fetchClipboardItems()
    }
}

#Preview {
    MainView()
        .environmentObject(ClipboardManager(persistenceController: PersistenceController.shared))
}

struct ScrollablePasteboardItemsView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    Spacer()
                    ForEach(clipboardManager.clipboardItems) { item in
                        LazyHStack {
                            ClipboardItemBox(item: item)
                                .onTapGesture {
                                    let pasteBoard = NSPasteboard.general
                                    pasteBoard.clearContents()
                                    pasteBoard.setString(item.contentDescriptionString, forType: .string)
                                    print("DEBUG: -----", item.contentDescriptionString)
                                    NotificationCenter.default.post(name: .textSelectedFromClipboardNotification, object: item)
                                }
                                .frame(width: 300, height: 300)
                                .id(item.id)
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification)) { _ in
                proxy.scrollTo(clipboardManager.clipboardItems.first?.id, anchor: .trailing)
            }
        }
    }
}
