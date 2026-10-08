import Foundation

struct ShinkansenTrainProvider: ScheduleFeedProvider, RealtimeFeedProvider {
    let providerID = "shinkansen"
    let displayName = "Japan Shinkansen"
    let dataScope = "japan-shinkansen-v2"
    let region = ProviderRegion.japan
    private let odptClient: ODPTClient?
    private let clock: RailClock

    init(consumerKey: String? = TrainyAPIConfig.odptConsumerKey, session: URLSession = .shared, clock: RailClock = .system) {
        self.clock = clock
        if let consumerKey = TrainyAPIConfig.cleanODPTKey(consumerKey) {
            self.odptClient = ODPTClient(consumerKey: consumerKey, session: session)
        } else {
            self.odptClient = nil
        }
    }

    var isODPTConfigured: Bool {
        odptClient != nil
    }

    var authStrategy: ProviderAuthStrategy {
        .localKey(environmentVariable: "ODPT_CONSUMER_KEY", infoPlistKey: "ODPTConsumerKey")
    }

    var requirements: Set<ProviderRequirement> {
        authStrategy.requirements.union([
            .networkAccess,
            .attribution("ODPT developer terms and attribution"),
            .terms("ODPT developer terms")
        ])
    }

    var sourceLinks: [ProviderSourceLink] {
        [
            ProviderSourceLink(title: "ODPT developer portal", url: URL(string: "https://developer.odpt.org/")!)
        ]
    }

    var capabilities: Set<ProviderCapability> {
        var capabilities: Set<ProviderCapability> = [.schedule]
        if isODPTConfigured {
            capabilities.insert(.serviceAlerts)
        }
        return capabilities
    }

    var availability: ProviderAvailability {
        if isODPTConfigured {
            return .available("ODPT timetable and service-alert lookups are configured.", requirements: requirements)
        }
        return .degraded("Starter catalog fallback is active. Configure ODPT_CONSUMER_KEY for ODPT timetable and alert feeds.", requirements: requirements)
    }

    var feedLabel: String {
        isODPTConfigured ? "Scheduled ODPT timetable data" : "Japan Shinkansen starter catalog"
    }

    var includesCatalogResultsInSearch: Bool {
        !isODPTConfigured
    }

    var catalog: [TrainTrip] {
        Self.allTrips
    }

    var defaultTrips: [TrainTrip] {
        Array(Self.allTrips.prefix(4))
    }

    func fetchRoutes() async throws -> [LiveTrainRoute] {
        Self.routes
    }

    func fetchTrips(matching query: String, knownRoutes: [LiveTrainRoute]) async throws -> [TrainTrip] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let availableRoutes = knownRoutes.isEmpty ? Self.routes : knownRoutes
        let routeMatches = cleanQuery.isEmpty ? Array(availableRoutes.prefix(4)) : routes(matching: cleanQuery, in: availableRoutes)
        let matchingRouteIDs = Set(routeMatches.map(\.id))

        let matches = Self.allTrips.filter { trip in
            if cleanQuery.isEmpty {
                return matchingRouteIDs.contains(trip.routeID ?? "")
            }

            return matchingRouteIDs.contains(trip.routeID ?? "") || searchableText(for: trip).localizedCaseInsensitiveContains(cleanQuery)
        }

        let sortedMatches = matches.sorted { lhs, rhs in
            let lhsRank = Self.routeRank[lhs.routeID ?? ""] ?? Int.max
            let rhsRank = Self.routeRank[rhs.routeID ?? ""] ?? Int.max
            if lhsRank == rhsRank {
                return lhs.origin.time.localizedStandardCompare(rhs.origin.time) == .orderedAscending
            }
            return lhsRank < rhsRank
        }

        var odptError: Error?
        if let odptClient {
            do {
                let odptTrips = try await fetchODPTTrips(client: odptClient, routes: routeMatches, starterMatches: sortedMatches)
                if !odptTrips.isEmpty {
                    return Array(odptTrips.prefix(16))
                }
            } catch {
                odptError = error
            }
        }

