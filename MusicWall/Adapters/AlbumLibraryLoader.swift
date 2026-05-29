import Foundation

enum AlbumLibraryLoader {
    struct LoadResult: Equatable {
        let records: [AlbumRecord]
        /// When true, caller must persist via `collection.replaceAll(..., persist: true)`.
        let shouldPersistCanonical: Bool
    }

    @MainActor
    static func load(
        preferences: PreferencesStore,
        repository: any AlbumRepository
    ) async -> LoadResult {
        if let records = preferences.load([AlbumRecord].self, for: .albumRecordsItems),
           !records.isEmpty {
            return LoadResult(records: records, shouldPersistCanonical: false)
        }

        if let legacy = preferences.load([LegacyStoredAlbum].self, for: .storedAlbumsItems),
           !legacy.isEmpty {
            return LoadResult(
                records: legacy.map { $0.asAlbumRecord() },
                shouldPersistCanonical: true
            )
        }

        let backupIDs = preferences.load([String].self, for: .backupAlbumIDs) ?? []
        guard !backupIDs.isEmpty else {
            return LoadResult(records: [], shouldPersistCanonical: false)
        }

        let ids = backupIDs.map { AlbumID(rawValue: $0) }
        let fetched = (try? await repository.fetch(ids: ids)) ?? []
        return LoadResult(records: fetched, shouldPersistCanonical: !fetched.isEmpty)
    }
}
