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

    func exportAlbums(_ albums: [AlbumRecord]) throws -> URL {
        guard !albums.isEmpty else {
            throw BackupError.emptyExport
        }
        let data = try codec.encode(albums)
        return try exportService.write(data)
    }

    func importBackup(from url: URL) throws -> BackupContents {
        let data = try reader.readData(from: url)
        return try codec.decode(data)
    }
}
