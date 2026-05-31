import Foundation

enum UITestFixtures {
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func utcDate(year: Int, month: Int, day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    static var baseTrio: [AlbumRecord] {
        [
            AlbumRecord(
                id: AlbumID(rawValue: "fixture-drake"),
                title: "Take Care",
                artistName: "Drake",
                releaseDate: utcDate(year: 2011, month: 11, day: 15),
                isExplicit: false
            ),
            AlbumRecord(
                id: AlbumID(rawValue: "fixture-cole"),
                title: "Born Sinners",
                artistName: "J. Cole",
                releaseDate: nil,
                isExplicit: false
            ),
            AlbumRecord(
                id: AlbumID(rawValue: "fixture-kendrick"),
                title: "Good Kid, m.A.A.d City",
                artistName: "Kendrick Lamar",
                releaseDate: utcDate(year: 2012, month: 10, day: 22),
                isExplicit: false
            ),
        ]
    }

    static var backupIDs: [String] {
        baseTrio.map(\.id.rawValue)
    }
}
