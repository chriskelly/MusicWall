import Foundation
import Testing
@testable import MusicWall

struct AppleMusicURLParserTests {
    @Test
    func albumID_fromStandardAppleMusicURL() throws {
        let url = try #require(URL(string: "https://music.apple.com/us/album/take-care-deluxe/1440857781"))
        #expect(AppleMusicURLParser.albumID(from: url) == "1440857781")
    }

    @Test
    func albumID_fromURLWithSongQueryParameter() throws {
        let url = try #require(
            URL(string: "https://music.apple.com/us/album/take-care-deluxe/1440857781?i=1440857782")
        )
        #expect(AppleMusicURLParser.albumID(from: url) == "1440857781")
    }

    @Test
    func albumID_fromIdPrefixedPath() throws {
        let url = try #require(URL(string: "https://music.apple.com/us/album/id1440857781"))
        #expect(AppleMusicURLParser.albumID(from: url) == "1440857781")
    }

    @Test
    func albumID_fromMusicSchemeURL() throws {
        let url = try #require(
            URL(string: "music://music.apple.com/us/album/take-care-deluxe/1440857781")
        )
        #expect(AppleMusicURLParser.albumID(from: url) == "1440857781")
    }

    @Test
    func albumID_returnsNilForPlaylistURL() throws {
        let url = try #require(URL(string: "https://music.apple.com/us/playlist/example/pl.u-abc123"))
        #expect(AppleMusicURLParser.albumID(from: url) == nil)
    }

    @Test
    func albumID_returnsNilForNonAppleMusicURL() throws {
        let url = try #require(URL(string: "https://example.com/album/123"))
        #expect(AppleMusicURLParser.albumID(from: url) == nil)
    }
}
