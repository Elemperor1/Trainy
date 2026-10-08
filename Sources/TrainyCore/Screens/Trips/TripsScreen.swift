import SwiftUI

private struct TripRoute: Identifiable, Hashable {
    let id: TrainTrip.ID
}

private struct RailMapRoute: Identifiable, Hashable {
    let id: TrainTrip.ID
}

struct TripsScreen: View {
    @ObservedObject var store: TrainStore
    @State private var bucket: TripBucket = .active
    @State private var isShowingAddTrip = false
    @State private var selectedTripRoute: TripRoute?
    @State private var selectedMapRoute: RailMapRoute?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var displayedTrips: [TrainTrip] {
        let trips: [TrainTrip]
        switch bucket {
        case .upcoming:
            trips = store.filteredTrips.filter { $0.progress <= 0.12 }
        case .active:
            trips = store.filteredTrips.filter { $0.progress > 0.12 && $0.progress < 0.95 }
        case .past:
            trips = store.filteredTrips.filter { $0.progress >= 0.95 }
        }

        guard bucket == .active, let selectedTrip = activeHeroTrip else {
            return trips
        }
        return trips.filter { $0.id != selectedTrip.id }
    }

    private var activeHeroTrip: TrainTrip? {
        guard bucket == .active, let selectedTrip = store.selectedTrip else { return nil }
        guard selectedTrip.progress > 0.12 && selectedTrip.progress < 0.95 else { return nil }
        return selectedTrip
    }

    private var listSectionTitle: LocalizedStringKey {
        bucket == .active && activeHeroTrip != nil ? "More active journeys" : bucket.sectionTitle
    }

    var body: some View {
        List {
            Section {
                TripsHeaderRow(statusText: store.liveStatusText.railFeedDisplayText) {
                    isShowingAddTrip = true
                }
                .railListCardRow()

                RailSegmentedControl(
                    options: TripBucket.allCases,
                    selection: $bucket,
                    title: \.title
                )
                    .railListCardRow()

                if let offlineMessage = store.offlineMessage {
                    OfflineBanner(message: offlineMessage) {
                        Task { await store.searchLiveTrips(matching: store.query) }
                    }
                    .railListCardRow()
                }

                if store.liveLoadState == .loading && store.trips.isEmpty {
                    LoadingSkeletonView(rows: 3)
                        .railListCardRow()
                } else if store.trips.isEmpty {
                    EmptyStateView(
                        title: "No saved journeys",
                        message: "Search by train number, route, station pair, operator, or time to start tracking.",
                        actionTitle: "Add Trip"
                    ) {
                        isShowingAddTrip = true
                    }
                    .railListCardRow()
                } else if let selectedTrip = activeHeroTrip {
                    ActiveTripSummary(trip: selectedTrip, store: store) {
                        selectedMapRoute = RailMapRoute(id: selectedTrip.id)
                    }
                    .railListCardRow()
                }
            }

            Section {
                if !displayedTrips.isEmpty {
                    SectionHeader(title: listSectionTitle, subtitle: store.liveStatusText.railFeedDisplayText)
                        .railListCardRow()
                }

                if displayedTrips.isEmpty && !store.trips.isEmpty && activeHeroTrip == nil {
                    EmptyStateView(
                        title: bucket.emptyTitle,
                        message: bucket.emptyMessage,
                        symbolName: bucket.emptySymbol,
                        actionTitle: "Search Rail"
                    ) {
                        isShowingAddTrip = true
                    }
                    .railListCardRow()
                } else {
                    ForEach(displayedTrips) { trip in
                        Button {
                            selectedTripRoute = TripRoute(id: trip.id)
                        } label: {
                            TrainTripCard(trip: trip, role: bucket.cardRole)
                        }
                        .buttonStyle(.plain)
                        .railListCardRow()
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                store.togglePin(for: trip)
                            } label: {
                                Label(store.isPinned(trip) ? "Unfavorite" : "Favorite", systemImage: store.isPinned(trip) ? "star.slash" : "star")
                            }
                            .tint(RailDesign.Palette.warning)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                store.toggleNotification(for: trip)
                            } label: {
                                Label(store.isNotified(trip) ? "Mute" : "Notify", systemImage: store.isNotified(trip) ? "bell.slash" : "bell")
                            }
                            .tint(RailDesign.Palette.accent)
                        }
                        .contextMenu {
                            Button {
                                store.select(trip)
                            } label: {
                                Label("Make Active", systemImage: "scope")
                            }
                            Button {
                                store.toggleNotification(for: trip)
                            } label: {
                                Label(store.isNotified(trip) ? "Mute Updates" : "Notify Me", systemImage: "bell")
                            }
                            ShareLink(item: trip.shareText) {
                                Label("Share Trip", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
        }
        .navigationDestination(item: $selectedTripRoute) { route in
            TrainDetailView(store: store, tripID: route.id)
        }
        .navigationDestination(item: $selectedMapRoute) { route in
            if let trip = store.trips.first(where: { $0.id == route.id }) ?? store.selectedTrip {
                RailJourneyMapScreen(trip: trip)
            } else {
                EmptyStateView(
                    title: "No map trip",
                    message: "Search and track a trip before opening the rail map.",
                    symbolName: "map"
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle("Trips")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await store.searchLiveTrips(matching: store.query)
        }
        .sheet(isPresented: $isShowingAddTrip) {
            NavigationStack {
                SearchScreen(store: store, showsCloseButton: true)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .animation(reduceMotion ? nil : RailDesign.Motion.soft, value: bucket)
        .railScreenChrome()
    }
}

private struct TripsHeaderRow: View {
    let statusText: String
    let addTrip: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: RailDesign.Spacing.m) {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Label("Japan Shinkansen", systemImage: "train.side.front.car")
                    .font(RailDesign.Typography.h3)
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(statusText)
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: RailDesign.Spacing.s)

            Button(action: addTrip) {
                Image(systemName: "plus")
                    .font(RailDesign.Typography.h3.weight(.bold))
                    .foregroundStyle(RailDesign.Palette.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .background(RailDesign.Palette.panel.opacity(0.72), in: Circle())
            .overlay(Circle().stroke(RailDesign.Palette.hairline, lineWidth: 1))
            .accessibilityLabel("Add trip")
            .accessibilityHint("Search for a new train to track")
        }
        .padding(.vertical, RailDesign.Spacing.xs)
    }
}

private extension String {
    var railFeedDisplayText: String {
        replacingOccurrences(of: "updated 0s ago", with: "updated now")
            .replacingOccurrences(of: "updated 1s ago", with: "updated now")
    }
}
