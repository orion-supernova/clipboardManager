//
//  CopiedAppLogoView.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 17.03.2023.
//

import SwiftUI

struct CopiedAppLogoView: View {

    // MARK: - Public Properties
    let app: CopiedFromApplication

    // MARK: - Lifecycle
    init(app: CopiedFromApplication) {
        self.app = app
    }
    let viewModel = CopiedAppLogoViewModel()

    // MARK: - Body
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(hex: "#1F1045")
                VStack {
                    Spacer()
                        .frame(width: proxy.size.width, height: 5)
                    HStack {
                        Spacer()
                            .frame(width: 10, height: proxy.size.height)
                        Text("From: \(app.applicationTitle ?? "Mahmut Clipboard")")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                        Spacer()
//                            .frame(width: 30, height: proxy.size.height)
                        Image(nsImage: viewModel.getImage(for: app.applicationTitle ?? ""))
                            .resizable()
                            .scaledToFit()
                            .frame(height: proxy.size.height)
                            .clipped()
                        Spacer()
                            .frame(width: 10, height: proxy.size.height)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

struct CopiedAppLogoView_Previews: PreviewProvider {
    static var previews: some View {
        CopiedAppLogoView(app: CopiedFromApplication(withApplication: NSRunningApplication()))
    }
}

class CopiedAppLogoViewModel {
    func getImage(for imageURLString: String) -> NSImage {
        var image = NSImage(named: "AppIcon")!
//        var image = NSImage(systemSymbolName: "folder", accessibilityDescription: "")!
        guard !imageURLString.isEmpty else { return image }

        StorageHelper.getImageFromDisk(for: imageURLString) { exists, newImage in
            guard exists else { return }
            image = newImage!
        }
        return image
    }
}
