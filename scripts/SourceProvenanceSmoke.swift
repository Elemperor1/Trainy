import Foundation

enum SourceProvenanceSmokeError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

@main
struct SourceProvenanceSmoke {
    static func main() throws {
        let starterTrip = TrainTrip.samples[0]
        try require(
            starterTrip.sourceProvenance.sourceKind == .starterCatalog,
            "Starter catalog trip was not labeled as starter catalog."
        )
        try require(
            starterTrip.sourceProvenance.confidence == .estimated,
            "Starter catalog trip should carry estimated confidence."
        )
        try require(
            TrainTrip.samples.allSatisfy { $0.speed == "Unknown" },
            "Starter catalog trips should not expose numeric live-speed values."
        )
        try require(
            starterTrip.sourceProvenance.sourceKind.compactTitle == "Starter",
            "Starter catalog compact copy should say Starter."
        )
        try require(
            starterTrip.sourceProvenance.riderExplanation.localizedCaseInsensitiveContains("starter catalog"),
            "Starter catalog copy should explain that it is starter catalog data."
        )
        try require(
            !starterTrip.sourceProvenance.riderExplanation.localizedCaseInsensitiveContains("live"),
            "Starter catalog copy should not claim live data."
        )
        try require(
            starterTrip.sourceProvenance.licenseAttributionText.localizedCaseInsensitiveContains("Trainy-owned starter catalog"),
            "Starter catalog license copy should identify Trainy's starter catalog."
        )
        try requireFact(
            starterTrip,
            .vehiclePosition,
            confidence: .inferred,
            sourceKind: .inferred,
            "Starter map coordinates should be inferred."
        )
        try requireFact(
            starterTrip,
            .carriageCue,
            confidence: .inferred,
            sourceKind: .inferred,
            "Starter best-car cue should be inferred."
        )
        try requireFact(
            starterTrip,
            .seatCue,
            confidence: .inferred,
            sourceKind: .inferred,
            "Starter seat cue should be inferred."
        )
        try requireFact(
            starterTrip,
            .speed,
            confidence: .unknown,
            sourceKind: .inferred,
            "Starter speed should be unknown."
        )

        let legacyStarterData = try legacyPayloadWithoutNewSourceFields(from: starterTrip)
        let decodedStarterTrip = try JSONDecoder().decode(TrainTrip.self, from: legacyStarterData)
        try require(
            decodedStarterTrip.sourceProvenance.sourceKind == .starterCatalog,
            "Legacy starter payload did not derive starter catalog provenance."
        )
        try requireFact(
            decodedStarterTrip,
            .vehiclePosition,
            confidence: .inferred,
            sourceKind: .inferred,
            "Legacy starter payload did not derive inferred map coordinates."
        )

        let odptLegacy = SourceProvenance.legacy(
            dataSource: "ODPT TrainTimetable API",
            providerID: "shinkansen",
            providerName: "JR Central"
        )
        try require(
            odptLegacy.sourceKind == .officialTimetable,
            "Legacy ODPT dataSource did not map to official timetable."
        )

        let odptFactory = SourceProvenance.odptTimetable(fetchedAt: nil)
        try require(
            odptFactory.sourceKind == .officialTimetable && odptFactory.confidence == .confirmed,
            "ODPT factory did not produce confirmed official timetable provenance."
        )
        try require(
            odptFactory.sourceKind.compactTitle == "Scheduled",
            "ODPT compact copy should use Scheduled for timetable-only data."
        )
        try require(
            odptFactory.summaryText.localizedCaseInsensitiveContains("Scheduled timetable"),
            "ODPT summary copy should use scheduled timetable wording."
        )
        try require(
            odptFactory.riderExplanation.localizedCaseInsensitiveContains("scheduled timetable") &&
                !odptFactory.riderExplanation.localizedCaseInsensitiveContains("live"),
            "ODPT rider copy should explain scheduled timetable data without live claims."
        )
        try require(
            odptFactory.licenseAttributionText.localizedCaseInsensitiveContains("License: ODPT developer terms") &&
                odptFactory.licenseAttributionText.localizedCaseInsensitiveContains("Attribution: Timetable data from ODPT TrainTimetable"),
            "ODPT license and attribution copy should be visible."
        )
        try requireTimetableFactMapping(source: odptFactory, label: "ODPT")

        let jrEastLegacy = SourceProvenance.legacy(
            dataSource: "JR East official timetable, Jun 2026 JR JIKOKUHYO",
            providerID: "shinkansen",
            providerName: "JR East"
        )
        try require(
            jrEastLegacy.sourceKind == .officialTimetable,
            "Legacy JR East dataSource did not map to official timetable."
        )

        let jrEastFactory = SourceProvenance.jrEastTimetable(
            sourceName: "JR East official timetable, Jun 2026 JR JIKOKUHYO",
            sourceURL: URL(string: "https://timetables.jreast.co.jp/en/")
        )
        try require(
            jrEastFactory.sourceKind == .officialTimetable && jrEastFactory.confidence == .confirmed,
            "JR East factory did not produce confirmed official timetable provenance."
        )
        try require(
            jrEastFactory.summaryText.localizedCaseInsensitiveContains("Scheduled timetable"),
            "JR East summary copy should use scheduled timetable wording."
        )
        try requireTimetableFactMapping(source: jrEastFactory, label: "JR East")

        let predictionSource = SourceProvenance(
            providerID: "gtfs-rt",
            providerName: "GTFS-RT test provider",
            sourceName: "Trip updates",
            sourceKind: .realtimePrediction,
            confidence: .estimated,
            freshness: .fresh,
            licenseName: "Test license",
            attributionText: "GTFS-RT trip updates"
        )
        try require(
            predictionSource.sourceKind.compactTitle == "Prediction" &&
                predictionSource.riderExplanation.localizedCaseInsensitiveContains("prediction"),
            "Realtime trip-update copy should use prediction wording."
        )

        let vehiclePositionSource = SourceProvenance(
            providerID: "vehicle-test",
            providerName: "Vehicle test provider",
            sourceName: "Vehicle positions",
            sourceKind: .vehiclePosition,
            confidence: .confirmed,
            freshness: .fresh
        )
        try require(
            vehiclePositionSource.sourceKind.riderTitle == "Vehicle position" &&
                vehiclePositionSource.riderExplanation.localizedCaseInsensitiveContains("actual vehicle position"),
            "Vehicle-position copy should be reserved for actual position feeds."
        )

        let staleSavedSource = SourceProvenance(
            providerID: "saved",
            providerName: "Saved trip",
            sourceName: "Legacy saved source",
            sourceKind: .inferred,
            confidence: .unknown,
            freshness: .stale
        )
        try require(
            staleSavedSource.riderExplanation.localizedCaseInsensitiveContains("stale saved data"),
            "Stale saved trip copy should warn the rider."
        )

        try require(
            SourceProvenance.providerUnavailableText(message: "quota reached").localizedCaseInsensitiveContains("source provider unavailable"),
            "Provider unavailable copy should be explicit."
        )

        let encoded = try JSONEncoder().encode(starterTrip)
        let roundTripped = try JSONDecoder().decode(TrainTrip.self, from: encoded)
        try require(
            roundTripped.sourceProvenance.sourceKind == starterTrip.sourceProvenance.sourceKind,
            "Encoded source provenance did not round-trip."
        )
        try require(
            roundTripped.factProvenance.contains { $0.fact == .vehiclePosition && $0.confidence == .inferred },
            "Encoded fact provenance did not round-trip."
        )

        print("Source provenance smoke passed: source labels, user-safe copy, license copy, legacy dataSource, ODPT, JR East, and mixed fact labels are mapped.")
    }

