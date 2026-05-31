import Testing
@testable import MusicWall

struct AppDependenciesUITestTests {
    @Test
    func uiTestFixtures_matchAlbumFixturesBaseTrio() {
        let ui = UITestFixtures.baseTrio
        let unit = AlbumFixtures.baseTrio
        #expect(ui.count == unit.count)
        for (left, right) in zip(ui, unit) {
            #expect(left.id == right.id)
            #expect(left.title == right.title)
            #expect(left.artistName == right.artistName)
        }
    }

    @Test
    func uiTest_savedLibrary_seedsAlbumRecords() {
        let deps = AppDependencies.uiTest(scenario: .savedLibrary)
        let records = deps.preferencesStore.load([AlbumRecord].self, for: .albumRecordsItems)
        #expect(records == UITestFixtures.baseTrio)
    }

    @Test
    func uiTest_restoreFromBackup_seedsBackupIDsOnly() {
        let deps = AppDependencies.uiTest(scenario: .restoreFromBackup)
        let records = deps.preferencesStore.load([AlbumRecord].self, for: .albumRecordsItems)
        let backupIDs = deps.preferencesStore.load([String].self, for: .backupAlbumIDs)
        #expect(records == nil || records?.isEmpty == true)
        #expect(backupIDs == UITestFixtures.backupIDs)
    }
}
