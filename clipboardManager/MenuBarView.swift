//
//  MenuBarView.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//


import SwiftUI

struct MenuBarView: View {
    var body: some View {
        List {
            ForEach(1...100, id: \.self) { item in
//                NSMenuItem(title: "hm",
//                                                  action: #selector(action),
//                                                  keyEquivalent: "")
//                clearAllMenuItem.target = target
//                menu.addItem(clearAllMenuItem)
            }
        }
    }
}
//
//struct JokeView_Previews: PreviewProvider {
//    static var previews: some View {
//        MenuBarView(menu: NSMenu(), action: Selector(""), target: ApplicationMenu())
//            .frame(width: 225, height: 225)
//    }
//}
