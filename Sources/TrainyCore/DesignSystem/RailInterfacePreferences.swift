import SwiftUI

/// Display preferences propagated through the SwiftUI environment.
struct RailInterfacePreferences: Equatable {
    var timeFormat: UserPreferences.TimeFormat
    var unitSystem: UserPreferences.UnitSystem
    var sourceLabelVerbosity: UserPreferences.SourceLabelVerbosity

    static let defaults = RailInterfacePreferences(
        timeFormat: .hour12,
        unitSystem: .metric,
        sourceLabelVerbosity: .compact
    )

    var usesMetricUnits: Bool {
        unitSystem != .imperial
    }
}

/// Environment key supplying one predictable interface-preference default.
private struct RailInterfacePreferencesKey: EnvironmentKey {
    static let defaultValue = RailInterfacePreferences.defaults
}

extension EnvironmentValues {
    var railInterfacePreferences: RailInterfacePreferences {
        get { self[RailInterfacePreferencesKey.self] }
        set { self[RailInterfacePreferencesKey.self] = newValue }
    }
}
