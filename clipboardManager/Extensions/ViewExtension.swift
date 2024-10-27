//
//  ViewExtension.swift
//  clipboardManager
//
//  Created by muratcankoc on 29/08/2024.
//

import SwiftUI

    // MARK: UI Design Helper functions
extension View {
    func hLeading() -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading)
    }
    func hTrailing() -> some View {
        self.frame(maxWidth: .infinity, alignment: .trailing)
    }
    func hCenter() -> some View {
        self.frame(maxWidth: .infinity, alignment: .center)
    }
    func vLeading() -> some View {
        self.frame(maxHeight: .infinity, alignment: .top)
    }
    func vTrailing() -> some View {
        self.frame(maxHeight: .infinity, alignment: .bottom)
    }
    func vCenter() -> some View {
        self.frame(maxHeight: .infinity, alignment: .center)
    }

        // MARK: Safe Area
#if os(iOS)
    func getSafeArea() -> UIEdgeInsets{
        guard let screen = UIApplication.shared.connectedScenes.first as? UIWindowScene else{
            return .zero
        }

        guard let safeArea = screen.windows.first?.safeAreaInsets else{
            return .zero
        }

        return safeArea
    }
#endif
}
