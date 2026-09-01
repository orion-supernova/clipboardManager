//
//  AppUpdate.swift
//  clipboardManager
//

import Foundation

struct AppStoreListing: Equatable, Sendable {
    var version: String
    var storeURL: URL
    var releaseNotes: String?
}

struct AvailableUpdate: Equatable, Sendable {
    var listing: AppStoreListing
    var foundAt: Date
}

enum AppVersion {
    static var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    /// Numeric, component-wise comparison ("3.1" > "3.0.9", "3.0" == "3.0.0").
    static func isNewer(_ candidate: String, than baseline: String) -> Bool {
        let lhs = components(candidate), rhs = components(baseline)
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let l = index < lhs.count ? lhs[index] : 0
            let r = index < rhs.count ? rhs[index] : 0
            if l != r { return l > r }
        }
        return false
    }

    private static func components(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    }
}
