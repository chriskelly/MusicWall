import Foundation

enum PreferencesKey: String, CaseIterable, Sendable {
    case storedAlbumsItems = "savedAlbumsItemsKey"
    case backupAlbumIDs = "backupIDsKey"
    case sortDirection = "sortDirectionKey"
    case currentSort = "currentSortKey"
    case homePageLayout = "homePageLayoutKey"
}
