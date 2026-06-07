import Foundation
import Testing
@testable import MusicWall

struct BackupCodecTests {
    private let codec = BackupCodec()

    private var sampleRecords: [AlbumRecord] {
        [
            AlbumFixtures.record(
                id: "fixture-a",
                title: "Take Care",
                artistName: "Drake",
                releaseDate: AlbumFixtures.utcDate(year: 2011, month: 11, day: 15),
                isExplicit: true
            ),
            AlbumFixtures.record(id: "fixture-b", title: "Born Sinners", artistName: "J. Cole"),
        ]
    }

    @Test
    func roundTripEncodesAndDecodesV2Records() throws {
        let records = sampleRecords
        let data = try codec.encode(records)
        let decoded = try codec.decode(data)
        #expect(decoded == .records(records))
    }

    @Test
    func decodeLegacyIDArrayReturnsIds() throws {
        let data = Data(#"["legacy-a","legacy-b"]"#.utf8)
        let decoded = try codec.decode(data)
        #expect(decoded == .ids(["legacy-a", "legacy-b"]))
    }

    @Test
    func decodeEmptyV2AlbumsThrowsEmptyImport() {
        let data = Data(#"{"version":2,"albums":[]}"#.utf8)
        #expect(throws: BackupError.emptyImport) {
            _ = try codec.decode(data)
        }
    }

    @Test
    func decodeEmptyLegacyArrayThrowsEmptyImport() {
        #expect(throws: BackupError.emptyImport) {
            _ = try codec.decode(Data("[]".utf8))
        }
    }

    @Test
    func decodeInvalidJSONThrowsInvalidFormat() {
        #expect(throws: BackupError.invalidFormat) {
            _ = try codec.decode(Data("{".utf8))
        }
    }

    @Test
    func decodeNonArrayLegacyJSONThrowsInvalidFormat() {
        #expect(throws: BackupError.invalidFormat) {
            _ = try codec.decode(Data("\"not-an-array\"".utf8))
        }
    }

    @Test
    func decodeWrongLegacyElementTypeThrowsInvalidFormat() {
        #expect(throws: BackupError.invalidFormat) {
            _ = try codec.decode(Data("[1, 2]".utf8))
        }
    }

    @Test
    func decodeUnsupportedVersionThrowsInvalidFormat() {
        let data = Data(#"{"version":99,"albums":[{"id":"x","title":"T","artistName":"A"}]}"#.utf8)
        #expect(throws: BackupError.invalidFormat) {
            _ = try codec.decode(data)
        }
    }
}
