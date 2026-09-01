//
//  UpdateClient.swift
//  clipboardManager
//
//  Looks the app up on the App Store (iTunes Lookup API) to discover newer
//  versions. The user is sent to the App Store page to update.
//

import ComposableArchitecture
import Foundation

struct UpdateClient: Sendable {
    /// The App Store listing for this app, or `nil` when the store has no entry.
    var check: @Sendable () async throws -> AppStoreListing?
}

extension UpdateClient: DependencyKey {
    static let liveValue = UpdateClient {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.walhallaa.clipboardManager"
        let region = Locale.current.region?.identifier.lowercased() ?? "us"
        var countries = [region]
        if region != "us" { countries.append("us") }

        for country in countries {
            var components = URLComponents(string: "https://itunes.apple.com/lookup")!
            components.queryItems = [
                URLQueryItem(name: "bundleId", value: bundleID),
                URLQueryItem(name: "country", value: country),
                URLQueryItem(name: "entity", value: "macSoftware"),
                URLQueryItem(name: "ts", value: String(Int(Date().timeIntervalSince1970))),
            ]
            var request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { continue }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let version = first["version"] as? String
            else { continue }

            let storeURL: URL
            if let trackID = first["trackId"] as? Int, let url = URL(string: "macappstore://apps.apple.com/app/id\(trackID)") {
                storeURL = url
            } else if let track = first["trackViewUrl"] as? String,
                      let url = URL(string: track.replacingOccurrences(of: "https://", with: "macappstore://")) {
                storeURL = url
            } else {
                continue
            }
            return AppStoreListing(version: version, storeURL: storeURL, releaseNotes: first["releaseNotes"] as? String)
        }
        return nil
    }

    static let previewValue = UpdateClient { nil }
}

extension DependencyValues {
    var updates: UpdateClient {
        get { self[UpdateClient.self] }
        set { self[UpdateClient.self] = newValue }
    }
}
