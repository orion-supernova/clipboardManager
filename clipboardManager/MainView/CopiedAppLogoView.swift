//
//  CopiedAppLogoView.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 17.03.2023.
//

import SwiftUI

struct CopiedAppLogoView: View {
    var body: some View {
        ZStack {
            Color(hex: "#1F1045")
            Text("App Unknown")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
        }
    }
}

struct CopiedAppLogoView_Previews: PreviewProvider {
    static var previews: some View {
        CopiedAppLogoView()
    }
}
