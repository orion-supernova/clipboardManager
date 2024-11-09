//
//  ClipboardItemBox.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 17.03.2023.
//

import SwiftUI
import AppKit

struct ClipboardItemBox: View, Equatable {
    var item: ClipboardItem
    @EnvironmentObject var clipboardManager: ClipboardManager
    @State private var thumbnail: NSImage?

    static func == (lhs: ClipboardItemBox, rhs: ClipboardItemBox) -> Bool {
        lhs.item == rhs.item
    }
    
    init(item: ClipboardItem) {
        self.item = item
    }
    var body: some View {
        ZStack {
            Color.black
            VStack {
                CopiedAppLogoView(app: item.copiedFromApplication)
                    .frame(height: 50)
                
                Spacer()
                
                getCopiedItemView(for: item)
                
                Spacer()
            }
        }
        .cornerRadius(10)
        .contextMenu {
            Button(action: {
                clipboardManager.deleteClipboardItem(withId: item.id)
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    func getCopiedItemView(for item: ClipboardItem) -> some View {
        switch item.type {
        case .color:
            return AnyView(
                ZStack {
                    Color(nsColor: detectColor(from: item.contentDescriptionString)!)
                    Text("Color: \(item.contentDescriptionString)")
                        .font(.title)
                }
                    .ignoresSafeArea()
            )
        case .text:
            return AnyView(
                Text(item.contentDescriptionString.isEmpty ? "#No Content#" : item.contentDescriptionString)
                    .foregroundColor(Color.random())
                    .font(item.contentDescriptionString.isEmpty ? .system(
                        size: 30,
                        weight: .bold,
                        design: .monospaced) : .system(size: 13))
            )
        case .image:
            return AnyView(
                VStack(spacing: 8) {
                    if let fileURL = item.fileURL {
                        LazyImageView(url: fileURL)
                            .frame(maxWidth: 250, maxHeight: 200)
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "photo.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 64, height: 64)
                                .foregroundColor(.gray)
                            
                            Text("Unable to load image")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if !item.contentDescriptionString.isEmpty {
                        Text(item.contentDescriptionString)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 10)
            )
        case .url:
            if let url = URL(dataRepresentation: item.content, relativeTo: nil) {
                return AnyView(
                    GeometryReader { geometry in
                        HStack {
                            Spacer()
                            URLPreview(url: url)
                                .frame(width: geometry.size.width-20, height: geometry.size.height, alignment: .center)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Spacer()
                        }
                    }
                    .frame(height: 230)
                )
            } else {
                return AnyView(
                    Text("Invalid URL")
                        .foregroundColor(Color.red)
                        .font(.system(size: 13))
                )
            }
        case .video:
            return AnyView(
                VStack {
                    Text(item.contentDescriptionString)
                        .frame(height: 20)
                    
                    if let thumbnailURL = item.thumbnailURL {
                        AsyncImageView(url: thumbnailURL)
                            .frame(maxWidth: 180, maxHeight: 180)
                            .overlay(
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white)
                            )
                    } else {
                        Image(systemName: "video")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 180, maxHeight: 180)
                    }
                }
            )
        
        case .file:
            return AnyView(
                VStack(spacing: 8) {
                    if let url = item.fileURL {
                        let icon = NSWorkspace.shared.icon(forFile: url.path)
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 60, maxHeight: 60)
                        
                        Text(url.lastPathComponent)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "doc")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 60, maxHeight: 60)
                            .foregroundColor(.gray)
                        
                        Text("File not available")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 8)
            )
        }
    }
    
}

// Add this helper view for async image loading
struct AsyncImageView: View {
    let url: URL
    @State private var image: NSImage?
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .drawingGroup() // Enable Metal rendering
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: 180, maxHeight: 180)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 180, maxHeight: 180)
            }
        }
        .onAppear {
            loadImage()
        }
        .onDisappear {
            // Clear memory when view disappears
            image = nil
        }
    }
    
    private func loadImage() {
        guard image == nil, !url.absoluteString.isEmpty else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                do {
                    let imageData = try Data(contentsOf: url)
                    if let image = NSImage(data: imageData) {
                        let resizedImage = image.resized(to: NSSize(width: 180, height: 180))
                        DispatchQueue.main.async {
                            self.image = resizedImage
                            self.isLoading = false
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.isLoading = false
                            print("[ERROR] Could not create image from data")
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.error = error
                        self.isLoading = false
                        print("[ERROR] Failed to load image: \(error)")
                    }
                }
            }
        }
    }
}

// Add this new view for lazy loading
struct LazyImageView: View {
    let url: URL
    @State private var image: NSImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Image(systemName: "photo.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            loadImage()
        }
        .onDisappear {
            // Clear memory when view disappears
            image = nil
        }
    }
    
    private func loadImage() {
        guard image == nil else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                if let image = NSImage(contentsOf: url) {
                    DispatchQueue.main.async {
                        self.image = image
                        self.isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            }
        }
    }
}
