import Foundation

struct ProviderProxyConfiguration: Hashable, Sendable {
    static let environmentVariable = "TRAINY_PROVIDER_PROXY_BASE_URL"
    static let infoPlistKey = "TrainyProviderProxyBaseURL"

    let baseURL: URL?

    init(baseURL: URL?) {
        self.baseURL = Self.normalizedURL(baseURL)
    }

    init(rawBaseURL: String?) {
        self.baseURL = Self.normalizedURL(from: rawBaseURL)
    }

    static func current(
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ProviderProxyConfiguration {
        let environmentValue = environment[environmentVariable]
        let infoPlistValue = infoDictionary?[infoPlistKey] as? String
        return ProviderProxyConfiguration(rawBaseURL: environmentValue ?? infoPlistValue)
    }

    var isConfigured: Bool {
        baseURL != nil
    }

    var displayHost: String {
        guard let baseURL else { return "Not configured" }
        return baseURL.host(percentEncoded: false) ?? baseURL.absoluteString
    }

    private static func normalizedURL(_ url: URL?) -> URL? {
        guard let url else { return nil }
        return normalizedURL(from: url.absoluteString)
    }

    private static func normalizedURL(from rawValue: String?) -> URL? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            var components = URLComponents(string: trimmed),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            let host = components.host?.lowercased(),
            !host.isEmpty,
            components.user == nil,
            components.password == nil,
            scheme == "https" || Self.isLoopbackHost(host)
        else {
            return nil
        }

        components.fragment = nil
        components.query = nil
        if components.path == "/" {
            components.path = ""
        }
        return components.url
    }

    private static func isLoopbackHost(_ host: String) -> Bool {
        host == "localhost" || host == "127.0.0.1" || host == "::1"
    }
}

enum ProviderProxyHealthStatus: String, Codable, Hashable, Sendable {
    case ok
    case missingCredential
    case rateLimited
    case offline
    case stale
    case unsupported
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = Self(rawValue: value) ?? .unknown
    }
}

enum ProviderProxyStaticFeedStatus: String, Codable, Hashable, Sendable {
    case fresh
    case stale
    case missing
    case unavailable
    case notApplicable
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = Self(rawValue: value) ?? .unknown
    }
}

struct ProviderProxyCacheHealth: Codable, Hashable, Sendable {
    let staticFeed: ProviderProxyStaticFeedStatus
    let updatedAt: Date?

    init(staticFeed: ProviderProxyStaticFeedStatus = .unknown, updatedAt: Date? = nil) {
        self.staticFeed = staticFeed
        self.updatedAt = updatedAt
    }
}

struct ProviderProxyProviderHealth: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let region: String
    let configured: Bool
    let status: ProviderProxyHealthStatus
    let capabilities: [String]
    let cache: ProviderProxyCacheHealth?
    let checkedAt: Date?
    let message: String

    init(
        id: String,
        region: String = "unknown",
        configured: Bool,
        status: ProviderProxyHealthStatus,
        capabilities: [String] = [],
        cache: ProviderProxyCacheHealth? = nil,
        checkedAt: Date? = nil,
        message: String
    ) {
        self.id = id
        self.region = region
        self.configured = configured
        self.status = status
        self.capabilities = capabilities
        self.cache = cache
        self.checkedAt = checkedAt
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        region = try container.decodeIfPresent(String.self, forKey: .region) ?? "unknown"
        configured = try container.decodeIfPresent(Bool.self, forKey: .configured) ?? false
        status = try container.decodeIfPresent(ProviderProxyHealthStatus.self, forKey: .status) ?? .unknown
        capabilities = try container.decodeIfPresent([String].self, forKey: .capabilities) ?? []
        cache = try container.decodeIfPresent(ProviderProxyCacheHealth.self, forKey: .cache)
        checkedAt = try container.decodeIfPresent(Date.self, forKey: .checkedAt)
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? status.displayName
    }
}

struct ProviderProxyHealthResponse: Codable, Hashable, Sendable {
    let generatedAt: Date?
    let providers: [ProviderProxyProviderHealth]

    init(generatedAt: Date?, providers: [ProviderProxyProviderHealth]) {
        self.generatedAt = generatedAt
        self.providers = providers
    }
}

protocol ProviderProxyHealthFetching: Sendable {
    func fetchProviderHealth(from baseURL: URL) async throws -> ProviderProxyHealthResponse
}

enum BoundedURLSessionError: Error, Equatable {
    case responseTooLarge
    case timedOut
}

/// Streams an HTTP body under both a byte ceiling and a whole-response deadline.
///
/// `URLRequest.timeoutInterval` is an inactivity timeout and `data(for:)`
/// materializes the complete body before callers can inspect its size. This
/// loader cancels the underlying task as soon as either explicit bound wins.
struct BoundedURLSession {
    private struct Payload: @unchecked Sendable {
        let data: Data
        let response: URLResponse
    }

