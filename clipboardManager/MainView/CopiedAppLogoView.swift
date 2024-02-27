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
//                    Spacer()
                    HStack {
                        Spacer()
                            .frame(width: 5)
                        Text("From: \(app.applicationTitle ?? "Mahmut Clipboard")")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                        Spacer()
                        Image(nsImage: viewModel.getImage(for: app.applicationTitle ?? ""))
                            .resizable()
                            .scaledToFit()
                        Spacer()
                            .frame(width: 5)
                    }
//                    Spacer()
                }
            }
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
