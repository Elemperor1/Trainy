import SwiftUI

struct FirstRunExperienceSheet: View {
    @ObservedObject var store: TrainStore
    let startWithShinkansen: () -> Void
    let browseProviders: () -> Void
    let skip: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                        RailIconBadge(symbol: "checkmark.seal.fill", tint: RailDesign.Palette.accent, size: .hero)
                        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                            Text("Welcome to Trainy")
                                .font(RailDesign.Typography.h1)
                                .foregroundStyle(RailDesign.Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Japan Shinkansen and Netherlands station boards are ready. Every status includes its source and freshness context.")
                                .font(RailDesign.Typography.body)
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        SectionHeader(title: "What each label means", subtitle: "Trainy never overclaims live data; the source is always labeled.")
                        RailSurface {
                            VStack(spacing: 0) {
                                FirstRunScopeRow(symbol: "books.vertical.fill", title: "Starter catalog", detail: "Curated Shinkansen examples are available without provider credentials")
                                RailDivider()
                                FirstRunScopeRow(symbol: "calendar.badge.checkmark", title: "Official timetable", detail: "ODPT and JR timetable data is shown as scheduled when those sources return trips")
                                RailDivider()
                                FirstRunScopeRow(symbol: "dot.radiowaves.left.and.right", title: "Realtime", detail: "Predictions and vehicle positions only appear when a provider supplies those feeds")
                            }
                        }
                    }
                }
                .padding(RailDesign.Spacing.m)
                .padding(.bottom, RailDesign.Layout.deepScrollBottomInset)
            }
            .background(RailGradientBackground().ignoresSafeArea())
            .navigationTitle("Trainy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip", action: skip)
                        .font(RailDesign.Typography.h3)
                        .frame(minHeight: 44)
                        .accessibilityHint("Skip the data-scope onboarding for now")
                }
            }
            .safeAreaInset(edge: .bottom) {
                FirstRunActionBar(
                    startWithShinkansen: startWithShinkansen,
                    browseProviders: browseProviders
                )
            }
        }
        .accessibilityIdentifier("onboarding.screen")
    }
}

/// One explanation row in the first-run data-scope contract.
private struct FirstRunScopeRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: symbol)
                .foregroundStyle(RailDesign.Palette.accent)
                .font(RailDesign.Typography.h3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text(title)
                    .font(RailDesign.Typography.h3)
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(detail)
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, RailDesign.Spacing.s)
        .accessibilityElement(children: .combine)
    }
}

/// First-run actions for starting with the flagship service or browsing providers.
private struct FirstRunActionBar: View {
    let startWithShinkansen: () -> Void
    let browseProviders: () -> Void

    var body: some View {
        VStack(spacing: RailDesign.Spacing.s) {
            RailActionButton(
                title: "Start with Shinkansen",
                symbol: "train.side.front.car",
                role: .primary,
                action: startWithShinkansen
            )
            .accessibilityIdentifier("onboarding.start")
            .accessibilityLabel("Start with Shinkansen")
            .accessibilityHint("Use Japan Shinkansen as the active rail scope")

            RailActionButton(
                title: "Browse providers",
                symbol: "globe.asia.australia",
                action: browseProviders
            )
            .accessibilityIdentifier("onboarding.providers")
            .accessibilityLabel("Browse providers")
            .accessibilityHint("Review supported, setup-required, and planned rail providers")
        }
        .padding(.horizontal, RailDesign.Spacing.m)
        .padding(.top, RailDesign.Spacing.s)
        .padding(.bottom, RailDesign.Spacing.xs)
        .railBottomMaterialBar()
    }
}
