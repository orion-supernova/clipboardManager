//
//  ContentView.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @State var tempArray: [String] = []
    @AppStorage("textArray", store: UserDefaults(suiteName: "com.walhallaa.clipboardManager")) var appStorageArrayData: Data = Data()

    var body: some View {
        ZStack {
            List(tempArray, id: \.self) { item in
                Text(item)
                Color.purple
                    .frame(width: CGFloat.greatestFiniteMagnitude, height: 3, alignment: .center)
            }
        }
        .onAppear(perform: {
            tempArray = Storage.loadStringArray(data: appStorageArrayData)
        })
        .navigationTitle("Haydarinna rinna rinanay")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
