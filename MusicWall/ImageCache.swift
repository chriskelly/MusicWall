//
//  ImageCache.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/29/25.
//

import Foundation

struct ImageCache {
    private let repository: any AlbumRepository
    private let fileManager = FileManager.default

    init(repository: any AlbumRepository) {
        self.repository = repository
    }

    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    /// Get cached artwork for an album ID and size, or fetch and cache it
    func getArtwork(albumID: String, size: Int) async -> URL? {
        let filename = "\(albumID)_\(size).jpg"
        let localURL = cacheDirectory.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: localURL.path) {
            return localURL
        }

        let id = AlbumID(rawValue: albumID)
        guard let artworkURL = await repository.artworkURL(for: id, width: size, height: size) else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: artworkURL)
            try data.write(to: localURL)
            return localURL
        } catch {
            print("Failed to cache artwork: \(error)")
            return artworkURL
        }
    }
}
