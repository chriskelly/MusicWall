import Foundation

struct LiveAlbumBackupService: AlbumBackupService {
    private let codec: BackupCodec
    private let exportService: FileExportService
    private let reader: any SecurityScopedReader

    init(
        codec: BackupCodec = BackupCodec(),
        exportService: FileExportService = FileExportService(),
        reader: any SecurityScopedReader = SecurityScopedResourceReader()
    ) {
        self.codec = codec
        self.exportService = exportService
        self.reader = reader
    }

    func exportAlbumIDs(_ ids: [String]) throws -> URL {
        guard !ids.isEmpty else {
            throw BackupError.emptyExport
        }
        let data = try codec.encode(ids)
        return try exportService.write(data)
    }

    func importAlbumIDs(from url: URL) throws -> [String] {
        let data = try reader.readData(from: url)
        return try codec.decode(data)
    }
}
