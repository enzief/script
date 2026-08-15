---
phase: 04-local-filesys-revert-tool
plan: 02
subsystem: local-filesys
tags: [zsh, dry-run, round-trip, sha256sum, mv, shadow-file, cli]

# Dependency graph
requires:
  - phase: 04-local-filesys-revert-tool
    provides: "04-01: retain-dir-struct-4-revert.zsh bidirectional shadow/real-file swap CLI (name-first + hash-verified matching, two-mv positional exchange, rollback)"
provides:
  - "retain-dir-struct-4-revert.zsh --dry-run: full-fidelity preview of swaps/skips/errors, gating only the two mv calls and the rollback"
  - "Proof (not just claim) that running the script twice with tree roles reversed is a byte-exact identity round trip (D-08), across multiple target trees, and with spaces in names"
affects: []

# Actuals (#2632)
actuals:
  tokens: 3086
  tasks: 2
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Dry-run gates only the mutating step (the two mv calls + rollback); every check upstream of it (validation, indexing, discriminator, hash verification, disambiguation, destination guard, counters) runs identically so the preview is provably accurate, not merely present"
    - "Filesystem-state proof via a sorted relpath+sha256 tree snapshot, compared before/after rather than trusting output text, for both the dry-run-is-a-no-op claim and the round-trip-is-an-identity claim"

key-files:
  created: []
  modified:
    - dev/local-filesys/retain-dir-struct-4-revert.zsh
    - dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh

key-decisions:
  - "No script changes were needed for Task 2 (round trip, multi-target-tree, spaces) -- the path derivation Task 1 (04-01) built is already symmetric by construction. This was verified by writing and running Case K/L/M/N against the unmodified script and getting a clean pass, not assumed."

patterns-established:
  - "tree_snapshot() test helper: sorted 'relpath sha256' listing for a whole tree, the load-bearing assertion for both dry-run-no-op and round-trip-identity claims"

requirements-completed: [LOCALFS-05]

coverage:
  - id: D1
    description: "--dry-run previews the exact swap/skip/error set a real run would produce, with matching Totals and exit status, and writes nothing to either tree"
    requirement: "LOCALFS-05"
    verification:
      - kind: unit
        ref: "dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh (Case I-J, 13 assertions)"
        status: pass
    human_judgment: false
  - id: D2
    description: "True round trip (SCRIPT4 H T then SCRIPT4 T H) is a byte-exact identity on both trees with the shadow carried across unchanged; shadows resolve across multiple target trees with per-tree placement; a cross-tree basename collision errors; names with spaces survive both hops"
    requirement: "LOCALFS-05"
    verification:
      - kind: unit
        ref: "dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh (Case K-N, 21 assertions)"
        status: pass
    human_judgment: false

duration: 18min
completed: 2026-08-15
status: complete
---

# Phase 4 Plan 2: Local Filesystem Revert Tool -- Dry-Run and Round-Trip Summary

**`--dry-run` added to the swap tool with full-fidelity preview (same Totals, same exit status, zero writes -- proven by tree-snapshot comparison), and the phase's headline claim -- a true round trip with zero stored location metadata -- confirmed by running the same script twice with tree roles reversed against a byte-exact snapshot, with no script changes required.**

## Performance

- **Duration:** ~18 min active work
- **Tasks:** 2 completed
- **Files modified:** 2 (both existing, from 04-01)

## Accomplishments