    private static func legacyPayloadWithoutNewSourceFields(from trip: TrainTrip) throws -> Data {
        let encoded = try JSONEncoder().encode(trip)
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            throw SourceProvenanceSmokeError.failed("Could not create legacy TrainTrip JSON.")
        }
        object.removeValue(forKey: "sourceProvenance")
        object.removeValue(forKey: "factProvenance")
        return try JSONSerialization.data(withJSONObject: object)
    }

    private static func requireFact(
        _ trip: TrainTrip,
        _ factKind: RailFactKind,
        confidence: ConfidenceLevel,
        sourceKind: SourceKind,
        _ message: String
    ) throws {
        let fact = trip.factProvenance.first { $0.fact == factKind }
        try require(
            fact?.confidence == confidence && fact?.sourceKind == sourceKind,
            message
        )
    }

    private static func requireTimetableFactMapping(source: SourceProvenance, label: String) throws {
        let facts = FactProvenance.timetableFacts(source: source)
        try require(
            facts.contains { $0.fact == .schedule && $0.confidence == .confirmed && $0.sourceKind == .officialTimetable },
            "\(label) timetable schedule should be confirmed official timetable."
        )
        try require(
            facts.contains { $0.fact == .platform && $0.confidence == .confirmed && $0.sourceKind == .officialTimetable },
            "\(label) timetable platform should be confirmed official timetable when supplied."
        )
        try require(
            !facts.contains { $0.fact == .route && $0.confidence == .confirmed },
            "\(label) timetable route label should not be marked as a confirmed timetable fact."
        )
        try require(
            facts.contains { $0.fact == .speed && $0.confidence == .unknown },
            "\(label) timetable speed should not be marked as live."
        )
        try require(
            facts.contains { $0.fact == .vehiclePosition && $0.confidence == .inferred && $0.sourceKind == .inferred },
            "\(label) timetable map marker should be inferred."
        )
        try require(
            facts.contains { $0.fact == .carriageCue && $0.confidence == .inferred && $0.sourceKind == .inferred },
            "\(label) timetable car cue should be inferred."
        )
        try require(
            facts.contains { $0.fact == .seatCue && $0.confidence == .inferred && $0.sourceKind == .inferred },
            "\(label) timetable seat cue should be inferred."
        )
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else {
            throw SourceProvenanceSmokeError.failed(message)
        }
    }
}
