import Foundation
@testable import MusicWall

final class MockAlbumBackupService: AlbumBackupService, @unchecked Sendable {
    var exportHandler: ([AlbumRecord]) throws -> URL = { _ in
        URL(fileURLWithPath: "/tmp/export.json")
    }
    var importHandler: (URL) throws -> BackupContents = { _ in .ids([]) }

    private(set) var exportCalls: [[AlbumRecord]] = []
    private(set) var importCalls: [URL] = []

    func exportAlbums(_ albums: [AlbumRecord]) throws -> URL {
        exportCalls.append(albums)
        return try exportHandler(albums)
    }

    func importBackup(from url: URL) throws -> BackupContents {
        importCalls.append(url)
        return try importHandler(url)
    }
}
