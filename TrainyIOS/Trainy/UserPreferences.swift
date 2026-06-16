import Foundation
import SwiftUI

/// User preferences for display formatting and unit conversion.
/// Preferences are stored in UserDefaults and control how data is presented.
struct UserPreferences {
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

        /// Returns the appropriate date style for this format preference
        var dateStyle: DateFormatter.Style {
            return .none
        }

        /// Returns the appropriate time style for this format preference
        var timeStyle: DateFormatter.Style {
            switch self {
            case .hour12: return .short  // Uses locale's 12-hour format
            case .hour24: return .medium // Forces 24-hour format in most locales
            }
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

    /// Formats a date string using the provider's time zone and user's time format preference
    func format(_ dateString: String, in timeZone: TimeZone) -> String {
        guard let date = Self.parseISODateTime(dateString) else { return dateString }
        return format(date, in: timeZone)
    }

    /// Formats a date using the provider's time zone and user's time format preference
    func format(_ date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = timeFormat.dateStyle
        formatter.timeStyle = timeFormat.timeStyle
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    /// Full timestamp formatting with date and time
    func formatFullTimestamp(_ date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = timeFormat.timeStyle
        formatter.timeZone = timeZone
        return formatter.string(from: date)
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