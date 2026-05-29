import Foundation
import MusicKit

struct LiveMusicAuthorizationProvider: MusicAuthorizationProviding {
    var authorizationStatus: MusicAuthorizationStatus {
        map(MusicAuthorization.currentStatus)
    }

    func requestAuthorization() async -> MusicAuthorizationStatus {
        map(await MusicAuthorization.request())
    }

    private func map(_ status: MusicAuthorization.Status) -> MusicAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unknown
        }
    }
}