- `--dry-run` added to `retain-dir-struct-4-revert.zsh`, reusing the Phase 1 `zparseopts -D -E -F -- -dry-run=opt_dryrun` idiom verbatim. Only the two `mv` calls (and the rollback) are gated; every upstream check (root-overlap rejection, the shadow-vs-non-shadow discriminator, name-index build, hash verification, collision disambiguation, the destination-occupied guard, and all counters) runs identically in dry-run mode. A dry run prints `Would swap: ` in place of `Swapped: `, still increments `swap_count`, and closes with `Dry run complete. No files were moved.` -- mirroring `retain-dir-struct-2-sorted.zsh`'s two-branch closing pattern.
- New `tree_snapshot()` test helper (sorted `relpath sha256` listing for a whole tree) added to the suite, used to prove filesystem state -- not output text -- is unchanged across a dry run and byte-exact across a round trip.
- Case I proves preview accuracy directly: one fixture with a clean match, a hash mismatch, a no-match, and a genuine ambiguity is run once with `--dry-run` and once for real, and the two runs' `Totals: ` lines are asserted equal.
- Case K proves the phase's headline claim: `SCRIPT4 H T` followed by `SCRIPT4 T H` returns both trees to their exact pre-run snapshot, with the shadow's bytes unchanged across both hops -- no script changes were needed to make this pass, confirming the path derivation built in 04-01 (`dest_shadow="${real_src}.txt"`, `dest_real="${shadow%.txt}"`) was already symmetric by construction.
- Case L confirms shadows resolve correctly across more than one target tree, each landing in the specific tree its own match came from (not merely "some" tree). Case M confirms a basename colliding across two different target trees with identical content is a genuine ambiguous-match error, never a first-tree-wins guess.
- Case N confirms directory and file names containing spaces survive a full round trip unchanged.
- Suite grew from 42 to 74 assertions, all passing. The pre-existing `test-retain-dir-struct.zsh` suite (scripts 1-3) remains unregressed.

## Task Commits

1. **Task 1: `--dry-run` preview that gates both moves and still reports every error**
   - `0a271b7` (test) -- RED: Case I/J added against the unmodified 04-01 script; 7 of 53 assertions failed as expected (the script didn't understand `--dry-run` yet)
   - `d1446b3` (feat) -- GREEN: flag added, gating only the mutating step; 53/53 assertions pass
2. **Task 2: True round trip, multiple target trees, and names with spaces**
   - `9a735f0` (test) -- Case K/L/M/N added; all 74 assertions pass with zero script changes, confirming the round trip already closes

_Task 1 is TDD (RED/GREEN pair). Task 2 is `type="auto"` (not TDD) -- its own action explicitly allows "if the round trip does not close, fix the script"; since it closed cleanly on the first run, only the test commit was needed._

## Files Created/Modified
- `dev/local-filesys/retain-dir-struct-4-revert.zsh` (+18/-2 lines) -- `--dry-run` flag, gating the two `mv` calls and the rollback only
- `dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh` (+225 lines) -- Cases I through N, plus the `tree_snapshot()` helper; suite now 74 assertions

## Decisions Made
- No script changes for Task 2: the round trip, multi-target-tree, and spaces cases were written and run against the unmodified 04-01 script and passed cleanly on the first attempt, so the plan's contingency ("if the round trip does not close, the defect is in the script's path derivation, fix it here") was not triggered. This was verified, not assumed -- Case K/L/M/N are genuinely exercised, not stubbed.

## Deviations from Plan

None -- plan executed exactly as written. Task 1's `<action>` and `<behavior>` were implemented as specified via a proper RED/GREEN TDD pair. Task 2's cases matched `<behavior>` exactly and required no script-side fix.

## Issues Encountered

None.

## User Setup Required

None -- no external service configuration required.

## Next Phase Readiness

- Phase 4 (`local-filesys-revert-tool`) is now feature-complete: `retain-dir-struct-4-revert.zsh` supports the full bidirectional swap with `--dry-run` preview, multi-target-tree resolution, and a proven byte-exact round trip. `LOCALFS-05` is satisfied.
- The threat register's remaining `mitigate` items from this plan (T-04-07 through T-04-11) are all closed: T-04-07/T-04-08 by Case I's snapshot-and-Totals-equality proof, T-04-09 by Case L, T-04-10 by Case K, T-04-11 by Case N. T-04-06 (symlinks, from 04-01) remains an accepted risk deferred to LOCALFS-04 (v2), unchanged.
- No blockers. This closes out Phase 4's active work; ready for phase-level verification/UAT.

---
*Phase: 04-local-filesys-revert-tool*
*Completed: 2026-08-15*

## Self-Check: PASSED

All created/modified files and commit hashes verified present.
