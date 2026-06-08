import Foundation

struct FileExportService {
    func write(_ data: Data) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MusicWall_Backup_\(Date().timeIntervalSince1970).json")
        try data.write(to: tempURL)
        return tempURL
    }
}
