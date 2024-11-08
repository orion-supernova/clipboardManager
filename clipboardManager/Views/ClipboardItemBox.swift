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
                VStack {
                    Text(item.contentDescriptionString)
                        .frame(height: 20)
                    
                    if let fileURL = item.fileURL {
                        AsyncImageView(url: fileURL)
                            .frame(maxWidth: 180, maxHeight: 180)
                    } else if let nsImage = NSImage(data: item.content) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 180, maxHeight: 180)
                    } else {
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 180, maxHeight: 180)
                    }
                }
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
    }
    
    private func loadImage() {
        guard !url.absoluteString.isEmpty else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                do {
                    let imageData = try Data(contentsOf: url)
                    if let image = NSImage(data: imageData) {
                        DispatchQueue.main.async {
                            self.image = image
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

#Preview {
    let url = URL(string: "https://www.youtube.com")
    let data = url?.dataRepresentation
    return ClipboardItemBox(item: ClipboardItem(id: UUID(), type: .url, content: data!, copiedFromApplication: .init(withApplication: NSRunningApplication()), timestamp: Date(), contentDescriptionString: "", fileURL: nil))
}
