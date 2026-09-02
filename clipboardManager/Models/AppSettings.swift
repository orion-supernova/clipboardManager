//
//  AppSettings.swift
//  clipboardManager
//
//  Persisted settings, shared across features via TCA's `@Shared(.appStorage)`.
//  Key strings are kept identical to v2.x so existing users keep their preferences.
//

import ComposableArchitecture
import Foundation

enum DragMode: String, CaseIterable, Sendable, Equatable {
    case copy
    case move

    var title: String {
        switch self {
        case .copy: "Copy"
        case .move: "Move"
        }
    }

    var explanation: String {
        switch self {
        case .copy: "Dragging a file out of the clipboard leaves the original where it is."
        case .move: "Dragging a file into Finder moves the original. Hold ⌥ while dropping to copy instead."
        }
    }
}

enum RetentionOption: Int, CaseIterable, Sendable {
    case twenty = 20
    case fifty = 50
    case hundred = 100
    case twoHundred = 200
    case fiveHundred = 500
    case unlimited = -1

    var title: String { self == .unlimited ? "Unlimited" : "\(rawValue) items" }
}

enum MaxAgeOption: Int, CaseIterable, Sendable {
    case oneHour = 1
    case sixHours = 6
    case oneDay = 24
    case twoDays = 48
    case oneWeek = 168
    case oneMonth = 720
    case never = -1

    var title: String {
        switch self {
        case .oneHour: "1 hour"
        case .sixHours: "6 hours"
        case .oneDay: "1 day"
        case .twoDays: "2 days"
        case .oneWeek: "1 week"
        case .oneMonth: "30 days"
        case .never: "Never"
        }
    }
}

enum SensitiveMaxAgeOption: Int, CaseIterable, Sendable {
    case tenMinutes = 10
    case oneHour = 60
    case oneDay = 1440
    case never = -1

    var title: String {
        switch self {
        case .tenMinutes: "10 minutes"
        case .oneHour: "1 hour"
        case .oneDay: "1 day"
        case .never: "Same as history"
        }
    }
}

extension SharedReaderKey where Self == AppStorageKey<Int>.Default {
    /// Maximum number of unpinned items kept. `-1` means unlimited.
    static var retainCount: Self {
        Self[.appStorage("retainCountUserDefaultsKey"), default: RetentionOption.fifty.rawValue]
    }

    /// Unpinned items older than this many hours are removed. `-1` means never.
    static var maxAgeHours: Self {
        Self[.appStorage("clearItemsOlderThanHoursUserDefaultsKey"), default: MaxAgeOption.twoDays.rawValue]
    }

    /// Sensitive items are forgotten after this many minutes. `-1` follows the history rules.
    static var sensitiveMaxAgeMinutes: Self {
        Self[.appStorage("sensitiveMaxAgeMinutes"), default: SensitiveMaxAgeOption.oneHour.rawValue]
    }
}

extension SharedReaderKey where Self == AppStorageKey<Bool>.Default {
    static var keyboardNavigation: Self {
        Self[.appStorage("enableKeyboardNavigationUserDefaultsKey"), default: true]
    }

    /// Simulate ⌘V in the frontmost app after choosing an item.
    static var autoPaste: Self {
        Self[.appStorage("autoPasteEnabled"), default: true]
    }

    /// Skip pasteboard contents flagged as concealed (password managers) or transient.
    static var ignoreConcealed: Self {
        Self[.appStorage("ignoreConcealedContent"), default: true]
    }

    /// Show ⌘1…⌘9 hints on the first nine cards.
    static var showShortcutHints: Self {
        Self[.appStorage("showShortcutHints"), default: true]
    }

    /// Temporarily stop recording the clipboard.
    static var capturePaused: Self {
        Self[.appStorage("capturePaused"), default: false]
    }

    /// Record card numbers, IBANs, keys and credentials (masked) instead of skipping them.
    static var recordSensitive: Self {
        Self[.appStorage("recordSensitiveContent"), default: true]
    }

    /// Run on-device text recognition on copied images so they can be searched.
    static var recognizeImageText: Self {
        Self[.appStorage("recognizeImageText"), default: true]
    }

    /// Fetch page titles for copied links.
    static var fetchLinkTitles: Self {
        Self[.appStorage("fetchLinkTitles"), default: true]
    }
}

extension SharedReaderKey where Self == AppStorageKey<String?>.Default {
    /// A version the user chose not to be reminded about.
    static var skippedUpdateVersion: Self {
        Self[.appStorage("skippedUpdateVersion"), default: nil]
    }
}

extension SharedReaderKey where Self == AppStorageKey<DragMode>.Default {
    static var dragMode: Self {
        Self[.appStorage("dragMode"), default: .copy]
    }
}

extension SharedReaderKey where Self == AppStorageKey<KeyboardShortcutSpec>.Default {
    /// Global shortcut that shows/hides the panel.
    static var toggleShortcut: Self {
        Self[.appStorage("toggleShortcut"), default: .default]
    }
}

extension SharedReaderKey where Self == InMemoryKey<AvailableUpdate?>.Default {
    /// A newer App Store version discovered by the update checker (not persisted).
    static var availableUpdate: Self {
        Self[.inMemory("availableUpdate"), default: nil]
    }
}

struct RetentionPolicy: Sendable, Equatable {
    var maxCount: Int?
    var maxAge: TimeInterval?
    var sensitiveMaxAge: TimeInterval?

    init(retainCount: Int, maxAgeHours: Int, sensitiveMaxAgeMinutes: Int = -1) {
        maxCount = retainCount > 0 ? retainCount : nil
        maxAge = maxAgeHours > 0 ? TimeInterval(maxAgeHours) * 3600 : nil
        sensitiveMaxAge = sensitiveMaxAgeMinutes > 0 ? TimeInterval(sensitiveMaxAgeMinutes) * 60 : nil
    }
}
