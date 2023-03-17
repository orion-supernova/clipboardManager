//
//  ClipboardItemBox.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 17.03.2023.
//

import SwiftUI

struct ClipboardItemBox: View {
    var stringArray: [String]
    var itemIndex: Int
    init(stringArray: [String], itemIndex: Int) {
        self.stringArray    = stringArray
        self.itemIndex      = itemIndex
    }
    var body: some View {
        GeometryReader { geometryProxy in
            ZStack {
                VStack {
                    CopiedAppLogoView()
                        .frame(width: geometryProxy.size.width, height: 50, alignment: .center)
//                    Spacer()
//                        .frame(width: geometryProxy.size.width, height: 20, alignment: .center)
//                    Text(stringArray.isEmpty ? "" : "\(itemIndex + 1)")
                    Spacer()
                    Text(stringArray.isEmpty ? "No Content" : stringArray[itemIndex])
                        .foregroundColor(Color.random())
                        .font(stringArray.isEmpty ? .system(size: 30, weight: .bold, design: .monospaced) : .system(size: 13))
                    Spacer()
                }
                .background {
                    Color.black
                }
            }
            .cornerRadius(5)
        }
    }
}

struct ClipboardItemBox_Previews: PreviewProvider {
    static var previews: some View {
        GeometryReader { proxy in
            ClipboardItemBox(stringArray: ["HMM"], itemIndex: 0)
        }
    }
}
