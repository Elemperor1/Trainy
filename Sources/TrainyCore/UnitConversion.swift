import Foundation
import SwiftUI

// MARK: - Speed and Distance Unit Conversion

/// Provides unit conversion for speed and distance values where source data exists.
/// Conversions are only applied when there is source-backed data.
struct UnitConverter {
    /// Converts speed between km/h and mph
    static func convertSpeed(_ kmh: Double) -> String {
        return String(format: "%.0f km/h", kmh)
    }

    /// Converts speed to user-preferred units
    static func convertSpeed(_ kmh: Double, useMetric: Bool) -> String {
        if !useMetric {
            let mph = kmh * 0.621371
            return String(format: "%.0f mph", mph)
        }
        return String(format: "%.0f km/h", kmh)
    }

    /// Converts distance between km and miles
    static func convertDistance(_ km: Double) -> String {
        return String(format: "%.1f km", km)
    }

    /// Converts distance to user-preferred units
    static func convertDistance(_ km: Double, useMetric: Bool) -> String {
        if !useMetric {
            let miles = km * 0.621371
            return String(format: "%.1f mi", miles)
        }
        return String(format: "%.1f km", km)
    }

    /// Converts a display string like "285 km/h" when it carries source-backed metric speed.
    static func displaySpeed(_ value: String, useMetric: Bool) -> String {
        guard let kmh = leadingNumber(in: value), value.localizedCaseInsensitiveContains("km/h") else {
            return value
        }
        return convertSpeed(kmh, useMetric: useMetric)
    }

    /// Converts a display string like "515 km" when it carries source-backed metric distance.
    static func displayDistance(_ value: String, useMetric: Bool) -> String {
        guard let km = leadingNumber(in: value), value.localizedCaseInsensitiveContains("km") else {
            return value
        }
        return convertDistance(km, useMetric: useMetric)
    }

    private static func leadingNumber(in value: String) -> Double? {
        let pattern = #"^\s*([0-9]+(?:\.[0-9]+)?)"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
            let range = Range(match.range(at: 1), in: value)
        else {
            return nil
        }
        return Double(value[range])
    }
}
