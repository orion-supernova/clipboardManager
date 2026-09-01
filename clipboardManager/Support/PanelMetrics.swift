//
//  PanelMetrics.swift
//  clipboardManager
//
//  Every vertical dimension of the panel is derived from these so the window is
//  always exactly as tall as its content (plus room for hover lift and shadows).
//

import Foundation

enum PanelMetrics {
    static let horizontalScreenInset: CGFloat = 18
    static let bottomScreenInset: CGFloat = 10
    static let maxWidth: CGFloat = 1800

    static let cardWidth: CGFloat = 250
    static let cardHeight: CGFloat = 236
    static let cardCornerRadius: CGFloat = 22
    static let cardSpacing: CGFloat = 14

    static let toolbarHeight: CGFloat = 40
    static let hintBarHeight: CGFloat = 28
    static let previewHeight: CGFloat = 320

    static let rowSpacing: CGFloat = 10
    static let topInset: CGFloat = 14
    static let bottomInset: CGFloat = 12
    /// Vertical breathing room around the card strip for hover scale and shadows.
    static let stripVerticalPadding: CGFloat = 12

    static let thumbnailMaxPixelSize = 640
    static let previewImageMaxPixelSize = 1600

    static var stripHeight: CGFloat { cardHeight + stripVerticalPadding * 2 }

    static var height: CGFloat {
        topInset + hintBarHeight + rowSpacing + toolbarHeight + rowSpacing + stripHeight + bottomInset
    }

    static var expandedHeight: CGFloat {
        height + previewHeight + rowSpacing
    }
}
