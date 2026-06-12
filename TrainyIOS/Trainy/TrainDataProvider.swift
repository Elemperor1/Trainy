import Foundation

struct LiveTrainRoute: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let summary: String
    let destinations: [String]
}

enum TrainDataProviderError: LocalizedError {
    case badURL
    case badResponse
    case noLiveTrips

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Trainy could not build the Shinkansen data request."
        case .badResponse:
            return "The Shinkansen data feed returned an unexpected response."
        case .noLiveTrips:
            return "No Shinkansen departures matched that search."
        }
    }
}

enum TrainyAPIConfig {
    static var odptConsumerKey: String? {
        cleanODPTKey(ProcessInfo.processInfo.environment["ODPT_CONSUMER_KEY"])
            ?? cleanODPTKey(Bundle.main.object(forInfoDictionaryKey: "ODPTConsumerKey") as? String)
    }

    static func cleanODPTKey(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }
}

struct ShinkansenTrainProvider {
    let providerID = "shinkansen"
    let dataScope = "japan-shinkansen-v2"
    private let odptClient: ODPTClient?
    private let timetableClient: JREastTimetableClient

    init(consumerKey: String? = TrainyAPIConfig.odptConsumerKey, session: URLSession = .shared) {
        self.timetableClient = JREastTimetableClient(session: session)
        if let consumerKey = TrainyAPIConfig.cleanODPTKey(consumerKey) {
            self.odptClient = ODPTClient(consumerKey: consumerKey, session: session)
        } else {
            self.odptClient = nil
        }
    }

    var isODPTConfigured: Bool {
        odptClient != nil
    }

    var feedLabel: String {
        isODPTConfigured ? "ODPT + official timetable feeds" : "Japan Shinkansen starter data"
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

        if odptClient != nil && !routeMatches.isEmpty {
            let timetableTrips = try await fetchOfficialTimetableTrips(routes: routeMatches, starterMatches: sortedMatches, query: cleanQuery)
            if !timetableTrips.isEmpty {
                return Array(timetableTrips.prefix(16))
            }
            if !routeMatches.isEmpty {
                throw odptError ?? TrainDataProviderError.noLiveTrips
            }
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
                let timetableTrips = try await fetchOfficialTimetableTrips(routes: [route], starterMatches: starterTrips, query: trip.train)
                return timetableTrips.first { $0.liveTripID == trip.liveTripID } ?? timetableTrips.first
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
                let routeTrips = timetables.prefix(10).compactMap { timetable in
                    Self.trip(from: timetable, route: route, railwayRef: railwayRef, starterTrips: routeStarterTrips, alerts: alerts)
                }
                trips.append(contentsOf: routeTrips)
            }
        }

        return trips.sorted {
            $0.origin.time.localizedStandardCompare($1.origin.time) == .orderedAscending
        }
    }

    private func fetchOfficialTimetableTrips(routes: [LiveTrainRoute], starterMatches: [TrainTrip], query: String) async throws -> [TrainTrip] {
        var trips: [TrainTrip] = []
        var fetchedURLs: Set<URL> = []

        for route in routes.prefix(4) {
            guard let reference = Self.jrEastTimetableReferencesByRouteID[route.id] else { continue }
            guard fetchedURLs.insert(reference.timetableURL).inserted else { continue }

            let routeStarterTrips = starterMatches.filter { $0.routeID == route.id }
            let timetables = try await timetableClient.fetchTrainTimetables(for: reference)
            let routeTrips = timetables.compactMap { timetable in
                Self.trip(from: timetable, route: route, reference: reference, starterTrips: routeStarterTrips)
            }
            trips.append(contentsOf: routeTrips)
        }

        let filteredTrips = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? trips
            : trips.filter { Self.tripMatches($0, query: query) }

        return filteredTrips.sorted {
            $0.origin.time.localizedStandardCompare($1.origin.time) == .orderedAscending
        }
    }
}

private struct ODPTClient {
    private let baseURL = URL(string: "https://api.odpt.org/api/v4")!
    private let consumerKey: String
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(consumerKey: String, session: URLSession) {
        self.consumerKey = consumerKey
        self.session = session
    }

    func fetchTrainTimetables(for railwayRef: ODPTRailwayReference) async throws -> [ODPTTrainTimetable] {
        try await fetch(
            resource: "odpt:TrainTimetable",
            queryItems: [
                URLQueryItem(name: "odpt:operator", value: railwayRef.operatorID),
                URLQueryItem(name: "odpt:railway", value: railwayRef.railwayID)
            ]
        )
    }

    func fetchAlerts(for railwayRefs: [ODPTRailwayReference]) async throws -> [TrainAlert] {
        var alerts: [TrainAlert] = []

        for railwayRef in railwayRefs {
            let information: [ODPTTrainInformation] = try await fetch(
                resource: "odpt:TrainInformation",
                queryItems: [
                    URLQueryItem(name: "odpt:operator", value: railwayRef.operatorID),
                    URLQueryItem(name: "odpt:railway", value: railwayRef.railwayID)
                ]
            )

            alerts.append(contentsOf: information.prefix(2).map { item in
                let status = item.status?.displayText ?? "Service update"
                let detail = item.text?.displayText ?? item.area?.displayText ?? "ODPT has a service notice for this Shinkansen route."
                let tone: TrainStatusTone = status.localizedCaseInsensitiveContains("normal") ? .good : .watch
                return TrainAlert(title: status, detail: detail, tone: tone)
            })
        }

        return Array(alerts.prefix(3))
    }

    private func fetch<T: Decodable>(resource: String, queryItems: [URLQueryItem]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(resource), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "acl:consumerKey", value: consumerKey)] + queryItems.compactMap { item in
            guard item.value?.isEmpty == false else { return nil }
            return item
        }
        guard let url = components?.url else { throw TrainDataProviderError.badURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 18
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Trainy iOS ODPT prototype", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TrainDataProviderError.badResponse
        }
        if httpResponse.statusCode == 404 {
            return try decoder.decode(T.self, from: Data("[]".utf8))
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TrainDataProviderError.badResponse
        }
        return try decoder.decode(T.self, from: data)
    }
}

private struct ODPTRailwayReference: Hashable {
    let railwayID: String
    let operatorID: String
}

private struct JREastTimetableReference: Hashable {
    let timetableURL: URL
    let operatorName: String
    let dataSource: String
    let trainLinkLimit: Int
}

private struct ODPTTrainTimetable: Decodable {
    let id: String?
    let sameAs: String?
    let operatorID: String?
    let railwayID: String?
    let calendar: String?
    let trainID: String?
    let trainNumber: String?
    let trainType: String?
    let trainName: [ODPTLocalizedText]?
    let originStations: [String]?
    let destinationStations: [String]?
    let timetableObjects: [ODPTTrainTimetableObject]
    let valid: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "@id"
        case sameAs = "owl:sameAs"
        case operatorID = "odpt:operator"
        case railwayID = "odpt:railway"
        case calendar = "odpt:calendar"
        case trainID = "odpt:train"
        case trainNumber = "odpt:trainNumber"
        case trainType = "odpt:trainType"
        case trainName = "odpt:trainName"
        case originStations = "odpt:originStation"
        case destinationStations = "odpt:destinationStation"
        case timetableObjects = "odpt:trainTimetableObject"
        case valid = "dct:valid"
        case updatedAt = "dc:date"
    }
}

