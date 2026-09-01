//
//  LinkMetadataClient.swift
//  clipboardManager
//
//  Rich previews for copied links: title, hero image and favicon through
//  LinkPresentation, with a lightweight HTML <title> fetch as fallback.
//

import AppKit
import ComposableArchitecture
import Foundation
import LinkPresentation

struct LinkMetadata: Sendable, Equatable {
    var title: String?
    var imagePNG: Data?
    var iconPNG: Data?

    var isEmpty: Bool { title == nil && imagePNG == nil && iconPNG == nil }
}

struct LinkMetadataClient: Sendable {
    var fetch: @Sendable (URL) async -> LinkMetadata?
}

extension LinkMetadataClient: DependencyKey {
    static let liveValue = LinkMetadataClient { url in
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        if let rich = await LinkPresentationFetcher.fetch(url), !rich.isEmpty { return rich }
        if let title = await HTMLTitleFetcher.title(for: url) { return LinkMetadata(title: title) }
        return nil
    }

    static let previewValue = LinkMetadataClient { _ in nil }
}

@MainActor
private enum LinkPresentationFetcher {
    static func fetch(_ url: URL) async -> LinkMetadata? {
        let provider = LPMetadataProvider()
        provider.timeout = 10
        provider.shouldFetchSubresources = true
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return nil }
        let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let image = await load(metadata.imageProvider, maxPixelSize: 900)
        let icon = await load(metadata.iconProvider, maxPixelSize: 128)
        return LinkMetadata(title: title.flatMap { $0.isEmpty ? nil : String($0.prefix(200)) }, imagePNG: image, iconPNG: icon)
    }

    private static func load(_ provider: NSItemProvider?, maxPixelSize: Int) async -> Data? {
        guard let provider, provider.canLoadObject(ofClass: NSImage.self) else { return nil }
        let tiff: Data? = await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
                continuation.resume(returning: (object as? NSImage)?.tiffRepresentation)
            }
        }
        guard let tiff,
              let thumbnail = ImageCoding.thumbnail(from: tiff, maxPixelSize: maxPixelSize)
        else { return nil }
        return ImageCoding.encodePNG(thumbnail)
    }
}

enum HTMLTitleFetcher {
    static func title(for url: URL) async -> String? {
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X) MahmutClipboard/3", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  (http.mimeType ?? "").contains("html")
            else { return nil }
            var data = Data()
            data.reserveCapacity(64 * 1024)
            for try await byte in bytes {
                data.append(byte)
                if data.count >= 200_000 { break }
                if data.count % 8192 == 0, data.range(of: Data("</title>".utf8)) != nil { break }
            }
            return HTMLTitle.extract(from: String(decoding: data, as: UTF8.self))
        } catch {
            return nil
        }
    }
}

enum HTMLTitle {
    static func extract(from html: String) -> String? {
        let candidates = [
            #"<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:title["']"#,
            #"<title[^>]*>([\s\S]*?)</title>"#,
        ]
        for pattern in candidates {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: html)
            else { continue }
            let title = decodeEntities(String(html[range]))
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !title.isEmpty { return String(title.prefix(200)) }
        }
        return nil
    }

    private static func decodeEntities(_ text: String) -> String {
        var result = text
        let named = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&#x27;": "'", "&apos;": "'", "&nbsp;": " ", "&ndash;": "–", "&mdash;": "—", "&hellip;": "…"]
        for (entity, value) in named { result = result.replacingOccurrences(of: entity, with: value) }
        if let regex = try? NSRegularExpression(pattern: #"&#(\d+);"#) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let whole = Range(match.range, in: result), let digits = Range(match.range(at: 1), in: result),
                      let code = UInt32(result[digits]), let scalar = Unicode.Scalar(code)
                else { continue }
                result.replaceSubrange(whole, with: String(Character(scalar)))
            }
        }
        return result
    }
}

extension DependencyValues {
    var linkMetadata: LinkMetadataClient {
        get { self[LinkMetadataClient.self] }
        set { self[LinkMetadataClient.self] = newValue }
    }
}
