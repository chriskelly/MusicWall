import Foundation

protocol AlbumBackupService: Sendable {
    func exportAlbums(_ albums: [AlbumRecord]) throws -> URL
    func importBackup(from url: URL) throws -> BackupContents
}
