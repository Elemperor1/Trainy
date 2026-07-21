import Foundation

/// Credential-free client for Trainy's narrow NS provider-proxy contract.
///
/// The iOS app sends station search text and validated station codes only to
/// Trainy's proxy. It never knows the NS upstream host, credential header, or
/// provider credential value.
struct NSClient: Sendable {
    static let sourceName = "NS Reisinformatie API"
    static let maximumResponseBytes = 1_048_576

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func searchStations(query: String, limit: Int = 20) async throws -> NSProxyStationSearchResponse {
        try await request(
            path: "v1/ns/stations",
            queryItems: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
    }

    func fetchDepartures(stationCode: String, limit: Int = 20) async throws -> NSProxyDeparturesResponse {
        try await request(
            path: "v1/ns/departures",
            queryItems: [
                URLQueryItem(name: "station", value: stationCode),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
    }

    func fetchDisruptions(stationCode: String? = nil, limit: Int = 6) async throws -> NSProxyDisruptionsResponse {
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let stationCode, !stationCode.isEmpty {
            items.append(URLQueryItem(name: "station", value: stationCode))
        }
        return try await request(path: "v1/ns/disruptions", queryItems: items)
    }

    private func request<Response: NSProxyContractResponse>(path: String, queryItems: [URLQueryItem]) async throws -> Response {
        guard let url = Self.endpointURL(baseURL: baseURL, path: path, queryItems: queryItems) else {
            throw NSClientError.invalidProxyConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await BoundedURLSession.data(
                for: request,
                using: session,
                maximumResponseBytes: Self.maximumResponseBytes,
                deadline: .seconds(8)
            )
        } catch BoundedURLSessionError.responseTooLarge {
            throw NSClientError.badResponse
        } catch BoundedURLSessionError.timedOut {
            throw NSClientError.timedOut
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw NSClientError.timedOut
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                throw NSClientError.offline
            default:
                throw NSClientError.unavailable
            }
        } catch {
            throw NSClientError.unavailable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSClientError.badResponse
        }
        if (200..<300).contains(httpResponse.statusCode) {
            do {
                let decoded = try Self.decoder.decode(Response.self, from: data)
                guard decoded.hasValidContract() else {
                    throw NSClientError.badResponse
                }
                return decoded
            } catch let error as NSClientError {
                throw error
            } catch {
                throw NSClientError.badResponse
            }
        }

        let proxyError = try? Self.decoder.decode(NSProxyErrorResponse.self, from: data)
        switch httpResponse.statusCode {
        case 400:
            throw NSClientError.invalidRequest
        case 429:
            let headerRetry = Int(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "")
            throw NSClientError.rateLimited(retryAfterSeconds: proxyError?.error.retryAfterSeconds ?? headerRetry)
        case 503:
            if proxyError?.status == "missingCredential" {
                throw NSClientError.notConfigured
            }
            throw NSClientError.unavailable
        default:
            throw NSClientError.unavailable
        }
    }

    static func endpointURL(baseURL: URL, path: String, queryItems: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.query = nil
        components.fragment = nil
        guard var url = components.url else { return nil }
        url.append(path: path)
        guard var endpoint = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        endpoint.queryItems = queryItems
        return endpoint.url
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = NSProxyTimestamp.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO-8601 proxy timestamp."
            )
        }
        return decoder
    }()
}

enum NSClientError: LocalizedError, Equatable, Sendable {
    case invalidProxyConfiguration
    case invalidRequest
    case notConfigured
    case offline
    case timedOut
    case rateLimited(retryAfterSeconds: Int?)
    case unavailable
    case badResponse

    var errorDescription: String? {
        switch self {
        case .invalidProxyConfiguration, .notConfigured:
            return "NS departures are not configured in this build."
        case .invalidRequest:
            return "Trainy could not send that station request."
        case .offline:
            return "You appear to be offline."
        case .timedOut:
            return "NS took too long to respond."
        case .rateLimited(let retryAfterSeconds):
            if let retryAfterSeconds {
                return "NS is busy. Try again in about \(retryAfterSeconds) seconds."
            }
            return "NS is busy. Try again shortly."
        case .unavailable:
            return "NS departures are temporarily unavailable."
        case .badResponse:
            return "Trainy could not read the NS response."
        }
    }
}
