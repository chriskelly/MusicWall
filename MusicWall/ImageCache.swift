//
//  ImageCache.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/29/25.
//

import Foundation

struct ImageCache {
    private let fileManager = FileManager.default
    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    /// Get cached artwork for an album ID and size, or fetch and cache it
    func getArtwork(albumID: String, size: Int) async -> URL? {
        let filename = "\(albumID)_\(size).jpg"
        let localURL = cacheDirectory.appendingPathComponent(filename)
        
        // If already cached, return the local URL
        if fileManager.fileExists(atPath: localURL.path) {
            return localURL
        }
        
        // Fetch the album and get the artwork URL
        guard let albums = try? await fetchAlbums(ids: [albumID]),
              let album = albums.first,
              let artworkURL = album.artwork?.url(width: size, height: size) else {
            return nil
        }
        
        // Download and cache the image
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
