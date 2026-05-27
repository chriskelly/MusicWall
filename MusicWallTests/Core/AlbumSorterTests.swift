import Foundation
import Testing
@testable import MusicWall

struct AlbumSorterTests {
    private func sortedIDs(
        _ albums: [AlbumRecord],
        key: AlbumSortKey,
        ascending: Bool
    ) -> [String] {
        AlbumSorter.sorted(albums, key: key, ascending: ascending).map(\.id.rawValue)
    }

    @Test(arguments: [
        (AlbumSortKey.artist, true, ["fixture-drake", "fixture-cole", "fixture-kendrick"]),
        (AlbumSortKey.artist, false, ["fixture-kendrick", "fixture-cole", "fixture-drake"]),
        (AlbumSortKey.title, true, ["fixture-cole", "fixture-kendrick", "fixture-drake"]),
        (AlbumSortKey.title, false, ["fixture-drake", "fixture-kendrick", "fixture-cole"]),
        (AlbumSortKey.year, true, ["fixture-drake", "fixture-kendrick", "fixture-cole"]),
        (AlbumSortKey.year, false, ["fixture-kendrick", "fixture-drake", "fixture-cole"]),
    ])
    func goldenSortOrder(key: AlbumSortKey, ascending: Bool, expectedIDs: [String]) {
        let result = sortedIDs(AlbumFixtures.baseTrio, key: key, ascending: ascending)
        #expect(result == expectedIDs)
    }

    @Test
    func artistSortIsCaseInsensitive() {
        let albums = [
            AlbumFixtures.record(id: "lower", title: "x", artistName: "beta"),
            AlbumFixtures.record(id: "upper", title: "y", artistName: "ALPHA"),
        ]
        let ascending = sortedIDs(albums, key: .artist, ascending: true)
        #expect(ascending == ["upper", "lower"])
        let descending = sortedIDs(albums, key: .artist, ascending: false)
        #expect(descending == ["lower", "upper"])
    }

    @Test
    func titleSortIsCaseInsensitive() {
        let albums = [
            AlbumFixtures.record(id: "lower", title: "hello", artistName: "A"),
            AlbumFixtures.record(id: "upper", title: "HELLO", artistName: "B"),
        ]
        let ascending = sortedIDs(albums, key: .title, ascending: true)
        #expect(ascending == ["lower", "upper"])
    }

    @Test
    func nilReleaseDateSortsLastAscendingYear() {
        let result = sortedIDs(AlbumFixtures.baseTrio, key: .year, ascending: true)
        #expect(result.last == "fixture-cole")
    }

    @Test
    func nilReleaseDateSortsLastDescendingYear() {
        let result = sortedIDs(AlbumFixtures.baseTrio, key: .year, ascending: false)
        #expect(result.last == "fixture-cole")
    }
}
