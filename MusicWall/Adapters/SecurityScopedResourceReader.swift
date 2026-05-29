import Foundation

struct SecurityScopedResourceReader: SecurityScopedReader {
    func readData(from url: URL) throws -> Data {
        guard url.startAccessingSecurityScopedResource() else {
            throw BackupError.fileAccessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            return try Data(contentsOf: url)
        } catch {
            throw BackupError.fileReadFailed(error.localizedDescription)
        }
    }
}
