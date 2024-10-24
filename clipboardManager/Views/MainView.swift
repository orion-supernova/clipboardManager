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
                }
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
        .environmentObject(ClipboardManager(persistenceController: PersistenceController.shared))
}

struct ScrollablePasteboardItemsView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @State private var searchText = ""
    @State private var items = ["Item 1", "Item 2"]
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack {
            ZStack {
                HStack {
                    Spacer()
                        .frame(width: 10)
                    
                    Button {
                        print("hmm")
                    } label: {
                        Image(systemName: "ellipsis")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15)
                    }
                    Spacer()
                }
                
                //                Color.secondary
                //                    .opacity(0.06)
                //                    .frame(maxWidth: 900, maxHeight: 60)
                //                    .clipShape(RoundedRectangle(cornerRadius: 10))
                HStack {
                    //                    ScrollViewReader { proxy in
                    //                        ScrollView(.horizontal, showsIndicators: true) {
                    //                            LazyHStack(spacing: 10) {
                    //                                ForEach(0..<32) { item in
                    //                                    Button(action: {
                    //                                        print("\(item) clicked")
                    //                                    }, label: {
                    //                                        Text("\(item)")
                    //                                            .padding()
                    //                                            .frame(width: 150, height: 40)
                    //                                            .foregroundStyle(Color.white)
                    //                                            .background(Color.red)
                    //                                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    //                                    })
                    //                                    .buttonStyle(PlainButtonStyle())
                    //                                }
                    //                            }
                    //                        }
                    //                    }
                    
                    
                    
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
                            DispatchQueue.global(qos: .background).async {
                                //                                clipboardManager.fetchClipboardItems()
                                DispatchQueue.main.async {
                                    searchText = ""
                                    clipboardManager.isSearchFieldVisible = false
                                }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 10, height: 10)
                        }
                        VStack {
                            TextField("Search", text: $searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 200, height: 20)
                                .padding(.horizontal, 5)
                                .focused($isFocused)
                                .onChange(of: searchText) { newValue in
                                    guard !newValue.isEmpty else { clipboardManager.isSearchFieldVisible = false; clipboardManager.fetchClipboardItems(); return }
                                    clipboardManager.fetchClipboardItems(withSearchText: searchText.lowercased())
                                }
                                .onAppear {
                                    isFocused = true
                                }
                        }
                        
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
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification)) { _ in
                    proxy.scrollTo(clipboardManager.clipboardItems.first?.id, anchor: .trailing)
                }
            }
            .onDisappear {
                clipboardManager.isSearchFieldVisible = false
            }
        }
    }
}
