import Foundation
import Testing
@testable import MusicWall

struct LiveAlbumBackupServiceTests {
    private struct DenyingReader: SecurityScopedReader {
        func readData(from url: URL) throws -> Data {
            throw BackupError.fileAccessDenied
        }
    }

    @Test
    func exportEmptyIDsThrowsEmptyExport() {
        let service = LiveAlbumBackupService(reader: DirectFileReader())
        #expect(throws: BackupError.emptyExport) {
            _ = try service.exportAlbumIDs([])
        }
    }

    @Test
    func exportImportRoundTrip() throws {
        let service = LiveAlbumBackupService(reader: DirectFileReader())
        let ids = ["id-a", "id-b"]
        let url = try service.exportAlbumIDs(ids)
        defer { try? FileManager.default.removeItem(at: url) }

        let imported = try service.importAlbumIDs(from: url)
        #expect(imported == ids)
    }

    @Test
    func importPropagatesFileAccessDenied() {
        let service = LiveAlbumBackupService(reader: DenyingReader())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("unused-\(UUID().uuidString).json")

        #expect(throws: BackupError.fileAccessDenied) {
            _ = try service.importAlbumIDs(from: url)
        }
    }
}
