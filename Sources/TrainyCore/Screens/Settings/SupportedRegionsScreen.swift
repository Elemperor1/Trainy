import SwiftUI

/// Provider-coverage directory grouped by rider availability and implementation readiness.
struct SupportedRegionsScreen: View {
    @ObservedObject var store: TrainStore

    private var riderAvailableProviders: [ProviderMetadata] {
        store.providerDirectory
            .filter(\.isRiderAvailable)
            .sorted { $0.region.displayName.localizedStandardCompare($1.region.displayName) == .orderedAscending }
    }

    private var configurationRequiredProviders: [ProviderMetadata] {
        store.providerDirectory
            .filter { $0.implementationStatus == .active && !$0.availability.canSearch }
            .sorted { $0.region.displayName.localizedStandardCompare($1.region.displayName) == .orderedAscending }
    }

    private var adapterReadyProviders: [ProviderMetadata] {
        store.providerDirectory
            .filter { $0.implementationStatus == .adapterReady }
            .sorted { $0.region.displayName.localizedStandardCompare($1.region.displayName) == .orderedAscending }
    }

    private var selectedProvider: ProviderMetadata? {
        store.providerDirectory.first { $0.id == store.activeProviderID }
    }

    private var plannedRegionNames: [String] {
        let implementedRegionIDs = Set(
            (riderAvailableProviders + configurationRequiredProviders + adapterReadyProviders).map(\.region.id)
        )
        return store.providerRegions
            .filter { $0.id != ProviderRegion.all.id && !implementedRegionIDs.contains($0.id) }
            .map(\.displayName)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                if let selectedProvider {
                    SettingsGroup(title: "Search scope") {
                        HStack(spacing: RailDesign.Spacing.s) {
                            Image(systemName: "scope")
                                .font(RailDesign.Typography.h3)
                                .foregroundStyle(RailDesign.Palette.accent)
                                .frame(width: 32, height: 32)
                                .background(RailDesign.Palette.accent.opacity(0.10), in: Circle())
                            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                                Text(selectedProvider.displayName)
                                    .font(RailDesign.Typography.h3)
                                    .foregroundStyle(RailDesign.Palette.ink)
                                Text("\(selectedProvider.region.displayName) · \(selectedProvider.capabilities.map(\.displayName).joined(separator: ", "))")
                                    .font(RailDesign.Typography.small)
                                    .foregroundStyle(RailDesign.Palette.secondaryText)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, RailDesign.Spacing.s)
                    }
                }

                VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                    SectionHeader(title: "Coverage", subtitle: "Bright markers are rider-available now. Adapter-ready and planned regions remain muted.")
                    SupportedRegionsGlobe(activeRegions: riderAvailableProviders.map(\.region.displayName))
                }

                SettingsGroup(title: "Available now") {
                    ForEach(riderAvailableProviders) { provider in
                        SupportedRegionProviderRow(
                            provider: provider,
                            isActive: provider.id == store.activeProviderID
                        )
                        if provider.id != riderAvailableProviders.last?.id {
                            Divider()
                                .background(RailDesign.Palette.hairline)
                        }
                    }
                }

                if !configurationRequiredProviders.isEmpty {
                    SettingsGroup(title: "Needs setup") {
                        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                            Text("These rider-ready providers need their required proxy or local configuration before they can be used in this build.")
                                .font(RailDesign.Typography.small)
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(configurationRequiredProviders) { provider in
                                SupportedRegionProviderRow(provider: provider, isActive: false)
                            }
                        }
                        .padding(.vertical, RailDesign.Spacing.s)
                    }
                }

                if !adapterReadyProviders.isEmpty {
                    SettingsGroup(title: "Adapter ready") {
                        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                            Text("Implemented and fixture-tested, but not rider-available until a secure data path and dedicated product surface are connected.")
                                .font(RailDesign.Typography.small)
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(adapterReadyProviders) { provider in
                                SupportedRegionProviderRow(provider: provider, isActive: false)
                            }
                        }
                        .padding(.vertical, RailDesign.Spacing.s)
                    }
                }

                if !plannedRegionNames.isEmpty {
                    SettingsGroup(title: "Planned regions") {
                        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                            Text("Visible for roadmap transparency, but not selectable or searchable in this build.")
                                .font(RailDesign.Typography.small)
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            SupportedRegionPillGrid(names: plannedRegionNames)
                        }
                        .padding(.vertical, RailDesign.Spacing.s)
                    }
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .navigationTitle("Supported regions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .railScreenChrome()
    }
}

/// Decorative globe that summarizes only regions riders can currently use.
private struct SupportedRegionsGlobe: View {
    let activeRegions: [String]

    /// Normalized marker position on the decorative globe.
    private struct Marker: Identifiable {
        let id: String
        let x: CGFloat
        let y: CGFloat
    }

    private var markers: [Marker] {
        activeRegions.compactMap { region in
            switch region {
            case "Japan":
                return Marker(id: region, x: 0.78, y: 0.43)
            case "Netherlands":
                return Marker(id: region, x: 0.46, y: 0.31)
            default:
                return nil
            }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: RailDesign.Radius.panel, style: .continuous)
                    .fill(RailDesign.Palette.panel)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                RailDesign.Palette.inset,
                                RailDesign.Palette.backgroundLift
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(RailDesign.Palette.hairline, lineWidth: 1)
                    )
                    .frame(width: 190, height: 190)

