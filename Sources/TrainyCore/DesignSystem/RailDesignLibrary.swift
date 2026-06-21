import SwiftUI

// MARK: - RailDesignLibrary
// Unified, reusable Design System component library.
//
// These primitives were extracted from the hand-rolled one-off views that were
// previously inlined in `ContentView.swift`. They are the single source of truth
// for these controls: all UI must route through this library (see the
// `review-design-system` review skill and `scripts/check-design-system-bypass.sh`).
// Do not re-inline these components or duplicate their styling tokens.

struct ControlMetricTile: View {
    let title: LocalizedStringKey
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .imageScale(.small)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .lineLimit(1)
            }
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(RailDesign.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RailDesign.Spacing.s)
        .padding(.vertical, 10)
        .background(RailDesign.Palette.textSurface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(RailDesign.Palette.hairline.opacity(0.7), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

struct SummaryActionLabel: View {
    let symbol: String
    let title: LocalizedStringKey

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.bold))
            .foregroundStyle(RailDesign.Palette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .railLiquidGlass(cornerRadius: 18, tint: .white.opacity(0.12), interactive: true, strokeOpacity: 0.28)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct SummaryIconLabel: View {
    let symbol: String
    let title: LocalizedStringKey

    var body: some View {
        Image(systemName: symbol)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(RailDesign.Palette.ink)
            .frame(width: 40, height: 34)
            .railLiquidGlass(cornerRadius: 17, tint: .white.opacity(0.12), interactive: true, strokeOpacity: 0.26)
            .accessibilityLabel(title)
    }
}

struct SummaryButton: View {
    let symbol: String
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SummaryActionLabel(symbol: symbol, title: title)
        }
        .buttonStyle(.plain)
    }
}

struct RailSegmentedPicker: View {
    @Binding var selection: TripBucket
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer(spacing: RailDesign.Spacing.xs) {
            HStack(spacing: RailDesign.Spacing.xs) {
                ForEach(TripBucket.allCases) { bucket in
                    Button {
                        selection = bucket
                    } label: {
                        Text(bucket.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selection == bucket ? RailDesign.Palette.ink : RailDesign.Palette.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, RailDesign.Spacing.s)
                            .background {
                                if selection == bucket {
                                    Capsule()
                                        .fill(RailDesign.Palette.accent.opacity(0.10))
                                        .glassEffectID(bucket.id, in: namespace)
                                        .railLiquidGlass(cornerRadius: 18, tint: RailDesign.Palette.accent.opacity(0.22), interactive: true)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == bucket ? .isSelected : [])
                }
            }
            .padding(6)
            .railLiquidGlass(cornerRadius: 24, tint: .white.opacity(0.12), interactive: true)
        }
    }
}

struct CoverageLegendItem: View {
    let title: LocalizedStringKey
    let tint: Color

    var body: some View {
        HStack(spacing: RailDesign.Spacing.xs) {
            Circle()
                .fill(tint)
                .frame(width: 9, height: 9)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RailDesign.Palette.secondaryText)
        }
    }
}

struct StatusSummaryItem: View {
    let title: LocalizedStringKey
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: RailDesign.Spacing.s) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .railLiquidGlass(cornerRadius: 17, tint: tint.opacity(0.18))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    let subtitle: Text

    init(title: LocalizedStringKey, subtitle: LocalizedStringKey) {
        self.title = title
        self.subtitle = Text(subtitle)
    }

    init(title: LocalizedStringKey, subtitle: String) {
        self.title = title
        self.subtitle = Text(subtitle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
                .foregroundStyle(RailDesign.Palette.ink)
            subtitle
                .font(.caption)
                .foregroundStyle(RailDesign.Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .textCase(nil)
    }
}

struct MiniStat: View {
    let title: LocalizedStringKey
    let value: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
            Text(value)
                .font(.headline.monospacedDigit().weight(.bold))
                .foregroundStyle(RailDesign.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(RailDesign.Palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RailDesign.Spacing.s)
        .railLiquidGlass(cornerRadius: RailDesign.Radius.control, tint: tint.opacity(0.12))
    }
}

struct InfoLine: View {
    let symbol: String
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: symbol)
                .foregroundStyle(RailDesign.Palette.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                Text(value.isEmpty ? "Not available" : value)
                    .font(.subheadline)
                    .foregroundStyle(RailDesign.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct DelayBar: View {
    let delayCount: Int
    let total: Int

    private var ratio: Double {
        min(1, max(0, Double(delayCount) / Double(total)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
            HStack {
                Text("Delay share")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                Spacer()
                Text("\(delayCount) of \(total)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(RailDesign.Palette.hairline)
                    Capsule()
                        .fill(delayCount == 0 ? RailDesign.Palette.mint : RailDesign.Palette.amber)
                        .frame(width: max(10, proxy.size.width * ratio))
                }
            }
            .frame(height: 10)
        }
    }
}

struct SettingsGroup<Content: View>: View {
    let title: LocalizedStringKey
    let content: Content

    init(title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            Text(title)
                .font(.headline)
                .foregroundStyle(RailDesign.Palette.ink)
            GlassPanel {
                VStack(spacing: 0) {
                    content
                }
            }
        }
    }
}

struct SettingsToggleRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            SettingsRowLabel(symbol: symbol, title: title, detail: detail)
        }
        .tint(RailDesign.Palette.accent)
        .padding(.vertical, RailDesign.Spacing.s)
    }
}

struct SettingsPickerRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    @Binding var selection: String
    let options: [String]

    var body: some View {
        HStack {
            SettingsRowLabel(symbol: symbol, title: title, detail: detail)
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.vertical, RailDesign.Spacing.s)
    }
}

struct SettingsInfoRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        SettingsRowLabel(symbol: symbol, title: title, detail: detail)
            .padding(.vertical, RailDesign.Spacing.s)
    }
}

struct SettingsNavigationRow<Destination: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let destination: Destination

    init(
        symbol: String,
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        @ViewBuilder destination: () -> Destination
    ) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(alignment: .center, spacing: RailDesign.Spacing.s) {
                SettingsRowLabel(symbol: symbol, title: title, detail: detail)
                Spacer(minLength: RailDesign.Spacing.s)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RailDesign.Palette.secondaryText)
            }
            .contentShape(Rectangle())
            .padding(.vertical, RailDesign.Spacing.s)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}

struct SettingsActionRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let actionTitle: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: RailDesign.Spacing.s) {
                SettingsRowLabel(symbol: symbol, title: title, detail: detail)
                Spacer(minLength: RailDesign.Spacing.s)
                Text(actionTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RailDesign.Palette.accent)
                    .padding(.horizontal, RailDesign.Spacing.s)
                    .padding(.vertical, 8)
                    .background(RailDesign.Palette.accent.opacity(0.12), in: Capsule())
            }
            .contentShape(Rectangle())
            .padding(.vertical, RailDesign.Spacing.s)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}

struct SettingsRowLabel: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: symbol)
                .foregroundStyle(RailDesign.Palette.accent)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
