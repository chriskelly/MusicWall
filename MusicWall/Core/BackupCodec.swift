import Foundation

struct BackupCodec {
    private struct BackupEnvelope: Codable {
        let version: Int
        let albums: [AlbumRecord]
    }

    private static let currentVersion = 2

    func encode(_ albums: [AlbumRecord]) throws -> Data {
        let envelope = BackupEnvelope(version: Self.currentVersion, albums: albums)
        do {
            return try JSONEncoder().encode(envelope)
        } catch {
            throw BackupError.invalidFormat
        }
    }

    func decode(_ data: Data) throws -> BackupContents {
        if let envelope = try? JSONDecoder().decode(BackupEnvelope.self, from: data) {
            guard envelope.version == Self.currentVersion else {
                throw BackupError.invalidFormat
            }
            guard !envelope.albums.isEmpty else {
                throw BackupError.emptyImport
            }
            return .records(envelope.albums)
        }

        let ids: [String]
        do {
            ids = try JSONDecoder().decode([String].self, from: data)
        } catch {
            throw BackupError.invalidFormat
        }
        guard !ids.isEmpty else {
            throw BackupError.emptyImport
        }
        return .ids(ids)
    }
}
