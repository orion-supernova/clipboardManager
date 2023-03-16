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
    let publisherFortempArrayChanged  = NotificationCenter.default.publisher(for: .clipboardArrayChangedNotification)
    let publisherForScrollToLastIndex = NotificationCenter.default.publisher(for: .scrollToLastIndexNotification)

    // MARK: - Body
    var body: some View {
        ZStack {
            // MARK: - EmptyView
            if tempArray.isEmpty {
                Text("No Content")
                    .frame(width: screenWidth, height: screenHeight, alignment: .center)

            } else {
                ZStack {
                    // MARK: - ScrollView Start
                    ScrollViewReader { proxy in
                        List(tempArray.indices, id: \.self) { index in
                            Text("\(index+1)")
                            Text(tempArray[index])
                                .id(index)
                                .onTapGesture {
                                    let pasteBoard = NSPasteboard.general
                                    pasteBoard.clearContents()
                                    pasteBoard.setString(tempArray[index],forType :.string)
                                }
                            Color.purple
                                .frame(width: CGFloat.greatestFiniteMagnitude, height: 3, alignment: .center)
                        }
                        .onReceive(publisherForScrollToLastIndex, perform: { output in
                            proxy.scrollTo(tempArray.count-1, anchor: .top)
                        })
                        .scrollIndicators(.hidden)
                    }
                    // MARK: - ScrollView End
                }
                .frame(width: screenWidth, height: screenHeight, alignment: .center)
            }
        }
        .cornerRadius(30)
        .onAppear {
            tempArray = StorageHelper.loadStringArray(data: appStorageArrayData)
        }
        .onReceive(publisherFortempArrayChanged, perform: { output in
            print(output)
            tempArray = output.object as? [String] ?? []
        })
        .navigationTitle(tempArray.isEmpty ? "Zuhahahaha" : "Haydarinna rinna rinanay")
    }
}

// MARK: - ContentView ViewModel
class ContentViewViewModel: ObservableObject {

    // MARK: - Public Properties
    @Published var stringArray = [String]()

    // MARK: - Public Actions
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