                Image(systemName: "globe.asia.australia.fill")
                    .font(RailDesign.Typography.regionGlobe)
                    .foregroundStyle(RailDesign.Palette.secondaryText.opacity(0.18))
                    .symbolRenderingMode(.hierarchical)

                ForEach(markers) { marker in
                    ZStack {
                        Circle()
                            .fill(RailDesign.Palette.accent.opacity(0.18))
                            .frame(width: 26, height: 26)
                        Circle()
                            .fill(RailDesign.Palette.accent)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(RailDesign.Palette.onAccent, lineWidth: 2))
                    }
                    .position(
                        x: proxy.size.width * marker.x,
                        y: proxy.size.height * marker.y
                    )
                }

                VStack {
                    Spacer()
                    HStack(spacing: RailDesign.Spacing.xs) {
                        Circle()
                            .fill(RailDesign.Palette.accent)
                            .frame(width: 8, height: 8)
                        Text("\(activeRegions.count) rider-available \(activeRegions.count == 1 ? "region" : "regions")")
                            .font(RailDesign.Typography.small.weight(.semibold))
                            .foregroundStyle(RailDesign.Palette.ink)
                    }
                    .padding(.horizontal, RailDesign.Spacing.s)
                    .padding(.vertical, RailDesign.Spacing.xs)
                    .railMaterialCapsule()
                    .padding(.bottom, RailDesign.Spacing.s)
                }
            }
        }
        .frame(height: 232)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rider-available regions: \(activeRegions.joined(separator: ", "))")
    }
}

/// One provider's region, readiness, and honest availability explanation.
private struct SupportedRegionProviderRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let provider: ProviderMetadata
    let isActive: Bool

    private var tint: Color {
        if isActive {
            return RailDesign.Palette.success
        }
        if !provider.availability.canSearch {
            return provider.availability.status.tint
        }
        return provider.implementationStatus == .adapterReady
            ? RailDesign.Palette.info
            : RailDesign.Palette.accent
    }

    private var statusText: String {
        if isActive {
            return "Selected"
        }
        if !provider.availability.canSearch {
            return provider.availability.status.displayName
        }
        return provider.implementationStatus.displayName
    }

    private var availabilityMessage: String {
        if provider.availability.message.contains("ODPT_CONSUMER_KEY") {
            return "Starter catalog is active. Add an ODPT consumer key in the developer configuration for official timetable and alert feeds."
        }
        if provider.id == "netherlands-ns" {
            if provider.availability.canSearch {
                return "Proxy-backed NS station search, departures, and service alerts are rider-available in this configured build."
            }
            return provider.availability.message
        }
        return provider.availability.message
    }

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: isActive ? "checkmark.seal.fill" : "circle.dashed")
                .font(RailDesign.Typography.h3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                        Text(provider.region.displayName)
                            .font(RailDesign.Typography.h3.weight(.bold))
                            .foregroundStyle(RailDesign.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        ProviderStatusPill(text: statusText, tint: tint)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.xs) {
                        Text(provider.region.displayName)
                            .font(RailDesign.Typography.h3.weight(.bold))
                            .foregroundStyle(RailDesign.Palette.ink)
                        ProviderStatusPill(text: statusText, tint: tint)
                    }
                }

                Text(provider.displayName)
                    .font(RailDesign.Typography.caption.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(availabilityMessage)
                    .font(RailDesign.Typography.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, RailDesign.Spacing.s)
        .accessibilityElement(children: .combine)
    }
}

/// Compact grid for regions that remain outside the rider-available directory.
private struct SupportedRegionPillGrid: View {
    let names: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: RailDesign.Spacing.xs)], alignment: .leading, spacing: RailDesign.Spacing.xs) {
            ForEach(names, id: \.self) { name in
                Text(name)
                    .font(RailDesign.Typography.caption.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, RailDesign.Spacing.xs)
                    .padding(.vertical, RailDesign.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RailDesign.Palette.hairline.opacity(0.78), in: Capsule())
            }
        }
    }
}

private extension ProviderMetadata {
    var sourcePolicyRequirements: [String] {
        requirements.compactMap { requirement in
            switch requirement {
            case .attribution(let label):
                return "Attribution: \(label)"
            case .terms(let label):
                return "Terms: \(label)"
            case .networkAccess, .localKey, .proxy, .providerAccount:
                return nil
            }
        }
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var operationalRequirements: [String] {
        requirements.compactMap { requirement in
            switch requirement {
            case .networkAccess, .localKey, .proxy, .providerAccount:
                return requirement.displayName
            case .attribution, .terms:
                return nil
            }
        }
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}

private extension ProviderAvailability.Status {
    var displayName: String {
        switch self {
        case .available:
            return "Available"
        case .degraded:
            return "Fallback"
        case .requiresConfiguration:
            return "Needs setup"
        case .requiresProxy:
            return "Needs proxy"
        case .unavailable:
            return "Unavailable"
        }
    }

    var tint: Color {
        switch self {
        case .available:
            return RailDesign.Palette.success
        case .degraded:
            return RailDesign.Palette.warning
        case .requiresConfiguration, .requiresProxy:
            return RailDesign.Palette.info
        case .unavailable:
            return RailDesign.Palette.secondaryText
        }
    }
}