    static func data(
        for request: URLRequest,
        using session: URLSession,
        maximumResponseBytes: Int,
        deadline: Duration
    ) async throws -> (Data, URLResponse) {
        let payload = try await withThrowingTaskGroup(of: Payload.self) { group in
            group.addTask {
                try await read(
                    request: request,
                    session: session,
                    maximumResponseBytes: maximumResponseBytes
                )
            }
            group.addTask {
                try await Task.sleep(for: deadline)
                try Task.checkCancellation()
                throw BoundedURLSessionError.timedOut
            }

            defer { group.cancelAll() }
            guard let first = try await group.next() else {
                throw BoundedURLSessionError.timedOut
            }
            return first
        }
        return (payload.data, payload.response)
    }

    private static func read(
        request: URLRequest,
        session: URLSession,
        maximumResponseBytes: Int
    ) async throws -> Payload {
        let (bytes, response) = try await session.bytes(for: request)
        let task = bytes.task
        return try await withTaskCancellationHandler {
            let expectedLength = response.expectedContentLength
            if expectedLength > Int64(maximumResponseBytes) {
                task.cancel()
                throw BoundedURLSessionError.responseTooLarge
            }

            var data = Data()
            if expectedLength > 0 {
                data.reserveCapacity(min(maximumResponseBytes, Int(expectedLength)))
            }
            do {
                for try await byte in bytes {
                    guard data.count < maximumResponseBytes else {
                        task.cancel()
                        throw BoundedURLSessionError.responseTooLarge
                    }
                    data.append(byte)
                }
            } catch {
                if Task.isCancelled { task.cancel() }
                throw error
            }
            return Payload(data: data, response: response)
        } onCancel: {
            task.cancel()
        }
    }
}

struct ProviderProxyHealthClient: ProviderProxyHealthFetching {
    static let maximumResponseBytes = 65_536

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchProviderHealth(from baseURL: URL) async throws -> ProviderProxyHealthResponse {
        let url = Self.healthURL(from: baseURL)
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
            throw ProviderProxyHealthError.unreadableHealth
        } catch BoundedURLSessionError.timedOut {
            throw ProviderProxyHealthError.timedOut
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderProxyHealthError.badResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ProviderProxyHealthError.badStatus(httpResponse.statusCode)
        }
        do {
            return try Self.makeDecoder().decode(ProviderProxyHealthResponse.self, from: data)
        } catch {
            throw ProviderProxyHealthError.unreadableHealth
        }
    }

    static func healthURL(from baseURL: URL) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        var url = components?.url ?? baseURL
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let suffix = "v1/health/providers"
        if path.isEmpty {
            url.append(path: suffix)
        } else if !path.hasSuffix(suffix) {
            url.append(path: suffix)
        }
        return url
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ProviderProxyDateParser.decodingStrategy
        return decoder
    }
}

enum ProviderProxyHealthError: LocalizedError, Equatable {
    case badResponse
    case badStatus(Int)
    case timedOut
    case unreadableHealth

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "The provider proxy returned an unexpected response."
        case .badStatus(let statusCode):
            return "The provider proxy returned HTTP \(statusCode)."
        case .timedOut:
            return "The provider proxy health check timed out."
        case .unreadableHealth:
            return "Trainy could not read provider proxy health."
        }
    }
}

enum ProviderProxyProviderIDAliases {
    static func aliases(for providerID: String) -> Set<String> {
        let baseAliases: Set<String> = [providerID]
        switch providerID {
        case "shinkansen":
            return baseAliases.union(["odpt", "japan-shinkansen"])
        case "netherlands-ns":
            return baseAliases.union(["ns"])
        case "taiwan-tdx":
            return baseAliases.union(["tdx"])
        case "transport-for-nsw":
            return baseAliases.union(["tfnsw"])
        case "switzerland-opentransportdata":
            return baseAliases.union(["swiss", "switzerland"])
        case "france-sncf-transport-data-gouv":
            return baseAliases.union(["france", "sncf", "transport-data-gouv"])
        case "uk-national-rail-darwin":
            return baseAliases.union(["darwin", "uk-darwin", "national-rail"])
        case "mta-lirr-metro-north":
            return baseAliases.union(["mta"])
        case "deutsche-bahn":
            return baseAliases.union(["db"])
        case "south-korea-tago-topis":
            return baseAliases.union(["tago", "topis"])
        default:
            return baseAliases
        }
    }
}

private enum ProviderProxyDateParser {
    static var decodingStrategy: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = parse(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO-8601 provider proxy date."
            )
        }
    }

    private static func parse(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }
}

extension ProviderProxyHealthStatus {
    var displayName: String {
        switch self {
        case .ok:
            return "OK"
        case .missingCredential:
            return "Missing credential"
        case .rateLimited:
            return "Rate limited"
        case .offline:
            return "Offline"
        case .stale:
            return "Stale"
        case .unsupported:
            return "Unsupported"
        case .unknown:
            return "Unknown"
        }
    }
}

extension ProviderProxyStaticFeedStatus {
    var displayName: String {
        switch self {
        case .fresh:
            return "Fresh"
        case .stale:
            return "Stale"
        case .missing:
            return "Missing"
        case .unavailable:
            return "Unavailable"
        case .notApplicable:
            return "Not applicable"
        case .unknown:
            return "Unknown"
        }
    }
}
