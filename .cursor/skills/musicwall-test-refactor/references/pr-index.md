# PR index (quick reference)

| PR | Branch slug example | Requires | Delivers |
|----|---------------------|----------|----------|
| 1 | `pr-01-test-harness` | — | `MusicWallTests`, CI test, `AppDependencies` |
| 2 | `pr-02-core-sorter` | 1 | `AlbumRecord`, `AlbumSorter`, sort tests |
| 3 | `pr-03-preferences` | 1 | `PreferencesStore`, UserDefaults adapter |
| 4 | `pr-04-album-collection` | 2, 3 | `AlbumCollection` in-memory + persist API |
| 5 | `pr-05-music-protocols` | 4 | Repository + playback protocols, adapters |
| 6 | `pr-06-migration-load` | 5 | Legacy JSON migration, `load()` |
| 7 | `pr-07-backup-codec` | 3 | `BackupCodec`, file/security abstractions |
| 8 | `pr-08-auth-vm` | 6 | `AuthViewModel`, auth protocol |
| 9 | `pr-09-home-vm` | 6 | `HomeViewModel`, thin home view |
| 10 | `pr-10-search-edit-vm` | 5 | Search + edit ViewModels |
| 11 | `pr-11-tap-artwork` | 5 | Tap coordinator, artwork DI |
| 12 | `pr-12-view-tests` | 9, 10, 11 | ViewInspector/snapshots |
| 13 | `pr-13-ui-tests` | 8, 9 | XCUITest + launch mocks |
| 14 | `pr-14-coverage-cleanup` | 12, 13 | Gates, delete legacy types |
| 15 | `pr-15-spm-split` | 14 | `Packages/MusicWallCore` etc. |

Invoke the matching skill: `/musicwall-test-refactor-pr-NN`
