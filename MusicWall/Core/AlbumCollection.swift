import Foundation

final class AlbumCollection {
    private(set) var items: [AlbumRecord] = []
    private var persistSuppressed = false
    private let persistItems: ([AlbumRecord]) -> Void
    private let persistBackupIDs: ([String]) -> Void

    init(
        persistItems: @escaping ([AlbumRecord]) -> Void,
        persistBackupIDs: @escaping ([String]) -> Void
    ) {
        self.persistItems = persistItems
        self.persistBackupIDs = persistBackupIDs
    }

    @discardableResult
    func add(_ record: AlbumRecord) -> Bool {
        guard !contains(id: record.id) else { return false }
        items.append(record)
        persistIfNeeded()
        return true
    }

    func update(_ record: AlbumRecord) {
        guard let index = items.firstIndex(where: { $0.id == record.id }) else { return }
        items[index] = record
        persistIfNeeded()
    }

    func remove(id: AlbumID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items.remove(at: index)
        persistIfNeeded()
    }

    func contains(id: AlbumID) -> Bool {
        items.contains { $0.id == id }
    }

    func applySort(key: AlbumSortKey, ascending: Bool) {
        items = AlbumSorter.sorted(items, key: key, ascending: ascending)
        persistIfNeeded()
    }

    func temporarilyShuffle() {
        performWithoutPersist {
            items.shuffle()
        }
    }

    func performWithoutPersist(_ block: () -> Void) {
        persistSuppressed = true
        defer { persistSuppressed = false }
        block()
    }

    func replaceAll(_ newItems: [AlbumRecord], persist: Bool) {
        items = newItems
        if persist {
            persistIfNeeded()
        }
    }

    private func persistIfNeeded() {
        guard !persistSuppressed else { return }
        persistItems(items)
        persistBackupIDs(items.map(\.id.rawValue))
    }
}
