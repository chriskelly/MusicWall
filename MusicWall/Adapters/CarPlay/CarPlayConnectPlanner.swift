import Foundation

enum CarPlayRootScreen: Equatable {
    case setupRequired
    case albumGrid(pages: [[AlbumRecord]])
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
        let pages = CarPlayAlbumPaginator.pages(from: albums)
        return .albumGrid(pages: pages)
    }
}
