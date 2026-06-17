import Foundation

struct ShinkansenStation {
    let name: String
    let code: String
    let latitude: Double
    let longitude: Double
}

enum ShinkansenStarterCatalog {
    static let allTrips: [TrainTrip] = [
        TrainTrip(
            id: "nozomi-231",
            providerID: "shinkansen",
            routeID: "tokaido",
            liveTripID: "nozomi-231",
            train: "Nozomi 231",
            operatorName: "JR Central",
            service: "Tokaido Shinkansen",
            origin: point(tokyo, time: "09:21"),
            destination: point(shinOsaka, time: "11:48"),
            duration: "2h 27m",
            status: "On time",
            statusTone: .good,
            category: .departing,
            platform: "18",
            nextStop: "Nagoya",
            eta: "10:58",
            speed: "Unknown",
            progress: 0.36,
            bestCar: 7,
            cars: 16,
            seat: "Car 7, Seat 12A",
            updated: "starter catalog",
            callout: "Stand by car marker 7 on platform 18. This starter catalog trip is ready for the Tokaido Shinkansen flow.",
            signal: 86,
            signalCopy: "Route, stop order, platform, and map coordinates are from Trainy's Shinkansen starter catalog. No delay, speed, or vehicle-position feed is connected.",
            stops: [
                stop(tokyo, time: "09:21", platform: "18", note: "Departed", state: .done),
                stop(shinYokohama, time: "09:39", platform: "3", note: "Departed", state: .done),
                stop(nagoya, time: "10:58", platform: "16", note: "Next stop", state: .current),
                stop(kyoto, time: "11:34", platform: "14", note: "Expected", state: .pending),
                stop(shinOsaka, time: "11:48", platform: "25", note: "Final stop", state: .pending)
            ],
            alerts: [
                TrainAlert(title: "Starter catalog", detail: "Tokaido route data is loaded for Japan-first validation.", tone: .good),
                TrainAlert(title: "Reserved seat cue", detail: "Car 7 keeps this trip aligned with the selected reserved seat.", tone: .good)
            ],
            pulse: "Tokaido starter corridor loaded",
            vehicleLatitude: 35.1709,
            vehicleLongitude: 136.8815,
            distanceText: "5 stops",
            dataSource: "Japan Shinkansen starter data"
        ),
        TrainTrip(
            id: "sakura-555",
            providerID: "shinkansen",
            routeID: "sanyo-kyushu",
            liveTripID: "sakura-555",
            train: "Sakura 555",
            operatorName: "JR West / JR Kyushu",
            service: "Sanyo-Kyushu Shinkansen",
            origin: point(shinOsaka, time: "10:06"),
            destination: point(kagoshimaChuo, time: "14:13"),
            duration: "4h 07m",
            status: "Boarding",
            statusTone: .good,
            category: .departing,
            platform: "20",
            nextStop: "Okayama",
            eta: "10:54",
            speed: "Unknown",
            progress: 0.05,
            bestCar: 5,
            cars: 8,
            seat: "Car 5, Seat 9D",
            updated: "starter catalog",
            callout: "Board the 8-car set from marker 5. This through-service is the first cross-operator Shinkansen case.",
            signal: 82,
            signalCopy: "Trainy knows the through route and major stops. Operator handoff data is not connected yet.",
            stops: [
                stop(shinOsaka, time: "10:06", platform: "20", note: "Boarding", state: .current),
                stop(okayama, time: "10:54", platform: "22", note: "Expected", state: .pending),
                stop(hiroshima, time: "11:35", platform: "12", note: "Expected", state: .pending),
                stop(hakata, time: "12:38", platform: "15", note: "JR Kyushu handoff", state: .pending),
                stop(kumamoto, time: "13:17", platform: "13", note: "Expected", state: .pending),
                stop(kagoshimaChuo, time: "14:13", platform: "12", note: "Final stop", state: .pending)
            ],
            alerts: [
                TrainAlert(title: "Through-service check", detail: "This trip validates JR West to JR Kyushu handoff behavior.", tone: .good),
                TrainAlert(title: "Short trainset", detail: "Sakura services usually use fewer cars than Tokaido Nozomi sets.", tone: .watch)
            ],
            pulse: "Sanyo-Kyushu starter corridor loaded",
            vehicleLatitude: 34.7335,
            vehicleLongitude: 135.5002,
            distanceText: "6 stops",
            dataSource: "Japan Shinkansen starter data"
        ),
        TrainTrip(
            id: "hayabusa-17",
            providerID: "shinkansen",
            routeID: "tohoku",
            liveTripID: "hayabusa-17",
            train: "Hayabusa 17",
            operatorName: "JR East",
            service: "Tohoku Shinkansen",
            origin: point(tokyo, time: "09:36"),
            destination: point(shinAomori, time: "12:49"),
            duration: "3h 13m",
            status: "On time",
            statusTone: .good,
            category: .departing,
            platform: "21",
            nextStop: "Sendai",
            eta: "11:07",
            speed: "Unknown",
            progress: 0.31,
            bestCar: 6,
            cars: 10,
            seat: "Car 6, Seat 6A",
            updated: "starter catalog",
            callout: "Use the north Shinkansen concourse and board near car 6 for balanced exits at Sendai and Morioka.",
            signal: 84,
            signalCopy: "Major Tohoku Shinkansen stops and map coordinates are loaded; the map marker is inferred from starter station geometry.",
            stops: [
                stop(tokyo, time: "09:36", platform: "21", note: "Departed", state: .done),
                stop(omiya, time: "10:01", platform: "17", note: "Departed", state: .done),
                stop(sendai, time: "11:07", platform: "12", note: "Next stop", state: .current),
                stop(morioka, time: "11:48", platform: "14", note: "Expected", state: .pending),
                stop(shinAomori, time: "12:49", platform: "13", note: "Final stop", state: .pending)
            ],
            alerts: [
                TrainAlert(title: "Tohoku route ready", detail: "Hayabusa coverage validates long-distance JR East Shinkansen trips.", tone: .good),
                TrainAlert(title: "Seat position", detail: "Car 6 keeps transfers balanced at the large intermediate stations.", tone: .good)
            ],
            pulse: "Tohoku starter corridor loaded",
            vehicleLatitude: 38.2602,
            vehicleLongitude: 140.8820,
            distanceText: "5 stops",
            dataSource: "Japan Shinkansen starter data"
        ),
        TrainTrip(
            id: "kagayaki-509",
            providerID: "shinkansen",
            routeID: "hokuriku",
            liveTripID: "kagayaki-509",
            train: "Kagayaki 509",
            operatorName: "JR East / JR West",
            service: "Hokuriku Shinkansen",
            origin: point(tokyo, time: "10:24"),
            destination: point(tsuruga, time: "13:32"),
            duration: "3h 08m",
            status: "Scheduled",
            statusTone: .good,
            category: .departing,
            platform: "22",
            nextStop: "Nagano",
            eta: "11:45",
            speed: "Unknown",
            progress: 0.0,
            bestCar: 8,
            cars: 12,
            seat: "Car 8, Seat 3E",
            updated: "starter catalog",
            callout: "Track this route to validate the new Kanazawa-Tsuruga extension shape in the app.",
            signal: 80,
            signalCopy: "The Hokuriku route includes the Tsuruga terminus, with JR West status data planned for a later provider.",
            stops: [
                stop(tokyo, time: "10:24", platform: "22", note: "Platform pending", state: .current),
                stop(nagano, time: "11:45", platform: "12", note: "Expected", state: .pending),
                stop(toyama, time: "12:30", platform: "13", note: "Expected", state: .pending),
                stop(kanazawa, time: "12:53", platform: "14", note: "Expected", state: .pending),
                stop(tsuruga, time: "13:32", platform: "12", note: "Final stop", state: .pending)
            ],
            alerts: [
                TrainAlert(title: "Hokuriku extension", detail: "Tsuruga is included so the starter dataset reflects the current endpoint shape.", tone: .good),
                TrainAlert(title: "Platform watch", detail: "Tokyo platform is representative starter catalog data until a station feed is wired.", tone: .watch)
            ],
            pulse: "Hokuriku starter corridor loaded",
            vehicleLatitude: 35.6812,
            vehicleLongitude: 139.7671,
            distanceText: "5 stops",
            dataSource: "Japan Shinkansen starter data"
        ),
        TrainTrip(
            id: "toki-327",
            providerID: "shinkansen",
            routeID: "joetsu",
            liveTripID: "toki-327",
            train: "Toki 327",
            operatorName: "JR East",
            service: "Joetsu Shinkansen",
            origin: point(tokyo, time: "13:40"),
            destination: point(niigata, time: "15:48"),
            duration: "2h 08m",
            status: "Scheduled",
            statusTone: .good,
            category: .departing,
            platform: "20",
            nextStop: "Takasaki",
            eta: "14:29",
            speed: "Unknown",
            progress: 0.0,
            bestCar: 4,
            cars: 10,
            seat: "Car 4, Seat 10C",
            updated: "starter catalog",
            callout: "Use this Joetsu trip to validate shorter regional Shinkansen tracking and snow-country stops.",
            signal: 79,
            signalCopy: "Trainy has the Joetsu corridor geometry and station order; delay and snow disruption feeds are future work.",
            stops: [
                stop(tokyo, time: "13:40", platform: "20", note: "Platform pending", state: .current),
                stop(takasaki, time: "14:29", platform: "12", note: "Expected", state: .pending),
                stop(echigoYuzawa, time: "14:56", platform: "11", note: "Expected", state: .pending),
                stop(niigata, time: "15:48", platform: "13", note: "Final stop", state: .pending)
            ],
            alerts: [
                TrainAlert(title: "Joetsu route ready", detail: "Niigata-bound service is available in search and tracking.", tone: .good),
                TrainAlert(title: "Weather-aware future", detail: "This route is a good candidate for later disruption data.", tone: .watch)
            ],
            pulse: "Joetsu starter corridor loaded",
            vehicleLatitude: 35.6812,
            vehicleLongitude: 139.7671,
            distanceText: "4 stops",
            dataSource: "Japan Shinkansen starter data"
        ),
        TrainTrip(
            id: "hayabusa-13",
            providerID: "shinkansen",
            routeID: "hokkaido",
            liveTripID: "hayabusa-13",
            train: "Hayabusa 13",
            operatorName: "JR East / JR Hokkaido",
            service: "Tohoku-Hokkaido Shinkansen",
            origin: point(tokyo, time: "08:20"),
            destination: point(shinHakodateHokuto, time: "12:17"),
            duration: "3h 57m",
            status: "Tunnel watch",
            statusTone: .watch,
            category: .attention,
            platform: "21",
            nextStop: "Shin-Aomori",
            eta: "11:29",
            speed: "Unknown",
            progress: 0.71,
            bestCar: 5,
            cars: 10,
            seat: "Car 5, Seat 8B",
            updated: "starter catalog",
            callout: "Watch the Shin-Aomori handoff and Seikan Tunnel segment. This validates cross-island trip presentation.",
            signal: 76,
            signalCopy: "Route geometry reaches Hokkaido, but tunnel-specific operational notices are not connected yet.",
            stops: [
                stop(tokyo, time: "08:20", platform: "21", note: "Departed", state: .done),
                stop(sendai, time: "09:52", platform: "12", note: "Departed", state: .done),
                stop(morioka, time: "10:32", platform: "14", note: "Departed", state: .done),
                stop(shinAomori, time: "11:29", platform: "13", note: "Next stop", state: .current),
                stop(shinHakodateHokuto, time: "12:17", platform: "11", note: "Final stop", state: .pending)
            ],
            alerts: [
                TrainAlert(title: "Hokkaido handoff", detail: "Cross-operator service is represented for later provider wiring.", tone: .watch),
                TrainAlert(title: "Long-distance buffer", detail: "Keep onward limited-express connections visible at Shin-Hakodate-Hokuto.", tone: .good)
            ],
            pulse: "Hokkaido starter corridor loaded",
            vehicleLatitude: 40.8287,
            vehicleLongitude: 140.6933,
            distanceText: "5 stops",
            dataSource: "Japan Shinkansen starter data"
        ),
        TrainTrip(
            id: "komachi-25",
            providerID: "shinkansen",
            routeID: "akita",
            liveTripID: "komachi-25",
            train: "Komachi 25",
            operatorName: "JR East",
            service: "Akita Shinkansen",
            origin: point(tokyo, time: "15:20"),
            destination: point(akita, time: "19:04"),
            duration: "3h 44m",
            status: "Coupled set",
            statusTone: .watch,
            category: .attention,
            platform: "23",
            nextStop: "Morioka",
            eta: "17:31",
            speed: "Unknown",
            progress: 0.58,
            bestCar: 14,
            cars: 17,
            seat: "Car 14, Seat 2A",
            updated: "starter catalog",
            callout: "Komachi runs coupled with Hayabusa on part of the route, so car numbering and split behavior matter.",
            signal: 73,
            signalCopy: "Mini-shinkansen split behavior is modeled as starter catalog metadata; coupling update feeds are future work.",
            stops: [
                stop(tokyo, time: "15:20", platform: "23", note: "Departed", state: .done),
                stop(sendai, time: "16:51", platform: "12", note: "Departed", state: .done),
                stop(morioka, time: "17:31", platform: "14", note: "Split next", state: .current),
                stop(tazawako, time: "18:08", platform: "1", note: "Expected", state: .pending),
                stop(akita, time: "19:04", platform: "12", note: "Final stop", state: .pending)
            ],
            alerts: [
                TrainAlert(title: "Coupled trainset", detail: "This trip exercises car numbers above 10 and split-route copy.", tone: .watch),
                TrainAlert(title: "Mini-shinkansen", detail: "Akita branch behavior is present for data-model scaling.", tone: .good)
            ],
            pulse: "Akita starter branch loaded",
            vehicleLatitude: 39.7015,
            vehicleLongitude: 141.1363,
            distanceText: "5 stops",
            dataSource: "Japan Shinkansen starter data"
        ),
        TrainTrip(
            id: "tsubasa-143",
            providerID: "shinkansen",
            routeID: "yamagata",
            liveTripID: "tsubasa-143",
            train: "Tsubasa 143",
            operatorName: "JR East",
            service: "Yamagata Shinkansen",
            origin: point(tokyo, time: "11:00"),
            destination: point(shinjo, time: "14:31"),
            duration: "3h 31m",
            status: "Scheduled",
            statusTone: .good,
            category: .departing,
            platform: "21",
            nextStop: "Fukushima",
            eta: "12:33",
            speed: "Unknown",
            progress: 0.0,
            bestCar: 13,
            cars: 17,
            seat: "Car 13, Seat 5D",
            updated: "starter catalog",
            callout: "Tsubasa validates Yamagata mini-shinkansen routing, coupled service, and compact branch stops.",
            signal: 78,
            signalCopy: "Branch station order and representative platforms are loaded; split operation updates are not connected yet.",
            stops: [
                stop(tokyo, time: "11:00", platform: "21", note: "Platform pending", state: .current),
                stop(fukushima, time: "12:33", platform: "14", note: "Split route", state: .pending),
                stop(yamagata, time: "13:44", platform: "1", note: "Expected", state: .pending),
                stop(shinjo, time: "14:31", platform: "1", note: "Final stop", state: .pending)
            ],
            alerts: [
                TrainAlert(title: "Branch route ready", detail: "Yamagata service is available for search and tracking.", tone: .good),
                TrainAlert(title: "Coupling future", detail: "Later data should distinguish the Tsubasa portion from the coupled set.", tone: .watch)
            ],
            pulse: "Yamagata starter branch loaded",
            vehicleLatitude: 35.6812,
            vehicleLongitude: 139.7671,
            distanceText: "4 stops",
            dataSource: "Japan Shinkansen starter data"
        )
    ]

