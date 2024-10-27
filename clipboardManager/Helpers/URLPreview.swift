//
//  URLPreview.swift
//  clipboardManager
//
//  Created by muratcankoc on 03/08/2024.
//

import SwiftUI
import WebKit


struct URLPreviewWeb: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}


import LinkPresentation


struct URLPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> LPLinkView {
        let linkView = LPLinkView(url: url)
        let metadataProvider = LPMetadataProvider()
        metadataProvider.startFetchingMetadata(for: url) { metadata, error in
            if let metadata = metadata {
                DispatchQueue.main.async {
                    linkView.metadata = metadata
                }
            }
        }
        return linkView
    }

    func updateNSView(_ nsView: LPLinkView, context: Context) {
        // No need to update anything here
    }
}


