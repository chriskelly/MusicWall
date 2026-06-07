import Foundation

struct FileExportService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func write(_ data: Data) throws -> URL {
        let tempURL = fileManager.temporaryDirectory
            .appendingPathComponent("MusicWall_Backup_\(Date().timeIntervalSince1970).json")
        try data.write(to: tempURL)
        return tempURL
    }
}
