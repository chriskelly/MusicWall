import Foundation
import Testing
@testable import MusicWall

@Suite struct ImageCacheTests {
    private func makeTempCacheDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func cacheHitReturnsLocalURLWithoutCallingProviderOrSession() async throws {
        let cacheDir = try makeTempCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }

        let albumID = "album-1"
        let size = 100
        let cachedFile = cacheDir.appendingPathComponent("\(albumID)_\(size).jpg")
        try Data([0xFF, 0xD8, 0xFF]).write(to: cachedFile)

        let provider = MockArtworkProvider()
        let session = MockURLSession()
        let cache = ImageCache(
            artworkProvider: provider,
            session: session,
            fileManager: .default,
            cacheDirectory: cacheDir
        )

        let result = await cache.getArtwork(albumID: albumID, size: size)

        #expect(result == cachedFile)
        #expect(provider.artworkURLCalls.isEmpty)
        #expect(session.dataCalls.isEmpty)
    }

    @Test func cacheMissDownloadsAndWritesFile() async throws {
        let cacheDir = try makeTempCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }

        let remoteURL = URL(string: "https://example.com/art.jpg")!
        let provider = MockArtworkProvider()
        provider.artworkURLHandler = { _, width, height in
            #expect(width == 100)
            #expect(height == 100)
            return remoteURL
        }
        let session = MockURLSession()
        session.dataHandler = { url in
            #expect(url == remoteURL)
            return (Data([0xFF, 0xD8, 0xFF]), URLResponse())
        }

        let cache = ImageCache(
            artworkProvider: provider,
            session: session,
            fileManager: .default,
            cacheDirectory: cacheDir
        )

        let result = await cache.getArtwork(albumID: "album-2", size: 100)

        let expectedLocal = cacheDir.appendingPathComponent("album-2_100.jpg")
        #expect(result == expectedLocal)
        #expect(FileManager.default.fileExists(atPath: expectedLocal.path))
        #expect(provider.artworkURLCalls.count == 1)
        #expect(session.dataCalls == [remoteURL])
    }

    @Test func downloadFailureReturnsRemoteURL() async throws {
        let cacheDir = try makeTempCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDir) }

        let remoteURL = URL(string: "https://example.com/art.jpg")!
        let provider = MockArtworkProvider()
        provider.artworkURLHandler = { _, _, _ in remoteURL }
        let session = MockURLSession()
        session.dataHandler = { _ in throw URLError(.notConnectedToInternet) }

        let cache = ImageCache(
            artworkProvider: provider,
            session: session,
            fileManager: .default,
            cacheDirectory: cacheDir
        )

        let result = await cache.getArtwork(albumID: "album-3", size: 100)

        #expect(result == remoteURL)
        let localFile = cacheDir.appendingPathComponent("album-3_100.jpg")
        #expect(FileManager.default.fileExists(atPath: localFile.path) == false)
    }
}
