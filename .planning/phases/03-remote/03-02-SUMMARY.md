---
phase: 03-remote
plan: 02
subsystem: remote
tags: [zsh, shadow-file-validation, safety, testing]

# Dependency graph
requires:
  - phase: 03-remote (plan 01)
    provides: hermetic dev/remote/ test harness (write-based fixtures, run_s1/run_s2, make_stub_rclone, mkfile helpers) that this plan extends in place
provides:
  - Per-iteration reset of ORIGINAL_LOCAL_PATH/MATCHED_REMOTE_PATH in rename-remote-files-2-rename-local.zsh, closing the stale-inheritance move risk
  - Non-empty validation after source, skipping malformed shadow files with an Error:-prefixed stderr message and continuing the run
  - write_shadow/write_bad_shadow fixture helpers for hand-writing shadow files without running script 1
  - 42 new assertions covering malformed-shadow, position-independence, empty-input, interruption-recovery, and repeat-run edges
affects: []

# Actuals (#2632)
actuals:
  tokens: 3673
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "unset before source: reset sourced shadow-file variables at the top of each while-loop iteration before re-sourcing, since zsh runs the loop body in the current shell and a malformed file would otherwise inherit the previous iteration's values"
    - "write_shadow/write_bad_shadow fixture helpers hand-write shadow files in script 1's exact KEY=\"value\" form, reaching validation branches script 1 itself never produces"

key-files:
  created: []
  modified:
    - dev/remote/rename-remote-files-2-rename-local.zsh
    - dev/remote/tests/test-rename-remote-files.zsh

key-decisions:
  - "D-04 honored: a malformed shadow file is skipped with an Error:-prefixed stderr message and continue; the run never aborts (no exit 1/return/break added)"
  - "D-05 honored: source kept as the loading mechanism; only a presence/non-empty check was added, no parser substitution"
  - "Regression guard executed manually (not encoded as a persistent test): temporarily removed the unset line, confirmed the suite drops from 77 to 76 passed with exactly 1 failure and non-zero exit, then restored the file from a pre-edit backup and re-verified 77 passed / 0 failed"

patterns-established:
  - "Per-iteration variable reset immediately before source, non-empty guard immediately after — the reset is load-bearing (proven empirically in 03-01-PLAN.md's environment_finding), not defensive garnish"

requirements-completed: [REMOTE-03]

coverage:
  - id: D1
    description: "rename-remote-files-2-rename-local.zsh resets ORIGINAL_LOCAL_PATH/MATCHED_REMOTE_PATH before each source and skips (via continue, Error: on stderr) any shadow file that leaves either variable empty, without aborting the run"
    requirement: "REMOTE-03"
    verification:
      - kind: integration
        ref: "dev/remote/tests/test-rename-remote-files.zsh (Plan 03-02 Task 1 section: comment-only, zero-byte, blank-original, blank-matched, position-independence scenarios, 25 assertions)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The reversion path's remaining edges are covered: empty shadow directory, a shadow whose sync file is absent (interruption-recovery state), and a repeat run over the same shadow directory, all safe and non-destructive"
    requirement: "REMOTE-03"
    verification:
      - kind: integration
        ref: "dev/remote/tests/test-rename-remote-files.zsh (Plan 03-02 Task 2 section, 17 assertions)"
        status: pass
    human_judgment: false
  - id: D3
    description: "A regression guard proves the suite would actually catch removal of the variable reset"
    verification:
      - kind: manual_procedural
        ref: "Manually removed the unset line, ran the suite (76 passed, 1 failed, exit 1), restored from backup, re-ran (77 passed, 0 failed, exit 0)"
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-08-13
status: complete
---

# Phase 03 Plan 02: Shadow-File Validation + Reversion-Path Edge Coverage Summary

