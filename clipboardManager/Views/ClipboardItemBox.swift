//
//  ClipboardItemBox.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 17.03.2023.
//

import SwiftUI

struct ClipboardItemBox: View {
    var item: ClipboardItem
    @EnvironmentObject var clipboardManager: ClipboardManager
    
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
                    if let nsImage = NSImage(data: item.content) {
                        if !item.contentDescriptionString.isEmpty {
                            Text(item.contentDescriptionString)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        
                        // Check if it's a file icon
                        if nsImage.size.width <= 32 && nsImage.size.height <= 32 {
                            // It's likely a file icon
                            VStack(spacing: 12) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 64, height: 64)
                                
                                if let fileExtension = item.contentDescriptionString.split(separator: ".").last {
                                    Text(".\(fileExtension)")
                                        .font(.system(size: 14, design: .monospaced))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                        } else {
                            // It's a regular image
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 250, maxHeight: 200)
                                .cornerRadius(8)
                        }
                    } else {
                        // Try to get file icon if it's a file path
                        if let filePath = String(data: item.content, encoding: .utf8) {
                            let workspace = NSWorkspace.shared
                            let icon = workspace.icon(forFile: filePath)
                            let url = URL(fileURLWithPath: filePath)
                            VStack(spacing: 12) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 64, height: 64)
                                
                                if !url.pathExtension.isEmpty {
                                    Text(".\(url.pathExtension)")
                                        .font(.system(size: 14, design: .monospaced))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                        } else {
                            Image(systemName: "doc.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 64, maxHeight: 64)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 10)
            )
        case .url:
            if let url = URL(dataRepresentation: item.content, relativeTo: nil) {
                return AnyView(
                    GeometryReader { geometry in
                        VStack(spacing: 8) {
                            URLPreview(url: url)
                                .frame(
                                    width: min(geometry.size.width - 20, 280),
                                    height: 160
                                )
                                .cornerRadius(8)
                            
                            Text(url.absoluteString)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
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

#Preview {
    let url = URL(string: "https://www.youtube.com")
    let data = url?.dataRepresentation
    return ClipboardItemBox(item: ClipboardItem(id: UUID(), type: .url, content: data!, copiedFromApplication: .init(withApplication: NSRunningApplication()), timestamp: Date(), contentDescriptionString: ""))
}

enum ClipboardContentType {
    case text
    case color
    case image
    case url
    case code
    case empty
    
    static func detect(from item: ClipboardItem) -> ClipboardContentType {
        // Empty content check
        if item.contentDescriptionString.isEmpty && item.content.isEmpty {
            return .empty
        }
        
        // URL detection
        if let _ = URL(dataRepresentation: item.content, relativeTo: nil) {
            return .url
        }
        
        // Color detection
        if let _ = detectColor(from: item.contentDescriptionString) {
            return .color
        }
        
        // Image detection
        if let nsImage = NSImage(data: item.content),
           nsImage.isValid {
            return .image
        }
        
        // Code detection (basic)
        if item.contentDescriptionString.contains("{") ||
           item.contentDescriptionString.contains("}") ||
           item.contentDescriptionString.contains("func ") ||
           item.contentDescriptionString.contains("class ") ||
           item.contentDescriptionString.contains("struct ") {
            return .code
        }
        
        return .text
    }
}

