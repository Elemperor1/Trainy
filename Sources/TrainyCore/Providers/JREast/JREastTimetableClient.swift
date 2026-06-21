import Foundation

struct JREastTimetableReference: Hashable, Sendable {
    let timetableURL: URL
    let operatorName: String
    let dataSource: String
    let trainLinkLimit: Int
}

struct JREastTrainTimetable: Hashable {
    let sourceURL: URL
    let title: String
    let trainName: String
    let trainNumber: String?
    let stops: [JREastTimedStop]
}

struct JREastTimedStop: Hashable {
    let stationName: String
    let arrivalTime: String?
    let departureTime: String?
    let platform: String

    var displayTime: String? {
        departureTime ?? arrivalTime
    }
}

struct JREastTimetableClient: Sendable {
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
        let sourceName = "JR East official timetable"
        var request = URLRequest(url: url)
        request.timeoutInterval = 18
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("Trainy iOS official timetable smoke", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TrainDataProviderError.badSourceResponse(source: sourceName, statusCode: nil)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TrainDataProviderError.badSourceResponse(source: sourceName, statusCode: httpResponse.statusCode)
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .shiftJIS) else {
            throw TrainDataProviderError.unreadableSourceResponse(source: sourceName)
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

    static func trainTimetable(from html: String, sourceURL: URL) -> JREastTrainTimetable? {
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