    static let tokyo = ShinkansenStation(name: "Tokyo", code: "TYO", latitude: 35.6812, longitude: 139.7671)
    static let shinYokohama = ShinkansenStation(name: "Shin-Yokohama", code: "SYH", latitude: 35.5075, longitude: 139.6176)
    static let nagoya = ShinkansenStation(name: "Nagoya", code: "NGO", latitude: 35.1709, longitude: 136.8815)
    static let kyoto = ShinkansenStation(name: "Kyoto", code: "KYO", latitude: 34.9858, longitude: 135.7588)
    static let shinOsaka = ShinkansenStation(name: "Shin-Osaka", code: "OSA", latitude: 34.7335, longitude: 135.5002)
    static let okayama = ShinkansenStation(name: "Okayama", code: "OKJ", latitude: 34.6666, longitude: 133.9186)
    static let hiroshima = ShinkansenStation(name: "Hiroshima", code: "HIJ", latitude: 34.3973, longitude: 132.4757)
    static let hakata = ShinkansenStation(name: "Hakata", code: "HKT", latitude: 33.5902, longitude: 130.4206)
    static let kumamoto = ShinkansenStation(name: "Kumamoto", code: "KMM", latitude: 32.7898, longitude: 130.6880)
    static let kagoshimaChuo = ShinkansenStation(name: "Kagoshima-Chuo", code: "KOJ", latitude: 31.5838, longitude: 130.5412)
    static let omiya = ShinkansenStation(name: "Omiya", code: "OMY", latitude: 35.9064, longitude: 139.6241)
    static let sendai = ShinkansenStation(name: "Sendai", code: "SDJ", latitude: 38.2602, longitude: 140.8820)
    static let morioka = ShinkansenStation(name: "Morioka", code: "MOR", latitude: 39.7015, longitude: 141.1363)
    static let shinAomori = ShinkansenStation(name: "Shin-Aomori", code: "AOJ", latitude: 40.8287, longitude: 140.6933)
    static let shinHakodateHokuto = ShinkansenStation(name: "Shin-Hakodate-Hokuto", code: "HKD", latitude: 41.9049, longitude: 140.6476)
    static let nagano = ShinkansenStation(name: "Nagano", code: "NGN", latitude: 36.6433, longitude: 138.1886)
    static let toyama = ShinkansenStation(name: "Toyama", code: "TOY", latitude: 36.7012, longitude: 137.2137)
    static let kanazawa = ShinkansenStation(name: "Kanazawa", code: "KMQ", latitude: 36.5781, longitude: 136.6480)
    static let tsuruga = ShinkansenStation(name: "Tsuruga", code: "TSU", latitude: 35.6456, longitude: 136.0769)
    static let takasaki = ShinkansenStation(name: "Takasaki", code: "TKS", latitude: 36.3223, longitude: 139.0124)
    static let echigoYuzawa = ShinkansenStation(name: "Echigo-Yuzawa", code: "EYZ", latitude: 36.9360, longitude: 138.8090)
    static let niigata = ShinkansenStation(name: "Niigata", code: "KIJ", latitude: 37.9120, longitude: 139.0610)
    static let tazawako = ShinkansenStation(name: "Tazawako", code: "TZW", latitude: 39.7000, longitude: 140.7221)
    static let akita = ShinkansenStation(name: "Akita", code: "AXT", latitude: 39.7166, longitude: 140.1297)
    static let fukushima = ShinkansenStation(name: "Fukushima", code: "FKS", latitude: 37.7541, longitude: 140.4595)
    static let yamagata = ShinkansenStation(name: "Yamagata", code: "GAJ", latitude: 38.2489, longitude: 140.3273)
    static let shinjo = ShinkansenStation(name: "Shinjo", code: "SJO", latitude: 38.7628, longitude: 140.3060)

