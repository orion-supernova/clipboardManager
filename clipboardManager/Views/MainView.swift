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
    @Environment(\.controlActiveState) private var controlActiveState
    let publisher = NotificationCenter.default.publisher(for: .allItemsClearedNotification)
    var body: some View {
        GeometryReader { reader in
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                    .ignoresSafeArea()
                
                if clipboardManager.clipboardItems.isEmpty, clipboardManager.isSearchFieldVisible == false {
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
                        .environmentObject(clipboardManager)
                }
            }
            .onReceive(publisher) { _ in
                clipboardManager.clipboardItems.removeAll()
            }
        }
        .frame(width: screenWidth, height: screenHeight, alignment: .center)
    }
    
    func refreshClipboardItems() {
        clipboardManager.fetchClipboardItems()
    }
}

#Preview {
    MainView()
        .environmentObject(ClipboardManager.shared)
}

struct ScrollablePasteboardItemsView: View {
    
    @EnvironmentObject var clipboardManager: ClipboardManager

    @State private var searchText = ""
    @State private var items = ["Item 1", "Item 2"]
    @FocusState private var isFocused: Bool
    @State private var isSearchFieldVisible = false
    @StateObject var wrapper = ScrollablePasteboardItemsViewWrapper()
    @State private var searchDispatchWorkItem: DispatchWorkItem?
    
    var body: some View {
        VStack {
            ZStack {
                HStack {
                    Spacer()
                        .frame(width: 10)
                    
                    Button {
                        NotificationCenter.default.post(name: .preferencesClickedNotification, object: nil)
                    } label: {
                        Image(systemName: "ellipsis")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15)
                    }
                    Spacer()
                }
                HStack {
                    VStack {
                        Text("Board Type: History")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.purple, Color.black.opacity(0.5)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                }
                .frame(maxWidth: 800, maxHeight: 40)
                
                HStack(spacing: 0) {
                    Spacer()
                    if clipboardManager.isSearchFieldVisible {
                        Button {
                            guard !searchText.isEmpty else { clipboardManager.isSearchFieldVisible = false; return }
                                DispatchQueue.main.async {
                                    searchText = ""
                                    clipboardManager.isSearchFieldVisible = false
                                    clipboardManager.fetchClipboardItems()
                                }
                        } label: {
                            Image(systemName: "xmark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 10, height: 10)
                        }
                        
                        TextField("Search", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 200, height: 20)
                            .padding(.horizontal, 5)
                            .focused($isFocused)
                            .onChange(of: searchText) { newValue in
                                debounceSearch(text: newValue)
                            }
                            .onAppear { isFocused = true }
                            .onDisappear { isFocused = false }
                        
                    } else {
                        Button {
                            clipboardManager.isSearchFieldVisible = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .padding()
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .frame(width: screenWidth, height: 70)
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 10) {
                        Spacer()
                            .frame(width: 5)
                        
                        if clipboardManager.clipboardItems.isEmpty, clipboardManager.isSearchFieldVisible {
                            HStack {
                                Spacer()
                                Text("No items found contains ''\(searchText)''")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .frame(width: screenWidth)
                        } else {
                            ForEach(clipboardManager.clipboardItems) { item in
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
    private func debounceSearch(text: String) {
        // Cancel the previous work item if it exists
        searchDispatchWorkItem?.cancel()
        
        // Create a new work item with the search functionality
        let newWorkItem = DispatchWorkItem { [weak clipboardManager] in
            if text.isEmpty {
                clipboardManager?.isSearchFieldVisible = false
                clipboardManager?.fetchClipboardItems()
            } else {
                clipboardManager?.isSearchFieldVisible = true
                clipboardManager?.fetchClipboardItems(withSearchText: text.lowercased())
            }
        }
        
        // Store the new work item
        searchDispatchWorkItem = newWorkItem
        
        // Execute the work item after a delay (e.g., 300 milliseconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: newWorkItem)
    }
}

class ScrollablePasteboardItemsViewWrapper: ObservableObject {
    // MARK: - Properties
    @Published var isSearchFieldVisible: Bool = false
    
    // MARK: - Lifecycle
    init () {
        NotificationCenter.default.addObserver(self, selector: #selector(hmm(_:)), name: .isSearchFieldVisibleNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Private Methods
    @objc private func hmm (_ notification: NSNotification) {
        if let object = notification.object as? Bool {
            print(object)
            isSearchFieldVisible = object
        }
    }
}