private struct ODPTTrainTimetableObject: Decodable {
    let arrivalTime: String?
    let departureTime: String?
    let arrivalStation: String?
    let departureStation: String?
    let arrivalPlatformNumber: String?
    let departurePlatformNumber: String?
    let platformNumber: String?

    enum CodingKeys: String, CodingKey {
        case arrivalTime = "odpt:arrivalTime"
        case departureTime = "odpt:departureTime"
        case arrivalStation = "odpt:arrivalStation"
        case departureStation = "odpt:departureStation"
        case arrivalPlatformNumber = "odpt:arrivalPlatformNumber"
        case departurePlatformNumber = "odpt:departurePlatformNumber"
        case platformNumber = "odpt:platformNumber"
    }
}

private struct ODPTTrainInformation: Decodable {
    let status: ODPTLocalizedText?
    let text: ODPTLocalizedText?
    let area: ODPTLocalizedText?

    enum CodingKeys: String, CodingKey {
        case status = "odpt:trainInformationStatus"
        case text = "odpt:trainInformationText"
        case area = "odpt:trainInformationArea"
    }
}

private struct ODPTLocalizedText: Decodable {
    let ja: String?
    let en: String?

    var displayText: String? {
        en?.isEmpty == false ? en : ja
    }
}

private struct ODPTTimedStop: Hashable {
    let stationID: String
    let time: String
    let platform: String
}

private struct JREastTrainTimetable: Hashable {
    let sourceURL: URL
    let title: String
    let trainName: String
    let trainNumber: String?
    let stops: [JREastTimedStop]
}

private struct JREastTimedStop: Hashable {
    let stationName: String
    let arrivalTime: String?
    let departureTime: String?
    let platform: String

    var displayTime: String? {
        departureTime ?? arrivalTime
    }
}

private struct JREastTimetableClient {
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func fetchTrainTimetables(for reference: JREastTimetableReference) async throws -> [JREastTrainTimetable] {
        let stationHTML = try await fetchHTML(from: reference.timetableURL)
        let trainURLs = Self.trainDetailURLs(from: stationHTML, baseURL: reference.timetableURL)
        var timetables: [JREastTrainTimetable] = []

        for trainURL in trainURLs.prefix(reference.trainLinkLimit) {
            let trainHTML = try await fetchHTML(from: trainURL)
            if let timetable = Self.trainTimetable(from: trainHTML, sourceURL: trainURL) {
                timetables.append(timetable)
            }
        }

        return timetables
    }