        if odptClient != nil {
            // ODPT is the only live source. It is not expected to carry Shinkansen
            // timetables (docs/japan-data-decision-record.md), so say so plainly
            // instead of substituting starter data. That includes a query such as a
            // train name and number, which matches no route but does match the catalog.
            if let odptError {
                throw odptError
            }
            throw TrainDataProviderError.noLiveTrips
        }

        if sortedMatches.isEmpty {
            throw TrainDataProviderError.noLiveTrips
        }

        return Array(sortedMatches.prefix(16))
    }

    func refresh(_ trip: TrainTrip, knownRoutes: [LiveTrainRoute]) async throws -> TrainTrip? {
        guard trip.providerID == providerID else { return nil }
        if let odptClient {
            let route = knownRoutes.first { $0.id == trip.routeID } ?? Self.routes.first { $0.id == trip.routeID }
            if let route {
                let starterTrips = Self.allTrips.filter { $0.routeID == route.id }
                let odptTrips = (try? await fetchODPTTrips(client: odptClient, routes: [route], starterMatches: starterTrips)) ?? []
                if let refreshedTrip = odptTrips.first(where: { $0.liveTripID == trip.liveTripID }) ?? odptTrips.first {
                    return refreshedTrip
                }
                return nil
            }
        }
        var refreshedTrip = Self.allTrips.first { $0.id == trip.id } ?? trip
        refreshedTrip.updated = "just now"
        refreshedTrip.progress = min(max(trip.progress + 0.012, refreshedTrip.progress), 0.98)
        return refreshedTrip
    }

    private func routes(matching query: String, in routes: [LiveTrainRoute]) -> [LiveTrainRoute] {
        let queryTokens = Self.searchTokens(from: query)
        guard !queryTokens.isEmpty else { return [] }

        let matches = routes.filter { route in
            let routeText = ([route.id, route.name, route.summary] + route.destinations)
                .joined(separator: " ")
            if routeText.localizedCaseInsensitiveContains(query) {
                return true
            }

            let routeTokens = Set(Self.searchTokens(from: routeText))
            let collapsedRouteText = Self.collapsedSearchText(routeText)
            return queryTokens.allSatisfy { token in
                routeTokens.contains(token) || collapsedRouteText.contains(token)
            }
        }
        return matches
    }

    private func searchableText(for trip: TrainTrip) -> String {
        let route = Self.routes.first { $0.id == trip.routeID }
        return [
            trip.id,
            trip.train,
            trip.operatorName,
            trip.service,
            trip.origin.name,
            trip.destination.name,
            trip.nextStop,
            trip.status,
            trip.dataSource ?? "",
            trip.sourceProvenance.sourceName,
            trip.sourceProvenance.sourceKind.displayName,
            trip.sourceProvenance.confidence.displayName,
            trip.sourceBreakdownText,
            route?.name ?? "",
            route?.summary ?? "",
            route?.destinations.joined(separator: " ") ?? "",
            trip.stops.map(\.name).joined(separator: " ")
        ].joined(separator: " ")
    }

    private func fetchODPTTrips(client: ODPTClient, routes: [LiveTrainRoute], starterMatches: [TrainTrip]) async throws -> [TrainTrip] {
        var trips: [TrainTrip] = []

        for route in routes.prefix(5) {
            guard let railwayRefs = Self.odptRailwaysByRouteID[route.id], !railwayRefs.isEmpty else { continue }
            let routeStarterTrips = starterMatches.filter { $0.routeID == route.id }
            let alerts = (try? await client.fetchAlerts(for: railwayRefs)) ?? []

            for railwayRef in railwayRefs {
                let timetables = try await client.fetchTrainTimetables(for: railwayRef)
                // Read after the response arrives so status and fetchedAt describe the data in hand.
                let now = clock.now
                let routeTrips = timetables.prefix(10).compactMap { timetable in
                    Self.trip(from: timetable, route: route, railwayRef: railwayRef, starterTrips: routeStarterTrips, alerts: alerts, now: now)
                }
                trips.append(contentsOf: routeTrips)
            }
        }

        return trips.sorted {
            $0.origin.time.localizedStandardCompare($1.origin.time) == .orderedAscending
        }
    }
}
