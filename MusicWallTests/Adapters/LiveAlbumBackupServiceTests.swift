import Foundation
import Testing
@testable import MusicWall

struct LiveAlbumBackupServiceTests {
    private struct DenyingReader: SecurityScopedReader {
        func readData(from url: URL) throws -> Data {
            throw BackupError.fileAccessDenied
        }
    }

    private var sampleRecords: [AlbumRecord] {
        [
            AlbumFixtures.record(id: "id-a", title: "Album A", artistName: "Artist A"),
            AlbumFixtures.record(id: "id-b", title: "Album B", artistName: "Artist B"),
        ]
    }

    @Test
    func exportEmptyAlbumsThrowsEmptyExport() {
        let service = LiveAlbumBackupService(reader: DirectFileReader())
        #expect(throws: BackupError.emptyExport) {
            _ = try service.exportAlbums([])
        }
    }

    @Test
    func exportImportV2RoundTrip() throws {
        let service = LiveAlbumBackupService(reader: DirectFileReader())
        let records = sampleRecords
        let url = try service.exportAlbums(records)
        defer { try? FileManager.default.removeItem(at: url) }

        let imported = try service.importBackup(from: url)
        #expect(imported == .records(records))
    }

    @Test
    func importLegacyIDsRoundTrip() throws {
        let legacyData = Data(#"["legacy-a","legacy-b"]"#.utf8)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("legacy-\(UUID().uuidString).json")
        try legacyData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let service = LiveAlbumBackupService(reader: DirectFileReader())
        let imported = try service.importBackup(from: tempURL)
        #expect(imported == .ids(["legacy-a", "legacy-b"]))
    }

    @Test
    func importPropagatesFileAccessDenied() {
        let service = LiveAlbumBackupService(reader: DenyingReader())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("unused-\(UUID().uuidString).json")

        #expect(throws: BackupError.fileAccessDenied) {
            _ = try service.importBackup(from: url)
        }
    }
}
