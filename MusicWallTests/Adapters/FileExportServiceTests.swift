import Foundation
import Testing
@testable import MusicWall

struct FileExportServiceTests {
    @Test
    func writeCreatesFileWithPayload() throws {
        let service = FileExportService()
        let payload = Data("[\"a\"]".utf8)
        let url = try service.write(payload)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.pathExtension == "json")
        #expect(url.lastPathComponent.hasPrefix("MusicWall_AlbumIDs_"))
        #expect(try Data(contentsOf: url) == payload)
    }
}
