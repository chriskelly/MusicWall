import Foundation
@testable import MusicWall

enum AlbumFixtures {
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func utcDate(year: Int, month: Int, day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    static func record(
        id: String,
        title: String,
        artistName: String,
        releaseDate: Date? = nil
    ) -> AlbumRecord {
        AlbumRecord(
            id: AlbumID(rawValue: id),
            title: title,
            artistName: artistName,
            releaseDate: releaseDate
        )
    }

    /// Canonical three-album sample (stable IDs/dates). Reused by PR 4+ collection tests.
    static var baseTrio: [AlbumRecord] {
        [
            record(id: "fixture-drake", title: "Take Care", artistName: "Drake", releaseDate: utcDate(year: 2011, month: 11, day: 15)),
            record(id: "fixture-cole", title: "Born Sinners", artistName: "J. Cole", releaseDate: nil),
            record(id: "fixture-kendrick", title: "Good Kid, m.A.A.d City", artistName: "Kendrick Lamar", releaseDate: utcDate(year: 2012, month: 10, day: 22)),
        ]
    }
}
