//
//  MusicService.swift
//  MusicWall
//
//  Created by Chris Kelly on 10/22/25.
//

import MusicKit
import Foundation


enum MusicService {
    static func searchAlbums(query: String) async throws -> [Album] {
        guard !query.isEmpty else {
            throw MusicServiceError.invalidQuery
        }
        do {
            let request = MusicCatalogSearchRequest(term: query, types: [Album.self])
            let response = try await request.response()
            return Array(response.albums)
        } catch {
            throw MusicServiceError.searchFailed(error.localizedDescription)
        }
    }
    
    static func fetchAlbums(ids: [String]) async throws -> [Album] {
        guard !ids.isEmpty else {return []}
        do {
            let musicItemIDs = ids.map { MusicItemID($0) }
            let request = MusicCatalogResourceRequest<Album>(matching: \.id, memberOf: musicItemIDs)
            let response = try await request.response()
            return Array(response.items)
        } catch {
            throw MusicServiceError.networkError(error.localizedDescription)
        }
    }
    
    static func playAlbum(id: MusicItemID) async throws {
        do {
            let request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: id)
            let response = try await request.response()
            
            guard let album = response.items.first else {
                throw MusicServiceError.albumNotFound
            }
            
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
