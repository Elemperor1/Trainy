import SwiftUI

enum TripBucket: String, CaseIterable, Identifiable {
    case upcoming
    case active
    case past

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .upcoming:
            return "Upcoming"
        case .active:
            return "Active"
        case .past:
            return "Past"
        }
    }

    var sectionTitle: LocalizedStringKey {
        switch self {
        case .upcoming:
            return "Ready to Depart"
        case .active:
            return "Current Journeys"
        case .past:
            return "Completed Journeys"
        }
    }

    var emptyTitle: LocalizedStringKey {
        switch self {
        case .upcoming:
            return "No upcoming trips"
        case .active:
            return "No active trips"
        case .past:
            return "No completed trips"
        }
    }

    var emptyMessage: LocalizedStringKey {
        switch self {
        case .upcoming:
            return "Saved departures appear here before they leave the origin station."
        case .active:
            return "Journeys in motion show progress, the next stop, platforms, and transfer cautions."
        case .past:
            return "Completed journeys will move into history once arrival data is available."
        }
    }

    var emptySymbol: String {
        switch self {
        case .upcoming:
            return "calendar.badge.clock"
        case .active:
            return "tram"
        case .past:
            return "clock.arrow.circlepath"
        }
    }

    var cardRole: TrainTripCard.Role {
        switch self {
        case .upcoming:
            return .upcoming
        case .active:
            return .active
        case .past:
            return .past
        }
    }
}
