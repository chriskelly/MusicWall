import Foundation

enum BackupError: Error, LocalizedError, Equatable {
    case emptyExport
    case emptyImport
    case fileAccessDenied
    case fileReadFailed(String)
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .emptyExport:
            return "No albums to export"
        case .emptyImport:
            return "Import file contains no album IDs"
        case .fileAccessDenied:
            return "Could not access file"
        case .fileReadFailed(let message):
            return "Failed to read file: \(message)"
        case .invalidFormat:
            return "Invalid file format"
        }
    }
}
