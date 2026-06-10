import Testing
@testable import MusicWall

struct CarPlayAlbumLibraryPresentationTests {
    @Test
    func connect_animatesAndLoadsArtworkInBackground() {
        #expect(CarPlayAlbumLibraryPresentation.connect.setsRootAnimated)
        #expect(CarPlayAlbumLibraryPresentation.connect.loadsArtworkInBackground)
        #expect(!CarPlayAlbumLibraryPresentation.connect.updatesSectionsInPlace)
    }

    @Test
    func shuffle_updatesInPlaceWithoutBlockingConnectBehavior() {
        #expect(!CarPlayAlbumLibraryPresentation.shuffle.setsRootAnimated)
        #expect(!CarPlayAlbumLibraryPresentation.shuffle.loadsArtworkInBackground)
        #expect(CarPlayAlbumLibraryPresentation.shuffle.updatesSectionsInPlace)
    }
}
