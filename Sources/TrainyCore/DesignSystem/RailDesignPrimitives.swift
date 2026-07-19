import SwiftUI

// MARK: - Semantic surfaces

enum RailSurfaceRole {
    case panel
    case inset
    case accent(Color)
    case status(Color)
    case material

    var fill: AnyShapeStyle {
        switch self {
        case .panel:
            return AnyShapeStyle(RailDesign.Palette.panel)
        case .inset:
            return AnyShapeStyle(RailDesign.Palette.inset)
        case let .accent(tint):
            return AnyShapeStyle(tint.opacity(0.10))
        case let .status(tint):
            return AnyShapeStyle(tint.opacity(0.10))
        case .material:
            return AnyShapeStyle(.regularMaterial)
        }
    }

    var stroke: Color {
        switch self {
        case .panel, .inset, .material:
            return RailDesign.Palette.hairline
        case let .accent(tint), let .status(tint):
            return tint.opacity(0.20)
        }
    }
}

struct RailSurface<Content: View>: View {
    let role: RailSurfaceRole
    let cornerRadius: CGFloat
    let padding: CGFloat
    let showsStroke: Bool
    let content: Content

    init(
        role: RailSurfaceRole = .panel,
        cornerRadius: CGFloat = RailDesign.Radius.card,
        padding: CGFloat = RailDesign.Spacing.m,
        showsStroke: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.role = role
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.showsStroke = showsStroke
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .railSurfaceStyle(
                role: role,
                cornerRadius: cornerRadius,
                showsStroke: showsStroke
            )
    }
}

private struct RailSurfaceModifier: ViewModifier {
    let role: RailSurfaceRole
    let cornerRadius: CGFloat
    let showsStroke: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(role.fill)
            )
            .overlay {
                if showsStroke {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(role.stroke, lineWidth: 1)
                }
            }
    }
}

// MARK: - Icons and dividers

struct RailIconBadge: View {
    enum Size {
        case compact
        case regular
        case hero

        var frame: CGFloat {
            switch self {
            case .compact: return 28
            case .regular: return 36
            case .hero: return 48
            }
        }

        var font: Font {
            switch self {
            case .compact: return RailDesign.Typography.caption.weight(.semibold)
            case .regular: return RailDesign.Typography.h3
            case .hero: return .title3.weight(.semibold)
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .compact: return RailDesign.Radius.xs
            case .regular: return RailDesign.Radius.sm
            case .hero: return RailDesign.Radius.control
            }
        }
    }

    let symbol: String
    let tint: Color
    var size: Size = .regular
    var circular = false

    var body: some View {
        Image(systemName: symbol)
            .font(size.font)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: size.frame, height: size.frame)
            .background {
                if circular {
                    Circle().fill(tint.opacity(0.11))
                } else {
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .fill(tint.opacity(0.11))
                }
            }
            .accessibilityHidden(true)
    }
}

struct RailBadge: View {
    private let title: Text
    let tint: Color
    var symbol: String?
    var minHeight: CGFloat = 30

    init(
        _ title: LocalizedStringKey,
        tint: Color,
        symbol: String? = nil,
        minHeight: CGFloat = 30
    ) {
        self.title = Text(title)
        self.tint = tint
        self.symbol = symbol
        self.minHeight = minHeight
    }

    init(
        _ title: String,
        tint: Color,
        symbol: String? = nil,
        minHeight: CGFloat = 30
    ) {
        self.title = Text(title)
        self.tint = tint
        self.symbol = symbol
        self.minHeight = minHeight
    }

    var body: some View {
        HStack(spacing: RailDesign.Spacing.xxs) {
            if let symbol {
                Image(systemName: symbol)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            title
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .font(RailDesign.Typography.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, RailDesign.Spacing.s)
        .frame(minHeight: minHeight)
        .background(tint.opacity(0.11), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.18), lineWidth: 1))
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
    }
}

struct RailDivider: View {
    var body: some View {
        Divider()
            .overlay(RailDesign.Palette.hairline)
    }
}

// MARK: - Rows

struct RailValueRow: View {
    enum Layout {
        case compact
        case stacked
    }

    let symbol: String
    let title: LocalizedStringKey
    let value: String
    var tint: Color = RailDesign.Palette.accent
    var valueLineLimit = 2
    var layout: Layout = .compact

    var body: some View {
        HStack(alignment: layout == .stacked ? .top : .center, spacing: RailDesign.Spacing.s) {
            Image(systemName: symbol)
                .font(RailDesign.Typography.small.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
                .accessibilityHidden(true)

            if layout == .stacked {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                    Text(title)
                        .font(RailDesign.Typography.caption.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                    valueText
                        .multilineTextAlignment(.leading)
                }
            } else {
                Text(title)
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)

                Spacer(minLength: RailDesign.Spacing.s)

                valueText
                    .multilineTextAlignment(.trailing)
            }
        }
        .frame(minHeight: 28)
        .accessibilityElement(children: .combine)
    }

