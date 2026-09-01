//
//  EmptyStateView.swift
//  clipboardManager
//

import SwiftUI

struct EmptyStateView: View {
    enum Mode: Equatable {
        case history
        case search(String)
        case filter(String)
        case folder(String)
    }

    let mode: Mode

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tint)
                .symbolEffect(.breathe, options: .repeat(.continuous), isActive: mode == .history)
                .contentTransition(.symbolEffect(.replace))
            Text(title)
                .font(.title3.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 24)
        .frame(maxWidth: 480)
        .panelGlass(in: .rect(cornerRadius: PanelMetrics.cardCornerRadius))
        .animation(.easeOut(duration: 0.18), value: mode)
    }

    private var symbol: String {
        switch mode {
        case .history: "clipboard"
        case .search: "magnifyingglass"
        case .filter: "line.3.horizontal.decrease.circle"
        case .folder: "folder"
        }
    }

    private var title: String {
        switch mode {
        case .history: "Nothing here yet"
        case let .search(query): "No matches for “\(query)”"
        case let .filter(name): "No \(name.lowercased()) yet"
        case let .folder(name): "“\(name)” is empty"
        }
    }

    private var detail: String {
        switch mode {
        case .history: "Copy anything — text, links, images, files — and it appears here."
        case .search: "Try a different search, or press ⎋ to clear it."
        case .filter: "Copy one and it shows up here instantly."
        case .folder: "Hover a card and use the folder button, or right-click → Add to Folder."
        }
    }
}
