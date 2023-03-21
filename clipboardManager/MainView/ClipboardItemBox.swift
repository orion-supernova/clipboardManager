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
                VStack(spacing: 0) {
                    CopiedAppLogoView(app: item.copiedFromApplication)
                        .frame(width: geometryProxy.size.width, height: 50, alignment: .center)
                    Text(item.text.isEmpty ? "No Content" : item.text)
                        .frame(width: geometryProxy.size.width, height: geometryProxy.size.height-50)
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
            ClipboardItemBox(item: ClipboardItem(id: UUID(), text: """
DUMMY TEXT

func didChangeDataSourceForRaces() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // View model'de data yok ise empty view'ın gösterilmesi için istek fail etmiş gibi davranılır.
            guard self.viewModel.races.isEmpty == false else { return self.didFailureActiveHippodromesRequest(error: nil) }
            
            // Mevcutta gösterilen herhangi bir emty view var ise gizlenir.
            self.hideEmptyDataView()
            
            // Default olarak gizli olan komponentler data ile birlikte gözükür hale getirilir.
            self.racesTabView.isHidden = false // Hipodromların gösterildiği alan.
            
            // Set Races Datasource to tabView
            let datasource = self.viewModel.makeRaceMenuTabDatasource()
            self.racesTabView.reloadData(with: datasource)
            
            // Set Races selection item id
            let selectedRaceId = self.viewModel.getSelectedRaceIdIfAny()
            self.racesTabView.selectTab(itemId: selectedRaceId)
        }
    }
    
    func didFailureActiveHippodromesRequest(error: TJKServices.TJKError?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Empty view en üstte durduğu için altında kalan view'lar gözükmez.
            self.showEmptyDataView()
            
            // Exception var ise exceptionları göster.
            self.handleError(error)
        }
    }
    
    func setLoadingViewVisibility(_ status: Bool) {
        status ? LottieHUD.shared.show() : LottieHUD.shared.dismiss()
    }

""", copiedFromApplication: CopiedFromApplication(withApplication: NSRunningApplication())))
        }
    }
}
