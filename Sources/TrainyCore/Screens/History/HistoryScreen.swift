import SwiftUI

struct HistoryScreen: View {
    @ObservedObject var store: TrainStore


    private var longestTripSummary: String {
        guard let trip = store.trips.max(by: { $0.durationMinutes < $1.durationMinutes }) else {
            return "Not available"
        }
        return "\(trip.train), \(trip.duration)"
    }

    private var summary: String {
        let count = store.trips.count
        let stationCount = Set(store.trips.flatMap { [$0.origin.name, $0.destination.name] + $0.stops.map(\.name) }).count
        let operatorCount = Set(store.trips.map(\.operatorName)).count
        return "\(count) trips · \(stationCount) stations · \(operatorCount) operators"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                    Text(summary)
                        .font(RailDesign.Typography.h3)
                        .foregroundStyle(RailDesign.Palette.ink)
                    Text("Trip history is stored locally on this device until you share it.")
                        .font(RailDesign.Typography.small)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                }
                .padding(RailDesign.Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                        .fill(RailDesign.Palette.panel)
                )

                SettingsGroup(title: "Highlights") {
                    RailValueRow(symbol: "arrow.left.and.right", title: "Longest trip", value: longestTripSummary)
                        .padding(.vertical, RailDesign.Spacing.xs)
                    Divider()
                        .background(RailDesign.Palette.hairline)
                    RailValueRow(symbol: "point.topleft.down.curvedto.point.bottomright.up", title: "Most-used route", value: store.trips.isEmpty ? "Not available" : "Japan Shinkansen")
                        .padding(.vertical, RailDesign.Spacing.xs)
                    Divider()
                        .background(RailDesign.Palette.hairline)
                    RailValueRow(symbol: "clock.badge.exclamationmark", title: "Delays tracked", value: store.trips.filter { RailServiceStatus.from($0) == .delayed }.count == 0 ? "No tracked delays" : "Some tracked delays")
                        .padding(.vertical, RailDesign.Spacing.xs)
                }

                if !store.trips.isEmpty {
                    SettingsGroup(title: "Recent journeys") {
                        ForEach(Array(store.trips.prefix(3))) { trip in
                            NavigationLink {
                                TrainDetailView(store: store, tripID: trip.id)
                            } label: {
                                HistoryTripRow(trip: trip)
                            }
                            .buttonStyle(.plain)

                            if trip.id != store.trips.prefix(3).last?.id {
                                Divider()
                                    .background(RailDesign.Palette.hairline)
                            }
                        }
                    }
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .railScreenChrome()
    }
}

/// Compact history row that preserves the trip's route and duration context.
private struct HistoryTripRow: View {
    let trip: TrainTrip

    var body: some View {
        HStack(spacing: RailDesign.Spacing.s) {
            Image(systemName: "train.side.front.car")
                .font(RailDesign.Typography.h3)
                .foregroundStyle(RailDesign.Palette.accent)
                .frame(width: 32, height: 32)
                .background(RailDesign.Palette.accent.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text(trip.train)
                    .font(RailDesign.Typography.h3)
                    .foregroundStyle(RailDesign.Palette.ink)
                Text("\(trip.origin.name) → \(trip.destination.name) · \(trip.duration)")
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: RailDesign.Spacing.s)

            Image(systemName: "chevron.right")
                .font(RailDesign.Typography.caption.weight(.semibold))
                .foregroundStyle(RailDesign.Palette.secondaryText)
        }
        .padding(.vertical, RailDesign.Spacing.s)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trip.train), \(trip.origin.name) to \(trip.destination.name), \(trip.duration)")
    }
}
