import Foundation

protocol AlbumBackupService: Sendable {
    func exportAlbumIDs(_ ids: [String]) throws -> URL
    func importAlbumIDs(from url: URL) throws -> [String]
}
