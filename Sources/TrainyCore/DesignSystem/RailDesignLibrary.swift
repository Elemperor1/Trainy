/// Subtle press feedback. Apple HIG and the make-interfaces-feel-better
/// skill both call for `scale(0.96)` on press. Apply this style to any
/// custom interactive surface that isn't already using a system button style.
struct PressableButtonStyle: ButtonStyle {
    var isStatic = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && !reduceMotion && !isStatic
                    ? 0.96
                    : 1
            )
            .animation(
                reduceMotion || isStatic ? nil : RailDesign.Motion.quick,
                value: configuration.isPressed
            )
    }
}

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

struct TripToolButton: View {
    let symbol: String
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: RailDesign.Spacing.xs) {
            Image(systemName: symbol)
                .font(RailDesign.Typography.small.weight(.semibold))
            Text(title)
                .font(RailDesign.Typography.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(RailDesign.Palette.ink)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(RailDesign.Palette.inset, in: RoundedRectangle(cornerRadius: RailDesign.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.sm, style: .continuous)
                .stroke(RailDesign.Palette.hairline, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: RailDesign.Radius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RailDesign.Palette.secondaryText)
                .textCase(.uppercase)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                    .fill(RailDesign.Palette.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                    .stroke(RailDesign.Palette.hairline, lineWidth: 1)
            )
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
        .accessibilityRepresentation {
            Toggle(title, isOn: $isOn)
                .accessibilityHint(detail)
        }
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
