//
//  MainView.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import AppKit
import Combine
import CoreData
import SwiftUI

struct MainView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @Environment(\.controlActiveState) private var controlActiveState
    @StateObject private var settings = ClipboardSettings.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    let publisher = NotificationCenter.default.publisher(for: .allItemsClearedNotification)

    @State private var keyMonitor: Any?
    @State private var searchText = ""

    // Add this to optimize view updates
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { reader in
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                    .ignoresSafeArea()

                if clipboardManager.orderedItems.isEmpty, !clipboardManager.isSearchFieldVisible {
                    EmptyStateView()
                } else {
                    ScrollablePasteboardItemsView(
                        scrollToIndex: moveSelection
                    )
                    .environmentObject(clipboardManager)
                }
            }
        }
        .frame(width: screenWidth, height: screenHeight, alignment: .center)
        // Optimize updates when window is not visible
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                // Pause expensive updates when not visible
                clipboardManager.pauseUpdates()
            } else {
                clipboardManager.resumeUpdates()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .arrowKeyPressedNotification)) {
            notification in
            if let direction = notification.object as? Int {
                moveSelection(direction: direction)
            }
        }
        // Add observer for window ready notification
        .onReceive(NotificationCenter.default.publisher(for: .windowDidBecomeReady)) { _ in
            // Force window activation and first responder status
            DispatchQueue.main.async {
                if let window = NSApplication.shared.windows.first {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    window.makeKey()
                    window.makeFirstResponder(window.contentView)
                }
            }
        }
    }

    // MARK: - MOVE SELECTION
    private func moveSelection(direction: Int) {
        let itemCount = clipboardManager.orderedItems.count
        guard itemCount > 0 else { return }

        let newIndex = clipboardManager.selectedItemIndex + direction
        let maxAllowedIndex =
            subscriptionManager.isSubscribed ? itemCount - 1 : min(2, itemCount - 1)

        if newIndex < 0 || newIndex > maxAllowedIndex {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)

            if !subscriptionManager.isSubscribed && newIndex > 2 && newIndex < itemCount {
                showSubscriptionView()
            }
            return
        }

        clipboardManager.updateSelection(newIndex)
    }

    private func showSubscriptionView() {
        NotificationCenter.default.post(
            name: .showSubscriptionViewNotification,
            object: nil
        )
    }
}

// Extract EmptyStateView for better performance
struct EmptyStateView: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color.purple.opacity(0.5),
                    Color.black.opacity(1),
                ], center: .center, startRadius: 1, endRadius: 450
            )
            .ignoresSafeArea()
            Text("No Clipboard Items")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
        }
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
    @State private var isHandlingVisibilityChange = false

    @State private var isScrolling = false
    @State private var scrollDebouncer: Timer?

    let scrollToIndex: (Int) -> Void

    private func clipboardItemView(item: ClipboardItem, index: Int) -> some View {
        ClipboardItemBox(item: item)
            .overlay(
                Group {
                    if !subscriptionManager.isSubscribed && index >= 3 {
                        lockedOverlay
                    } else if settings.enableKeyboardNavigation && index == clipboardManager.selectedItemIndex {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 2)
                    }
                }
            )
            .onTapGesture {
                handleItemTap(item: item, index: index)
            }
            .frame(width: 300, height: 300)
            .id(item.id)
            .onAppear {
                clipboardManager.preloadItem(item)
            }
            .onDisappear {
                clipboardManager.unloadItem(item)
            }
    }

    // MARK: - HANDLE TAP ITEM
    private func handleItemTap(item: ClipboardItem, index: Int) {
        if !subscriptionManager.isSubscribed && index >= 3 {
            showSubscriptionView()
        } else {
            // Update selection through ClipboardManager
            clipboardManager.updateSelection(index)
            
            // Copy to pasteboard and notify
            copyItemToPasteboard(item)
            NotificationCenter.default.post(
                name: .textSelectedFromClipboardNotification, object: nil)
        }
    }

    private func copyItemToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .file, .video:
            if let fileURL = item.fileURL {
                pasteboard.writeObjects([fileURL as NSURL])
            }
        case .image:
            if let fileURL = item.fileURL,
                let image = NSImage(contentsOf: fileURL)
            {
                pasteboard.writeObjects([image])
            }
        default:
            if let string = String(data: item.content, encoding: .utf8) {
                pasteboard.setString(string, forType: .string)
            }
        }
    }

    var body: some View {
        VStack {
            ZStack {
                HStack {
                    Spacer()
                        .frame(width: 10)

                    Button {
                        NotificationCenter.default.post(
                            name: .preferencesClickedNotification, object: nil)
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
                                    gradient: Gradient(colors: [
                                        Color.purple, Color.black.opacity(0.5),
                                    ]),
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
                            guard !searchText.isEmpty else {
                                clipboardManager.isSearchFieldVisible = false
                                return
                            }
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
                        .help(
                            subscriptionManager.isSubscribed
                                ? "Search" : "Upgrade to Pro to use search")
                    }
                }
            }
            .frame(width: screenWidth, height: 70)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        Spacer()
                            .frame(width: 5)

                        if clipboardManager.clipboardItems.isEmpty
                            && clipboardManager.isSearchFieldVisible
                        {
                            emptySearchResultView
                        } else {
                            ForEach(Array(clipboardManager.orderedItems.enumerated()), id: \.1.id) {
                                index, item in
                                clipboardItemView(item: item, index: index)
                                    .id(item.id)
                                    .frame(width: 300, height: 300)
                                    .layoutPriority(1)
                            }
                        }
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSScrollView.willStartLiveScrollNotification)
                ) { _ in
                    handleScrollStart()
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSScrollView.didEndLiveScrollNotification)
                ) { _ in
                    handleScrollEnd()
                }
                .onChange(of: clipboardManager.selectedItemIndex) { _ in
                    if clipboardManager.selectedItemIndex < clipboardManager.orderedItems.count {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            let item = clipboardManager.orderedItems[clipboardManager.selectedItemIndex]
                            proxy.scrollTo(item.id, anchor: .center)
                        }
                    }
                }

            }
        }
        .onChange(of: clipboardManager.selectedItemIndex) { newValue in
            print("ScrollablePasteboardItemsView detected selectedItemIndex change to:", newValue)
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

    private var emptySearchResultView: some View {
        HStack {
            Spacer()
            Text("No items found contains ''\(searchText)''")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(width: screenWidth)
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
        NotificationCenter.default.post(
            name: .showSubscriptionViewNotification,
            object: nil
        )
    }

    private func handleScrollStart() {
        isScrolling = true
        clipboardManager.pauseUpdates()
        scrollDebouncer?.invalidate()

        // Immediately cancel any pending image loads
        NotificationCenter.default.post(name: .cancelImageLoadsNotification, object: nil)
    }

    private func handleScrollEnd() {
        scrollDebouncer?.invalidate()
        scrollDebouncer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            DispatchQueue.main.async {
                isScrolling = false
                clipboardManager.resumeUpdates()
            }
        }
    }
}

class ScrollablePasteboardItemsViewWrapper: ObservableObject {
    // MARK: - Properties
    @Published var isSearchFieldVisible: Bool = false

    // MARK: - Lifecycle
    init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(hmm(_:)), name: .isSearchFieldVisibleNotification, object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Private Methods
    @objc private func hmm(_ notification: NSNotification) {
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
