import SwiftUI

struct StationSnapshot: Identifiable, Hashable {
    let name: String
    let code: String
    let trips: [TrainTrip]

    var id: String { name }

    var departureTrips: [TrainTrip] {
        trips.filter { $0.origin.name == name || $0.stops.contains { $0.name == name && $0.state != .done } }
    }

    var arrivalTrips: [TrainTrip] {
        trips.filter { $0.destination.name == name || $0.stops.contains { $0.name == name && $0.state == .done } }
    }

    var platforms: [String] {
        Array(
            Set(
                trips.flatMap { trip in
                    ([trip.origin.name: trip.displayPlatform][name].map { [$0] } ?? []) +
                    trip.stops.filter { $0.name == name }.map(\.displayPlatform)
                }
            )
        )
        .sorted()
    }

    var routeNames: [String] {
        Array(Set(trips.map(\.service))).sorted()
    }

    var status: RailServiceStatus {
        if trips.contains(where: { RailServiceStatus.from($0) == .canceled }) {
            return .canceled
        }
        if trips.contains(where: { RailServiceStatus.from($0) == .delayed || RailServiceStatus.from($0) == .disruption }) {
            return .disruption
        }
        return .onTime
    }
}
