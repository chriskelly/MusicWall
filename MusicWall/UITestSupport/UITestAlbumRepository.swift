import Foundation

struct UITestAlbumRepository: AlbumRepository, Sendable {
    func search(query: String, source: AlbumSearchSource) async throws -> [AlbumRecord] {
        []
    }

    func fetch(ids: [AlbumID]) async throws -> [AlbumRecord] {
        let requested = Set(ids.map(\.rawValue))
        return UITestFixtures.baseTrio.filter { requested.contains($0.id.rawValue) }
    }
}
