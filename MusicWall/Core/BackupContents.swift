import Foundation

enum BackupContents: Equatable, Sendable {
    case records([AlbumRecord])
    case ids([String])

    var count: Int {
        switch self {
        case .records(let records): records.count
        case .ids(let ids): ids.count
        }
    }
}
