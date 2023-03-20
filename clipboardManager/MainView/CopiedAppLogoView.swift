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

    // MARK: - Body
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(hex: "#1F1045")
                VStack {
                    Spacer()
                    Image(nsImage: NSImage(data: (app.applicationIcon?.imageData)!)!)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: 40, alignment: .center)

                    Text(app.applicationTitle ?? "Unknown")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                    Spacer()
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
