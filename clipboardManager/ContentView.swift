//
//  ContentView.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import SwiftUI
import CoreData

// MARK: - ContentView
struct ContentView: View {
    @State var tempArray: [String] = []
    @AppStorage("textArray", store: UserDefaults(suiteName: "com.walhallaa.clipboardManager")) var appStorageArrayData: Data = Data()
    @StateObject var viewModel = ContentViewViewModel()
    let publisher = NotificationCenter.default.publisher(for: NSNotification.Name("tempArrayChanged"))

    // MARK: - Body
    var body: some View {
        ZStack {
            if tempArray.isEmpty {
                Text("No Content")
                    .frame(width: 300, height: 300, alignment: .center)

            } else {
                ZStack {
                    List(tempArray, id: \.self) { item in
                        Text(item)
                            .onTapGesture {
                                let pasteBoard = NSPasteboard.general
                                pasteBoard.clearContents()
                                pasteBoard.setString(item,forType :.string)
                            }
                        Color.purple
                            .frame(width: CGFloat.greatestFiniteMagnitude, height: 3, alignment: .center)
                    }
                }
                .frame(width: 500, height: 500, alignment: .center)
            }
        }
        .onAppear {
            tempArray = StorageHelper.loadStringArray(data: appStorageArrayData)
        }
        .onReceive(publisher, perform: { output in
            print(output)
            tempArray = output.object as? [String] ?? []
        })
        .navigationTitle(tempArray.isEmpty ? "Zuhahahaha" : "Haydarinna rinna rinanay")
    }
}

// MARK: - ContentView ViewModel
class ContentViewViewModel: ObservableObject {
    @Published var stringArray = [String]()
    @objc func tempArrayChanged(_ sender: NSNotification) {
        guard let array = sender.object as? [String] else { return }
        stringArray = array
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
