import Foundation

struct ODPTClient: Sendable {
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
