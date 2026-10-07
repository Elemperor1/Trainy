import SwiftUI

/// Rider-facing trip summary with route times and current service status.
struct TrainDetailHero: View {
    let trip: TrainTrip
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

    private var formattedETA: String {
        trip.eta.formattedAsTime(
            in: trip.destination.timeZone,
            format: interfacePreferences.timeFormat
        )
    }

    var body: some View {
        RailSurface(cornerRadius: RailDesign.Radius.panel, padding: RailDesign.Spacing.l) {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    Text(trip.operatorName)
                        .font(RailDesign.Typography.small.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .textCase(.uppercase)
                        .lineLimit(1)
                    Spacer(minLength: RailDesign.Spacing.s)
                    ServiceStatusPill(status: RailServiceStatus.from(trip))
                }

                HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.xs) {
                    Text(formattedOriginTime)
                        .font(RailDesign.Typography.display.monospacedDigit())
                        .foregroundStyle(RailDesign.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("→")
                        .font(RailDesign.Typography.h2)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                    Text(formattedDestinationTime)
                        .font(RailDesign.Typography.display.monospacedDigit())
                        .foregroundStyle(RailDesign.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                    Text(trip.train)
                        .font(RailDesign.Typography.h2)
                        .foregroundStyle(RailDesign.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(trip.fromTo)
                        .font(RailDesign.Typography.small)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Flat timeline of the stops belonging to a selected trip.
struct StopTimelineList: View {
    let trip: TrainTrip

    var body: some View {
        RailSurface {
            VStack(spacing: 0) {
                ForEach(Array(trip.stops.enumerated()), id: \.element.id) { index, stop in
                    StopTimelineRow(stop: stop, isLast: index == trip.stops.count - 1)
                }
            }
        }
    }
}

/// Source-backed boarding, carriage, seat, and speed facts for a trip.
struct TrainDetailBoardingCard: View {
    let trip: TrainTrip
    let useMetric: Bool

    var body: some View {
        RailSurface {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                RailValueRow(symbol: "rectangle.split.3x1.fill", title: "Platform", value: trip.displayPlatform)
                RailDivider()
                RailValueRow(symbol: "train.side.front.car", title: "Carriage", value: "Car \(trip.bestCar) of \(trip.cars)")
                RailDivider()
                RailValueRow(symbol: "seat", title: "Seat", value: trip.seat)
                RailDivider()
                RailValueRow(symbol: "speedometer", title: "Speed", value: UnitConverter.displaySpeed(trip.speed, useMetric: useMetric))
            }
        }
    }
}

/// Compact provenance summary with a route to the complete source disclosure.
struct CompactSourcePanel: View {
    let trip: TrainTrip
    let showDetails: () -> Void

    var body: some View {
        RailSurface {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                Button(action: showDetails) {
                    HStack(spacing: RailDesign.Spacing.s) {
                        SourceBadge(trip: trip, style: .regular)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(RailDesign.Typography.caption.weight(.semibold))
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                    }
                }
                .buttonStyle(PressableButtonStyle())
                .contentShape(Rectangle())
                .accessibilityHint("Opens source details")

                RailDivider()

                VStack(spacing: RailDesign.Spacing.s) {
                    RailValueRow(symbol: "building.columns", title: "Provider", value: trip.sourceProvenance.providerName)
                    RailValueRow(symbol: "doc.text.magnifyingglass", title: "Source", value: trip.sourceProvenance.sourceName)
                    RailValueRow(symbol: "checkmark.seal", title: "Confidence", value: trip.sourceProvenance.summaryText)
                    RailValueRow(symbol: "clock.badge.checkmark", title: "Freshness", value: trip.sourceProvenance.freshness.displayName)
                }
                if let sourceURL = trip.sourceProvenance.sourceURL {
                    Link(destination: sourceURL) {
                        HStack(spacing: RailDesign.Spacing.s) {
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(RailDesign.Palette.accent)
                            Text(sourceURL.host ?? sourceURL.absoluteString)
                                .font(RailDesign.Typography.h3)
                                .foregroundStyle(RailDesign.Palette.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                    }
                    .accessibilityLabel("Open source \(trip.sourceProvenance.sourceName)")
                }
            }
        }
    }
}
