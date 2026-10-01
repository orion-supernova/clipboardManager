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

/// What a page says about itself, for the preview: not stored, fetched on view.
struct LinkDetails: Sendable, Equatable {
    var siteName: String?
    var summary: String?
}

struct LinkMetadataClient: Sendable {
    var fetch: @Sendable (URL) async -> LinkMetadata?
    var details: @Sendable (URL) async -> LinkDetails?
}

extension LinkMetadataClient: DependencyKey {
    static let liveValue: LinkMetadataClient = {
        let cache = LinkDetailsCache()
        return LinkMetadataClient(
            fetch: { url in
                guard isWeb(url) else { return nil }
                let rich = await LinkPresentationFetcher.fetch(url)
                if let rich, rich.title != nil, rich.imagePNG != nil { return rich }
                // LinkPresentation came back empty or partial: read the page's own
                // Open Graph tags and fill in whatever it missed.
                guard let page = await HTMLMetaFetcher.meta(for: url) else { return rich.flatMap { $0.isEmpty ? nil : $0 } }
                async let image = rich?.imagePNG == nil ? HTMLMetaFetcher.thumbnail(at: page.imageURL, maxPixelSize: 900) : nil
                async let icon = rich?.iconPNG == nil ? HTMLMetaFetcher.thumbnail(at: page.iconURL, maxPixelSize: 128) : nil
                let (fetchedImage, fetchedIcon) = await (image, icon)
                let merged = LinkMetadata(
                    title: rich?.title ?? page.title,
                    imagePNG: rich?.imagePNG ?? fetchedImage,
                    iconPNG: rich?.iconPNG ?? fetchedIcon
                )
                await cache.store(LinkDetails(siteName: page.siteName, summary: page.summary), for: url)
                return merged.isEmpty ? nil : merged
            },
            details: { url in
                guard isWeb(url) else { return nil }
                if let cached = await cache.details(for: url) { return cached }
                guard let page = await HTMLMetaFetcher.meta(for: url) else { return nil }
                let details = LinkDetails(siteName: page.siteName, summary: page.summary)
                await cache.store(details, for: url)
                return details
            }
        )
    }()

    static let previewValue = LinkMetadataClient(fetch: { _ in nil }, details: { _ in nil })

    private static func isWeb(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}

/// Arrowing back and forth through links must not refetch each page.
private actor LinkDetailsCache {
    private var entries: [URL: LinkDetails] = [:]

    func details(for url: URL) -> LinkDetails? { entries[url] }

    func store(_ details: LinkDetails, for url: URL) {
        if entries.count > 200 { entries.removeAll() }
        entries[url] = details
    }
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

/// What a page's `<head>` says about it: Open Graph first, then plain HTML.
struct PageMeta: Sendable {
    var title: String?
    var summary: String?
    var siteName: String?
    var imageURL: URL?
    var iconURL: URL?
}

enum HTMLMetaFetcher {
    static func meta(for url: URL) async -> PageMeta? {
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
                if data.count >= 300_000 { break }
                // Everything we want lives in <head>; stop once it closes.
                if data.count % 8192 == 0, data.range(of: Data("</head>".utf8)) != nil { break }
            }
            let html = String(decoding: data, as: UTF8.self)
            let base = http.url ?? url
            return PageMeta(
                title: HTMLTitle.extract(from: html),
                summary: HTMLTitle.meta(["og:description", "twitter:description", "description"], in: html),
                siteName: HTMLTitle.meta(["og:site_name", "application-name"], in: html),
                imageURL: HTMLTitle.meta(["og:image", "og:image:url", "twitter:image"], in: html).flatMap { URL(string: $0, relativeTo: base)?.absoluteURL },
                iconURL: HTMLTitle.iconHref(in: html).flatMap { URL(string: $0, relativeTo: base)?.absoluteURL }
                    ?? URL(string: "/favicon.ico", relativeTo: base)?.absoluteURL
            )
        } catch {
            return nil
        }
    }

    /// Downloads and downsamples a page image; capped so a huge hero can't stall anything.
    static func thumbnail(at url: URL?, maxPixelSize: Int) async -> Data? {
        guard let url, url.scheme?.hasPrefix("http") == true else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X) MahmutClipboard/3", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              data.count < 8_000_000,
              let image = ImageCoding.thumbnail(from: data, maxPixelSize: maxPixelSize)
        else { return nil }
        return ImageCoding.encodePNG(image)
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

    /// The first non-empty `<meta property|name="…" content="…">` among `names`.
    static func meta(_ names: [String], in html: String) -> String? {
        for name in names {
            let escaped = NSRegularExpression.escapedPattern(for: name)
            let patterns = [
                #"<meta[^>]+(?:property|name)=["']"# + escaped + #"["'][^>]+content=["']([^"']+)["']"#,
                #"<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']"# + escaped + #"["']"#,
            ]
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                      let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                      let range = Range(match.range(at: 1), in: html)
                else { continue }
                let value = decodeEntities(String(html[range])).trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return String(value.prefix(400)) }
            }
        }
        return nil
    }

    /// `<link rel="icon" | "apple-touch-icon" href="…">`, preferring the larger touch icon.
    static func iconHref(in html: String) -> String? {
        for rel in ["apple-touch-icon", "icon", "shortcut icon"] {
            let escaped = NSRegularExpression.escapedPattern(for: rel)
            let patterns = [
                #"<link[^>]+rel=["']"# + escaped + #"["'][^>]+href=["']([^"']+)["']"#,
                #"<link[^>]+href=["']([^"']+)["'][^>]+rel=["']"# + escaped + #"["']"#,
            ]
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                      let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                      let range = Range(match.range(at: 1), in: html)
                else { continue }
                return String(html[range])
            }
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
