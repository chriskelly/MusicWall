import Testing
@testable import MusicWall

struct DomainErrorTests {
    @Test
    func backupErrorDescriptions() {
        #expect(BackupError.emptyExport.errorDescription == "No albums to export")
        #expect(BackupError.emptyImport.errorDescription == "Import file contains no album IDs")
        #expect(BackupError.fileAccessDenied.errorDescription == "Could not access file")
        #expect(BackupError.fileReadFailed("disk").errorDescription == "Failed to read file: disk")
        #expect(BackupError.invalidFormat.errorDescription == "Invalid file format")
    }

    @Test
    func playbackErrorDescriptions() {
        #expect(PlaybackError.albumNotFound.errorDescription == "Album not found")
        #expect(PlaybackError.playbackFailed("timeout").errorDescription == "Playback failed: timeout")
    }

    @Test
    func albumRepositoryErrorDescriptions() {
        #expect(AlbumRepositoryError.invalidQuery.errorDescription == "Search query cannot be empty")
        #expect(AlbumRepositoryError.albumNotFound.errorDescription == "Album not found")
        #expect(AlbumRepositoryError.searchFailed("x").errorDescription == "Search failed: x")
        #expect(AlbumRepositoryError.networkError("offline").errorDescription == "Network error: offline")
    }
}
