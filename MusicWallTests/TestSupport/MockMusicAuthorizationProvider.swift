import Foundation
@testable import MusicWall

final class MockMusicAuthorizationProvider: MusicAuthorizationProviding, @unchecked Sendable {
    var authorizationStatus: MusicAuthorizationStatus
    var requestHandler: (() async -> MusicAuthorizationStatus)?
    private(set) var requestCallCount = 0

    init(authorizationStatus: MusicAuthorizationStatus = .notDetermined) {
        self.authorizationStatus = authorizationStatus
    }

    func requestAuthorization() async -> MusicAuthorizationStatus {
        requestCallCount += 1
        if let requestHandler {
            return await requestHandler()
        }
        return authorizationStatus
    }
}
