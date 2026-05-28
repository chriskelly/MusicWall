import Foundation
@testable import MusicWall

final class MockPlaybackController: PlaybackController, @unchecked Sendable {
    private(set) var playCalls: [AlbumID] = []
    private(set) var pauseCallCount = 0
    var playHandler: ((AlbumID) async throws -> Void)?

    func play(albumId: AlbumID) async throws {
        playCalls.append(albumId)
        if let playHandler { try await playHandler(albumId) }
    }

    func pause() {
        pauseCallCount += 1
    }
}
