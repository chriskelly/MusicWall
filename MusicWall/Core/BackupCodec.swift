import Foundation

struct BackupCodec {
    func encode(_ ids: [String]) throws -> Data {
        do {
            return try JSONEncoder().encode(ids)
        } catch {
            throw BackupError.invalidFormat
        }
    }

    func decode(_ data: Data) throws -> [String] {
        let ids: [String]
        do {
            ids = try JSONDecoder().decode([String].self, from: data)
        } catch {
            throw BackupError.invalidFormat
        }
        guard !ids.isEmpty else {
            throw BackupError.emptyImport
        }
        return ids
    }
}
