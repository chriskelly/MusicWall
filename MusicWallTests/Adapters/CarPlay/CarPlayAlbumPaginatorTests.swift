import Foundation
import Testing
@testable import MusicWall

struct CarPlayAlbumPaginatorTests {
    private func albums(count: Int) -> [AlbumRecord] {
        (0..<count).map { index in
            AlbumFixtures.record(
                id: "album-\(index)",
                title: "Title \(index)",
                artistName: "Artist \(index)"
            )
        }
    }

    @Test
    func empty_returnsNoPages() {
        #expect(CarPlayAlbumPaginator.pages(from: [], pageSize: 8).isEmpty)
    }

    @Test
    func eightAlbums_returnsOnePage() {
        let pages = CarPlayAlbumPaginator.pages(from: albums(count: 8), pageSize: 8)
        #expect(pages.count == 1)
        #expect(pages[0].count == 8)
    }

    @Test
    func nineAlbums_returnsTwoPages() {
        let pages = CarPlayAlbumPaginator.pages(from: albums(count: 9), pageSize: 8)
        #expect(pages.count == 2)
        #expect(pages[0].count == 8)
        #expect(pages[1].count == 1)
    }

    @Test
    func buttonTitlesMatchAlbumTitles() {
        let input = albums(count: 3)
        let pages = CarPlayAlbumPaginator.pages(from: input, pageSize: 8)
        #expect(pages[0].map(\.title) == input.map(\.title))
    }
}
