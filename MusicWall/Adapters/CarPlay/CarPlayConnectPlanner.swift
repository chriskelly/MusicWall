import Foundation

enum CarPlayRootScreen: Equatable {
    case setupRequired
    case albumLibrary(albums: [AlbumRecord])
}

enum CarPlayConnectPlanner {
    static func rootScreen(
        authorizationStatus: MusicAuthorizationStatus,
        albums: [AlbumRecord]
    ) -> CarPlayRootScreen {
        guard authorizationStatus == .authorized else {
            return .setupRequired
        }
        guard !albums.isEmpty else {
            return .setupRequired
        }
        return .albumLibrary(albums: albums)
    }
}
