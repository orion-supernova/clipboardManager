//
//  MainView.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import SwiftUI
import CoreData
import AppKit
import Combine

struct MainView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @Environment(\.controlActiveState) private var controlActiveState
    @StateObject private var settings = ClipboardSettings.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    let publisher = NotificationCenter.default.publisher(for: .allItemsClearedNotification)
    
    @State private var selectedItemIndex: Int = 0
    @State private var keyMonitor: Any?
    
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
                    ScrollablePasteboardItemsView(
                        selectedItemIndex: $selectedItemIndex,
                        scrollToIndex: moveSelection
                    )
                    .environmentObject(clipboardManager)
                }
            }
            .onReceive(publisher) { _ in
                clipboardManager.clipboardItems.removeAll()
            }
            .onAppear {
                setupKeyboardMonitoring()
            }
            .onDisappear {
                removeKeyboardMonitor()
            }
            .onChange(of: settings.enableKeyboardNavigation) { newValue in
                if newValue {
                    setupKeyboardMonitoring()
                } else {
                    removeKeyboardMonitor()
                }
            }
        }
        .frame(width: screenWidth, height: screenHeight, alignment: .center)
    }
    
    private func setupKeyboardMonitoring() {
        removeKeyboardMonitor()
        
        guard settings.enableKeyboardNavigation else { return }
        
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 123: // Left Arrow
                moveSelection(direction: -1)
                return nil
            case 124: // Right Arrow
                moveSelection(direction: 1)
                return nil
            case 36: // Return/Enter
                if !clipboardManager.clipboardItems.isEmpty {
                    let index = min(selectedItemIndex, clipboardManager.clipboardItems.count - 1)
                    let item = clipboardManager.clipboardItems[index]
                    let pasteBoard = NSPasteboard.general
                    pasteBoard.clearContents()
                    pasteBoard.setString(item.contentDescriptionString, forType: .string)
                    NotificationCenter.default.post(name: .textSelectedFromClipboardNotification, object: item)
                }
                return nil
            default:
                return event
            }
        }
    }
    
    private func removeKeyboardMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    private func moveSelection(direction: Int) {
        let itemCount = clipboardManager.clipboardItems.count
        guard itemCount > 0 else { return }
        
        let newIndex = selectedItemIndex + direction
        let maxAllowedIndex = subscriptionManager.isSubscribed ? itemCount - 1 : min(2, itemCount - 1)
        
        // Check bounds and provide feedback if needed
        if newIndex < 0 || newIndex > maxAllowedIndex {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            
            // Show subscription prompt if trying to navigate beyond free tier limit
            if !subscriptionManager.isSubscribed && newIndex > 2 && newIndex < itemCount {
                showSubscriptionView()
            }
            return
        }
        
        selectedItemIndex = newIndex
    }
    
    private func showSubscriptionView() {
        WindowManager.shared.showWindow(
            id: "subscription",
            title: "Upgrade to Pro",
            view: SubscriptionView(),
            width: 400,
            height: 500
        )
    }
}

#Preview {
    MainView()
        .environmentObject(ClipboardManager.shared)
}

struct ScrollablePasteboardItemsView: View {
    
    @EnvironmentObject var clipboardManager: ClipboardManager
    @StateObject private var settings = ClipboardSettings.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var searchText = ""
    @State private var items = ["Item 1", "Item 2"]
    @FocusState private var isFocused: Bool
    @State private var isSearchFieldVisible = false
    @StateObject var wrapper = ScrollablePasteboardItemsViewWrapper()
    @State private var searchDispatchWorkItem: DispatchWorkItem?
    @Binding var selectedItemIndex: Int
    let scrollToIndex: (Int) -> Void
    
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
                            if subscriptionManager.isSubscribed {
                                clipboardManager.isSearchFieldVisible = true
                            } else {
                                showSubscriptionView()
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .opacity(subscriptionManager.isSubscribed ? 1.0 : 0.5)
                                .padding()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(subscriptionManager.isSubscribed ? "Search" : "Upgrade to Pro to use search")
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
                            ForEach(Array(clipboardManager.clipboardItems.enumerated()), id: \.element.id) { index, item in
                                ClipboardItemBox(item: item)
                                    .overlay(
                                        Group {
                                            if !subscriptionManager.isSubscribed && index >= 3 {
                                                lockedOverlay
                                            } else if settings.enableKeyboardNavigation && index == selectedItemIndex {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.blue, lineWidth: 2)
                                            }
                                        }
                                    )
                                    .onTapGesture {
                                        if !subscriptionManager.isSubscribed && index >= 3 {
                                            showSubscriptionView()
                                        } else {
                                            selectedItemIndex = index
                                            let pasteBoard = NSPasteboard.general
                                            pasteBoard.clearContents()
                                            pasteBoard.setString(item.contentDescriptionString, forType: .string)
                                            NotificationCenter.default.post(name: .textSelectedFromClipboardNotification, object: item)
                                        }
                                    }
                                    .frame(width: 300, height: 300)
                                    .id(item.id)
                            }
                        }

                    }

                }
                .onChange(of: selectedItemIndex) { newIndex in
                    if newIndex < clipboardManager.clipboardItems.count {
                        withAnimation {
                            proxy.scrollTo(clipboardManager.clipboardItems[newIndex].id, anchor: .center)
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
    
    private var lockedOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
            VStack {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                Text("Pro Feature")
                    .foregroundColor(.white)
                    .font(.headline)
            }
        }
        .cornerRadius(8)
    }
    
    private func showSubscriptionView() {
        WindowManager.shared.showWindow(
            id: "subscription",
            title: "Upgrade to Pro",
            view: SubscriptionView(),
            width: 400,
            height: 500
        )
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

// Add this class to manage navigation state
class NavigationState: ObservableObject {
    @Published var selectedItemIndex: Int = 0
}


