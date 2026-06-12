import Foundation
import SwiftUI

enum TrainStatusTone: String, Codable, CaseIterable {
    case good
    case watch
    case late

    var tint: Color {
        switch self {
        case .good:
            return TrainyColor.green
        case .watch:
            return TrainyColor.amber
        case .late:
            return TrainyColor.red
        }
    }

    var softFill: Color {
        tint.opacity(0.14)
    }
}

enum TripFilter: String, CaseIterable, Identifiable, Codable {
    case all
    case departing
    case attention

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .departing:
            return "Departing"
        case .attention:
            return "Needs Watch"
        }
    }
}

struct StationPoint: Hashable, Codable {
    let name: String
    let code: String
    let time: String
    let latitude: Double?
    let longitude: Double?

    init(name: String, code: String, time: String, latitude: Double? = nil, longitude: Double? = nil) {
        self.name = name
        self.code = code
        self.time = time
        self.latitude = latitude
        self.longitude = longitude
    }
}

struct StationStop: Identifiable, Hashable, Codable {
    enum StopState: String, Codable {
        case done
        case current
        case pending
    }

    let id = UUID()
    let name: String
    let time: String
    let platform: String
    let note: String
    let state: StopState

    private enum CodingKeys: String, CodingKey {
        case name
        case time
        case platform
        case note
        case state
    }
}

struct TrainAlert: Identifiable, Hashable, Codable {
    let id = UUID()
    let title: String
    let detail: String
    let tone: TrainStatusTone

    private enum CodingKeys: String, CodingKey {
        case title
        case detail
        case tone
    }
}

struct TrainTrip: Identifiable, Hashable, Codable {
    let id: String
    let providerID: String?
    let routeID: String?
    let liveTripID: String?
    let train: String
    let operatorName: String
    let service: String
    let origin: StationPoint
    let destination: StationPoint
    let duration: String
    let status: String
    let statusTone: TrainStatusTone
    let category: TripFilter
    let platform: String
    let nextStop: String
    let eta: String
    let speed: String
    var progress: Double
    let bestCar: Int
    let cars: Int
    let seat: String
    var updated: String
    let callout: String
    let signal: Int
    let signalCopy: String
    let stops: [StationStop]
    let alerts: [TrainAlert]
    let pulse: String
    let vehicleLatitude: Double?
    let vehicleLongitude: Double?
    let distanceText: String?
    let dataSource: String?

    init(
        id: String,
        providerID: String? = nil,
        routeID: String? = nil,
        liveTripID: String? = nil,
        train: String,
        operatorName: String,
        service: String,
        origin: StationPoint,
        destination: StationPoint,
        duration: String,
        status: String,
        statusTone: TrainStatusTone,
        category: TripFilter,
        platform: String,
        nextStop: String,
        eta: String,
        speed: String,
        progress: Double,
        bestCar: Int,
        cars: Int,
        seat: String,
        updated: String,
        callout: String,
        signal: Int,
        signalCopy: String,
        stops: [StationStop],
        alerts: [TrainAlert],
        pulse: String,
        vehicleLatitude: Double? = nil,
        vehicleLongitude: Double? = nil,
        distanceText: String? = nil,
        dataSource: String? = nil
    ) {
        self.id = id
        self.providerID = providerID
        self.routeID = routeID
        self.liveTripID = liveTripID
        self.train = train
        self.operatorName = operatorName
        self.service = service
        self.origin = origin
        self.destination = destination
        self.duration = duration
        self.status = status
        self.statusTone = statusTone
        self.category = category
        self.platform = platform
        self.nextStop = nextStop
        self.eta = eta
        self.speed = speed
        self.progress = progress
        self.bestCar = bestCar
        self.cars = cars
        self.seat = seat
        self.updated = updated
        self.callout = callout
        self.signal = signal
        self.signalCopy = signalCopy
        self.stops = stops
        self.alerts = alerts
        self.pulse = pulse
        self.vehicleLatitude = vehicleLatitude
        self.vehicleLongitude = vehicleLongitude
        self.distanceText = distanceText
        self.dataSource = dataSource
    }
}

enum TrainyColor {
    static let ink = Color(red: 16.0 / 255.0, green: 20.0 / 255.0, blue: 25.0 / 255.0)
    static let muted = Color(red: 96.0 / 255.0, green: 109.0 / 255.0, blue: 122.0 / 255.0)
    static let paper = Color(red: 247.0 / 255.0, green: 249.0 / 255.0, blue: 250.0 / 255.0)
    static let line = Color(red: 217.0 / 255.0, green: 222.0 / 255.0, blue: 228.0 / 255.0)
    static let red = Color(red: 216.0 / 255.0, green: 74.0 / 255.0, blue: 58.0 / 255.0)
    static let green = Color(red: 31.0 / 255.0, green: 143.0 / 255.0, blue: 103.0 / 255.0)
    static let amber = Color(red: 197.0 / 255.0, green: 122.0 / 255.0, blue: 22.0 / 255.0)
    static let blue = Color(red: 40.0 / 255.0, green: 104.0 / 255.0, blue: 199.0 / 255.0)
    static let teal = Color(red: 15.0 / 255.0, green: 143.0 / 255.0, blue: 149.0 / 255.0)
}

extension TrainTrip {
    private static let shinkansenProvider = ShinkansenTrainProvider()

    static let samples: [TrainTrip] = shinkansenProvider.defaultTrips
    static let discoverable: [TrainTrip] = Array(shinkansenProvider.catalog.dropFirst(shinkansenProvider.defaultTrips.count))
}
