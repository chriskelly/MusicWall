import Foundation
@testable import MusicWall

struct DirectFileReader: SecurityScopedReader {
    func readData(from url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            throw BackupError.fileReadFailed(error.localizedDescription)
        }
    }
}
