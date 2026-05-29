import Foundation
import Testing
@testable import MusicWall

struct BackupCodecTests {
    private let codec = BackupCodec()

    @Test
    func roundTripEncodesAndDecodesIDs() throws {
        let ids = ["fixture-a", "fixture-b"]
        let data = try codec.encode(ids)
        let decoded = try codec.decode(data)
        #expect(decoded == ids)
    }

    @Test
    func decodeEmptyArrayThrowsEmptyImport() {
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
    func decodeNonArrayJSONThrowsInvalidFormat() {
        #expect(throws: BackupError.invalidFormat) {
            _ = try codec.decode(Data("\"not-an-array\"".utf8))
        }
    }

    @Test
    func decodeWrongElementTypeThrowsInvalidFormat() {
        #expect(throws: BackupError.invalidFormat) {
            _ = try codec.decode(Data("[1, 2]".utf8))
        }
    }
}
