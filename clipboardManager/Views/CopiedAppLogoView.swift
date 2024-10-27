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
//                Color(hex: "#1F1045")
                LinearGradient(colors: [
                    Color.black
                        .opacity(1),
                    Color.purple
                        .opacity(0.5)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack {
                    HStack {
                        Spacer()
                            .frame(width: 5)
                        Text("From: \(app.applicationTitle ?? "Mahmut Clipboard")")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                        Spacer()
                        Image(nsImage: app.getApplication()?.icon ?? NSImage(named: "AppIcon")!)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(10)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct CopiedAppLogoView_Previews: PreviewProvider {
    static var previews: some View {
        CopiedAppLogoView(app: CopiedFromApplication(withApplication: NSRunningApplication()))
    }
}
