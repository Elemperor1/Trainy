import SwiftUI

struct StationDetailView: View {
    let station: StationSnapshot
    @State private var isFavorite = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                    HStack(alignment: .top) {
                        StationBadge(name: station.name, code: station.code)
                        Spacer()
                        Button {
                            isFavorite.toggle()
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(RailDesign.Typography.h3)
                                .foregroundStyle(isFavorite ? RailDesign.Palette.warning : RailDesign.Palette.secondaryText)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .background(RailDesign.Palette.panel, in: Circle())
                        .overlay(Circle().stroke(RailDesign.Palette.hairline, lineWidth: 1))
                        .accessibilityLabel(isFavorite ? "Remove favorite station" : "Favorite station")
                        .accessibilityHint("Stars this station for quick access on the Stations tab")
                    }

                    HStack(spacing: RailDesign.Spacing.s) {
                        MetricTile(title: "Departures", value: "\(station.departureTrips.count)", subtitle: "tracked", symbolName: "arrow.up.right", tint: RailDesign.Palette.accent)
                        MetricTile(title: "Platforms", value: station.platforms.prefix(3).joined(separator: ", "), subtitle: "known", symbolName: "rectangle.split.3x1", tint: RailDesign.Palette.info)
                    }
                }
                .padding(RailDesign.Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: RailDesign.Radius.panel, style: .continuous)
                        .fill(RailDesign.Palette.panel)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RailDesign.Radius.panel, style: .continuous)
                        .stroke(RailDesign.Palette.hairline, lineWidth: 1)
                )

                BoardSection(title: "Tracked departures", trips: station.departureTrips, empty: "No tracked departures for this station.")
                BoardSection(title: "Arrivals", trips: station.arrivalTrips, empty: "No tracked arrivals for this station.")

                VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                    SectionHeader(title: "Station notes", subtitle: "Facilities, access, disruptions, and popular route clues")
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                        RailValueRow(symbol: "figure.roll", title: "Accessibility", value: "Step-free route details are not connected yet.", layout: .stacked)
                        RailValueRow(symbol: "cup.and.saucer", title: "Facilities", value: "Food, restrooms, and waiting areas depend on station data availability.", layout: .stacked)
                        RailValueRow(symbol: "exclamationmark.triangle", title: "Disruptions", value: station.status == .onTime ? "No tracked disruption in saved trips." : "One or more tracked trips need attention.", layout: .stacked)
                        RailValueRow(symbol: "point.topleft.down.curvedto.point.bottomright.up", title: "Popular routes", value: station.routeNames.prefix(3).joined(separator: ", "), layout: .stacked)
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
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .navigationTitle(station.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .railScreenChrome()
    }
}

private struct BoardSection: View {
    let title: LocalizedStringKey
    let trips: [TrainTrip]
    let empty: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            SectionHeader(title: title, subtitle: "Time, destination, platform, operator, and status")
            if trips.isEmpty {
                EmptyStateView(title: "No board items", message: empty, symbolName: "list.bullet.rectangle")
                    .padding(.vertical, RailDesign.Spacing.l)
            } else {
                VStack(spacing: 0) {
                    ForEach(trips) { trip in
                        StationBoardRow(trip: trip)
                        if trip.id != trips.last?.id {
                            Divider().background(RailDesign.Palette.hairline)
                        }
                    }
                }
                .padding(.horizontal, RailDesign.Spacing.m)
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
    }
}

private struct StationBoardRow: View {
    let trip: TrainTrip
    @Environment(\.railInterfacePreferences) private var interfacePreferences

    var body: some View { stationBoardContent }

    @ViewBuilder
    private var stationBoardContent: some View {
        HStack(spacing: RailDesign.Spacing.s) {
            originTimeColumn
            columnStack
            Spacer()
            PlatformChip(platform: trip.platform, label: "Track")
        }
        .padding(.vertical, RailDesign.Spacing.s)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    private var originTimeColumn: some View {
        Text(
            trip.origin.time.formattedAsTime(
                in: trip.origin.timeZone,
                format: interfacePreferences.timeFormat
            )
        )
            .font(RailDesign.Typography.h3.monospacedDigit())
            .foregroundStyle(RailDesign.Palette.ink)
            .frame(width: 58, alignment: .leading)
    }

    private var columnStack: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
            Text(trip.destination.name)
                .font(RailDesign.Typography.h3)
                .foregroundStyle(RailDesign.Palette.ink)
            Text(trip.operatorName + " · " + trip.train)
                .font(RailDesign.Typography.caption)
                .foregroundStyle(RailDesign.Palette.secondaryText)
            SourceBadge(trip: trip)
        }
    }

    private var accessibilitySummary: String {
        trip.train + ", " + trip.origin.name + " to " + trip.destination.name + ", " + trip.sourceProvenance.sourceKind.riderTitle + ", " + trip.sourceProvenance.freshness.displayName
    }
}
