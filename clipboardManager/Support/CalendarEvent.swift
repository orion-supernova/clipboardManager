//
//  CalendarEvent.swift
//  clipboardManager
//
//  "Add to Calendar" without calendar access: write a one-event .ics file and
//  let Calendar open it, which shows its own add-event sheet.
//

import Foundation

enum CalendarEvent {
    static func ics(title: String, start: Date, duration: TimeInterval, allDay: Bool) -> String {
        let stamp = utc.string(from: Date())
        let timing: [String]
        if allDay {
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
            timing = ["DTSTART;VALUE=DATE:\(day.string(from: start))", "DTEND;VALUE=DATE:\(day.string(from: end))"]
        } else {
            timing = ["DTSTART:\(utc.string(from: start))", "DTEND:\(utc.string(from: start.addingTimeInterval(duration)))"]
        }
        return ([
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Mahmut Clipboard//EN",
            "BEGIN:VEVENT",
            "UID:\(UUID().uuidString)@mahmut",
            "DTSTAMP:\(stamp)",
        ] + timing + [
            "SUMMARY:\(escape(title))",
            "END:VEVENT",
            "END:VCALENDAR",
        ]).joined(separator: "\r\n")
    }

    /// Writes the event to a temporary file Calendar can open.
    static func file(title: String, start: Date, duration: TimeInterval, allDay: Bool) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "Mahmut Event \(UUID().uuidString.prefix(8)).ics")
        try ics(title: title, start: start, duration: duration, allDay: allDay).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static let utc: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter
    }()

    private static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}

enum UserHome {
    /// The real home folder. Inside the sandbox `NSHomeDirectory()` is the app's
    /// container, so a copied "~/Documents/x" must be expanded against this.
    static var path: String {
        if let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir { return String(cString: dir) }
        return NSHomeDirectory()
    }

    static func expand(_ path: String) -> String {
        path.hasPrefix("~/") ? self.path + path.dropFirst() : path
    }
}
