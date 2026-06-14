import Darwin
import Foundation

enum ODPTSmokeError: LocalizedError {
    case noLiveTimetableTrips(query: String)
    case missingRoute(query: String, routeIDs: Set<String>)
    case starterDataReturned(query: String)

    var errorDescription: String? {
        switch self {
        case .noLiveTimetableTrips(let query):
            return "No real timetable-backed trips returned for '\(query)'."
        case .missingRoute(let query, let routeIDs):
            return "Timetable smoke query '\(query)' returned route IDs \(routeIDs.sorted()), which did not satisfy the expected route check."
        case .starterDataReturned(let query):
            return "Smoke query '\(query)' returned starter data while ODPT is configured."
        }
    }
}

@main
struct ODPTSmoke {
    static func main() async {
        let provider = ShinkansenTrainProvider(session: URLSession(configuration: .ephemeral))
        guard provider.isODPTConfigured else {
            fputs("ODPT_CONSUMER_KEY is not configured. Copy TrainyIOS/Config/odpt.env.example to TrainyIOS/Config/odpt.env and set the key.\n", stderr)
            exit(2)
        }

        do {
            let routes = try await provider.fetchRoutes()
            try await runSmoke(
                query: "Tokyo to Shin-Osaka",
                provider: provider,
                routes: routes,
                routeCheck: { $0.contains("tokaido") }
            )
            try await runSmoke(
                query: "JR East",
                provider: provider,
                routes: routes,
                routeCheck: { !$0.isDisjoint(with: ["tohoku", "joetsu", "hokuriku", "akita", "yamagata", "hokkaido"]) }
            )
            print("Timetable smoke passed: Tokyo to Shin-Osaka and JR East searches returned real timetable trips.")
        } catch {
            fputs("ODPT smoke failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func runSmoke(
        query: String,
        provider: ShinkansenTrainProvider,
        routes: [LiveTrainRoute],
        routeCheck: (Set<String>) -> Bool
    ) async throws {
        let trips = try await provider.fetchTrips(matching: query, knownRoutes: routes)
        guard !trips.isEmpty else {
            throw ODPTSmokeError.noLiveTimetableTrips(query: query)
        }
        guard trips.allSatisfy({ trip in
            trip.sourceProvenance.sourceKind == .officialTimetable &&
                (trip.dataSource == "ODPT TrainTimetable API" || trip.dataSource?.localizedCaseInsensitiveContains("official timetable") == true)
        }) else {
            throw ODPTSmokeError.starterDataReturned(query: query)
        }
        guard trips.allSatisfy(hasTimetableFactLabels) else {
            throw ODPTSmokeError.noLiveTimetableTrips(query: "\(query) missing structured timetable provenance")
        }

        let routeIDs = Set(trips.compactMap(\.routeID))
        guard routeCheck(routeIDs) else {
            throw ODPTSmokeError.missingRoute(query: query, routeIDs: routeIDs)
        }

        let preview = trips.prefix(3).map { trip in
            "\(trip.train) \(trip.origin.name)->\(trip.destination.name) platform \(trip.platform)"
        }.joined(separator: "; ")
        print("\(query): \(trips.count) real timetable trips; \(preview)")
    }

    private static func hasTimetableFactLabels(_ trip: TrainTrip) -> Bool {
        let facts = trip.factProvenance
        let platformOK: Bool
        if trip.platform == "TBD" {
            platformOK = facts.contains { $0.fact == .platform && $0.confidence == .unknown && $0.sourceKind == .officialTimetable }
        } else {
            platformOK = facts.contains { $0.fact == .platform && $0.confidence == .confirmed && $0.sourceKind == .officialTimetable }
        }

        return facts.contains { $0.fact == .schedule && $0.confidence == .confirmed && $0.sourceKind == .officialTimetable } &&
            platformOK &&
            facts.contains { $0.fact == .speed && $0.confidence == .unknown } &&
            facts.contains { $0.fact == .vehiclePosition && $0.confidence == .inferred && $0.sourceKind == .inferred } &&
            facts.contains { $0.fact == .carriageCue && $0.confidence == .inferred && $0.sourceKind == .inferred } &&
            facts.contains { $0.fact == .seatCue && $0.confidence == .inferred && $0.sourceKind == .inferred }
    }
}
