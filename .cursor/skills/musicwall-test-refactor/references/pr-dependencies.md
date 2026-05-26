# PR dependency graph

Implement in order unless noted. PRs 8–11 can run in parallel **after PR 6** if conflicts are coordinated.

```
PR1 → PR2 → PR3
PR2 → PR4
PR3 → PR4
PR4 → PR5 → PR6
PR3 → PR7
PR6 → PR8, PR9
PR5 → PR10, PR11
PR8, PR9, PR10, PR11 → PR12
PR8, PR9 → PR13
PR12, PR13 → PR14
PR14 → PR15 (optional SPM)
```

## Parallelization notes

| After merged | Can parallelize |
|--------------|-----------------|
| PR 6 | PR 8 (auth), PR 9 (home), PR 7 (backup) if backup doesn't touch same files as PR 6 |
| PR 5 | PR 10 (search/edit), PR 11 (layout/artwork) |

Avoid merging two PRs that both rename `Album.swift` / `HomePageView.swift` without rebasing.

## Prerequisite check (agent)

Before starting PR *N*:

```bash
git fetch origin main
git log origin/main --oneline | head -20
# Confirm commit messages or files from PR 1..N-1 exist
```

If a prerequisite PR is incomplete, **stop** and tell the user to merge or rebase.
