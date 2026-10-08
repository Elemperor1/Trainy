import SwiftUI

/// Complete rider-facing detail surface for one selected trip.
struct TrainDetailView: View {
    @ObservedObject var store: TrainStore
    let tripID: TrainTrip.ID
    @Environment(\.railInterfacePreferences) private var interfacePreferences
    @State private var sourceDetailTrip: TrainTrip?

    private var trip: TrainTrip? {
        store.trips.first { $0.id == tripID } ?? store.selectedTrip
    }

    private var useMetric: Bool {
        interfacePreferences.usesMetricUnits
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                if let trip {
                    TrainDetailHero(trip: trip)

                    SectionHeader(title: "Rail map", subtitle: "See the route, upcoming stops, and any disruption markers.")
                        .padding(.horizontal, RailDesign.Spacing.xs)

                    NavigationLink {
                        RailJourneyMapScreen(trip: trip)
                    } label: {
                        TrainDetailMapLink(trip: trip)
                    }
                    .buttonStyle(PressableButtonStyle())

                    SectionHeader(title: "Next stops", subtitle: "Scheduled times, platforms, and the operator-handoff cue for this train.")
                        .padding(.horizontal, RailDesign.Spacing.xs)

                    StopTimelineList(trip: trip)

                    SectionHeader(title: "Boarding and platform", subtitle: "Platform, carriage, seat, and current speed where the source supplies them.")
                        .padding(.horizontal, RailDesign.Spacing.xs)

                    TrainDetailBoardingCard(trip: trip, useMetric: useMetric)

                    SectionHeader(title: "Source and freshness", subtitle: "Every fact on this card is labeled with its source, confidence, and freshness.")
                        .padding(.horizontal, RailDesign.Spacing.xs)

                    CompactSourcePanel(trip: trip) {
                        sourceDetailTrip = trip
                    }
                } else {
                    EmptyStateView(
                        title: "Trip unavailable",
                        message: "This trip is no longer saved. Search and track a service to open a detail view.",
                        symbolName: "train.side.front.car"
                    )
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .navigationTitle(trip?.train ?? "Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                RailToolbarIconButton(
                    symbol: "arrow.clockwise",
                    accessibilityLabel: "Refresh trip"
                ) {
                    store.refreshSelectedTrip()
                }

                if let trip {
                    RailToolbarShareLink(item: trip.shareText)
                }
            }
        }
        .onAppear {
            if let trip {
                store.select(trip)
            }
        }
        .sheet(item: $sourceDetailTrip) { trip in
            SourceDetailSheet(trip: trip)
        }
        .railScreenChrome()
    }
}

/// Navigation surface that opens the selected trip's full rail map.
private struct TrainDetailMapLink: View {
    let trip: TrainTrip

    var body: some View {
        RailSurface {
            RailNavigationCard(
                symbol: "map.fill",
                title: "Open rail map",
                detail: "Next: \(trip.nextStop) · \(trip.vehiclePositionDisplayState.mapLabel)"
            )
        }
        .accessibilityLabel("Open rail map for \(trip.train). Next stop \(trip.nextStop). \(trip.vehiclePositionDisplayState.mapLabel).")
    }
}
