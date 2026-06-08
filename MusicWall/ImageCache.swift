//
//  ImageCache.swift
//  MusicWall
//

import Foundation

// FileManager is not Sendable; cache reads/writes use a dedicated directory synchronously.
struct ImageCache: @unchecked Sendable {
    private let artworkProvider: any ArtworkProvider
    private let session: any URLSessionDataProviding
    private let fileManager: FileManager
    private let cacheDirectory: URL

    init(
        artworkProvider: any ArtworkProvider,
        session: any URLSessionDataProviding = URLSession.shared,
        fileManager: FileManager = .default,
        cacheDirectory: URL? = nil
    ) {
        self.artworkProvider = artworkProvider
        self.session = session
        self.fileManager = fileManager
        self.cacheDirectory = cacheDirectory
            ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    /// Get cached artwork for an album ID and size, or fetch and cache it
    func getArtwork(albumID: String, size: Int) async -> URL? {
        let filename = "\(albumID)_\(size).jpg"
        let localURL = cacheDirectory.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: localURL.path) {
            return localURL
        }

        let id = AlbumID(rawValue: albumID)
        guard let artworkURL = await artworkProvider.artworkURL(for: id, width: size, height: size) else {
            return nil
        }

        do {
            let (data, _) = try await session.data(from: artworkURL)
            try data.write(to: localURL)
            return localURL
        } catch {
            print("Failed to cache artwork: \(error)")
            return artworkURL
        }
    }
}
