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
        GeometryReader { reader in
            ZStack {
                VStack {
                    Spacer()
                        .frame(width: reader.size.width, height: 17, alignment: .center)
                    // MARK: - ScrollView Start
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                Spacer()
                                ForEach(tempArray.isEmpty ? 0..<1 : tempArray.reversed().indices, id: \.self) { index in
                                    HStack {
                                        ClipboardItemBox(stringArray: tempArray.reversed(), itemIndex: index)
                                            .onTapGesture {
                                                if !tempArray.isEmpty {
                                                    let pasteBoard = NSPasteboard.general
                                                    pasteBoard.clearContents()
                                                    pasteBoard.setString(tempArray.reversed()[index],forType :.string)
                                                    NotificationCenter.default.post(name: .textSelectedFromClipboardNotification, object: nil)
                                                }
                                            }
                                            .frame(width: 270, height: 280)
                                            .id(index)
                                    }
                                }
                            }
                        }
                        .onReceive(publisherForAppBecomeActive, perform: { output in
                            proxy.scrollTo(0, anchor: .trailing)
                        })
                        .scrollIndicators(.hidden)
                    }
                    // MARK: - ScrollView End
                }
            }
        }
        .background {
            VisualEffectView(material: .popover, blendingMode: .withinWindow)
                .ignoresSafeArea()
        }
        .frame(width: screenWidth, height: screenHeight, alignment: .center)
        .onAppear {
            tempArray = StorageHelper.loadStringArray(data: appStorageArrayData)
        }
        .onReceive(publisherFortempArrayChanged, perform: { output in
            print(output)
            tempArray = output.object as? [String] ?? []
        })
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
