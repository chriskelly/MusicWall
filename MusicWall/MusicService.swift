//
//  MusicService.swift
//  MusicWall
//
//  Created by Chris Kelly on 10/22/25.
//

import MusicKit
import Foundation

typealias MusicKitAlbum = MusicKit.Album

enum MusicService {
    enum Location {
        case catalog
        case library
    }
    
    static func searchAlbums(query: String, location: Location) async throws -> [MusicKitAlbum] {
        guard !query.isEmpty else {
            throw MusicServiceError.invalidQuery
        }
        do {
            switch location {
            case .catalog:
                let request = MusicCatalogSearchRequest(term: query, types: [MusicKitAlbum.self])
                let response = try await request.response()
                return Array(response.albums)
            case .library:
                let request = MusicLibrarySearchRequest(term: query, types: [MusicKitAlbum.self])
                let response = try await request.response()
                return Array(response.albums)
            }
        } catch {
            throw MusicServiceError.searchFailed(error.localizedDescription)
        }
    }
    
    static func fetchAlbums(ids: [String]) async throws -> [MusicKitAlbum] {
        guard !ids.isEmpty else {return []}
        do {
            let musicItemIDs = ids.map { MusicItemID($0) }
            var libraryRequest = MusicLibraryRequest<MusicKitAlbum>()
            libraryRequest.filter(matching: \.id, memberOf: musicItemIDs)
            let libraryResponse = try await libraryRequest.response()
            let libraryAlbums = Array(libraryResponse.items)
            if !libraryAlbums.isEmpty {
                return libraryAlbums
            }
            let catalogRequest = MusicCatalogResourceRequest<MusicKitAlbum>(matching: \.id, memberOf: musicItemIDs)
            let catalogResponse = try await catalogRequest.response()
            if catalogResponse.items.isEmpty {throw MusicServiceError.albumNotFound}
            return Array(catalogResponse.items)
        } catch {
            throw MusicServiceError.networkError(error.localizedDescription)
        }
    }
    
    static func playAlbum(id: MusicItemID) async throws {
        do {
            let album = try await fetchAlbums(ids: [id.rawValue]).first!
            let player = SystemMusicPlayer.shared
            player.queue = [album]
            try await player.play()
        } catch let error as MusicServiceError {
            throw error // Re-throw our custom errors
        } catch {
            throw MusicServiceError.playbackFailed(error.localizedDescription)
        }
    }
}

enum MusicServiceError: Error, LocalizedError {
    case albumNotFound
    case searchFailed(String)
    case playbackFailed(String)
    case invalidQuery
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .albumNotFound:
            return "Album not found"
        case .searchFailed(let message):
            return "Search failed: \(message)"
        case .playbackFailed(let message):
            return "Playback failed: \(message)"
        case .invalidQuery:
            return "Search query cannot be empty"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

