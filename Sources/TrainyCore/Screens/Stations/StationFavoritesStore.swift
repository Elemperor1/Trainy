import Combine
import Foundation

/// A station the rider starred, stored with everything needed to open its board
/// without searching for it again.
struct FavoriteStation: Codable, Hashable, Identifiable, Sendable {
    let providerID: String
    let code: String
    let name: String
    let shortName: String?
    let countryCode: String?
    let latitude: Double?
    let longitude: Double?

    var id: String { "\(providerID):\(code)" }

    init(_ station: ProviderStation) {
        providerID = station.providerID
        code = station.code
        name = station.name
        shortName = station.shortName
        countryCode = station.countryCode
        latitude = station.latitude
        longitude = station.longitude
    }

    var station: ProviderStation {
        ProviderStation(
            providerID: providerID,
            code: code,
            name: name,
            shortName: shortName,
            countryCode: countryCode,
            latitude: latitude,
            longitude: longitude
        )
    }
}

/// The riders' starred stations across every provider, saved on the device.
///
/// Favorites are plain user preferences, so they live in `UserDefaults` as one
/// JSON list under `trainy.stationFavorites`. When the saved-places model from
/// the engineering plan lands (items 1.4 and 4.1), that work migrates this key;
/// the payload is versioned only by its shape, which `FavoriteStation` keeps
/// additive.
@MainActor
final class StationFavoritesStore: ObservableObject {
    static let storageKey = "trainy.stationFavorites"
    /// An unreadable payload is copied here before it can be overwritten.
    static let undecodableStorageKey = "trainy.stationFavorites.undecodable"

    @Published private(set) var stations: [FavoriteStation]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        stations = Self.load(from: defaults)
    }

    func isFavorite(_ station: ProviderStation) -> Bool {
        stations.contains { $0.id == station.id }
    }

    /// Stars the station, or removes the star if it is already there.
    func toggle(_ station: ProviderStation) {
        if let index = stations.firstIndex(where: { $0.id == station.id }) {
            stations.remove(at: index)
        } else {
            stations.append(FavoriteStation(station))
        }
        persist()
    }

    /// The favorites that belong to one provider, in name order.
    func favorites(for providerID: String) -> [FavoriteStation] {
        stations
            .filter { $0.providerID == providerID }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(stations) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [FavoriteStation] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        do {
            return try JSONDecoder().decode([FavoriteStation].self, from: data)
        } catch {
            defaults.set(data, forKey: undecodableStorageKey)
            return []
        }
    }
}
