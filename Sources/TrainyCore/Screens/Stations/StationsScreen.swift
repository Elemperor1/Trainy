import SwiftUI

struct StationsScreen: View {
    @ObservedObject var store: TrainStore
    let nsProvider: any NSRiderDataProviding
    let nsStartsLoading: Bool
    @State private var stationQuery = ""

    private var stations: [StationSnapshot] {
        let cleanQuery = stationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let snapshots = store.stationSnapshots
        guard !cleanQuery.isEmpty else { return snapshots }
        return snapshots.filter { station in
            station.name.localizedCaseInsensitiveContains(cleanQuery) || station.code.localizedCaseInsensitiveContains(cleanQuery)
        }
    }

    private var overview: String {
        let platforms = store.watchedPlatformCount
        let risks = store.riskCount
        return "\(store.stationSnapshots.count) stations · \(platforms) platforms · \(risks) need watch"
    }

    /// Builds one accessible station-navigation row for the station directory.
    @ViewBuilder
    private func stationRow(for station: StationSnapshot) -> some View {
        NavigationLink {
            StationDetailView(station: station)
        } label: {
            StationCard(station: station)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(station.name), \(station.code), \(station.departureTrips.count) departures, \(station.platforms.count) tracks"
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                NavigationLink {
                    NSStationSearchView(provider: nsProvider, startsLoading: nsStartsLoading)
                } label: {
                    RailSurface(role: .accent(RailDesign.Palette.accent)) {
                        RailNavigationCard(
                            symbol: "train.side.front.car",
                            title: "NS departures",
                            detail: store.providerProxyConfiguration.isConfigured
                                ? "Search Dutch stations and open proxy-backed departure boards."
                                : "Rider surface ready; a configured provider proxy is required for NS data.",
                            tint: RailDesign.Palette.accent
                        )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens NS station search and freshness-labelled departure boards")
                .accessibilityIdentifier("stations.nsDepartures")
                .padding(.horizontal, RailDesign.Spacing.m)
                .padding(.top, RailDesign.Spacing.s)

                HStack {
                    Text(overview)
                        .font(RailDesign.Typography.small.weight(.medium))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                    Spacer()
                    if !stations.isEmpty {
                        Text("\(stations.count) shown")
                            .font(RailDesign.Typography.caption)
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, RailDesign.Spacing.m)
                .padding(.top, RailDesign.Spacing.s)

                LazyVStack(spacing: RailDesign.Spacing.xs) {
                    ForEach(stations) { station in
                        stationRow(for: station)
                    }
                }
                .padding(.horizontal, RailDesign.Spacing.m)

                if stations.isEmpty {
                    EmptyStateView(
                        title: "No station found",
                        message: "Search a station name, short code, platform, or route stop.",
                        symbolName: "tram.circle",
                        actionTitle: "Search a train"
                    ) {
                        // Focus the searchable field by sending a notification
                        // that SearchScreen listens for and re-focuses itself.
                        NotificationCenter.default.post(name: .trainyFocusSearch, object: nil)
                    }
                    .padding(.horizontal, RailDesign.Spacing.m)
                }
            }
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .navigationTitle("Stations")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $stationQuery, prompt: "Station, platform, or route")
        .railScreenChrome()
    }
}

private struct StationCard: View {
    let station: StationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
            HStack {
                StationBadge(name: station.name, code: station.code)
                Spacer()
                ServiceStatusPill(status: station.status)
                Image(systemName: "chevron.right")
                    .font(RailDesign.Typography.caption.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.secondaryText)
            }

            Text("\(station.departureTrips.count) departures · \(station.platforms.count) tracks · \(station.routeNames.count) routes")
                .font(RailDesign.Typography.small)
                .foregroundStyle(RailDesign.Palette.secondaryText)
                .monospacedDigit()
        }
        .padding(RailDesign.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .fill(RailDesign.Palette.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .stroke(RailDesign.Palette.hairline, lineWidth: 1)
        )
    }
}
