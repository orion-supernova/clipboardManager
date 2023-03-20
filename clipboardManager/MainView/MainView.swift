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
    @AppStorage("hmArray", store: UserDefaults(suiteName: "com.walhallaa.clipboardManager")) var appStorageArrayData: Data = Data()
    @ObservedObject var viewModel = MainViewViewModel()
    let publisherFortempArrayChanged  = NotificationCenter.default.publisher(for: .clipboardArrayChangedNotification)
    let publisherForClipBoardCleared  = NotificationCenter.default.publisher(for: .clipboardArrayClearedNotification)
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
                                ForEach(viewModel.clipboardItemArray.isEmpty ? viewModel.emptyArray : viewModel.clipboardItemArray.reversed(), id: \.id) { item in
                                    HStack {
                                        ClipboardItemBox(item: item)
                                            .onTapGesture {
                                                if !viewModel.clipboardItemArray.isEmpty {
                                                    let pasteBoard = NSPasteboard.general
                                                    pasteBoard.clearContents()
                                                    pasteBoard.setString(item.text,forType :.string)
                                                    NotificationCenter.default.post(name: .textSelectedFromClipboardNotification, object: nil)
                                                }
                                            }
                                            .frame(width: 270, height: 280)
                                            .id(item.id)
                                    }
                                }
                            }
                        }
                        .onReceive(publisherForAppBecomeActive, perform: { output in
                            proxy.scrollTo(viewModel.clipboardItemArray.last?.id, anchor: .trailing)
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
            viewModel.clipboardItemArray = StorageHelper.loadStringArray(data: appStorageArrayData)
        }
        .onReceive(publisherFortempArrayChanged, perform: { output in
            let newString = output.object as? String ?? ""
            viewModel.clipboardItemArray.append(ClipboardItem(id: UUID(), text: newString))
            print("[DEBUG] added String -> \(newString)")
        })
        .onReceive(publisherForClipBoardCleared, perform: { output in
            viewModel.clipboardItemArray = []
            print("[DEBUG] All Items Deleted!")
        })
    }
}



// MARK: - MainView ViewModel
class MainViewViewModel: ObservableObject {
    // MARK: - Public Properties
    @Published var clipboardItemArray = [ClipboardItem]()
    var emptyArray = [ClipboardItem(id: UUID(), text: "")]
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
