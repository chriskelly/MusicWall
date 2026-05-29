import Foundation

struct AlbumRecord: Equatable, Sendable, Identifiable, Codable {
    let id: AlbumID
    let title: String
    let artistName: String
    let releaseDate: Date?
    let isExplicit: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, artistName, releaseDate, isExplicit
    }

    init(
        id: AlbumID,
        title: String,
        artistName: String,
        releaseDate: Date?,
        isExplicit: Bool
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.releaseDate = releaseDate
        self.isExplicit = isExplicit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(AlbumID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artistName = try container.decode(String.self, forKey: .artistName)
        releaseDate = try container.decodeIfPresent(Date.self, forKey: .releaseDate)
        isExplicit = try container.decodeIfPresent(Bool.self, forKey: .isExplicit) ?? false
    }
}
