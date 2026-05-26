---
name: musicwall-test-refactor-pr-03
description: >-
  MusicWall test refactor PR 3 only — PreferencesStore protocol and UserDefaults
  adapter replacing static UserDefaultsManager. Invoke explicitly.
disable-model-invocation: true
paths:
  - MusicWall/**
  - MusicWallTests/**
---

# PR 3 — PreferencesStore + persistence adapter

**Requires:** PR 1 merged  
**Blocks:** PR 4, PR 7

## Goal

Make persistence injectable and fully unit-testable while preserving existing keys and JSON shapes.

## In scope

- Define **`PreferencesStore`** protocol: generic `save<T: Encodable>`, `load<T: Decodable>` (or typed methods per key).
- Implement **`UserDefaultsPreferencesStore`** using injectable `UserDefaults` instance.
- Migrate **`UserDefaultsManager`** call sites to store instance OR deprecate wrapper with forwarding (pick one; remove static in PR 14).
- Preserve **exact** `Key` raw strings from current `UserDefaultsManager.Key`.
- **Tests:** round-trip each key; corrupt/truncated data returns nil; isolated suite name per test.

## Out of scope

- `AlbumCollection` (PR 4).
- Backup file I/O (PR 7).

## Acceptance criteria

- [ ] All `UserDefaultsManager` keys covered by tests.
- [ ] App still reads existing user data on simulator.
- [ ] No MusicKit imports in persistence layer.

## Keys to preserve

`savedAlbumsItemsKey`, `backupIDsKey`, `sortDirectionKey`, `currentSortKey`, `homePageLayoutKey` (see `UserDefaultsManager.swift`).
