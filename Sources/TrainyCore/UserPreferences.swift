import Foundation
import SwiftUI

/// User preferences for display formatting and unit conversion.
/// Preferences are stored in UserDefaults and control how data is presented.
struct UserPreferences: @unchecked Sendable {
    /// Time format preference: 12-hour (e.g., "9:45 PM") or 24-hour (e.g., "21:45")
    enum TimeFormat: String, CaseIterable, Codable, Sendable {
        case hour12 = "12-hour"
        case hour24 = "24-hour"

        var displayName: String {
            switch self {
            case .hour12: return "12-hour"
            case .hour24: return "24-hour"
            }
        }

        /// Returns the exact display pattern for this format preference.
        var timePattern: String {
            switch self {
            case .hour12:
                return "h:mm a"
            case .hour24:
                return "HH:mm"
            }
        }

        func makeFormatter(timeZone: TimeZone, includeDate: Bool = false) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = includeDate ? "M/d/yy, \(timePattern)" : timePattern
            return formatter
        }
    }

    /// Unit system preference: metric or imperial
    enum UnitSystem: String, CaseIterable, Codable, Sendable {
        case metric
        case imperial

        var displayName: String {
            switch self {
            case .metric: return "Metric"
            case .imperial: return "Imperial"
            }
        }
    }

    /// Shared instance for app-wide access
    static let shared = UserPreferences()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Current time format preference (defaults to 12-hour)
    var timeFormat: TimeFormat {
        get {
            let rawValue = defaults.string(forKey: "trainy.timeFormat") ?? "12-hour"
            return TimeFormat(rawValue: rawValue) ?? .hour12
        }
        set {
            defaults.set(newValue.rawValue, forKey: "trainy.timeFormat")
        }
    }

    /// Current unit system preference (defaults to metric)
    var unitSystem: UnitSystem {
        get {
            let rawValue = defaults.string(forKey: "trainy.unitSystem") ?? "metric"
            return UnitSystem(rawValue: rawValue) ?? .metric
        }
        set {
            defaults.set(newValue.rawValue, forKey: "trainy.unitSystem")
        }
    }

    /// Current source label verbosity preference (defaults to compact)
    var sourceLabelVerbosity: SourceLabelVerbosity {
        get {
            let rawValue = defaults.string(forKey: "trainy.sourceLabelVerbosity") ?? SourceLabelVerbosity.compact.rawValue
            return SourceLabelVerbosity(rawValue: rawValue) ?? .compact
        }
        set {
            defaults.set(newValue.rawValue, forKey: "trainy.sourceLabelVerbosity")
        }
    }

    /// Formats a time string (HH:MM format) using the provider's time zone and user's time format preference
    func formatTimeString(_ timeString: String, in timeZone: TimeZone) -> String {
        let pieces = timeString.split(separator: ":").compactMap { Int($0) }
        guard pieces.count >= 2 else { return timeString }

        // Create a date with today's date and the specified time
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day], from: now)

        var dateComponents = DateComponents()
        dateComponents.year = components.year
        dateComponents.month = components.month
        dateComponents.day = components.day
        dateComponents.hour = pieces[0]
        dateComponents.minute = pieces[1]

        if let date = calendar.date(from: dateComponents) {
            return timeFormat.makeFormatter(timeZone: timeZone).string(from: date)
        }

        // Fallback: return the original string if formatting fails
        return timeString
    }

    /// Formats a date string using the provider's time zone and user's time format preference
    func format(_ dateString: String, in timeZone: TimeZone) -> String {
        guard let date = Self.parseISODateTime(dateString) else { return dateString }
        return format(date, in: timeZone)
    }

    /// Formats a date using the provider's time zone and user's time format preference
    func format(_ date: Date, in timeZone: TimeZone) -> String {
        timeFormat.makeFormatter(timeZone: timeZone).string(from: date)
    }

    /// Full timestamp formatting with date and time
    func formatFullTimestamp(_ date: Date, in timeZone: TimeZone) -> String {
        timeFormat.makeFormatter(timeZone: timeZone, includeDate: true).string(from: date)
    }

    /// Returns the user's preferred unit system (metric or imperial)
    var useMetric: Bool {
        unitSystem == .metric
    }

    /// Parses ISO8601 datetime string to Date
    private static func parseISODateTime(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
