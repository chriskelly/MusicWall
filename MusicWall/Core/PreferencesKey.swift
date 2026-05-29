import Foundation

enum PreferencesKey: String, CaseIterable, Sendable {
    case albumRecordsItems = "albumRecordsItemsKey"
    case storedAlbumsItems = "savedAlbumsItemsKey"
    case backupAlbumIDs = "backupIDsKey"
    case sortDirection = "sortDirectionKey"
    case currentSort = "currentSortKey"
    case homePageLayout = "homePageLayoutKey"
}