    private var valueText: some View {
        Text(value.isEmpty ? "Not available" : value)
            .font(RailDesign.Typography.small.weight(.semibold))
            .foregroundStyle(RailDesign.Palette.ink)
            .lineLimit(valueLineLimit)
            .minimumScaleFactor(0.78)
            .fixedSize(horizontal: false, vertical: layout == .stacked)
    }
}

struct RailNavigationCard: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: String
    var tint: Color = RailDesign.Palette.accent

    var body: some View {
        HStack(spacing: RailDesign.Spacing.m) {
            RailIconBadge(symbol: symbol, tint: tint, size: .hero)

            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text(title)
                    .font(RailDesign.Typography.h3)
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(detail)
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: RailDesign.Spacing.s)

            Image(systemName: "chevron.right")
                .font(RailDesign.Typography.caption.weight(.semibold))
                .foregroundStyle(RailDesign.Palette.secondaryText)
                .offset(y: 1)
                .accessibilityHidden(true)
        }
        .contentShape(RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Actions

struct RailActionLabel: View {
    enum Role {
        case primary
        case secondary
        case quiet
    }

    let title: LocalizedStringKey
    let symbol: String
    var role: Role = .secondary

    var body: some View {
        Label(title, systemImage: symbol)
            .font(RailDesign.Typography.h3)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, RailDesign.Spacing.s)
            .background(background, in: RoundedRectangle(cornerRadius: RailDesign.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RailDesign.Radius.control, style: .continuous)
                    .stroke(stroke, lineWidth: role == .quiet ? 0 : 1)
            )
    }

    private var foreground: Color {
        switch role {
        case .primary:
            return RailDesign.Palette.onAccent
        case .secondary, .quiet:
            return RailDesign.Palette.ink
        }
    }

    private var background: Color {
        switch role {
        case .primary:
            return RailDesign.Palette.accent
        case .secondary:
            return RailDesign.Palette.inset
        case .quiet:
            return .clear
        }
    }

    private var stroke: Color {
        role == .secondary ? RailDesign.Palette.hairline : .clear
    }
}

struct RailActionButton: View {
    let title: LocalizedStringKey
    let symbol: String
    var role: RailActionLabel.Role = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RailActionLabel(title: title, symbol: symbol, role: role)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct RailToolbarIconButton: View {
    let symbol: String
    let accessibilityLabel: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct RailToolbarShareLink: View {
    let item: String
    var symbol = "square.and.arrow.up"

    var body: some View {
        ShareLink(item: item) {
            Image(systemName: symbol)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Share trip")
    }
}

// MARK: - Selection

struct RailSegmentedControl<Option: Identifiable & Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> LocalizedStringKey

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        options: [Option],
        selection: Binding<Option>,
        title: @escaping (Option) -> LocalizedStringKey
    ) {
        self.options = options
        _selection = selection
        self.title = title
    }

    var body: some View {
        HStack(spacing: RailDesign.Spacing.xxs) {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(RailDesign.Typography.h3)
                        .foregroundStyle(
                            selection == option
                                ? RailDesign.Palette.ink
                                : RailDesign.Palette.secondaryText
                        )
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if selection == option {
                                RoundedRectangle(
                                    cornerRadius: RailDesign.Radius.sm,
                                    style: .continuous
                                )
                                .fill(RailDesign.Palette.accent.opacity(0.12))
                                .matchedGeometryEffect(id: option.id, in: namespace)
                            }
                        }
                }
                .buttonStyle(PressableButtonStyle(isStatic: true))
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .padding(RailDesign.Spacing.xxs)
        .background(
            RailDesign.Palette.inset,
            in: RoundedRectangle(cornerRadius: RailDesign.Radius.control, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.control, style: .continuous)
                .stroke(RailDesign.Palette.hairline, lineWidth: 1)
        )
        .animation(reduceMotion ? nil : RailDesign.Motion.quick, value: selection)
    }
}

// MARK: - Screen and list policies

extension View {
    func railSurfaceStyle(
        role: RailSurfaceRole = .panel,
        cornerRadius: CGFloat = RailDesign.Radius.card,
        showsStroke: Bool = true
    ) -> some View {
        modifier(
            RailSurfaceModifier(
                role: role,
                cornerRadius: cornerRadius,
                showsStroke: showsStroke
            )
        )
    }

    func railListCardRow() -> some View {
        listRowInsets(
            EdgeInsets(
                top: RailDesign.Spacing.xs,
                leading: RailDesign.Spacing.m,
                bottom: RailDesign.Spacing.xs,
                trailing: RailDesign.Spacing.m
            )
        )
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

}
