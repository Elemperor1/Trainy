import SwiftUI
import UIKit

enum RailDesign {
    enum Palette {
        static let background = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.055, green: 0.064, blue: 0.070, alpha: 1)
                : UIColor(red: 0.972, green: 0.984, blue: 0.982, alpha: 1)
        })

        static let backgroundLift = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.115, green: 0.104, blue: 0.128, alpha: 1)
                : UIColor(red: 1.000, green: 0.996, blue: 0.976, alpha: 1)
        })

        static let panel = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.105, green: 0.112, blue: 0.118, alpha: 0.86)
                : UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.74)
        })

        static let textSurface = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.170, green: 0.182, blue: 0.180, alpha: 0.74)
                : UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.58)
        })

        static let ink = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.936, green: 0.944, blue: 0.930, alpha: 1)
                : UIColor(red: 0.050, green: 0.077, blue: 0.084, alpha: 1)
        })

        static let secondaryText = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.688, green: 0.715, blue: 0.700, alpha: 1)
                : UIColor(red: 0.350, green: 0.420, blue: 0.430, alpha: 1)
        })

        static let hairline = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.780, green: 0.820, blue: 0.790, alpha: 0.24)
                : UIColor(red: 0.165, green: 0.245, blue: 0.245, alpha: 0.11)
        })

        static let accent = Color(red: 0.074, green: 0.455, blue: 0.430)
        static let marine = Color(red: 0.082, green: 0.310, blue: 0.510)
        static let violet = Color(red: 0.420, green: 0.315, blue: 0.600)
        static let copper = Color(red: 0.760, green: 0.390, blue: 0.225)
        static let mint = Color(red: 0.210, green: 0.670, blue: 0.510)
        static let amber = Color(red: 0.890, green: 0.570, blue: 0.140)
        static let red = Color(red: 0.820, green: 0.225, blue: 0.195)
        static let blue = Color(red: 0.170, green: 0.405, blue: 0.820)
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 20
        static let xl: CGFloat = 28
        static let xxl: CGFloat = 36
    }

    enum Radius {
        static let chip: CGFloat = 13
        static let control: CGFloat = 18
        static let panel: CGFloat = 28
        static let hero: CGFloat = 34
    }

    enum Motion {
        static let soft = Animation.spring(response: 0.36, dampingFraction: 0.86)
        static let quick = Animation.spring(response: 0.24, dampingFraction: 0.82)
    }

    enum Typography {
        static let metricValue = Font.system(.title2, design: .rounded).weight(.bold)
        static let routeTitle = Font.system(.title3, design: .rounded).weight(.semibold)
        static let compactLabel = Font.system(.caption, design: .rounded).weight(.semibold)
    }
}

enum RailServiceStatus: String, CaseIterable, Identifiable {
    case onTime
    case delayed
    case canceled
    case platformChanged
    case boarding
    case arrived
    case disruption

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .onTime:
            return "On time"
        case .delayed:
            return "Delayed"
        case .canceled:
            return "Canceled"
        case .platformChanged:
            return "Platform changed"
        case .boarding:
            return "Boarding open"
        case .arrived:
            return "Arrived"
        case .disruption:
            return "Disruption"
        }
    }

    var symbolName: String {
        switch self {
        case .onTime:
            return "checkmark.circle.fill"
        case .delayed:
            return "clock.badge.exclamationmark.fill"
        case .canceled:
            return "xmark.octagon.fill"
        case .platformChanged:
            return "arrow.triangle.branch"
        case .boarding:
            return "figure.walk.arrival"
        case .arrived:
            return "mappin.and.ellipse"
        case .disruption:
            return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .onTime, .boarding, .arrived:
            return RailDesign.Palette.mint
        case .delayed, .platformChanged:
            return RailDesign.Palette.amber
        case .canceled:
            return RailDesign.Palette.red
        case .disruption:
            return RailDesign.Palette.copper
        }
    }

    var glassTint: Color {
        tint.opacity(0.16)
    }

    static func from(_ trip: TrainTrip) -> RailServiceStatus {
        let status = trip.status.lowercased()
        let alerts = trip.alerts.map { "\($0.title) \($0.detail)" }.joined(separator: " ").lowercased()

        if trip.progress >= 0.98 || status.contains("arrived") {
            return .arrived
        }
        if status.contains("cancel") {
            return .canceled
        }
        if status.contains("platform") || alerts.contains("platform") {
            return .platformChanged
        }
        if status.contains("boarding") || status.contains("open") {
            return .boarding
        }
        if trip.statusTone == .late || status.contains("delay") || status.contains("late") {
            return .delayed
        }
        if trip.statusTone == .watch {
            return .disruption
        }
        return .onTime
    }
}

struct RailGradientBackground: View {
    var body: some View {
        ZStack {
            RailDesign.Palette.background

            LinearGradient(
                colors: [
                    RailDesign.Palette.backgroundLift.opacity(0.92),
                    RailDesign.Palette.background.opacity(0.76),
                    RailDesign.Palette.accent.opacity(0.10),
                    RailDesign.Palette.copper.opacity(0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    RailDesign.Palette.mint.opacity(0.20),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 420
            )

            RadialGradient(
                colors: [
                    RailDesign.Palette.copper.opacity(0.12),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 360
            )
        }
    }
}

private struct RailLiquidGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color
    let interactive: Bool
    let strokeOpacity: Double

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content
                .background(
                    RailDesign.Palette.panel,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(RailDesign.Palette.hairline.opacity(0.95), lineWidth: 1.2)
                )
        } else if interactive {
            content
                .background(
                    ZStack {
                        RailDesign.Palette.panel
                        tint.opacity(0.26)
                    },
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay(glassStroke)
        } else {
            content
                .background(
                    ZStack {
                        RailDesign.Palette.panel
                        tint.opacity(0.20)
                    },
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay(glassStroke)
        }
    }

    private var glassStroke: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(strokeOpacity),
                        RailDesign.Palette.hairline.opacity(0.28),
                        .white.opacity(strokeOpacity * 0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

private struct RailPanelShadowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .shadow(
                color: RailDesign.Palette.ink.opacity(contrast == .increased ? 0.05 : (colorScheme == .dark ? 0.22 : 0.075)),
                radius: contrast == .increased ? 4 : 18,
                x: 0,
                y: contrast == .increased ? 2 : 9
            )
    }
}

extension View {
    func railLiquidGlass(
        cornerRadius: CGFloat = RailDesign.Radius.panel,
        tint: Color = .white.opacity(0.10),
        interactive: Bool = false,
        strokeOpacity: Double = 0.42
    ) -> some View {
        modifier(
            RailLiquidGlassModifier(
                cornerRadius: cornerRadius,
                tint: tint,
                interactive: interactive,
                strokeOpacity: strokeOpacity
            )
        )
    }

    func railPanelShadow() -> some View {
        modifier(RailPanelShadowModifier())
    }

    func railScreenChrome() -> some View {
        background(RailGradientBackground().ignoresSafeArea())
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
