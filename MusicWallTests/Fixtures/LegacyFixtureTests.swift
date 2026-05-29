import Foundation
import MusicKit
import Testing
@testable import MusicWall

struct LegacyFixtureTests {
    @Test
    func legacyFixtureJSON() throws {
        let data = try Self.sampleLegacyFixtureData()
        #expect(!data.isEmpty)
    }

    static func sampleLegacyFixtureData() throws -> Data {
        let legacy = [
            LegacyStoredAlbum(
                id: MusicItemID("golden-album-1"),
                title: "Take Care",
                artistName: "Drake",
                releaseDate: nil
            ),
            LegacyStoredAlbum(
                id: MusicItemID("golden-album-2"),
                title: "Edited Title",
                artistName: "Local Artist",
                releaseDate: Date(timeIntervalSince1970: 1_300_000_000)
            ),
        ]
        return try JSONEncoder().encode(legacy)
    }

    @Test
    func legacyFixtureDecodes() throws {
        let data = try Self.sampleLegacyFixtureData()
        let legacy = try JSONDecoder().decode([LegacyStoredAlbum].self, from: data)
        #expect(legacy.count == 2)
        #expect(legacy[0].id.rawValue == "golden-album-1")
        #expect(legacy[1].title == "Edited Title")
    }

    @Test
    func bundledLegacyFixtureMatchesSampleEncoding() throws {
        let sample = try Self.sampleLegacyFixtureData()
        let url = try #require(
            Bundle(for: BundleToken.self).url(
                forResource: "legacy_stored_albums_v1",
                withExtension: "json"
            )
        )
        let bundled = try Data(contentsOf: url)
        let bundledRecords = try JSONDecoder().decode([LegacyStoredAlbum].self, from: bundled)
        let sampleRecords = try JSONDecoder().decode([LegacyStoredAlbum].self, from: sample)
        #expect(bundledRecords.map { $0.asAlbumRecord() } == sampleRecords.map { $0.asAlbumRecord() })
    }
}

private final class BundleToken {}
