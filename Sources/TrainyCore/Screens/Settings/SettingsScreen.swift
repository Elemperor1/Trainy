import SwiftUI

struct SettingsScreen: View {
    @ObservedObject var store: TrainStore
    @Binding var diagnosticsConsent: Bool
    @AppStorage("trainy.timeFormat") private var timeFormatRaw = UserPreferences.TimeFormat.hour12.rawValue
    @AppStorage("trainy.unitSystem") private var unitSystemRaw = UserPreferences.UnitSystem.metric.rawValue

    private var usesMetricUnits: Binding<Bool> {
        Binding(
            get: { unitSystemRaw != UserPreferences.UnitSystem.imperial.rawValue },
            set: { unitSystemRaw = $0 ? UserPreferences.UnitSystem.metric.rawValue : UserPreferences.UnitSystem.imperial.rawValue }
        )
    }

    /// Returns rider-facing setup guidance without exposing credential names.
    private func providerDetail(for provider: ProviderMetadata) -> LocalizedStringKey {
        if provider.availability.message.contains("ODPT_CONSUMER_KEY") {
            return "Starter catalog is active. Add an ODPT consumer key in the developer configuration for official timetable and alert feeds."
        }
        if provider.id == "netherlands-ns" {
            return LocalizedStringKey(provider.availability.message)
        }
        return LocalizedStringKey(provider.availability.message)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                SettingsGroup(title: "Display") {
                    SettingsPickerRow(symbol: "clock", title: "Time format", detail: "Applies to trip cards, station boards, and shared trip text", selection: $timeFormatRaw, options: UserPreferences.TimeFormat.allCases.map(\.rawValue))
                    SettingsToggleRow(symbol: "ruler", title: "Metric units", detail: "Used for source-backed speed and distance values", isOn: usesMetricUnits)
                }

                SettingsGroup(title: "Providers") {
                    if let active = store.providerDirectory.first(where: { $0.id == store.activeProviderID }) {
                        SettingsNavigationRow(
                            symbol: "globe.asia.australia.fill",
                            title: LocalizedStringKey(active.displayName),
                            detail: providerDetail(for: active)
                        ) {
                            SupportedRegionsScreen(store: store)
                        }
                    } else {
                        SettingsInfoRow(symbol: "exclamationmark.triangle", title: "No active provider", detail: "Configured provider keys were not found.")
                    }
                    if store.providerProxyConfiguration.isConfigured {
                        Divider()
                            .background(RailDesign.Palette.hairline)
                        ProviderProxyStatusSummary(store: store)
                    }
                }

                SettingsGroup(title: "Privacy") {
                    SettingsInfoRow(
                        symbol: "internaldrive",
                        title: "On-device data",
                        detail: "Saved trips, pins, notification choices, provider and region choices, and display settings stay in Trainy's on-device storage."
                    )
                    Divider()
                        .background(RailDesign.Palette.hairline)
                    SettingsToggleRow(
                        symbol: "stethoscope",
                        title: "Share crash diagnostics",
                        detail: "Opt in to Firebase Crashlytics crash reports. Trainy adds no trip details, searches, or user identifier. Changes take effect on the next launch.",
                        isOn: $diagnosticsConsent
                    )
                }

                SettingsGroup(title: "About") {
                    SettingsInfoRow(symbol: "info.circle", title: "Trainy", detail: "An original rail companion interface built with system fonts, SF Symbols, and app-owned data.")
                    Divider()
                        .background(RailDesign.Palette.hairline)
                    SettingsActionRow(
                        symbol: "sparkles.rectangle.stack",
                        title: "Onboarding guide",
                        detail: "Review how Trainy labels starter, scheduled, and realtime data.",
                        actionTitle: "Open"
                    ) {
                        store.resetFirstRun()
                    }
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .railScreenChrome()
    }
}
