import SwiftUI

struct SearchScreen: View {
    @ObservedObject var store: TrainStore
    var showsCloseButton = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFieldFocused: Bool
    @State private var searchText = ""
    @State private var manualAddNotice = false

    private var results: [TrainTrip] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Array(store.discoveryTrips.prefix(8))
        }
        return store.searchableResults
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                if let offlineMessage = store.offlineMessage {
                    OfflineBanner(message: offlineMessage) {
                        Task { await store.searchLiveTrips(matching: searchText) }
                    }
                }

                SearchHeroView(scopeText: store.searchScopeText)

                if let notice = store.searchCapabilityNotice {
                    SearchCapabilityNoticeView(notice: notice)
                }

                if searchText.isEmpty {
                    RecentSearchesView(
                        examples: Array(store.searchExamples.prefix(4)),
                        providerName: store.activeProviderName
                    ) { value in
                        searchText = value
                    }
                    FavoriteStationsStrip(stations: store.stationSnapshots.prefix(6).map { $0.name }) { station in
                        searchText = station
                    }
                }

                SearchResultsSection(
                    title: searchText.isEmpty ? "Suggested services" : "Matching services",
                    isLoading: store.liveLoadState == .loading,
                    results: results,
                    query: searchText,
                    emptyState: store.searchEmptyState(for: searchText, results: results)
                ) { trip in
                    store.track(trip)
                    store.select(trip)
                    if showsCloseButton {
                        dismiss()
                    }
                } manualAdd: {
                    manualAddNotice = true
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Train number, station pair, operator, route, or time"
        )
        .searchFocused($searchFieldFocused)
        .onReceive(NotificationCenter.default.publisher(for: .trainyFocusSearch)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                searchFieldFocused = true
            }
        }
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task(id: searchText) {
            await runSearch()
        }
        .alert("Manual trip note", isPresented: $manualAddNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Manual trip creation is not connected in this build. This note does not add or connect a provider trip; saved scheduled and starter catalog trips remain available.")
        }
        .animation(reduceMotion ? nil : RailDesign.Motion.quick, value: searchText)
        .railScreenChrome()
    }

    private func runSearch() async {
        let cleanQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        store.query = cleanQuery
        guard !cleanQuery.isEmpty else { return }
        try? await Task.sleep(for: .milliseconds(260))
        guard !Task.isCancelled else { return }
        await store.searchLiveTrips(matching: cleanQuery)
    }
}

private struct SearchHeroView: View {
    let scopeText: String

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: "scope")
                .font(RailDesign.Typography.h3)
                .foregroundStyle(RailDesign.Palette.accent)
                .frame(width: 32, height: 32)
                .background(RailDesign.Palette.accent.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text(scopeText)
                    .font(RailDesign.Typography.h3)
                    .foregroundStyle(RailDesign.Palette.ink)
                    .lineLimit(1)
                Text("Search scheduled and saved services by train, station pair, route, operator, or departure time.")
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SearchCapabilityNoticeView: View {
    let notice: TrainStore.SearchCapabilityNotice

    private var tint: Color {
        switch notice.kind {
        case .realtimeUnavailable:
            return RailDesign.Palette.info
        case .scheduleUnavailable:
            return RailDesign.Palette.warning
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: notice.symbolName)
                .font(RailDesign.Typography.h3)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text(notice.title)
                    .font(RailDesign.Typography.h3.weight(.bold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(notice.message)
                    .font(RailDesign.Typography.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(RailDesign.Spacing.m)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .stroke(tint.opacity(0.20), lineWidth: 1)
                .padding(.horizontal, RailDesign.Layout.progressStrokeInset)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct RecentSearchesView: View {
    let examples: [String]
    let providerName: String
    let select: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            SectionHeader(title: "Try a search", subtitle: providerName)
            VStack(spacing: 0) {
                ForEach(examples, id: \.self) { item in
                    Button {
                        select(item)
                    } label: {
                        HStack(spacing: RailDesign.Spacing.s) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                            Text(item)
                                .foregroundStyle(RailDesign.Palette.ink)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                        }
                        .font(RailDesign.Typography.small)
                        .padding(.vertical, RailDesign.Spacing.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Search for " + item))
                    if item != examples.last {
                        Divider().background(RailDesign.Palette.hairline)
                    }
                }
            }
            .padding(.horizontal, RailDesign.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                    .fill(RailDesign.Palette.panel)
            )
        }
    }
}

private struct FavoriteStationsStrip: View {
    let stations: [String]
    let select: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            SectionHeader(title: "Favorite stations", subtitle: "Fast station search")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RailDesign.Spacing.s) {
                    ForEach(stations, id: \.self) { station in
                        Button {
                            select(station)
                        } label: {
                            StationBadge(name: station, code: String(station.prefix(3)))
                                .padding(RailDesign.Spacing.s)
                                .background(RailDesign.Palette.panel, in: RoundedRectangle(cornerRadius: RailDesign.Radius.control, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: RailDesign.Radius.control, style: .continuous)
                                        .stroke(RailDesign.Palette.hairline, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, RailDesign.Spacing.xxs)
            }
        }
    }
}
