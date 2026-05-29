import Foundation

struct PreviewMusicAuthorizationProvider: MusicAuthorizationProviding {
    var authorizationStatus: MusicAuthorizationStatus
    var requestResult: MusicAuthorizationStatus?

    init(status: MusicAuthorizationStatus, requestResult: MusicAuthorizationStatus? = nil) {
        self.authorizationStatus = status
        self.requestResult = requestResult
    }

    func requestAuthorization() async -> MusicAuthorizationStatus {
        requestResult ?? authorizationStatus
    }
}
