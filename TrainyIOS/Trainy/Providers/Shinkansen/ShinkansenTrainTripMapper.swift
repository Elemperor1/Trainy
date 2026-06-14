import Foundation

extension ShinkansenTrainProvider {
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
        let sourceProvenance = SourceProvenance.odptTimetable(
            publishedAt: SourceProvenance.date(from: timetable.updatedAt),
            validUntil: SourceProvenance.date(from: timetable.valid)
        )
        let starterSource = fallback?.sourceProvenance ?? .starterCatalog()

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
            signalCopy: "Scheduled timetable, route, and stop order are loaded from ODPT. The map marker uses station geometry, not a vehicle-position feed.",
            stops: stationStops(from: timedStops, currentIndex: currentIndex),
            alerts: tripAlerts,
            pulse: "\(route.name) loaded from ODPT",
            vehicleLatitude: point(for: currentStop.stationID, time: currentStop.time).latitude,
            vehicleLongitude: point(for: currentStop.stationID, time: currentStop.time).longitude,
            distanceText: "\(timedStops.count) stops",
            dataSource: "ODPT TrainTimetable API",
            sourceProvenance: sourceProvenance,
            factProvenance: FactProvenance.timetableFacts(
                source: sourceProvenance,
                starterSource: starterSource,
                hasPlatform: currentStop.platform != "TBD"
            )
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
        let sourceProvenance = SourceProvenance.jrEastTimetable(sourceName: reference.dataSource, sourceURL: timetable.sourceURL)
        let starterSource = fallback?.sourceProvenance ?? .starterCatalog()

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
            updated: "scheduled timetable",
            callout: "Official timetable: \(trainDisplayName) toward \(destination.name). Next timetable stop \(stationName(from: currentStop.stationID)) at \(currentStop.time).",
            signal: 90,
            signalCopy: "Scheduled timetable, route, stop times, and platform tracks are loaded from JR East's timetable pages. ODPT metadata remains configured when available.",
            stops: stationStops(from: timedStops, currentIndex: currentIndex),
            alerts: [
                TrainAlert(title: "Official timetable", detail: "Loaded from \(reference.dataSource). Check operating dates before travel.", tone: .good)
            ],
            pulse: "\(route.name) loaded from scheduled timetable",
            vehicleLatitude: point(for: currentStop.stationID, time: currentStop.time).latitude,
            vehicleLongitude: point(for: currentStop.stationID, time: currentStop.time).longitude,
            distanceText: "\(timedStops.count) stops",
            dataSource: reference.dataSource,
            sourceProvenance: sourceProvenance,
            factProvenance: FactProvenance.timetableFacts(
                source: sourceProvenance,
                starterSource: starterSource,
                hasPlatform: currentStop.platform != "TBD"
            )
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
        ProviderTextUtilities.stableID(from: value)
    }

    static func lastIdentifierComponent(_ value: String) -> String {
        ProviderTextUtilities.lastIdentifierComponent(value)
    }

    static func spacedCamelCase(_ value: String) -> String {
        ProviderTextUtilities.spacedCamelCase(value)
    }

    static func normalizedStationKey(_ name: String) -> String {
        ProviderTextUtilities.normalizedStationKey(name)
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
        ProviderTextUtilities.searchTokens(from: value)
    }

    static func collapsedSearchText(_ value: String) -> String {
        ProviderTextUtilities.collapsedSearchText(value)
    }
}
