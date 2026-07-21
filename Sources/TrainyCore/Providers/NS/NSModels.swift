import Foundation

enum NSProxyTimestamp {
    private static let pattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:?\d{2})$"#

    static func date(from value: String) -> Date? {
        guard !value.isEmpty,
              value.count <= 64,
              value.range(of: pattern, options: .regularExpression) != nil
        else { return nil }

        let bytes = Array(value.utf8)
        func integer(_ range: Range<Int>) -> Int? {
            guard range.upperBound <= bytes.count else { return nil }
            return Int(String(decoding: bytes[range], as: UTF8.self))
        }
        guard let year = integer(0..<4),
              let month = integer(5..<7),
              let day = integer(8..<10),
              let hour = integer(11..<13),
              let minute = integer(14..<16),
              let second = integer(17..<19)
        else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
        guard let localDate = calendar.date(from: components) else { return nil }
        let resolved = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: localDate
        )
        guard resolved.year == year,
              resolved.month == month,
              resolved.day == day,
              resolved.hour == hour,
              resolved.minute == minute,
              resolved.second == second
        else { return nil }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let wholeSeconds = ISO8601DateFormatter()
        wholeSeconds.formatOptions = [.withInternetDateTime]
        return wholeSeconds.date(from: value)
    }
}

protocol NSProxyContractResponse: Decodable {
    func hasValidContract() -> Bool
}

private enum NSProxyContractLimits {
    static let maximumItems = 25

    static func valid(_ value: String, maximumCharacters: Int) -> Bool {
        !value.isEmpty && value.count <= maximumCharacters
    }

    static func valid(_ value: String?, maximumCharacters: Int) -> Bool {
        value.map { valid($0, maximumCharacters: maximumCharacters) } ?? true
    }

    static func validRequestID(_ value: String) -> Bool {
        valid(value, maximumCharacters: 128)
    }

    static func validMetadata(_ value: NSProxyMetadata) -> Bool {
        value.provider == "ns"
            && value.source == NSClient.sourceName
            && value.attribution == "Data from Nederlandse Spoorwegen (NS)"
            && value.expiresAt >= value.fetchedAt
    }

    static func validStationCode(_ value: String) -> Bool {
        guard valid(value, maximumCharacters: 8) else { return false }
        return value.unicodeScalars.allSatisfy {
            CharacterSet.uppercaseLetters.contains($0) || CharacterSet.decimalDigits.contains($0)
        }
    }
}

/// Compact metadata supplied by the Trainy provider proxy for every NS response.
struct NSProxyMetadata: Decodable, Hashable, Sendable {
    enum Freshness: String, Decodable, Hashable, Sendable {
        case fresh
        case stale
    }

    enum CacheStatus: String, Decodable, Hashable, Sendable {
        case hit
        case miss
        case staleFallback = "stale-fallback"
    }

    let provider: String
    let source: String
    let attribution: String
    let fetchedAt: Date
    let expiresAt: Date
    let freshness: Freshness
    let cacheStatus: CacheStatus
}

struct NSProxyStationSearchResponse: NSProxyContractResponse, Sendable {
    struct Payload: Decodable, Sendable {
        let stations: [NSProxyStation]
    }

    let data: Payload
    let meta: NSProxyMetadata
    let requestId: String

    func hasValidContract() -> Bool {
        data.stations.count <= NSProxyContractLimits.maximumItems
            && NSProxyContractLimits.validMetadata(meta)
            && NSProxyContractLimits.validRequestID(requestId)
            && data.stations.allSatisfy(\.hasValidContract)
    }
}

struct NSProxyStation: Decodable, Hashable, Sendable {
    let code: String
    let name: String
    let shortName: String?
    let countryCode: String?
    let latitude: Double?
    let longitude: Double?

    fileprivate var hasValidContract: Bool {
        NSProxyContractLimits.validStationCode(code)
            && NSProxyContractLimits.valid(name, maximumCharacters: 120)
            && NSProxyContractLimits.valid(shortName, maximumCharacters: 80)
            && NSProxyContractLimits.valid(countryCode, maximumCharacters: 3)
            && latitude.map { $0.isFinite && (-90...90).contains($0) } ?? true
            && longitude.map { $0.isFinite && (-180...180).contains($0) } ?? true
    }
}

struct NSProxyDeparturesResponse: NSProxyContractResponse, Sendable {
    struct Payload: Decodable, Sendable {
        struct Station: Decodable, Sendable {
            let code: String
        }

        let station: Station
        let departures: [NSProxyDeparture]
    }

    let data: Payload
    let meta: NSProxyMetadata
    let requestId: String

    func hasValidContract() -> Bool {
        NSProxyContractLimits.validStationCode(data.station.code)
            && data.departures.count <= NSProxyContractLimits.maximumItems
            && data.departures.allSatisfy(\.hasValidContract)
            && NSProxyContractLimits.validMetadata(meta)
            && NSProxyContractLimits.validRequestID(requestId)
    }
}

struct NSProxyDeparture: Decodable, Hashable, Sendable {
    enum Status: String, Decodable, Hashable, Sendable {
        case scheduled
        case onTime
        case delayed
        case boarding
        case arriving
        case atPlatform
        case departed
        case cancelled
    }

    let id: String
    let service: String
    let destination: String
    let scheduledAt: String
    let expectedAt: String?
    let platform: String?
    let status: Status

    fileprivate var hasValidContract: Bool {
        guard NSProxyContractLimits.valid(id, maximumCharacters: 160),
              NSProxyContractLimits.valid(service, maximumCharacters: 120),
              NSProxyContractLimits.valid(destination, maximumCharacters: 160),
              NSProxyContractLimits.valid(platform, maximumCharacters: 16),
              let scheduledDate = NSProxyTimestamp.date(from: scheduledAt)
        else { return false }

        let expectedDate = expectedAt.flatMap(NSProxyTimestamp.date)
        guard expectedAt == nil || expectedDate != nil else { return false }

        switch status {
        case .scheduled:
            return expectedDate == nil
        case .onTime:
            return expectedDate.map { $0 <= scheduledDate } ?? false
        case .delayed:
            return expectedDate.map { $0 > scheduledDate } ?? false
        case .boarding, .arriving, .atPlatform, .departed, .cancelled:
            return true
        }
    }
}

struct NSProxyDisruptionsResponse: NSProxyContractResponse, Sendable {
    struct Payload: Decodable, Sendable {
        let disruptions: [NSProxyDisruption]
    }

    let data: Payload
    let meta: NSProxyMetadata
    let requestId: String

    func hasValidContract() -> Bool {
        data.disruptions.count <= NSProxyContractLimits.maximumItems
            && data.disruptions.allSatisfy(\.hasValidContract)
            && NSProxyContractLimits.validMetadata(meta)
            && NSProxyContractLimits.validRequestID(requestId)
    }
}

struct NSProxyDisruption: Decodable, Hashable, Sendable {
    enum Severity: String, Decodable, Hashable, Sendable {
        case watch
        case major
    }

    let id: String
    let title: String
    let detail: String
    let severity: Severity

    fileprivate var hasValidContract: Bool {
        NSProxyContractLimits.valid(id, maximumCharacters: 160)
            && NSProxyContractLimits.valid(title, maximumCharacters: 180)
            && NSProxyContractLimits.valid(detail, maximumCharacters: 1_000)
    }
}

struct NSProxyErrorResponse: Decodable, Sendable {
    struct ProxyError: Decodable, Sendable {
        let code: String
        let message: String
        let retryAfterSeconds: Int?
    }

    let status: String?
    let error: ProxyError
    let requestId: String?
}
