//
//  MainView.swift
//  clipboardManager
//
//  Created by Murat Can KOÇ on 15.03.2023.
//

import SwiftUI
import CoreData

// MARK: - MainView
struct MainView: View {
    @State var tempArray: [String] = []
    @AppStorage("textArray", store: UserDefaults(suiteName: "com.walhallaa.clipboardManager")) var appStorageArrayData: Data = Data()
    @StateObject var viewModel = MainViewViewModel()
    let publisherFortempArrayChanged  = NotificationCenter.default.publisher(for: .clipboardArrayChangedNotification)
    let publisherForScrollToLastIndex = NotificationCenter.default.publisher(for: .scrollToLastIndexNotification)
    let publisherForAppBecomeActive   = NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification)

    // MARK: - Body
    var body: some View {
        ZStack {
            // MARK: - ScrollView Start
            ScrollViewReader { proxy in
                List(tempArray.isEmpty ? 0..<1 : tempArray.indices, id: \.self) { index in
                    Text(tempArray.isEmpty ? "" : "\(index + 1)")
                    Text(tempArray.isEmpty ? "No Content" : tempArray[index])
                        .font(tempArray.isEmpty ? .system(size: 30, weight: .bold, design: .monospaced) : .system(size: 13))
//                        .scaledToFit()
                        .onTapGesture {
                            let pasteBoard = NSPasteboard.general
                            pasteBoard.clearContents()
                            pasteBoard.setString(tempArray[index],forType :.string)
                            NotificationCenter.default.post(name: .textSelectedFromClipboardNotification, object: nil)
                        }
                    Color.purple
                        .frame(width: CGFloat.greatestFiniteMagnitude, height: 3, alignment: .center)
                        .id(index)
                }
                .onReceive(publisherForAppBecomeActive, perform: { output in
                    proxy.scrollTo(tempArray.count-1, anchor: .top)
                })
//                .onReceive(publisherForScrollToLastIndex, perform: { output in
//                    proxy.scrollTo(tempArray.count-1, anchor: .top)
//                })
                .scrollIndicators(.hidden)
            }
            // MARK: - ScrollView End
        }
        .frame(width: screenWidth, height: screenHeight, alignment: .center)
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

// MARK: - MainView ViewModel
class MainViewViewModel: ObservableObject {

    // MARK: - Public Properties
    @Published var stringArray = [String]()

    // MARK: - Public Actions
    @objc func tempArrayChanged(_ sender: NSNotification) {
        guard let array = sender.object as? [String] else { return }
        stringArray = array
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
