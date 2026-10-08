import Foundation

extension TrainStore {
    var offlineMessage: String? {
        if case .offline(let message) = liveLoadState {
            return message
        }
        return nil
    }
}
