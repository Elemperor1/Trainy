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

        // Inset surface — slightly lighter than the canvas, used for chips, search
        // fields, and the duration capsule inside a trip card. Defined here so
        // every inset call site uses the same value and the dark-mode contrast
        // stays in sync with --surface-inset in the web tokens.
        static let inset = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.121, green: 0.130, blue: 0.140, alpha: 1)
                : UIColor(red: 0.949, green: 0.957, blue: 0.965, alpha: 1)
        })

        static let ink = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.936, green: 0.944, blue: 0.930, alpha: 1)
                : UIColor(red: 0.050, green: 0.077, blue: 0.084, alpha: 1)
        })

        // Disabled / hairline ink for dividers and inactive separators.
        // Lives next to `ink` so the design system stays compact.
        static let inkDisabled = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.420, green: 0.450, blue: 0.460, alpha: 1)
                : UIColor(red: 0.628, green: 0.654, blue: 0.682, alpha: 1)
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

        // MARK: Semantic roles
        // Route all status/meaning colors through these aliases so palette swaps
        // and theming stay centralized. Do not hardcode status colors inline.
        static let success = mint
        static let warning = amber
        static let danger = red
        static let info = blue
        static let onAccent = Color.white
    }

    enum Spacing {
        // Tokens: 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let hero: CGFloat = 64
    }

    enum Radius {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let chip: CGFloat = 13
        static let control: CGFloat = 16
        static let card: CGFloat = 16
        static let panel: CGFloat = 24
        static let hero: CGFloat = 32
        static let pill: CGFloat = 999
        static let station: CGFloat = 12
    }

    enum Layout {
        /// Keeps the final scroll item clear of the persistent tab bar and
        /// floating controls without reconstructing an arbitrary inset.
        static let deepScrollBottomInset: CGFloat = 160
        /// Optical inset for sub-pixel progress strokes.
        static let progressStrokeInset: CGFloat = 0.5
    }

    enum Motion {
        static let soft = Animation.spring(response: 0.36, dampingFraction: 0.86)
        static let quick = Animation.spring(response: 0.24, dampingFraction: 0.82)
        static let shimmer = Animation.linear(duration: 1.4).repeatForever(autoreverses: false)
    }

    enum Typography {
        // Display / H1 / H2 / H3 / Body / Small / Caption. Each maps to a
        // semantic role so we don't sprinkle raw `.font(.system(...))`
        // across screens; the legacy aliases below stay so existing call
        // sites compile and read the same as before.

        /// 36 pt display value. Large enough to anchor journey times while
        /// preserving an optical gap between two 12-hour timestamps on iPhone.
        static let display = Font.system(size: 36, weight: .bold, design: .rounded)

        /// 28 pt screen title. Used by every `navigationTitle`.
        static let h1 = Font.system(size: 28, weight: .semibold, design: .rounded)

        /// 18 pt section header. Used by every `SectionHeader` and card title.
        static let h2 = Font.system(size: 18, weight: .semibold, design: .rounded)

        /// 15 pt card title / list-row title.
        static let h3 = Font.system(size: 15, weight: .semibold, design: .rounded)

        /// 14 pt default body copy.
        static let body = Font.system(size: 14, weight: .regular, design: .default)

        /// 13 pt secondary metadata.
        static let small = Font.system(size: 13, weight: .regular, design: .default)

        /// 11 pt uppercase eyebrow text.
        static let caption = Font.system(size: 11, weight: .medium, design: .default)

        // Legacy aliases so existing call sites still compile and read the
        // same shape they used to. New code should prefer the tokens above.
        static let largeTitle = display
        static let title = h1
        static let metricValue = display
        static let routeTitle = h3
        static let headline = h3
        static let callout = body
        static let compactLabel = Font.system(size: 12, weight: .semibold, design: .default)
        static let micro = small

        // Illustration and map-canvas roles are intentionally named here
        // instead of being reconstructed at each annotation call site.
        static let regionGlobe = Font.system(size: 152, weight: .regular)
        static let mapPositionLabel = Font.system(size: 10, weight: .bold, design: .rounded)

        static func mapTransferSymbol(isEmphasized: Bool) -> Font {
            Font.system(size: isEmphasized ? 11 : 8, weight: .bold)
        }

        static func mapStationLabel(isEmphasized: Bool) -> Font {
            Font.system(size: isEmphasized ? 10 : 9, weight: .bold, design: .rounded)
        }

        static func mapVehicle(isLive: Bool) -> Font {
            isLive ? h2.weight(.black) : small.weight(.black)
        }
    }

    /// Elevation presets. Use with `railPanelShadow()` or custom shadows so
    /// shadow values are never hardcoded inline in screens.
    enum Elevation {
        struct Shadow {
            let radius: CGFloat
            let y: CGFloat
            let opacity: Double
        }
        /// Resting card.
        static let resting = Shadow(radius: 18, y: 9, opacity: 0.10)
        /// Raised / interactive.
        static let raised = Shadow(radius: 26, y: 14, opacity: 0.16)
        /// Hero panel.
        static let hero = Shadow(radius: 34, y: 18, opacity: 0.22)
        /// Compact map annotation.
        static let mapLabel = Shadow(radius: 4, y: 2, opacity: 0.08)
        /// Service alert annotation.
        static let mapAlert = Shadow(radius: 8, y: 3, opacity: 0.32)

        static func mapStation(isEmphasized: Bool) -> Shadow {
            Shadow(radius: isEmphasized ? 8 : 3, y: 2, opacity: 0.34)
        }

        static func mapVehicle(isLive: Bool) -> Shadow {
            Shadow(radius: isLive ? 14 : 9, y: 5, opacity: 0.26)
        }
    }
}

extension TrainStatusTone {
    var tint: Color {
        switch self {
        case .good:
            return RailDesign.Palette.success
        case .watch:
            return RailDesign.Palette.warning
        case .late:
            return RailDesign.Palette.danger
        }
    }

    var softFill: Color {
        tint.opacity(0.14)
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

    var accessibilityTitle: String {
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
                .glassEffect(
                    .regular.tint(tint).interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .overlay(glassStroke)
        } else {
            content
                .glassEffect(
                    .regular.tint(tint),
                    in: .rect(cornerRadius: cornerRadius)
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
    let elevation: RailDesign.Elevation.Shadow
    let tint: Color?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let baseColor = tint ?? RailDesign.Palette.ink
        let resolvedOpacity = tint == nil
            ? (colorScheme == .dark ? elevation.opacity : elevation.opacity * 0.75)
            : elevation.opacity

        content
            .shadow(
                color: baseColor.opacity(contrast == .increased ? min(resolvedOpacity, 0.08) : resolvedOpacity),
                radius: contrast == .increased ? 4 : elevation.radius,
                x: 0,
                y: contrast == .increased ? 2 : elevation.y
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

    func railPanelShadow(
        _ elevation: RailDesign.Elevation.Shadow = RailDesign.Elevation.resting
    ) -> some View {
        modifier(RailPanelShadowModifier(elevation: elevation, tint: nil))
    }

    func railShadow(
        _ elevation: RailDesign.Elevation.Shadow,
        tint: Color
    ) -> some View {
        modifier(RailPanelShadowModifier(elevation: elevation, tint: tint))
    }

    func railScreenChrome() -> some View {
        background(RailGradientBackground().ignoresSafeArea())
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }

    func railTabBarChrome() -> some View {
        toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }

    func railBottomMaterialBar() -> some View {
        background(.ultraThinMaterial)
    }

    func railMaterialCapsule() -> some View {
        background(.regularMaterial, in: Capsule())
    }
}
