//
//  ClipboardItemBox.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 17.03.2023.
//

import SwiftUI

struct ClipboardItemBox: View {
    var item: ClipboardItem
    init(item: ClipboardItem) {
        self.item = item
    }
    var body: some View {
        GeometryReader { geometryProxy in
            ZStack {
                VStack {
                    CopiedAppLogoView(app: item.copiedFromApplication)
                        .frame(width: geometryProxy.size.width, height: 50, alignment: .center)
//                    Spacer()
//                        .frame(width: geometryProxy.size.width, height: 20, alignment: .center)
//                    Text(clipboardItemArray.isEmpty ? "" : "\(itemIndex + 1)")
                    Spacer()
                    Text(item.text.isEmpty ? "No Content" : item.text)
                        .foregroundColor(Color.random())
                        .font(item.text.isEmpty ? .system(size: 30, weight: .bold, design: .monospaced) : .system(size: 13))
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
            ClipboardItemBox(item: ClipboardItem(id: UUID(), text: "hmm", copiedFromApplication: CopiedFromApplication(withApplication: NSRunningApplication())))
        }
    }
}
