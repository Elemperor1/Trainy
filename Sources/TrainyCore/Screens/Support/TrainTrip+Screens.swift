import MapKit
import SwiftUI

extension TrainTrip {
    var shareText: String {
        let formattedETA = eta.formattedAsTime(
            in: destination.timeZone,
            format: UserPreferences.shared.timeFormat
        )
        return "\(train): \(origin.name) to \(destination.name), \(status), platform \(displayPlatform), ETA \(formattedETA). Source: \(sourceProvenance.sourceKind.riderTitle), \(sourceProvenance.freshness.displayName)."
    }

    var transferSummary: String {
        let transferStops = stops.filter { $0.note.localizedCaseInsensitiveContains("handoff") || $0.note.localizedCaseInsensitiveContains("transfer") }
        return transferStops.isEmpty ? "Direct" : "\(transferStops.count) transfer cue\(transferStops.count == 1 ? "" : "s")"
    }

    var transferWarningCopy: LocalizedStringKey {
        if statusTone == .good {
            return "No urgent transfer warning is attached to this trip. Recheck platform and stop notes before changing trains."
        }
        return "This service has an alert. Leave extra time for the next platform, route change, or operator handoff."
    }

    var durationMinutes: Int {
        var total = 0
        let pieces = duration.split(separator: " ")
        for piece in pieces {
            if piece.hasSuffix("h"), let hours = Int(piece.dropLast()) {
                total += hours * 60
            } else if piece.hasSuffix("m"), let minutes = Int(piece.dropLast()) {
                total += minutes
            }
        }
        return total
    }

    var vehicleCoordinate: CLLocationCoordinate2D? {
        guard let latitude = vehicleLatitude, let longitude = vehicleLongitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var previewRegion: MKCoordinateRegion {
        let coordinates = ([origin.coordinate, destination.coordinate, vehicleCoordinate] + stops.map { stop in
            if stop.name == origin.name {
                return origin.coordinate
            }
            if stop.name == destination.name {
                return destination.coordinate
            }
            return nil
        })
        .compactMap { $0 }

        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
                span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
            )
        }

        let minLatitude = coordinates.map(\.latitude).min() ?? 35.6812
        let maxLatitude = coordinates.map(\.latitude).max() ?? 35.6812
        let minLongitude = coordinates.map(\.longitude).min() ?? 139.7671
        let maxLongitude = coordinates.map(\.longitude).max() ?? 139.7671

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.8, (maxLatitude - minLatitude) * 1.8),
                longitudeDelta: max(0.8, (maxLongitude - minLongitude) * 1.8)
            )
        )
    }
}

extension TrainTrip {
    var fromTo: String { "\(origin.name) → \(destination.name)" }
}

extension StationPoint {
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
