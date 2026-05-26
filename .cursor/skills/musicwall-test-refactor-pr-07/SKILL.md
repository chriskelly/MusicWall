---
name: musicwall-test-refactor-pr-07
description: >-
  MusicWall test refactor PR 7 only — BackupCodec pure JSON plus file export/import
  with SecurityScopedReader test seam. Invoke explicitly.
disable-model-invocation: true
paths:
  - MusicWall/**
  - MusicWallTests/**
---

# PR 7 — Backup codec + file services

**Requires:** PR 3 merged (can ship parallel to PR 5–6 if rebased carefully)  
**Blocks:** none critical (Home PR 9 uses export)

## Goal

100% unit-testable backup encode/decode; isolate security-scoped file access.

## In scope

- **`BackupCodec`**: `encode([String]) -> Data`, `decode(Data) -> [String]` (throws domain errors)
- **`FileExportService`**: temp URL write (from current `BackupService.exportAlbumIDs`)
- **`SecurityScopedReader`** protocol; live impl uses `startAccessingSecurityScopedResource()`; test impl reads file directly
- Map **`BackupServiceError`** cases to new types
- Update call sites in `HomePageView` (until PR 9 moves to ViewModel)
- **Tests:** all error paths; round-trip JSON; empty array errors; invalid JSON

## Out of scope

- `HomeViewModel` (PR 9) unless already merged — then wire VM in same PR with rebase.

## Acceptance criteria

- [ ] `BackupService.swift` deleted or thin deprecated shim.
- [ ] ≥95% line coverage on codec in CI report (informational until PR 14).
