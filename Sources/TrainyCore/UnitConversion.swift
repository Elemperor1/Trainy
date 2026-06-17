import Foundation
import SwiftUI

// MARK: - Speed and Distance Unit Conversion

/// Provides unit conversion for speed and distance values where source data exists.
/// Conversions are only applied when there is source-backed data.
struct UnitConverter {
    /// Converts speed between km/h and mph
    /// Currently defaults to km/h; future enhancement will integrate with UserPreferences
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
    /// Currently defaults to km; future enhancement will integrate with UserPreferences
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
}