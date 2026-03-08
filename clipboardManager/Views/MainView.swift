//
//  MainView.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    @Environment(\.controlActiveState) private var controlActiveState
    let publisher = NotificationCenter.default.publisher(for: .allItemsClearedNotification)
    var body: some View {
        GeometryReader { reader in
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                    .ignoresSafeArea()
                
                if viewModel.items.isEmpty, viewModel.isSearchFieldVisible == false {
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
                        .environmentObject(viewModel)
                }
            }
            .onReceive(publisher) { _ in
                viewModel.items.removeAll()
            }
        }
        .frame(width: screenWidth, height: screenHeight, alignment: .center)
    }
}

#Preview {
    MainView()
        .environmentObject(
            ClipboardViewModel(
                repository: ClipboardRepository(context: PersistenceController.shared.container.viewContext),
                clipboardService: ClipboardService(
                    repository: ClipboardRepository(context: PersistenceController.shared.container.viewContext),
                    settings: SettingsStore()
                ),
                settings: SettingsStore()
            )
        )
}

struct ScrollablePasteboardItemsView: View {
    
    @EnvironmentObject var viewModel: ClipboardViewModel

    @State private var searchText = ""
    @FocusState private var isFocused: Bool
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
                    if viewModel.isSearchFieldVisible {
                        Button {
                            guard !searchText.isEmpty else { viewModel.isSearchFieldVisible = false; return }
                            DispatchQueue.main.async {
                                searchText = ""
                                viewModel.isSearchFieldVisible = false
                                viewModel.refresh()
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
                            viewModel.isSearchFieldVisible = true
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
                        
                        if viewModel.items.isEmpty, viewModel.isSearchFieldVisible {
                            HStack {
                                Spacer()
                                Text("No items found contains ''\(searchText)''")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .frame(width: screenWidth)
                        } else {
                            ForEach(viewModel.items) { item in
                                ClipboardItemBox(item: item)
                                    .onTapGesture {
                                        viewModel.selectItem(item)
                                    }
                                    .frame(width: 300, height: 300)
                                    .id(item.id)
                            }
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification)) { _ in
                    proxy.scrollTo(viewModel.items.first?.id, anchor: .trailing)
                }
            }
        }
    }
    private func debounceSearch(text: String) {
        searchDispatchWorkItem?.cancel()
        let newWorkItem = DispatchWorkItem { [weak viewModel] in
            if text.isEmpty {
                viewModel?.isSearchFieldVisible = false
                viewModel?.refresh()
            } else {
                viewModel?.isSearchFieldVisible = true
                viewModel?.search(text.lowercased())
            }
        }
        searchDispatchWorkItem = newWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: newWorkItem)
    }
}
