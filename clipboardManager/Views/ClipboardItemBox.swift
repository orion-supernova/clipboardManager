//
//  ClipboardItemBox.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 17.03.2023.
//

import SwiftUI
import AppKit

struct ClipboardItemBox: View {
    var item: ClipboardItem
    @EnvironmentObject var clipboardManager: ClipboardManager
    @State private var thumbnail: NSImage?
    @State private var isLoading = true
    
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
                withAnimation(.easeOut(duration: 0.2)) {
                    clipboardManager.deleteClipboardItem(withId: item.id)
                }
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    func getCopiedItemView(for item: ClipboardItem) -> some View {
        switch item.type {
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
                        LazyImageView(url: thumbnailURL)
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

// Add this optimized image loading view
struct LazyImageView: View {
    let url: URL
    @State private var image: NSImage?
    @State private var isLoading = true
    @State private var isVisible = false
    private static var imageCache = NSCache<NSURL, NSImage>()
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image(systemName: "photo.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            isVisible = true
            if let cachedImage = Self.imageCache.object(forKey: url as NSURL) {
                self.image = cachedImage
                self.isLoading = false
            } else {
                loadImageIfNeeded()
            }
        }
        .onDisappear {
            isVisible = false
            cancelLoad()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cancelImageLoadsNotification)) { _ in
            cancelLoad()
        }
    }
    
    private func cancelLoad() {
        image = nil
        isLoading = true
        isVisible = false
    }
    
    private func loadImageIfNeeded() {
        guard image == nil, isVisible else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [isVisible] in
            guard isVisible else { return }
            loadImage()
        }
    }
    
    private func loadImage() {
        guard image == nil else { return }
        
        DispatchQueue.global(qos: .utility).async {
            autoreleasepool {
                guard isVisible else { return }
                guard let originalImage = NSImage(contentsOf: url) else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                guard isVisible else { return }
                let resizedImage = resizeImage(originalImage, targetSize: NSSize(width: 250, height: 200))
                Self.imageCache.setObject(resizedImage, forKey: url as NSURL)
                
                DispatchQueue.main.async {
                    guard isVisible else { return }
                    self.image = resizedImage
                    self.isLoading = false
                }
            }
        }
    }
    
    private func resizeImage(_ image: NSImage, targetSize: NSSize) -> NSImage {
        let targetRect = NSRect(origin: .zero, size: targetSize)
        let newImage = NSImage(size: targetSize)
        
        newImage.lockFocus()
        image.draw(in: targetRect, from: .zero, operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        
        return newImage
    }
}

// Add this notification name
extension NSNotification.Name {
    static let cancelImageLoadsNotification = NSNotification.Name("cancelImageLoadsNotification")
}
