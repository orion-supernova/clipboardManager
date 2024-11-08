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
            print("Image data size: \(item.content.count) bytes")
            if let nsImage = NSImage(data: item.content) {
                print("NSImage size: \(nsImage.size)")
                if let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    print("CGImage size: \(CGSize(width: cgImage.width, height: cgImage.height))")
                }
                return AnyView(
                    VStack {
                        Text(item.contentDescriptionString)
                            .frame(height: 20)
                            
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 180, maxHeight: 180)
                    }
                    
                )
            } else {
                return AnyView(
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 180, maxHeight: 180)
                )
            }
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

#Preview {
    let url = URL(string: "https://www.youtube.com")
    let data = url?.dataRepresentation
    return ClipboardItemBox(item: ClipboardItem(id: UUID(), type: .url, content: data!, copiedFromApplication: .init(withApplication: NSRunningApplication()), timestamp: Date(), contentDescriptionString: ""))
}
