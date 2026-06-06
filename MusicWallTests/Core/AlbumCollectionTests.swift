import Foundation
import Testing
@testable import MusicWall

struct AlbumCollectionTests {
    private final class PersistSpy {
        var itemsCalls: [[AlbumRecord]] = []
        var backupCalls: [[String]] = []

        func makeCollection() -> AlbumCollection {
            AlbumCollection(
                persistItems: { [weak self] records in
                    self?.itemsCalls.append(records)
                },
                persistBackupIDs: { [weak self] ids in
                    self?.backupCalls.append(ids)
                }
            )
        }
    }

    @Test
    func addDedupesByID() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()
        let record = AlbumFixtures.record(id: "a", title: "T", artistName: "A")

        let first = collection.add(record)
        let second = collection.add(record)

        #expect(first == true)
        #expect(second == false)
        #expect(collection.items.count == 1)
        #expect(spy.itemsCalls.count == 1)
        #expect(spy.backupCalls.count == 1)
    }

    @Test
    func updateMissingIDIsNoOp() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()
        collection.replaceAll(AlbumFixtures.baseTrio, persist: true)
        spy.itemsCalls.removeAll()
        spy.backupCalls.removeAll()

        collection.update(
            AlbumFixtures.record(id: "missing", title: "X", artistName: "Y")
        )

        #expect(collection.items == AlbumFixtures.baseTrio)
        #expect(spy.itemsCalls.isEmpty)
        #expect(spy.backupCalls.isEmpty)
    }

    @Test
    func updateExistingReplacesAndPersists() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()
        collection.replaceAll([AlbumFixtures.record(id: "a", title: "Old", artistName: "A")], persist: true)
        spy.itemsCalls.removeAll()

        collection.update(AlbumFixtures.record(id: "a", title: "New", artistName: "A"))

        #expect(collection.items.first?.title == "New")
        #expect(spy.itemsCalls.count == 1)
    }

    @Test
    func removeExistingAndMissing() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()
        collection.replaceAll([AlbumFixtures.record(id: "a", title: "T", artistName: "A")], persist: true)
        spy.itemsCalls.removeAll()

        collection.remove(id: AlbumID(rawValue: "missing"))
        #expect(collection.items.count == 1)
        #expect(spy.itemsCalls.isEmpty)

        collection.remove(id: AlbumID(rawValue: "a"))
        #expect(collection.items.isEmpty)
        #expect(spy.itemsCalls.count == 1)
    }

    @Test
    func itemsPreserveOrderAfterReplaceAll() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()
        collection.replaceAll(AlbumFixtures.baseTrio, persist: false)

        #expect(collection.items.map(\.id.rawValue) == ["fixture-drake", "fixture-cole", "fixture-kendrick"])
    }

    @Test
    func temporarilyShuffleDoesNotPersist() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()
        collection.replaceAll(AlbumFixtures.baseTrio, persist: true)
        let before = collection.items
        spy.itemsCalls.removeAll()
        spy.backupCalls.removeAll()

        collection.temporarilyShuffle()

        #expect(Set(collection.items.map(\.id)) == Set(before.map(\.id)))
        #expect(spy.itemsCalls.isEmpty)
        #expect(spy.backupCalls.isEmpty)
    }

    @Test
    func applySortMatchesAlbumSorter() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()
        collection.replaceAll(AlbumFixtures.baseTrio, persist: false)

        collection.applySort(key: .artist, ascending: true)

        #expect(collection.items.map(\.id.rawValue) == ["fixture-drake", "fixture-cole", "fixture-kendrick"])
    }

    @Test
    func performWithoutPersistSkipsSaves() {
        let spy = PersistSpy()
        let collection = spy.makeCollection()

        collection.performWithoutPersist {
            collection.add(AlbumFixtures.record(id: "a", title: "T", artistName: "A"))
            collection.add(AlbumFixtures.record(id: "b", title: "U", artistName: "B"))
        }

        #expect(spy.itemsCalls.isEmpty)
        #expect(collection.items.count == 2)

        collection.replaceAll(collection.items, persist: true)
        #expect(spy.itemsCalls.count == 1)
    }
}
