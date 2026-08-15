---
phase: 04-local-filesys-revert-tool
plan: 01
subsystem: local-filesys
tags: [zsh, sha256sum, find, mv, shadow-file, cli]

# Dependency graph
requires:
  - phase: 01-local-filesystem
    provides: "retain-dir-struct-1.zsh shadow format (sha256sum output redirected to .txt), print -r -- / process-substitution conventions, assert-style test harness"
provides:
  - "retain-dir-struct-4-revert.zsh: bidirectional shadow/real-file swap CLI, name-first + hash-verified matching, two-mv positional exchange"
  - "tests/test-retain-dir-struct-4-revert.zsh: 42-assertion regression suite covering the clean swap, every D-04/D-05/D-06 failure mode, and partial-swap rollback"
affects: ["04-02: adds --dry-run and proves the reverse (revert-revert) direction round-trips"]

# Actuals (#2632)
actuals:
  tokens: 5668
  tasks: 2
  commits: 4

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Name-first-then-hash-disambiguate matching: basename index built once over all target trees, hash used only to verify a unique match or disambiguate a name collision"
    - "Two-mv positional swap with existence guard before either move (no mv -f/-n), and rollback-by-reverse-mv on a partial failure"

key-files:
  created:
    - dev/local-filesys/retain-dir-struct-4-revert.zsh
    - dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh
  modified: []

key-decisions:
  - "One bidirectional script, not a revert/revert-revert pair (CONTEXT.md Claude's Discretion) — D-08 confirms revert-revert is the identical swap with tree roles reversed, so two scripts would duplicate the whole matching-and-swap core for no behavioral difference"
  - "Collision disambiguation (D-03) runs a targeted second find pass only for basenames that actually collide, keeping the common unique-match case at one traversal"

patterns-established:
  - "Rollback-by-reverse-mv on partial swap failure: if the second mv fails, move the real file back to restore pre-swap state; report a distinct unrepairable-state error if the rollback mv itself fails"

requirements-completed: [LOCALFS-05]

coverage:
  - id: D1
    description: "Shadow/real-file swap tool: name-first matching, mandatory hash verification, two-mv positional exchange, non-shadow .txt passthrough, occupied-destination refusal, overlapping-root rejection"
    requirement: "LOCALFS-05"
    verification:
      - kind: unit
        ref: "dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh (Case A-E, 24 assertions)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Collision disambiguation by hash, partial-swap rollback via a stubbed mv, and the swapped/skipped/error run-level exit contract"
    requirement: "LOCALFS-05"
    verification:
      - kind: unit
        ref: "dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh (Case F-H, 18 assertions)"
        status: pass
    human_judgment: false

duration: 21min
completed: 2026-08-15
status: complete
---

# Phase 4 Plan 1: Local Filesystem Revert Tool Summary

**Bidirectional shadow/real-file swap CLI (`retain-dir-struct-4-revert.zsh`) with name-first, hash-verified matching, a genuine two-`mv` positional exchange, and full rollback of a partially-completed swap — 42-assertion regression suite, zero failures.**

## Performance

- **Duration:** ~21 min active work (06:24:45 → 07:22:46; excludes the mid-plan pause awaiting the tracer checkpoint's human approval)
- **Started:** 2026-08-15T06:24:45-06:00
- **Completed:** 2026-08-15T07:22:46-06:00
- **Tasks:** 2 completed
- **Files modified:** 2 (both new)

## Accomplishments
- New `dev/local-filesys/retain-dir-struct-4-revert.zsh`: given a home tree of hash-only shadow `.txt` files and one or more target trees of real files, resolves each shadow by basename, verifies the candidate's sha256 against the shadow's stored hash (mandatory even on a unique match — D-04), and swaps the shadow and the real file's positions with exactly two `mv` calls — the shadow is relocated byte-for-byte, never regenerated (D-07).
- Every failure mode D-04/D-05/D-06 calls for is implemented and non-destructive: a name collision resolves by hash when exactly one candidate matches and errors as ambiguous when more than one does; a hash mismatch never moves anything; a missing name match skips and the run continues; an occupied destination refuses the swap; a partially-completed swap (second `mv` fails) is rolled back to its pre-swap state.
- New `dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh`: 42 assertions across 8 fixture cases, including a fixture-owned `mv` stub on `PATH` (subshell-scoped) that forces a deterministic partial-swap failure to prove rollback.

## Task Commits

Each task was committed atomically as a RED/GREEN TDD pair:

1. **Task 1: End-to-end shadow/real swap — one shadow, one unique-name match, real mv**
   - `847bdb2` (test) — failing suite: clean swap, non-shadow passthrough, occupied destination, overlapping roots, usage error
   - `70c930f` (feat) — clean unique-match swap path; collision case still hard-errors (Task 2 scope)
2. **Task 2: Collision disambiguation, rollback, and the run-level error contract**
   - `5dfc0d0` (test) — failing suite additions: hash-disambiguated resolution, genuine ambiguous duplicates, mv-stub rollback, exit-status contract
   - `3c0eab7` (feat) — hash disambiguation on collision, rollback-by-reverse-mv, Totals/Ignored summary lines, error-count-driven exit status

_TDD tasks each produced a test → feat commit pair, matching the plan's RED/GREEN gates._

## Files Created/Modified
- `dev/local-filesys/retain-dir-struct-4-revert.zsh` (187 lines) - the swap CLI
- `dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh` (399 lines) - the tracked regression suite

## Decisions Made
- Single bidirectional script rather than a `revert`/`revert-revert` pair (CONTEXT.md Claude's Discretion, per D-08's confirmed symmetry) — avoids duplicating the entire matching-and-swap core for zero behavioral difference.
- Collision disambiguation only runs a second, targeted `find` pass for basenames that actually collide, so the common unique-match path still costs one traversal.
- Rollback restores the real file to its original target-tree path when the second `mv` (shadow move) fails; a distinct "ROLLBACK FAILED" stderr message covers the one state the tool cannot self-repair (the rollback `mv` itself failing).

## Deviations from Plan

None — plan executed exactly as written. Task 1 and Task 2's `<action>` and `<behavior>` blocks were implemented as specified; the two-site edit boundary described in Task 2 (collision branch, mv rollback, counters/summary/exit) was followed without restructuring Task 1's control flow.

## Issues Encountered
- The Case G (rollback) test fixture initially stubbed `mv` to succeed only on its very first invocation and fail on every call after — but the rollback logic's own recovery `mv` call also runs through the same stubbed `PATH`, so it was itself being stubbed out, silently failing the rollback and leaving the real file at the wrong path. Fixed by making the stub fail specifically on call #2 (the shadow move) and delegate to the real `mv` on every other call, including the rollback's. Caught immediately by the two path assertions in Case G failing during GREEN; fixed and reverified within the same task before committing.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- The `revert` direction is fully implemented, tested, and safe against every planned failure mode. Plan 04-02 adds `--dry-run` (D-09, following the `retain-dir-struct-2-sorted.zsh` precedent) and proves the reverse direction (`revert-revert`) round-trips by running this same script with the home and target tree roles swapped (D-08).
- No blockers. The threat register's five `mitigate` items (T-04-01 through T-04-05) are all closed by this plan's implementation and covered by the test suite; T-04-06 (symlinks) remains an accepted risk deferred to LOCALFS-04 (v2), unchanged from the plan.

---
*Phase: 04-local-filesys-revert-tool*
*Completed: 2026-08-15*

## Self-Check: PASSED

All created files and commit hashes verified present.
