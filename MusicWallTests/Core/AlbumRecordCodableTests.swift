import Foundation
import Testing
@testable import MusicWall

struct AlbumRecordCodableTests {
    @Test
    func roundTripIncludesIsExplicit() throws {
        let record = AlbumFixtures.record(
            id: "id-1",
            title: "Take Care",
            artistName: "Drake",
            isExplicit: true
        )
        let data = try JSONEncoder().encode([record])
        let decoded = try JSONDecoder().decode([AlbumRecord].self, from: data)
        #expect(decoded == [record])
    }

    @Test
    func missingIsExplicitDefaultsFalse() throws {
        let json = """
        [{"id":"id-1","title":"T","artistName":"A"}]
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode([AlbumRecord].self, from: data)
        #expect(decoded.count == 1)
        #expect(decoded[0].isExplicit == false)
    }
}
