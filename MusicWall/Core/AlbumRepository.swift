import Foundation

enum AlbumSearchSource: Sendable, Equatable {
    case catalog
    case library
}

enum AlbumRepositoryError: Error, LocalizedError, Equatable {
    case invalidQuery
    case albumNotFound
    case searchFailed(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Search query cannot be empty"
        case .albumNotFound:
            return "Album not found"
        case .searchFailed(let message):
            return "Search failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

protocol AlbumRepository: Sendable {
    func search(query: String, source: AlbumSearchSource) async throws -> [AlbumRecord]
    func fetch(ids: [AlbumID]) async throws -> [AlbumRecord]
    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL?
}