    static let stationByName: [String: ShinkansenStation] = {
        let stations = [
            tokyo,
            shinYokohama,
            nagoya,
            kyoto,
            shinOsaka,
            okayama,
            hiroshima,
            hakata,
            kumamoto,
            kagoshimaChuo,
            omiya,
            sendai,
            morioka,
            shinAomori,
            shinHakodateHokuto,
            nagano,
            toyama,
            kanazawa,
            tsuruga,
            takasaki,
            echigoYuzawa,
            niigata,
            tazawako,
            akita,
            fukushima,
            yamagata,
            shinjo
        ]

        return Dictionary(uniqueKeysWithValues: stations.map { (ProviderTextUtilities.normalizedStationKey($0.name), $0) })
    }()

    static let stationNameOverrides: [String: String] = [
        "ShinYokohama": "Shin-Yokohama",
        "ShinOsaka": "Shin-Osaka",
        "KagoshimaChuo": "Kagoshima-Chuo",
        "ShinAomori": "Shin-Aomori",
        "ShinHakodateHokuto": "Shin-Hakodate-Hokuto",
        "EchigoYuzawa": "Echigo-Yuzawa"
    ]

    static func point(_ station: ShinkansenStation, time: String) -> StationPoint {
        StationPoint(name: station.name, code: station.code, time: time, latitude: station.latitude, longitude: station.longitude)
    }

    static func stop(_ station: ShinkansenStation, time: String, platform: String, note: String, state: StationStop.StopState) -> StationStop {
        StationStop(name: station.name, time: time, platform: platform, note: note, state: state)
    }

}

extension ShinkansenTrainProvider {
    static var allTrips: [TrainTrip] { ShinkansenStarterCatalog.allTrips }
    static var stationByName: [String: ShinkansenStation] { ShinkansenStarterCatalog.stationByName }
    static var stationNameOverrides: [String: String] { ShinkansenStarterCatalog.stationNameOverrides }

    static func point(_ station: ShinkansenStation, time: String) -> StationPoint {
        ShinkansenStarterCatalog.point(station, time: time)
    }

    static func point(_ station: ShinkansenStation, time: String, timeZoneIdentifier: String) -> StationPoint {
        StationPoint(name: station.name, code: station.code, time: time, latitude: station.latitude, longitude: station.longitude, timeZoneIdentifier: timeZoneIdentifier)
    }
}