    private func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 18
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("Trainy iOS official timetable smoke", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw TrainDataProviderError.badResponse
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .shiftJIS) else {
            throw TrainDataProviderError.badResponse
        }
        return html
    }

    private static func trainDetailURLs(from html: String, baseURL: URL) -> [URL] {
        let hrefs = captureGroups(pattern: #"href="([^"]*train/[^"]+\.html)""#, in: html)
        var urls: [URL] = []
        var seen: Set<URL> = []

        for href in hrefs {
            guard let url = URL(string: decodeEntities(href), relativeTo: baseURL)?.absoluteURL else { continue }
            if seen.insert(url).inserted {
                urls.append(url)
            }
        }

        return urls
    }

    private static func trainTimetable(from html: String, sourceURL: URL) -> JREastTrainTimetable? {
        guard let titleBlock = firstCapture(pattern: #"<p class="line_name">([\s\S]*?)</p>"#, in: html) else { return nil }
        let title = cleanText(titleBlock)
        let trainName = title
            .replacingOccurrences(of: #"^Shinkansen\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*\([^)]*\)\s*$"#, with: "", options: .regularExpression)
        let trainNumberBlock = firstCapture(pattern: #"<th>Train number</th>\s*<td colspan="2">([\s\S]*?)</td>"#, in: html)
        let trainNumber = trainNumberBlock.map(cleanText).flatMap { $0.isEmpty ? nil : $0 }
        let rowBlocks = captureGroups(pattern: #"<tr class="time">([\s\S]*?)</tr>"#, in: html)
        let stops = rowBlocks.compactMap(timedStop)

        guard !trainName.isEmpty, !stops.isEmpty else { return nil }
        return JREastTrainTimetable(sourceURL: sourceURL, title: title, trainName: trainName, trainNumber: trainNumber, stops: stops)
    }

    private static func timedStop(from row: String) -> JREastTimedStop? {
        guard let stationBlock = firstCapture(pattern: #"<th class="time">([\s\S]*?)</th>"#, in: row) else { return nil }
        let stationName = cleanText(stationBlock)
        guard !stationName.isEmpty else { return nil }

        var arrivalTime: String?
        var departureTime: String?
        let timeMatches = captureMatches(pattern: #"(\d{2}:\d{2})\s*<span class="dep_arr">(Arr\.|Dep\.)</span>"#, in: row)
        for match in timeMatches {
            guard match.count >= 2 else { continue }
            if match[1] == "Dep." {
                departureTime = match[0]
            } else if match[1] == "Arr." {
                arrivalTime = match[0]
            }
        }

        guard arrivalTime != nil || departureTime != nil else { return nil }

        let platformBlock = firstCapture(pattern: #"<td class="platform">\s*<span[^>]*>([\s\S]*?)</span>\s*</td>"#, in: row)
        let platform = platformBlock.map(cleanText).flatMap { $0.isEmpty ? nil : $0 } ?? "TBD"
        return JREastTimedStop(stationName: stationName, arrivalTime: arrivalTime, departureTime: departureTime, platform: platform)
    }

    private static func firstCapture(pattern: String, in value: String) -> String? {
        captureGroups(pattern: pattern, in: value).first
    }

    private static func captureGroups(pattern: String, in value: String) -> [String] {
        captureMatches(pattern: pattern, in: value).compactMap(\.first)
    }

    private static func captureMatches(pattern: String, in value: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.matches(in: value, options: [], range: range).map { result in
            (1..<result.numberOfRanges).compactMap { index in
                guard let matchRange = Range(result.range(at: index), in: value) else { return nil }
                return String(value[matchRange])
            }
        }
    }

    private static func cleanText(_ value: String) -> String {
        let withoutTags = value.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        let decoded = decodeEntities(withoutTags)
        return decoded
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}

private extension ShinkansenTrainProvider {
    static let routes: [LiveTrainRoute] = [
        LiveTrainRoute(
            id: "tokaido",
            name: "Tokaido Shinkansen",
            summary: "JR Central trunk route between Tokyo, Nagoya, Kyoto, and Shin-Osaka.",
            destinations: ["Tokyo", "Shin-Yokohama", "Nagoya", "Kyoto", "Shin-Osaka", "Nozomi", "Hikari", "Kodama"]
        ),
        LiveTrainRoute(
            id: "sanyo-kyushu",
            name: "Sanyo and Kyushu Shinkansen",
            summary: "JR West and JR Kyushu high-speed route from Shin-Osaka through Hakata to Kagoshima-Chuo.",
            destinations: ["Shin-Osaka", "Okayama", "Hiroshima", "Hakata", "Kumamoto", "Kagoshima-Chuo", "Sakura", "Mizuho"]
        ),
        LiveTrainRoute(
            id: "tohoku",
            name: "Tohoku Shinkansen",
            summary: "JR East route from Tokyo through Sendai and Morioka to Shin-Aomori.",
            destinations: ["Tokyo", "Omiya", "Sendai", "Morioka", "Shin-Aomori", "Hayabusa", "Yamabiko"]
        ),
        LiveTrainRoute(
            id: "hokuriku",
            name: "Hokuriku Shinkansen",
            summary: "JR East and JR West route from Tokyo to Nagano, Toyama, Kanazawa, and Tsuruga.",
            destinations: ["Tokyo", "Nagano", "Toyama", "Kanazawa", "Tsuruga", "Kagayaki", "Hakutaka"]
        ),
        LiveTrainRoute(
            id: "joetsu",
            name: "Joetsu Shinkansen",
            summary: "JR East route from Tokyo to Takasaki, Echigo-Yuzawa, and Niigata.",
            destinations: ["Tokyo", "Takasaki", "Echigo-Yuzawa", "Niigata", "Toki", "Tanigawa"]
        ),
        LiveTrainRoute(
            id: "hokkaido",
            name: "Tohoku and Hokkaido Shinkansen",
            summary: "Through service from Tokyo and Tohoku to Shin-Hakodate-Hokuto.",
            destinations: ["Tokyo", "Sendai", "Morioka", "Shin-Aomori", "Shin-Hakodate-Hokuto", "Hayabusa"]
        ),
        LiveTrainRoute(
            id: "akita",
            name: "Akita Shinkansen",
            summary: "JR East mini-shinkansen route from Tokyo and Morioka to Akita.",
            destinations: ["Tokyo", "Sendai", "Morioka", "Tazawako", "Akita", "Komachi"]
        ),
        LiveTrainRoute(
            id: "yamagata",
            name: "Yamagata Shinkansen",
            summary: "JR East mini-shinkansen route from Tokyo and Fukushima to Yamagata and Shinjo.",
            destinations: ["Tokyo", "Fukushima", "Yamagata", "Shinjo", "Tsubasa"]
        )
    ]

    static let routeRank: [String: Int] = Dictionary(uniqueKeysWithValues: routes.enumerated().map { ($0.element.id, $0.offset) })

    static let odptRailwaysByRouteID: [String: [ODPTRailwayReference]] = [
        "tokaido": [
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-Central.TokaidoShinkansen", operatorID: "odpt.Operator:JR-Central")
        ],
        "sanyo-kyushu": [
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-West.SanyoShinkansen", operatorID: "odpt.Operator:JR-West"),
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-Kyushu.KyushuShinkansen", operatorID: "odpt.Operator:JR-Kyushu")
        ],
        "tohoku": [
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-East.TohokuShinkansen", operatorID: "odpt.Operator:JR-East")
        ],
        "hokuriku": [
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-East.HokurikuShinkansen", operatorID: "odpt.Operator:JR-East"),
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-West.HokurikuShinkansen", operatorID: "odpt.Operator:JR-West")
        ],
        "joetsu": [
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-East.JoetsuShinkansen", operatorID: "odpt.Operator:JR-East")
        ],
        "hokkaido": [
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-East.TohokuShinkansen", operatorID: "odpt.Operator:JR-East"),
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-Hokkaido.HokkaidoShinkansen", operatorID: "odpt.Operator:JR-Hokkaido")
        ],
        "akita": [
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-East.AkitaShinkansen", operatorID: "odpt.Operator:JR-East")
        ],
        "yamagata": [
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-East.YamagataShinkansen", operatorID: "odpt.Operator:JR-East")
        ]
    ]

    static let jrEastTimetableReferencesByRouteID: [String: JREastTimetableReference] = [
        "tokaido": JREastTimetableReference(
            timetableURL: URL(string: "https://timetables.jreast.co.jp/en/2606/timetable/tt1039/1039010.html")!,
            operatorName: "JR Central",
            dataSource: "JR East official timetable, Jun 2026 JR JIKOKUHYO",
            trainLinkLimit: 18
        ),
        "tohoku": JREastTimetableReference(
            timetableURL: URL(string: "https://timetables.jreast.co.jp/en/2606/timetable/tt1039/1039020.html")!,
            operatorName: "JR East",
            dataSource: "JR East official timetable, Jun 2026 JR JIKOKUHYO",
            trainLinkLimit: 18
        ),
        "hokuriku": JREastTimetableReference(
            timetableURL: URL(string: "https://timetables.jreast.co.jp/en/2606/timetable/tt1039/1039060.html")!,
            operatorName: "JR East / JR West",
            dataSource: "JR East official timetable, Jun 2026 JR JIKOKUHYO",
            trainLinkLimit: 18
        ),
        "joetsu": JREastTimetableReference(
            timetableURL: URL(string: "https://timetables.jreast.co.jp/en/2606/timetable/tt1039/1039050.html")!,
            operatorName: "JR East",
            dataSource: "JR East official timetable, Jun 2026 JR JIKOKUHYO",
            trainLinkLimit: 18
        ),
        "hokkaido": JREastTimetableReference(
            timetableURL: URL(string: "https://timetables.jreast.co.jp/en/2606/timetable/tt1039/1039020.html")!,
            operatorName: "JR East / JR Hokkaido",
            dataSource: "JR East official timetable, Jun 2026 JR JIKOKUHYO",
            trainLinkLimit: 18
        ),
        "akita": JREastTimetableReference(
            timetableURL: URL(string: "https://timetables.jreast.co.jp/en/2606/timetable/tt1039/1039020.html")!,
            operatorName: "JR East",
            dataSource: "JR East official timetable, Jun 2026 JR JIKOKUHYO",
            trainLinkLimit: 18
        ),
        "yamagata": JREastTimetableReference(
            timetableURL: URL(string: "https://timetables.jreast.co.jp/en/2606/timetable/tt1039/1039020.html")!,
            operatorName: "JR East",
            dataSource: "JR East official timetable, Jun 2026 JR JIKOKUHYO",
            trainLinkLimit: 18
        )
    ]

    static let allTrips: [TrainTrip] = [
        TrainTrip(
            id: "nozomi-231",
            providerID: "shinkansen",
            routeID: "tokaido",
            liveTripID: "nozomi-231",
            train: "Nozomi 231",
            operatorName: "JR Central",
            service: "Tokaido Shinkansen",
            origin: point(tokyo, time: "09:21"),
            destination: point(shinOsaka, time: "11:48"),
            duration: "2h 27m",
            status: "On time",
            statusTone: .good,
            category: .departing,
            platform: "18",
            nextStop: "Nagoya",
            eta: "10:58",
            speed: "258 km/h",
            progress: 0.36,
            bestCar: 7,
            cars: 16,
            seat: "Car 7, Seat 12A",
            updated: "status feed",
            callout: "Stand by car marker 7 on platform 18. This status feed is ready for the Tokaido Shinkansen flow.",
            signal: 86,
            signalCopy: "Route, stop order, platform, and map coordinates are from Trainy's Shinkansen starter data. Live JR delay feeds are not connected yet.",
            stops: [
                stop(tokyo, time: "09:21", platform: "18", note: "Departed", state: .done),
                stop(shinYokohama, time: "09:39", platform: "3", note: "Departed", state: .done),
                stop(nagoya, time: "10:58", platform: "16", note: "Next stop", state: .current),
                stop(kyoto, time: "11:34", platform: "14", note: "Expected", state: .pending),
                stop(shinOsaka, time: "11:48", platform: "25", note: "Final stop", state: .pending)
            ],
            alerts: [
                TrainAlert(title: "Shinkansen status feed", detail: "Tokaido route data is loaded for Japan-first validation.", tone: .good),
                TrainAlert(title: "Reserved seat cue", detail: "Car 7 keeps this trip aligned with the selected reserved seat.", tone: .good)
            ],
            pulse: "Tokaido starter corridor loaded",
            vehicleLatitude: 35.1709,
            vehicleLongitude: 136.8815,
            distanceText: "5 stops",
            dataSource: "Japan Shinkansen starter data"
        ),
        TrainTrip(
            id: "sakura-555",
            providerID: "shinkansen",
            routeID: "sanyo-kyushu",
            liveTripID: "sakura-555",
            train: "Sakura 555",
            operatorName: "JR West / JR Kyushu",
            service: "Sanyo-Kyushu Shinkansen",
            origin: point(shinOsaka, time: "10:06"),
            destination: point(kagoshimaChuo, time: "14:13"),
            duration: "4h 07m",
            status: "Boarding",
            statusTone: .good,
            category: .departing,
            platform: "20",
            nextStop: "Okayama",
            eta: "10:54",
            speed: "0 km/h",
            progress: 0.05,
            bestCar: 5,
            cars: 8,
            seat: "Car 5, Seat 9D",
            updated: "status feed",
            callout: "Board the 8-car set from marker 5. This through-service is the first cross-operator Shinkansen case.",
            signal: 82,
            signalCopy: "Trainy knows the through route and major stops, with live operator handoff data still pending.",
            stops: [
                stop(shinOsaka, time: "10:06", platform: "20", note: "Boarding", state: .current),
                stop(okayama, time: "10:54", platform: "22", note: "Expected", state: .pending),
                stop(hiroshima, time: "11:35", platform: "12", note: "Expected", state: .pending),
                stop(hakata, time: "12:38", platform: "15", note: "JR Kyushu handoff", state: .pending),
                stop(kumamoto, time: "13:17", platform: "13", note: "Expected", state: .pending),
                stop(kagoshimaChuo, time: "14:13", platform: "12", note: "Final stop", state: .pending)
            ],
            alerts: [
                TrainAlert(title: "Through-service check", detail: "This trip validates JR West to JR Kyushu handoff behavior.", tone: .good),
                TrainAlert(title: "Short trainset", detail: "Sakura services usually use fewer cars than Tokaido Nozomi sets.", tone: .watch)
            ],
            pulse: "Sanyo-Kyushu starter corridor loaded",
            vehicleLatitude: 34.7335,
            vehicleLongitude: 135.5002,
            distanceText: "6 stops",
            dataSource: "Japan Shinkansen starter data"
        ),
        TrainTrip(
            id: "hayabusa-17",
            providerID: "shinkansen",
            routeID: "tohoku",
            liveTripID: "hayabusa-17",
            train: "Hayabusa 17",
            operatorName: "JR East",
            service: "Tohoku Shinkansen",
            origin: point(tokyo, time: "09:36"),
            destination: point(shinAomori, time: "12:49"),
            duration: "3h 13m",
            status: "On time",
            statusTone: .good,
            category: .departing,
            platform: "21",
            nextStop: "Sendai",
            eta: "11:07",
            speed: "286 km/h",
            progress: 0.31,
            bestCar: 6,
            cars: 10,
            seat: "Car 6, Seat 6A",
            updated: "status feed",
            callout: "Use the north Shinkansen concourse and board near car 6 for balanced exits at Sendai and Morioka.",
            signal: 84,
            signalCopy: "Major Tohoku Shinkansen stops and map coordinates are loaded; live train location is simulated for now.",
            stops: [
                stop(tokyo, time: "09:36", platform: "21", note: "Departed", state: .done),
                stop(omiya, time: "10:01", platform: "17", note: "Departed", state: .done),
                stop(sendai, time: "11:07", platform: "12", note: "Next stop", state: .current),
                stop(morioka, time: "11:48", platform: "14", note: "Expected", state: .pending),
                stop(shinAomori, time: "12:49", platform: "13", note: "Final stop", state: .pending)
            ],
            alerts: [
                TrainAlert(title: "Tohoku route ready", detail: "Hayabusa coverage validates long-distance JR East Shinkansen trips.", tone: .good),
                TrainAlert(title: "Seat position", detail: "Car 6 keeps transfers balanced at the large intermediate stations.", tone: .good)
            ],
            pulse: "Tohoku starter corridor loaded",
            vehicleLatitude: 38.2602,
            vehicleLongitude: 140.8820,
            distanceText: "5 stops",
            dataSource: "Japan Shinkansen starter data"
        ),
        TrainTrip(
            id: "kagayaki-509",
            providerID: "shinkansen",
            routeID: "hokuriku",
            liveTripID: "kagayaki-509",
            train: "Kagayaki 509",
            operatorName: "JR East / JR West",
            service: "Hokuriku Shinkansen",
            origin: point(tokyo, time: "10:24"),
            destination: point(tsuruga, time: "13:32"),
            duration: "3h 08m",
            status: "Scheduled",
            statusTone: .good,
            category: .departing,
            platform: "22",
            nextStop: "Nagano",
            eta: "11:45",
            speed: "0 km/h",
            progress: 0.0,
            bestCar: 8,
            cars: 12,
            seat: "Car 8, Seat 3E",
            updated: "status feed",
            callout: "Track this route to validate the new Kanazawa-Tsuruga extension shape in the app.",
            signal: 80,
            signalCopy: "The Hokuriku route includes the Tsuruga terminus, with live JR West status data planned for a later provider.",
            stops: [
                stop(tokyo, time: "10:24", platform: "22", note: "Platform pending", state: .current),
                stop(nagano, time: "11:45", platform: "12", note: "Expected", state: .pending),
                stop(toyama, time: "12:30", platform: "13", note: "Expected", state: .pending),
                stop(kanazawa, time: "12:53", platform: "14", note: "Expected", state: .pending),
                stop(tsuruga, time: "13:32", platform: "12", note: "Final stop", state: .pending)
            ],
            alerts: [
                TrainAlert(title: "Hokuriku extension", detail: "Tsuruga is included so the starter dataset reflects the current endpoint shape.", tone: .good),
                TrainAlert(title: "Platform watch", detail: "Tokyo platform is representative starter data until a live station feed is wired.", tone: .watch)
            ],
            pulse: "Hokuriku starter corridor loaded",
            vehicleLatitude: 35.6812,
            vehicleLongitude: 139.7671,
            distanceText: "5 stops",
            dataSource: "Japan Shinkansen starter data"
        ),
        TrainTrip(
            id: "toki-327",
            providerID: "shinkansen",
            routeID: "joetsu",
            liveTripID: "toki-327",
            train: "Toki 327",
            operatorName: "JR East",
            service: "Joetsu Shinkansen",
            origin: point(tokyo, time: "13:40"),
            destination: point(niigata, time: "15:48"),
            duration: "2h 08m",
            status: "Scheduled",
            statusTone: .good,
            category: .departing,
            platform: "20",
            nextStop: "Takasaki",
            eta: "14:29",
            speed: "0 km/h",
            progress: 0.0,
            bestCar: 4,
            cars: 10,
            seat: "Car 4, Seat 10C",
            updated: "status feed",
            callout: "Use this Joetsu trip to validate shorter regional Shinkansen tracking and snow-country stops.",
            signal: 79,
            signalCopy: "Trainy has the Joetsu corridor geometry and station order; real delay and snow disruption feeds are future work.",
            stops: [
                stop(tokyo, time: "13:40", platform: "20", note: "Platform pending", state: .current),
                stop(takasaki, time: "14:29", platform: "12", note: "Expected", state: .pending),
                stop(echigoYuzawa, time: "14:56", platform: "11", note: "Expected", state: .pending),
                stop(niigata, time: "15:48", platform: "13", note: "Final stop", state: .pending)
            ],
            alerts: [
                TrainAlert(title: "Joetsu route ready", detail: "Niigata-bound service is available in search and tracking.", tone: .good),
                TrainAlert(title: "Weather-aware future", detail: "This route is a good candidate for later disruption data.", tone: .watch)
            ],
            pulse: "Joetsu starter corridor loaded",
            vehicleLatitude: 35.6812,
            vehicleLongitude: 139.7671,
            distanceText: "4 stops",
            dataSource: "Japan Shinkansen starter data"
        ),
        TrainTrip(
            id: "hayabusa-13",
            providerID: "shinkansen",
            routeID: "hokkaido",
            liveTripID: "hayabusa-13",
            train: "Hayabusa 13",
            operatorName: "JR East / JR Hokkaido",
            service: "Tohoku-Hokkaido Shinkansen",
            origin: point(tokyo, time: "08:20"),
            destination: point(shinHakodateHokuto, time: "12:17"),
            duration: "3h 57m",
            status: "Tunnel watch",
            statusTone: .watch,
            category: .attention,
            platform: "21",
            nextStop: "Shin-Aomori",
            eta: "11:29",
            speed: "260 km/h",
            progress: 0.71,
            bestCar: 5,
            cars: 10,
            seat: "Car 5, Seat 8B",
            updated: "status feed",
            callout: "Watch the Shin-Aomori handoff and Seikan Tunnel segment. This validates cross-island trip presentation.",
            signal: 76,
            signalCopy: "Route geometry reaches Hokkaido, but tunnel-specific operational notices are not connected yet.",
            stops: [
                stop(tokyo, time: "08:20", platform: "21", note: "Departed", state: .done),
                stop(sendai, time: "09:52", platform: "12", note: "Departed", state: .done),
                stop(morioka, time: "10:32", platform: "14", note: "Departed", state: .done),
                stop(shinAomori, time: "11:29", platform: "13", note: "Next stop", state: .current),
                stop(shinHakodateHokuto, time: "12:17", platform: "11", note: "Final stop", state: .pending)
            ],
            alerts: [
                TrainAlert(title: "Hokkaido handoff", detail: "Cross-operator service is represented for later live provider wiring.", tone: .watch),
                TrainAlert(title: "Long-distance buffer", detail: "Keep onward limited-express connections visible at Shin-Hakodate-Hokuto.", tone: .good)
            ],
            pulse: "Hokkaido starter corridor loaded",
            vehicleLatitude: 40.8287,
            vehicleLongitude: 140.6933,
            distanceText: "5 stops",
            dataSource: "Japan Shinkansen starter data"
        ),
        TrainTrip(
            id: "komachi-25",
            providerID: "shinkansen",
            routeID: "akita",
            liveTripID: "komachi-25",
            train: "Komachi 25",
            operatorName: "JR East",
            service: "Akita Shinkansen",
            origin: point(tokyo, time: "15:20"),
            destination: point(akita, time: "19:04"),
            duration: "3h 44m",
            status: "Coupled set",
            statusTone: .watch,
            category: .attention,
            platform: "23",
            nextStop: "Morioka",
            eta: "17:31",
            speed: "275 km/h",
            progress: 0.58,
            bestCar: 14,
            cars: 17,
            seat: "Car 14, Seat 2A",
            updated: "status feed",
            callout: "Komachi runs coupled with Hayabusa on part of the route, so car numbering and split behavior matter.",
            signal: 73,
            signalCopy: "Mini-shinkansen split behavior is modeled as starter metadata; real coupling updates are future work.",
            stops: [
                stop(tokyo, time: "15:20", platform: "23", note: "Departed", state: .done),
                stop(sendai, time: "16:51", platform: "12", note: "Departed", state: .done),
                stop(morioka, time: "17:31", platform: "14", note: "Split next", state: .current),
                stop(tazawako, time: "18:08", platform: "1", note: "Expected", state: .pending),
                stop(akita, time: "19:04", platform: "12", note: "Final stop", state: .pending)
            ],
            alerts: [
                TrainAlert(title: "Coupled trainset", detail: "This trip exercises car numbers above 10 and split-route copy.", tone: .watch),
                TrainAlert(title: "Mini-shinkansen", detail: "Akita branch behavior is present for data-model scaling.", tone: .good)
            ],
            pulse: "Akita starter branch loaded",
            vehicleLatitude: 39.7015,
            vehicleLongitude: 141.1363,
            distanceText: "5 stops",
            dataSource: "Japan Shinkansen starter data"
        ),
        TrainTrip(
            id: "tsubasa-143",
            providerID: "shinkansen",
            routeID: "yamagata",
            liveTripID: "tsubasa-143",
            train: "Tsubasa 143",
            operatorName: "JR East",
            service: "Yamagata Shinkansen",
            origin: point(tokyo, time: "11:00"),
            destination: point(shinjo, time: "14:31"),
            duration: "3h 31m",
            status: "Scheduled",
            statusTone: .good,
            category: .departing,
            platform: "21",
            nextStop: "Fukushima",
            eta: "12:33",
            speed: "0 km/h",
            progress: 0.0,
            bestCar: 13,
            cars: 17,
            seat: "Car 13, Seat 5D",
            updated: "status feed",
            callout: "Tsubasa validates Yamagata mini-shinkansen routing, coupled service, and compact branch stops.",
            signal: 78,
            signalCopy: "Branch station order and representative platforms are loaded; live split operation updates are not connected yet.",
            stops: [
                stop(tokyo, time: "11:00", platform: "21", note: "Platform pending", state: .current),
                stop(fukushima, time: "12:33", platform: "14", note: "Split route", state: .pending),
                stop(yamagata, time: "13:44", platform: "1", note: "Expected", state: .pending),
                stop(shinjo, time: "14:31", platform: "1", note: "Final stop", state: .pending)
            ],
            alerts: [
                TrainAlert(title: "Branch route ready", detail: "Yamagata service is available for search and tracking.", tone: .good),
                TrainAlert(title: "Coupling future", detail: "Later data should distinguish the Tsubasa portion from the coupled set.", tone: .watch)
            ],
            pulse: "Yamagata starter branch loaded",
            vehicleLatitude: 35.6812,
            vehicleLongitude: 139.7671,
            distanceText: "4 stops",
            dataSource: "Japan Shinkansen starter data"
        )
    ]

    static let tokyo = ShinkansenStation(name: "Tokyo", code: "TYO", latitude: 35.6812, longitude: 139.7671)
    static let shinYokohama = ShinkansenStation(name: "Shin-Yokohama", code: "SYH", latitude: 35.5075, longitude: 139.6176)
    static let nagoya = ShinkansenStation(name: "Nagoya", code: "NGO", latitude: 35.1709, longitude: 136.8815)
    static let kyoto = ShinkansenStation(name: "Kyoto", code: "KYO", latitude: 34.9858, longitude: 135.7588)
    static let shinOsaka = ShinkansenStation(name: "Shin-Osaka", code: "OSA", latitude: 34.7335, longitude: 135.5002)
    static let okayama = ShinkansenStation(name: "Okayama", code: "OKJ", latitude: 34.6666, longitude: 133.9186)
    static let hiroshima = ShinkansenStation(name: "Hiroshima", code: "HIJ", latitude: 34.3973, longitude: 132.4757)
    static let hakata = ShinkansenStation(name: "Hakata", code: "HKT", latitude: 33.5902, longitude: 130.4206)
    static let kumamoto = ShinkansenStation(name: "Kumamoto", code: "KMM", latitude: 32.7898, longitude: 130.6880)
    static let kagoshimaChuo = ShinkansenStation(name: "Kagoshima-Chuo", code: "KOJ", latitude: 31.5838, longitude: 130.5412)
    static let omiya = ShinkansenStation(name: "Omiya", code: "OMY", latitude: 35.9064, longitude: 139.6241)
    static let sendai = ShinkansenStation(name: "Sendai", code: "SDJ", latitude: 38.2602, longitude: 140.8820)
    static let morioka = ShinkansenStation(name: "Morioka", code: "MOR", latitude: 39.7015, longitude: 141.1363)
    static let shinAomori = ShinkansenStation(name: "Shin-Aomori", code: "AOJ", latitude: 40.8287, longitude: 140.6933)
    static let shinHakodateHokuto = ShinkansenStation(name: "Shin-Hakodate-Hokuto", code: "HKD", latitude: 41.9049, longitude: 140.6476)
    static let nagano = ShinkansenStation(name: "Nagano", code: "NGN", latitude: 36.6433, longitude: 138.1886)
    static let toyama = ShinkansenStation(name: "Toyama", code: "TOY", latitude: 36.7012, longitude: 137.2137)
    static let kanazawa = ShinkansenStation(name: "Kanazawa", code: "KMQ", latitude: 36.5781, longitude: 136.6480)
    static let tsuruga = ShinkansenStation(name: "Tsuruga", code: "TSU", latitude: 35.6456, longitude: 136.0769)
    static let takasaki = ShinkansenStation(name: "Takasaki", code: "TKS", latitude: 36.3223, longitude: 139.0124)
    static let echigoYuzawa = ShinkansenStation(name: "Echigo-Yuzawa", code: "EYZ", latitude: 36.9360, longitude: 138.8090)
    static let niigata = ShinkansenStation(name: "Niigata", code: "KIJ", latitude: 37.9120, longitude: 139.0610)
    static let tazawako = ShinkansenStation(name: "Tazawako", code: "TZW", latitude: 39.7000, longitude: 140.7221)
    static let akita = ShinkansenStation(name: "Akita", code: "AXT", latitude: 39.7166, longitude: 140.1297)
    static let fukushima = ShinkansenStation(name: "Fukushima", code: "FKS", latitude: 37.7541, longitude: 140.4595)
    static let yamagata = ShinkansenStation(name: "Yamagata", code: "GAJ", latitude: 38.2489, longitude: 140.3273)
    static let shinjo = ShinkansenStation(name: "Shinjo", code: "SJO", latitude: 38.7628, longitude: 140.3060)

    static let stationByName: [String: ShinkansenStation] = {
        let stations = [
            tokyo,
            shinYokohama,
            nagoya,
            kyoto,
            shinOsaka,
            okayama,
            hiroshima,
            hakata,
            kumamoto,
            kagoshimaChuo,
            omiya,
            sendai,
            morioka,
            shinAomori,
            shinHakodateHokuto,
            nagano,
            toyama,
            kanazawa,
            tsuruga,
            takasaki,
            echigoYuzawa,
            niigata,
            tazawako,
            akita,
            fukushima,
            yamagata,
            shinjo
        ]

        return Dictionary(uniqueKeysWithValues: stations.map { (normalizedStationKey($0.name), $0) })
    }()

    static let stationNameOverrides: [String: String] = [
        "ShinYokohama": "Shin-Yokohama",
        "ShinOsaka": "Shin-Osaka",
        "KagoshimaChuo": "Kagoshima-Chuo",
        "ShinAomori": "Shin-Aomori",
        "ShinHakodateHokuto": "Shin-Hakodate-Hokuto",
        "EchigoYuzawa": "Echigo-Yuzawa"
    ]

    static func point(_ station: ShinkansenStation, time: String) -> StationPoint {
        StationPoint(name: station.name, code: station.code, time: time, latitude: station.latitude, longitude: station.longitude)
    }

    static func stop(_ station: ShinkansenStation, time: String, platform: String, note: String, state: StationStop.StopState) -> StationStop {
        StationStop(name: station.name, time: time, platform: platform, note: note, state: state)
    }

    static func trip(
        from timetable: ODPTTrainTimetable,
        route: LiveTrainRoute,
        railwayRef: ODPTRailwayReference,
        starterTrips: [TrainTrip],
        alerts: [TrainAlert]
    ) -> TrainTrip? {
        let timedStops = timedStops(from: timetable)
        guard let first = timedStops.first, let last = timedStops.last else { return nil }

        let trainDisplayName = trainName(from: timetable, route: route)
        let origin = point(for: first.stationID, time: first.time)
        let destination = point(for: last.stationID, time: last.time)
        let currentIndex = currentStopIndex(in: timedStops)
        let currentStop = timedStops[currentIndex]
        let statusTone = alerts.map(\.tone).maxBySeverity ?? .good
        let fallback = starterTrips.first { starter in
            trainDisplayName.localizedCaseInsensitiveContains(starter.train) || starter.train.localizedCaseInsensitiveContains(trainDisplayName)
        } ?? starterTrips.first
        let liveTripID = timetable.trainID ?? timetable.sameAs ?? timetable.id ?? trainDisplayName
        let tripAlerts = alerts.isEmpty
            ? [TrainAlert(title: "ODPT timetable", detail: "Trainy loaded this trip from the ODPT TrainTimetable API.", tone: .good)]
            : alerts

        return TrainTrip(
            id: "odpt-\(route.id)-\(stableID(from: liveTripID))",
            providerID: "shinkansen",
            routeID: route.id,
            liveTripID: liveTripID,
            train: trainDisplayName,
            operatorName: operatorName(from: railwayRef.operatorID),
            service: route.name,
            origin: origin,
            destination: destination,
            duration: durationText(from: first.time, to: last.time),
            status: statusText(for: timedStops),
            statusTone: statusTone,
            category: statusTone == .good ? .departing : .attention,
            platform: currentStop.platform,
            nextStop: stationName(from: currentStop.stationID),
            eta: currentStop.time,
            speed: "Timetable",
            progress: progress(currentIndex: currentIndex, count: timedStops.count),
            bestCar: fallback?.bestCar ?? 6,
            cars: fallback?.cars ?? 10,
            seat: fallback?.seat ?? "Reserved seat",
            updated: timetable.updatedAt.map { "ODPT \(shortTimestamp($0))" } ?? "ODPT timetable",
            callout: "ODPT timetable: \(trainDisplayName) toward \(destination.name). Next timetable stop \(stationName(from: currentStop.stationID)) at \(currentStop.time).",
            signal: alerts.isEmpty ? 88 : 82,
            signalCopy: "Train timetable, route, and stop order are loaded from ODPT. Live vehicle position depends on operator coverage and is not assumed.",
            stops: stationStops(from: timedStops, currentIndex: currentIndex),
            alerts: tripAlerts,
            pulse: "\(route.name) loaded from ODPT",
            vehicleLatitude: point(for: currentStop.stationID, time: currentStop.time).latitude,
            vehicleLongitude: point(for: currentStop.stationID, time: currentStop.time).longitude,
            distanceText: "\(timedStops.count) stops",
            dataSource: "ODPT TrainTimetable API"
        )
    }

    static func trip(
        from timetable: JREastTrainTimetable,
        route: LiveTrainRoute,
        reference: JREastTimetableReference,
        starterTrips: [TrainTrip]
    ) -> TrainTrip? {
        let timedStops = timetable.stops.compactMap { stop -> ODPTTimedStop? in
            guard let time = stop.displayTime else { return nil }
            return ODPTTimedStop(stationID: stop.stationName, time: time, platform: stop.platform)
        }
        guard let first = timedStops.first, let last = timedStops.last else { return nil }

        let trainDisplayName = timetable.trainName
        let origin = point(for: first.stationID, time: first.time)
        let destination = point(for: last.stationID, time: last.time)
        let currentIndex = currentStopIndex(in: timedStops)
        let currentStop = timedStops[currentIndex]
        let fallback = starterTrips.first { starter in
            trainDisplayName.localizedCaseInsensitiveContains(starter.train) || starter.train.localizedCaseInsensitiveContains(trainDisplayName)
        } ?? starterTrips.first
        let liveTripID = timetable.trainNumber ?? timetable.sourceURL.absoluteString

        return TrainTrip(
            id: "jreast-\(route.id)-\(stableID(from: liveTripID))",
            providerID: "shinkansen",
            routeID: route.id,
            liveTripID: liveTripID,
            train: trainDisplayName,
            operatorName: reference.operatorName,
            service: route.name,
            origin: origin,
            destination: destination,
            duration: durationText(from: first.time, to: last.time),
            status: statusText(for: timedStops),
            statusTone: .good,
            category: .departing,
            platform: currentStop.platform,
            nextStop: stationName(from: currentStop.stationID),
            eta: currentStop.time,
            speed: "Timetable",
            progress: progress(currentIndex: currentIndex, count: timedStops.count),
            bestCar: fallback?.bestCar ?? 6,
            cars: fallback?.cars ?? 10,
            seat: fallback?.seat ?? "Reserved seat",
            updated: "official timetable",
            callout: "Official timetable: \(trainDisplayName) toward \(destination.name). Next timetable stop \(stationName(from: currentStop.stationID)) at \(currentStop.time).",
            signal: 90,
            signalCopy: "Train timetable, route, stop times, and platform tracks are loaded from JR East's official timetable pages. ODPT metadata remains configured when available.",
            stops: stationStops(from: timedStops, currentIndex: currentIndex),
            alerts: [
                TrainAlert(title: "Official timetable", detail: "Loaded from \(reference.dataSource). Check operating dates before travel.", tone: .good)
            ],
            pulse: "\(route.name) loaded from official timetable",
            vehicleLatitude: point(for: currentStop.stationID, time: currentStop.time).latitude,
            vehicleLongitude: point(for: currentStop.stationID, time: currentStop.time).longitude,
            distanceText: "\(timedStops.count) stops",
            dataSource: reference.dataSource
        )
    }

    static func timedStops(from timetable: ODPTTrainTimetable) -> [ODPTTimedStop] {
        var stops: [ODPTTimedStop] = []

        for object in timetable.timetableObjects {
            let stationID = object.departureStation ?? object.arrivalStation
            let time = object.departureTime ?? object.arrivalTime
            guard let stationID, let time else { continue }
            let platform = platformNumber(for: object, stationID: stationID)
            let stop = ODPTTimedStop(stationID: stationID, time: time, platform: platform)
            if stops.last != stop {
                stops.append(stop)
            }
        }

        return stops
    }

    static func stationStops(from timedStops: [ODPTTimedStop], currentIndex: Int) -> [StationStop] {
        timedStops.prefix(8).enumerated().map { index, timedStop in
            StationStop(
                name: stationName(from: timedStop.stationID),
                time: timedStop.time,
                platform: timedStop.platform,
                note: stopNote(index: index, currentIndex: currentIndex),
                state: stopState(index: index, currentIndex: currentIndex)
            )
        }
    }

    static func trainName(from timetable: ODPTTrainTimetable, route: LiveTrainRoute) -> String {
        let service = timetable.trainName?.compactMap(\.displayText).first
            ?? timetable.trainType.map(lastIdentifierComponent)
            ?? route.name.replacingOccurrences(of: " Shinkansen", with: "")
        let number = timetable.trainNumber ?? timetable.trainID.map(lastIdentifierComponent) ?? ""
        if number.isEmpty || service.localizedCaseInsensitiveContains(number) {
            return service
        }
        return "\(service) \(number)"
    }

    static func point(for odptStationID: String, time: String) -> StationPoint {
        let name = stationName(from: odptStationID)
        if let station = stationByName[normalizedStationKey(name)] {
            return point(station, time: time)
        }
        return StationPoint(name: name, code: stationCode(for: name), time: time)
    }

    static func stationName(from odptStationID: String) -> String {
        let raw = lastIdentifierComponent(odptStationID)
        if let override = stationNameOverrides[raw] {
            return override
        }
        return spacedCamelCase(raw)
            .replacingOccurrences(of: "Shin ", with: "Shin-")
            .replacingOccurrences(of: " Chuo", with: "-Chuo")
    }

    static func statusText(for timedStops: [ODPTTimedStop]) -> String {
        guard let first = timedStops.first, let last = timedStops.last else { return "ODPT timetable" }
        let now = currentTokyoMinutes()
        let firstMinutes = minutes(from: first.time)
        let lastMinutes = minutes(from: last.time, allowingNextDayAfter: firstMinutes)

        if now < firstMinutes {
            return "Scheduled"
        }
        if now <= lastMinutes {
            return "In timetable"
        }
        return "Completed"
    }

    static func currentStopIndex(in timedStops: [ODPTTimedStop]) -> Int {
        guard !timedStops.isEmpty else { return 0 }
        let now = currentTokyoMinutes()
        let firstMinutes = minutes(from: timedStops[0].time)
        return timedStops.firstIndex { stop in
            minutes(from: stop.time, allowingNextDayAfter: firstMinutes) >= now
        } ?? max(0, timedStops.count - 1)
    }

    static func progress(currentIndex: Int, count: Int) -> Double {
        guard count > 1 else { return 0 }
        return min(max(Double(currentIndex) / Double(count - 1), 0), 0.98)
    }

    static func stopNote(index: Int, currentIndex: Int) -> String {
        if index < currentIndex {
            return "Passed"
        }
        if index == currentIndex {
            return "Next timetable stop"
        }
        return "Scheduled"
    }

    static func stopState(index: Int, currentIndex: Int) -> StationStop.StopState {
        if index < currentIndex {
            return .done
        }
        if index == currentIndex {
            return .current
        }
        return .pending
    }

    static func durationText(from start: String, to end: String) -> String {
        let startMinutes = minutes(from: start)
        let endMinutes = minutes(from: end, allowingNextDayAfter: startMinutes)
        let duration = max(0, endMinutes - startMinutes)
        if duration >= 60 {
            return "\(duration / 60)h \(duration % 60)m"
        }
        return "\(duration)m"
    }

    static func currentTokyoMinutes() -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let components = calendar.dateComponents([.hour, .minute], from: Date())
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static func minutes(from time: String, allowingNextDayAfter startMinutes: Int? = nil) -> Int {
        let pieces = time.split(separator: ":").compactMap { Int($0) }
        guard pieces.count >= 2 else { return 0 }
        var value = pieces[0] * 60 + pieces[1]
        if let startMinutes, value < startMinutes {
            value += 24 * 60
        }
        return value
    }

    static func shortTimestamp(_ value: String) -> String {
        String(value.prefix(16)).replacingOccurrences(of: "T", with: " ")
    }

    static func operatorName(from odptOperatorID: String) -> String {
        switch lastIdentifierComponent(odptOperatorID) {
        case "JR-East":
            return "JR East"
        case "JR-Central":
            return "JR Central"
        case "JR-West":
            return "JR West"
        case "JR-Kyushu":
            return "JR Kyushu"
        case "JR-Hokkaido":
            return "JR Hokkaido"
        default:
            return lastIdentifierComponent(odptOperatorID)
        }
    }

    static func stationCode(for name: String) -> String {
        let letters = name.filter { $0.isLetter || $0.isNumber }
        return String(letters.prefix(3)).uppercased()
    }

    static func stableID(from value: String) -> String {
        let characters = value.map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
        return String(characters).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    static func lastIdentifierComponent(_ value: String) -> String {
        value.split(separator: ".").last.map(String.init) ?? value
    }

    static func spacedCamelCase(_ value: String) -> String {
        var result = ""
        var previousWasLowercase = false

        for character in value {
            if character.isUppercase && previousWasLowercase {
                result.append(" ")
            }
            result.append(character)
            previousWasLowercase = character.isLowercase || character.isNumber
        }

        return result
    }

    static func normalizedStationKey(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func tripMatches(_ trip: TrainTrip, query: String) -> Bool {
        let tokens = searchTokens(from: query)
        guard !tokens.isEmpty else { return true }

        let route = routes.first { $0.id == trip.routeID }
        let text = [
            trip.id,
            trip.train,
            trip.operatorName,
            trip.service,
            trip.origin.name,
            trip.destination.name,
            trip.nextStop,
            trip.status,
            trip.dataSource ?? "",
            route?.name ?? "",
            route?.summary ?? "",
            route?.destinations.joined(separator: " ") ?? "",
            trip.stops.map(\.name).joined(separator: " ")
        ].joined(separator: " ")
        let collapsedText = collapsedSearchText(text)

        return tokens.allSatisfy { token in
            collapsedText.contains(token)
        }
    }

    static func platformNumber(for object: ODPTTrainTimetableObject, stationID: String) -> String {
        let isDepartureStop = object.departureStation == stationID || object.departureTime != nil
        let candidates = isDepartureStop
            ? [object.departurePlatformNumber, object.platformNumber, object.arrivalPlatformNumber]
            : [object.arrivalPlatformNumber, object.platformNumber, object.departurePlatformNumber]

        return candidates.compactMap(platformLabel(from:)).first ?? "TBD"
    }

    static func platformLabel(from value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let component = lastIdentifierComponent(trimmed)
            .replacingOccurrences(of: "Platform", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: ".:-_ "))

        return component.isEmpty ? trimmed : component
    }

    static func searchTokens(from value: String) -> [String] {
        let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let normalized = String(folded.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        })
        let stopWords: Set<String> = ["to", "from", "for", "via"]
        return normalized
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty && !stopWords.contains($0) }
    }

    static func collapsedSearchText(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }
}

private struct ShinkansenStation {
    let name: String
    let code: String
    let latitude: Double
    let longitude: Double
}

private extension Array where Element == TrainStatusTone {
    var maxBySeverity: TrainStatusTone? {
        if contains(.late) {
            return .late
        }
        if contains(.watch) {
            return .watch
        }
        return first
    }
}
