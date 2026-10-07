import SwiftUI

/// Displays configured proxy availability, per-provider health, and recovery controls.
struct ProviderProxyStatusSummary: View {
    @ObservedObject var store: TrainStore

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
                Image(systemName: statusSymbol)
                    .font(RailDesign.Typography.h3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(statusTint)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.xs) {
                        Text("Provider proxy")
                            .font(RailDesign.Typography.h3)
                            .foregroundStyle(RailDesign.Palette.ink)
                        ProviderStatusPill(text: statusText, tint: statusTint)
                    }
                    Text(detailText)
                        .font(RailDesign.Typography.caption)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: RailDesign.Spacing.xs)

                Button {
                    Task {
                        await store.refreshProviderProxyHealth()
                    }
                } label: {
                    Label(actionTitle, systemImage: "arrow.clockwise")
                }
                .font(RailDesign.Typography.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(store.providerProxyLoadState == .loading)
                .accessibilityHint("Checks provider, cache, and proxy availability again")
            }

            if !store.providerProxyHealthProviders.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(store.providerProxyHealthProviders.prefix(6).enumerated()), id: \.element.id) { index, health in
                        if index > 0 {
                            Divider()
                                .background(RailDesign.Palette.hairline)
                        }
                        ProviderProxyHealthProviderRow(health: health)
                    }
                }
            }
        }
        .padding(.vertical, RailDesign.Spacing.s)
        .task {
            guard store.providerProxyHealth == nil else { return }
            await store.refreshProviderProxyHealth()
        }
    }

    private var statusText: String {
        switch store.providerProxyLoadState {
        case .notConfigured:
            return "Not configured"
        case .idle:
            return "Configured"
        case .loading:
            return "Checking"
        case .loaded:
            return hasAttention ? "Attention" : "Healthy"
        case .unavailable:
            return "Unavailable"
        }
    }

    private var detailText: String {
        switch store.providerProxyLoadState {
        case .notConfigured:
            return "No provider proxy base URL is configured."
        case .idle:
            return "Ready to check app-safe provider health at \(store.providerProxyConfiguration.displayHost)."
        case .loading:
            return "Checking provider and cache health at \(store.providerProxyConfiguration.displayHost)."
        case .loaded(let generatedAt):
            let timestamp = generatedAt.map { Self.dateFormatter.string(from: $0) } ?? "an unknown time"
            return "Provider health was generated at \(timestamp)."
        case .unavailable(let message):
            return "Could not load provider health: \(message)"
        }
    }

    private var actionTitle: LocalizedStringKey {
        switch store.providerProxyLoadState {
        case .loading:
            return "Checking"
        case .unavailable:
            return "Retry"
        case .notConfigured, .idle, .loaded:
            return "Check"
        }
    }

    private var statusTint: Color {
        switch store.providerProxyLoadState {
        case .notConfigured:
            return RailDesign.Palette.secondaryText
        case .idle, .loading:
            return RailDesign.Palette.info
        case .loaded:
            return hasAttention ? RailDesign.Palette.warning : RailDesign.Palette.success
        case .unavailable:
            return RailDesign.Palette.danger
        }
    }

    private var statusSymbol: String {
        switch store.providerProxyLoadState {
        case .notConfigured:
            return "lock.slash"
        case .idle:
            return "cloud"
        case .loading:
            return "arrow.clockwise"
        case .loaded:
            return hasAttention ? "exclamationmark.shield.fill" : "checkmark.shield.fill"
        case .unavailable:
            return "wifi.slash"
        }
    }

    private var hasAttention: Bool {
        store.providerProxyHealthProviders.contains { $0.status != .ok }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

/// One proxy provider's reported health and static-feed cache state.
private struct ProviderProxyHealthProviderRow: View {
    let health: ProviderProxyProviderHealth

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: health.status.symbolName)
                .foregroundStyle(health.status.tint)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.xs) {
                    Text(health.id)
                        .font(RailDesign.Typography.caption.weight(.bold))
                        .foregroundStyle(RailDesign.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    ProviderStatusPill(text: health.status.displayName, tint: health.status.tint)
                }
                Text(health.message)
                    .font(RailDesign.Typography.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let cache = health.cache {
                    Text("Static feed: \(cache.staticFeed.displayName)")
                        .font(RailDesign.Typography.caption.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                }
            }
        }
        .padding(.vertical, RailDesign.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

private extension ProviderProxyHealthStatus {
    var tint: Color {
        switch self {
        case .ok:
            return RailDesign.Palette.success
        case .missingCredential, .rateLimited, .stale:
            return RailDesign.Palette.warning
        case .offline:
            return RailDesign.Palette.danger
        case .unsupported, .unknown:
            return RailDesign.Palette.secondaryText
        }
    }

    var symbolName: String {
        switch self {
        case .ok:
            return "checkmark.shield.fill"
        case .missingCredential:
            return "lock.shield"
        case .rateLimited:
            return "speedometer"
        case .offline:
            return "wifi.slash"
        case .stale:
            return "clock.badge.exclamationmark"
        case .unsupported:
            return "nosign"
        case .unknown:
            return "questionmark.circle"
        }
    }
}
