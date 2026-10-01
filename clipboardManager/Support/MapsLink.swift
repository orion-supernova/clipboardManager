//
//  MapsLink.swift
//  clipboardManager
//
//  Map links say almost nothing about themselves: every Google Maps page is
//  titled "Google Maps". The place lives in the URL — a /place/ name, a
//  dropped pin's coordinates, an Apple Maps q= — so read it from there.
//

import Foundation

enum MapsLink {
    static func isMaps(_ url: URL?) -> Bool {
        guard let url, let host = url.host()?.lowercased() else { return false }
        if host == "maps.app.goo.gl" || host.hasPrefix("maps.google.") || host == "maps.apple.com" || host.hasSuffix("openstreetmap.org") {
            return true
        }
        if host == "goo.gl", url.path().hasPrefix("/maps") { return true }
        if host.hasPrefix("www.google.") || host.hasPrefix("google.") { return url.path().hasPrefix("/maps") }
        return false
    }

    /// Titles a maps page gives itself, which tell you nothing.
    static func isGenericTitle(_ title: String?) -> Bool {
        guard let title = title?.trimmingCharacters(in: .whitespaces).lowercased() else { return true }
        return ["google maps", "apple maps", "maps", "openstreetmap"].contains(title)
    }

    /// "Moda Sahili, Kadıköy" from a /place/ URL, or "Dropped pin · 40.9310, 29.2179".
    static func describe(_ url: URL) -> String? {
        let path = url.path()
        if let range = path.range(of: "/place/") {
            let name = path[range.upperBound...].split(separator: "/").first.map(String.init) ?? ""
            let decoded = (name.removingPercentEncoding ?? name).replacingOccurrences(of: "+", with: " ")
            if !decoded.isEmpty, coordinates(in: decoded) == nil { return decoded }
        }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let q = query.first(where: { $0.name == "q" || $0.name == "query" })?.value, !q.isEmpty, coordinates(in: q) == nil {
            return q.replacingOccurrences(of: "+", with: " ")
        }
        let candidates = [path.removingPercentEncoding ?? path] + query.compactMap { ["q", "ll", "sll", "query", "center"].contains($0.name) ? $0.value : nil }
        for candidate in candidates {
            if let (lat, lon) = coordinates(in: candidate) {
                return "Dropped pin · \(format(lat)), \(format(lon))"
            }
        }
        return nil
    }

    private static func coordinates(in text: String) -> (Double, Double)? {
        guard let match = text.range(of: #"-?\d{1,2}\.\d{3,}\s*,\s*\+?-?\d{1,3}\.\d{3,}"#, options: .regularExpression) else { return nil }
        let parts = text[match].split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " +")) }
        guard parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]),
              (-90...90).contains(lat), (-180...180).contains(lon)
        else { return nil }
        return (lat, lon)
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.4f", value)
    }
}