**`rename-remote-files-2-rename-local.zsh` now resets its sourced shadow variables every iteration and skips (rather than silently inherits) any shadow file missing them, backed by 42 new assertions covering the stale-inheritance bug, position independence, and the reversion path's interruption/repeat-run edges.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-08-13T12:32Z (approx, following 03-01 completion)
- **Completed:** 2026-08-13T12:42:23Z
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments
- `rename-remote-files-2-rename-local.zsh`: added `unset ORIGINAL_LOCAL_PATH MATCHED_REMOTE_PATH` immediately before `source`, and a non-empty guard immediately after that emits an `Error:`-prefixed stderr message naming the shadow file and `continue`s — closing the silent wrong-file-relocation risk where a malformed shadow file inherited the previous iteration's move targets
- `source` kept unchanged (D-05); the run never aborts on a bad file — no `exit 1`, `return`, or `break` was added (D-04)
- Added `write_shadow`/`write_bad_shadow` fixture helpers to the suite, letting hand-written shadow files reach validation branches script 1 itself never produces
- Task 1: 25 new assertions — comment-only shadow, zero-byte shadow, empty-string assignment (both `ORIGINAL_LOCAL_PATH=""` and `MATCHED_REMOTE_PATH=""` variants), and a position-independence scenario with the malformed file nested among three valid ones, asserting content/counts rather than relative order
- Task 2: 17 new assertions — empty shadow directory (no `Error:`, no `reverting:` line), a shadow whose sync file is absent modeling the script-1-interruption state (pre-existing `warning:` line unchanged, sibling valid shadow still reverted), and a repeat run over the same shadow directory (second pass warns per file, no `Error:` line, byte-identical content via sha256sum comparison)
- Suite grew from 35 to 77 assertions, 0 failures, identical `Results:` line from the repository root and from `dev/remote/tests/`
- Regression guard executed and confirmed: removing the `unset` line drops the suite to 76 passed / 1 failed with a non-zero exit, proving the position-independence scenario actually catches the stale-inheritance bug; restored and re-verified 77/0 clean

## Task Commits

Each task was committed atomically:

1. **Task 1: A malformed shadow file is skipped, not silently driven by the previous one's paths** - `fb8c693` (feat)
2. **Task 2: The reversion path's remaining edges — empty inputs, missing sync file, and a repeat run** - `94edf7a` (test)

**Plan metadata:** (this commit, following SUMMARY.md write)

## Files Created/Modified
- `dev/remote/rename-remote-files-2-rename-local.zsh` - per-iteration variable reset before `source`, non-empty guard with `continue` after
- `dev/remote/tests/test-rename-remote-files.zsh` - `write_shadow`/`write_bad_shadow` helpers, malformed-shadow scenarios (Task 1), reversion-path edge scenarios (Task 2)

## Decisions Made
- D-04 honored: skip-and-continue with `Error:`-prefixed stderr; no abort path added
- D-05 honored: `source` retained; only a presence/non-empty check added, no parser substitution
- Regression guard (plan Task 2 acceptance criterion) run manually against a backup copy rather than encoded as a permanent suite scenario — a self-mutating test that edits its own script under test would be an unusual and fragile pattern; the manual confirmation (documented above) satisfies the acceptance criterion's intent without adding that risk to the suite

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed zsh `path`/`PATH` special-parameter collision in `write_bad_shadow`**
- **Found during:** Task 1, first suite run after adding the malformed-shadow scenarios
- **Issue:** `write_bad_shadow` declared `local path="$1"`. In zsh, `path` is a special array tied to `$PATH`; assigning a scalar to it inside the function silently broke command lookup (`mkdir: command not found`) for the remainder of that function call, corrupting several fixtures
- **Fix:** Renamed the local variable to `shadow_path` throughout the function
- **Files modified:** `dev/remote/tests/test-rename-remote-files.zsh`
- **Verification:** Re-ran the suite; the one resulting failure (position-independence scenario) cleared and all 63 Task-1 assertions passed
- **Committed in:** `fb8c693` (Task 1 commit — fixed before commit, so no separate fix commit was needed)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Fix was internal to the new test helper and caught before the task commit; no scope creep, no change to the plan's required files or acceptance criteria.

## Issues Encountered
None beyond the deviation above.

## User Setup Required

None - no external service configuration required. This plan's `<human-check>` verification item (truncating a real shadow file on a scratch copy of a script-1-produced tree) is deferred to end-of-phase verification per `human_verify_mode: end-of-phase` in `.planning/config.json`, consistent with 03-01's handling of the same setting.

## Next Phase Readiness
- REMOTE-01 through REMOTE-04 are now all closed: REMOTE-01/REMOTE-02/REMOTE-04 in `03-01-PLAN.md`, REMOTE-03 here.
- Phase 3 (remote) success criteria are met per both plans' `<success_criteria>` sections. The one flagged divergence (D-03: dependency preflight checks scoped to script 1 only, since script 2 invokes neither `rclone` nor `jq`) is intentional per CONTEXT.md and was already surfaced in `03-01-SUMMARY.md`.
- The phase-3 suite (`dev/remote/tests/test-rename-remote-files.zsh`, 77 assertions) is hermetic, cwd-independent, and covers both remote scripts end to end.
- Outstanding: the phase's `<human-check>` scratch-copy verification (real shadow tree, truncate one shadow file, confirm MegaSync reports renames) remains for end-of-phase human verification — not a blocker for this plan.
- No blockers.

---
*Phase: 03-remote*
*Completed: 2026-08-13*

## Self-Check: PASSED
