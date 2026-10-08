import SwiftUI

struct SearchResultsSection: View {
    let title: LocalizedStringKey
    let isLoading: Bool
    let results: [TrainTrip]
    let query: String
    let emptyState: TrainStore.SearchEmptyState?
    let track: (TrainTrip) -> Void
    let manualAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            SectionHeader(title: title, subtitle: "Departure, arrival, duration, transfers, operator, and status")

            if isLoading && !query.isEmpty {
                LoadingSkeletonView(rows: 2)
            } else if let emptyState {
                SearchEmptyStateView(emptyState: emptyState, manualAdd: manualAdd)
            } else {
                VStack(spacing: RailDesign.Spacing.s) {
                    ForEach(results) { trip in
                        SearchResultCard(trip: trip) {
                            track(trip)
                        }
                    }
                }
            }
        }
    }
}

private struct SearchEmptyStateView: View {
    let emptyState: TrainStore.SearchEmptyState
    let manualAdd: () -> Void

    var body: some View {
        if let actionTitle = emptyState.actionTitle {
            EmptyStateView(
                title: LocalizedStringKey(emptyState.title),
                message: LocalizedStringKey(emptyState.message),
                symbolName: emptyState.symbolName,
                actionTitle: LocalizedStringKey(actionTitle)
            ) {
                manualAdd()
            }
        } else {
            EmptyStateView(
                title: LocalizedStringKey(emptyState.title),
                message: LocalizedStringKey(emptyState.message),
                symbolName: emptyState.symbolName
            )
        }
    }
}

private struct SearchResultCard: View {
    let trip: TrainTrip
    let track: () -> Void
    @State private var sourceDetailTrip: TrainTrip?
    @Environment(\.railInterfacePreferences) private var interfacePreferences

    private var formattedOriginTime: String {
        trip.origin.time.formattedAsTime(
            in: trip.origin.timeZone,
            format: interfacePreferences.timeFormat
        )
    }

    private var formattedDestinationTime: String {
        trip.destination.time.formattedAsTime(
            in: trip.destination.timeZone,
            format: interfacePreferences.timeFormat
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                    Text(trip.train)
                        .font(RailDesign.Typography.h3)
                        .foregroundStyle(RailDesign.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(trip.operatorName)
                        .font(RailDesign.Typography.caption.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: RailDesign.Spacing.xs) {
                    ServiceStatusPill(status: RailServiceStatus.from(trip))
                    Button {
                        sourceDetailTrip = trip
                    } label: {
                        SourceBadge(trip: trip)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens source details")
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                    Text(formattedOriginTime)
                        .font(RailDesign.Typography.h3.monospacedDigit())
                    Text(trip.origin.name)
                        .font(RailDesign.Typography.caption)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: RailDesign.Spacing.xxs) {
                    Text(formattedDestinationTime)
                        .font(RailDesign.Typography.h3.monospacedDigit())
                    Text(trip.destination.name)
                        .font(RailDesign.Typography.caption)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(RailDesign.Palette.ink)

            HStack {
                PlatformChip(platform: trip.platform)
                Spacer()
                Button(action: track) {
                    Label("Track", systemImage: "plus.circle")
                }
                .font(RailDesign.Typography.h3)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(RailDesign.Palette.accent)
                .accessibilityIdentifier("search.track.\(trip.id)")
            }
        }
        .padding(RailDesign.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .fill(RailDesign.Palette.panel)
        )
        .sheet(item: $sourceDetailTrip) { trip in
            SourceDetailSheet(trip: trip)
        }
        .accessibilityIdentifier("search.result.\(trip.id)")
    }
}
