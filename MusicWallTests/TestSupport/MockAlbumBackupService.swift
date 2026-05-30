import Foundation
@testable import MusicWall

final class MockAlbumBackupService: AlbumBackupService, @unchecked Sendable {
    var exportHandler: ([String]) throws -> URL = { _ in
        URL(fileURLWithPath: "/tmp/export.json")
    }
    var importHandler: (URL) throws -> [String] = { _ in [] }

    private(set) var exportCalls: [[String]] = []
    private(set) var importCalls: [URL] = []

    func exportAlbumIDs(_ ids: [String]) throws -> URL {
        exportCalls.append(ids)
        return try exportHandler(ids)
    }

    func importAlbumIDs(from url: URL) throws -> [String] {
        importCalls.append(url)
        return try importHandler(url)
    }
}
