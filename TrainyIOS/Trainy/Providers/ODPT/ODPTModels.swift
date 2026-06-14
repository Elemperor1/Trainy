import Foundation

struct ODPTRailwayReference: Hashable, Sendable {
    let railwayID: String
    let operatorID: String
}

struct ODPTTrainTimetable: Decodable {
    let id: String?
    let sameAs: String?
    let operatorID: String?
    let railwayID: String?
    let calendar: String?
    let trainID: String?
    let trainNumber: String?
    let trainType: String?
    let trainName: [ODPTLocalizedText]?
    let originStations: [String]?
    let destinationStations: [String]?
    let timetableObjects: [ODPTTrainTimetableObject]
    let valid: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "@id"
        case sameAs = "owl:sameAs"
        case operatorID = "odpt:operator"
        case railwayID = "odpt:railway"
        case calendar = "odpt:calendar"
        case trainID = "odpt:train"
        case trainNumber = "odpt:trainNumber"
        case trainType = "odpt:trainType"
        case trainName = "odpt:trainName"
        case originStations = "odpt:originStation"
        case destinationStations = "odpt:destinationStation"
        case timetableObjects = "odpt:trainTimetableObject"
        case valid = "dct:valid"
        case updatedAt = "dc:date"
    }
}

struct ODPTTrainTimetableObject: Decodable {
    let arrivalTime: String?
    let departureTime: String?
    let arrivalStation: String?
    let departureStation: String?
    let arrivalPlatformNumber: String?
    let departurePlatformNumber: String?
    let platformNumber: String?

    enum CodingKeys: String, CodingKey {
        case arrivalTime = "odpt:arrivalTime"
        case departureTime = "odpt:departureTime"
        case arrivalStation = "odpt:arrivalStation"
        case departureStation = "odpt:departureStation"
        case arrivalPlatformNumber = "odpt:arrivalPlatformNumber"
        case departurePlatformNumber = "odpt:departurePlatformNumber"
        case platformNumber = "odpt:platformNumber"
    }
}

struct ODPTTrainInformation: Decodable {
    let status: ODPTLocalizedText?
    let text: ODPTLocalizedText?
    let area: ODPTLocalizedText?

    enum CodingKeys: String, CodingKey {
        case status = "odpt:trainInformationStatus"
        case text = "odpt:trainInformationText"
        case area = "odpt:trainInformationArea"
    }
}

struct ODPTLocalizedText: Decodable {
    let ja: String?
    let en: String?

    var displayText: String? {
        en?.isEmpty == false ? en : ja
    }
}

struct ODPTTimedStop: Hashable {
    let stationID: String
    let time: String
    let platform: String
}
