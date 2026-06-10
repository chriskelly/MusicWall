import UIKit
import Testing
@testable import MusicWall

struct CarPlayArtworkCacheTests {
    @Test
    func resetIfNeeded_clearsImagesWhenPixelSizeChanges() {
        var cache = CarPlayArtworkCache()
        let image = UIImage()
        let album = AlbumFixtures.record(id: "a", title: "A", artistName: "Artist")

        cache.resetIfNeeded(pixelSize: 100)
        cache.store(image, albumID: album.id, pixelSize: 100)
        cache.resetIfNeeded(pixelSize: 200)

        #expect(cache.image(for: album.id, pixelSize: 100) == nil)
        #expect(cache.missingAlbums(from: [album], pixelSize: 200) == [album])
    }

    @Test
    func isFullyCached_falseUntilEveryAlbumHasArtwork() {
        var cache = CarPlayArtworkCache()
        let albums = AlbumFixtures.baseTrio
        cache.resetIfNeeded(pixelSize: 64)

        #expect(!cache.isFullyCached(albums: albums, pixelSize: 64))

        for album in albums {
            cache.store(UIImage(), albumID: album.id, pixelSize: 64)
        }

        #expect(cache.isFullyCached(albums: albums, pixelSize: 64))
        #expect(cache.missingAlbums(from: albums, pixelSize: 64).isEmpty)
    }
}
