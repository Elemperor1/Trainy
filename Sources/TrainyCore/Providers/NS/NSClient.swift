import Foundation

// HTTP client for the NS Reisinformatie API.
// Every request carries the Ocp-Apim-Subscription-Key header required by the NS APIM gateway.
struct NSClient: Sendable {
    private let baseURL = URL(string: "https://gateway.apiportal.ns.nl/reisinformatie-api/api")!
    private let subscriptionKey: String
    private let session: URLSession
    private let decoder = JSONDecoder()

    static let sourceName = "NS Reisinformatie API"

    init(subscriptionKey: String, session: URLSession) {
        self.subscriptionKey = subscriptionKey
        self.session = session
    }

    func fetchDepartures(stationCode: String) async throws -> [NSDeparture] {
        let response: NSDeparturesResponse = try await fetch(
            path: "v2/departures",
            queryItems: [URLQueryItem(name: "station", value: stationCode)],
            sourceName: "NS departures API"
        )
        return response.departures
    }

    func fetchActiveDisruptions() async throws -> [NSDisruption] {
        let response: NSDisruptionsResponse = try await fetch(
            path: "v3/disruptions",
            queryItems: [URLQueryItem(name: "isActive", value: "true")],
            sourceName: "NS disruptions API"
        )
        return response.disruptions
    }

    func fetchStations() async throws -> [NSStation] {
        let response: NSStationsResponse = try await fetch(
            path: "v2/stations",
            queryItems: [],
            sourceName: "NS stations API"
        )
        return response.payload?.stations ?? []
    }

    private func fetch<T: Decodable>(path: String, queryItems: [URLQueryItem], sourceName: String) async throws -> T {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw TrainDataProviderError.badURL
        }
        let nonEmptyQuery = queryItems.compactMap { item -> URLQueryItem? in
            guard item.value?.isEmpty == false else { return nil }
            return item
        }
        components.queryItems = nonEmptyQuery.isEmpty ? nil : nonEmptyQuery
        guard let url = components.url else { throw TrainDataProviderError.badURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 18
        request.setValue(subscriptionKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Trainy iOS NS prototype", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TrainDataProviderError.badSourceResponse(source: sourceName, statusCode: nil)
        }

        // NS gateway returns 401/403 when the subscription key is missing or invalid.
        switch httpResponse.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw TrainDataProviderError.unreadableSourceResponse(source: sourceName)
            }
        case 429:
            // Upstream rate limit. Surface as a distinct error so the provider can map it to .rateLimited.
            throw NSClientError.rateLimited
        case 401, 403:
            throw NSClientError.missingCredential
        default:
            throw TrainDataProviderError.badSourceResponse(source: sourceName, statusCode: httpResponse.statusCode)
        }
    }
}

enum NSClientError: LocalizedError, Equatable, Sendable {
    case rateLimited
    case missingCredential

    var errorDescription: String? {
        switch self {
        case .rateLimited:
            return "NS API rate limit reached. Try again shortly."
        case .missingCredential:
            return "NS API subscription key is missing or not authorized."
        }
    }
}
