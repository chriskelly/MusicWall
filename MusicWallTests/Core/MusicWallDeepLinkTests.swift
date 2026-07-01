import Foundation
import Testing
@testable import MusicWall

struct MusicWallDeepLinkTests {
    @Test
    func addAlbumURL_roundTripsAlbumID() throws {
        let expectedID = "1440857781"
        let url = try #require(MusicWallDeepLink.addAlbumURL(albumID: expectedID))
        #expect(MusicWallDeepLink.albumID(from: url) == expectedID)
    }

    @Test
    func albumID_returnsNilForUnknownHost() throws {
        let url = try #require(URL(string: "musicwall://unknown?id=123"))
        #expect(MusicWallDeepLink.albumID(from: url) == nil)
    }

    @Test
    func albumID_returnsNilWhenQueryMissing() throws {
        let url = try #require(URL(string: "musicwall://add-album"))
        #expect(MusicWallDeepLink.albumID(from: url) == nil)
    }
}
