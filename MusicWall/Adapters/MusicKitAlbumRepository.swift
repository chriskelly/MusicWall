import Foundation
import MusicKit

struct MusicKitAlbumRepository: AlbumRepository, Sendable {
    func search(query: String, source: AlbumSearchSource) async throws -> [AlbumRecord] {
        guard !query.isEmpty else { throw AlbumRepositoryError.invalidQuery }
        do {
            let albums: [MusicKit.Album]
            switch source {
            case .catalog:
                let request = MusicCatalogSearchRequest(term: query, types: [MusicKit.Album.self])
                albums = Array(try await request.response().albums)
            case .library:
                let request = MusicLibrarySearchRequest(term: query, types: [MusicKit.Album.self])
                albums = Array(try await request.response().albums)
            }
            return albums.map(AlbumMapper.record(from:))
        } catch {
            throw AlbumRepositoryError.searchFailed(error.localizedDescription)
        }
    }

    func fetch(ids: [AlbumID]) async throws -> [AlbumRecord] {
        guard !ids.isEmpty else { return [] }
        let albums = try await fetchMusicKitAlbums(ids: ids)
        return albums.map(AlbumMapper.record(from:))
    }

    func artworkURL(for id: AlbumID, width: Int, height: Int) async -> URL? {
        guard let album = try? await musicKitAlbum(for: id) else { return nil }
        return album.artwork?.url(width: width, height: height)
    }

    func musicKitAlbum(for id: AlbumID) async throws -> MusicKit.Album {
        let albums = try await fetchMusicKitAlbums(ids: [id])
        guard let album = albums.first else { throw AlbumRepositoryError.albumNotFound }
        return album
    }

    private func fetchMusicKitAlbums(ids: [AlbumID]) async throws -> [MusicKit.Album] {
        do {
            let musicItemIDs = ids.map { MusicItemID($0.rawValue) }
            var libraryRequest = MusicLibraryRequest<MusicKit.Album>()
            libraryRequest.filter(matching: \.id, memberOf: musicItemIDs)
            let libraryAlbums = Array(try await libraryRequest.response().items)
            if !libraryAlbums.isEmpty { return libraryAlbums }

            let catalogRequest = MusicCatalogResourceRequest<MusicKit.Album>(
                matching: \.id,
                memberOf: musicItemIDs
            )
            let catalogAlbums = Array(try await catalogRequest.response().items)
            if catalogAlbums.isEmpty { throw AlbumRepositoryError.albumNotFound }
            return catalogAlbums
        } catch let error as AlbumRepositoryError {
            throw error
        } catch {
            throw AlbumRepositoryError.networkError(error.localizedDescription)
        }
    }
}
