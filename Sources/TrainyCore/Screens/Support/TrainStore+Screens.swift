import Foundation

extension TrainStore {
    var offlineMessage: String? {
        if case .offline(let message) = liveLoadState {
            return message
        }
        return nil
    }

    var stationSnapshots: [StationSnapshot] {
        let stationNames = Set(
            trips.flatMap { trip in
                [trip.origin.name, trip.destination.name] + trip.stops.map(\.name)
            }
        )

        return stationNames.sorted().map { stationName in
            let matchingTrips = trips.filter { trip in
                trip.origin.name == stationName ||
                trip.destination.name == stationName ||
                trip.stops.contains { $0.name == stationName }
            }
            let code = matchingTrips
                .compactMap { trip in
                    if trip.origin.name == stationName { return trip.origin.code }
                    if trip.destination.name == stationName { return trip.destination.code }
                    return nil
                }
                .first ?? String(stationName.prefix(3))

            return StationSnapshot(name: stationName, code: code, trips: matchingTrips)
        }
    }
}
