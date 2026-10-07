import SwiftUI

struct ActiveTripSummary: View {
    let trip: TrainTrip
    @ObservedObject var store: TrainStore
    let openMap: () -> Void
    @State private var activeStatusMessage: LocalizedStringKey?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.railInterfacePreferences) private var interfacePreferences

    /// Presents a transient action status message to the rider.
    private func showStatus(_ message: LocalizedStringKey) {
        updateStatus(message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            updateStatus(nil)
        }
    }

    /// Replaces or clears the current transient action status message.
    private func updateStatus(_ message: LocalizedStringKey?) {
        if reduceMotion {
            activeStatusMessage = message
        } else {
            withAnimation(RailDesign.Motion.quick) {
                activeStatusMessage = message
            }
        }
    }

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
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                        Text(trip.train)
                            .font(RailDesign.Typography.h2.weight(.bold))
                            .foregroundStyle(RailDesign.Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(trip.fromTo)
                            .font(RailDesign.Typography.h3)
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: RailDesign.Spacing.s)
                    VStack(alignment: .trailing, spacing: RailDesign.Spacing.xs) {
                        ServiceStatusPill(status: RailServiceStatus.from(trip))
                        SourceBadge(trip: trip)
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                        Text(formattedOriginTime)
                            .font(RailDesign.Typography.display.monospacedDigit())
                            .foregroundStyle(RailDesign.Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(trip.origin.name)
                            .font(RailDesign.Typography.caption)
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: RailDesign.Spacing.xs)
                    Image(systemName: "arrow.right")
                        .font(RailDesign.Typography.small.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .accessibilityHidden(true)
                    Spacer(minLength: RailDesign.Spacing.xs)
                    VStack(alignment: .trailing, spacing: RailDesign.Spacing.xxs) {
                        Text(formattedDestinationTime)
                            .font(RailDesign.Typography.display.monospacedDigit())
                            .foregroundStyle(RailDesign.Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(trip.destination.name)
                            .font(RailDesign.Typography.caption)
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                            .lineLimit(1)
                    }
                }

                ProgressView(value: trip.progress)
                    .tint(RailServiceStatus.from(trip).tint)
                    .accessibilityLabel("Journey progress")
                    .accessibilityValue("\(Int(trip.progress * 100)) percent")
            }
            .padding(RailDesign.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .background(RailDesign.Palette.hairline)

            VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                HStack(spacing: RailDesign.Spacing.xs) {
                    ControlMetricTile(title: "Next", value: trip.nextStop, symbol: "location.north.line.fill", tint: RailDesign.Palette.accent)
                    ControlMetricTile(title: "ETA", value: formattedETA, symbol: "clock", tint: RailDesign.Palette.info)
                    ControlMetricTile(
                        title: "Platform",
                        value: trip.displayPlatform,
                        symbol: "rectangle.split.3x1.fill",
                        tint: trip.platformDisplayState.isKnown ? RailDesign.Palette.info : RailDesign.Palette.secondaryText
                    )
                }

                Button(action: openMap) {
                    HStack(spacing: RailDesign.Spacing.s) {
                        Image(systemName: "map.fill")
                            .font(RailDesign.Typography.h3.weight(.bold))
                            .foregroundStyle(RailDesign.Palette.accent)
                            .frame(width: 34, height: 34)
                            .background(RailDesign.Palette.accent.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                            Text("Open rail map")
                                .font(RailDesign.Typography.h3)
                                .foregroundStyle(RailDesign.Palette.ink)
                            Text("Route line, map position, stops, and disruptions")
                                .font(RailDesign.Typography.small)
                                .foregroundStyle(RailDesign.Palette.ink.opacity(0.68))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(RailDesign.Typography.caption.weight(.bold))
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                    }
                    .padding(RailDesign.Spacing.s)
                    .background(RailDesign.Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: RailDesign.Radius.control, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: RailDesign.Radius.control, style: .continuous)
                            .stroke(RailDesign.Palette.accent.opacity(0.20), lineWidth: 1)
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(Text("Open rail map for " + trip.train))

                VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                    if let message = activeStatusMessage {
                        SuccessBanner(symbol: "checkmark.circle.fill", title: message)
                            .transition(
                                reduceMotion
                                    ? .identity
                                    : .opacity.combined(with: .move(edge: .top))
                            )
                    }
                    HStack(spacing: RailDesign.Spacing.s) {
                        Button {
                            store.refreshSelectedTrip()
                            showStatus("Refreshed \(trip.train)")
                        } label: {
                            TripToolButton(symbol: "arrow.clockwise", title: "Refresh")
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityLabel("Refresh trip")

                        Button {
                            store.toggleNotification(for: trip)
                            showStatus(store.isNotified(trip) ? "Alerts enabled for \(trip.train)" : "Alerts muted for \(trip.train)")
                        } label: {
                            TripToolButton(symbol: store.isNotified(trip) ? "bell.fill" : "bell", title: store.isNotified(trip) ? "Alerts on" : "Alerts off")
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityLabel(Text(store.isNotified(trip) ? ("Turn off alerts for " + trip.train) : ("Turn on alerts for " + trip.train)))

                        ShareLink(item: trip.shareText) {
                            TripToolButton(symbol: "square.and.arrow.up", title: "Share")
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityLabel(Text("Share " + trip.train))
                        .simultaneousGesture(TapGesture().onEnded {
                            showStatus("Share sheet opened for \(trip.train)")
                        })
                    }
                }
            }
            .padding(RailDesign.Spacing.m)
        }
        .background(
            RoundedRectangle(cornerRadius: RailDesign.Radius.panel, style: .continuous)
                .fill(RailDesign.Palette.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.panel, style: .continuous)
                .stroke(RailDesign.Palette.hairline, lineWidth: 1)
        )
    }
}
