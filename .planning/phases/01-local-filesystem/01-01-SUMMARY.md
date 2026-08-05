---
phase: 01-local-filesystem
plan: 01
subsystem: local-filesys
tags: [zsh, shell-scripting, testing, shadow-map, hash-matching]

# Dependency graph
requires: []
provides:
  - "retain-dir-struct-2-sorted.zsh with --dry-run preview flag"
  - "print-only output (no echo) across retain-dir-struct-2-sorted.zsh"
  - "both find-driven loops in retain-dir-struct-2-sorted.zsh on process substitution"
  - "dev/local-filesys/tests/test-retain-dir-struct.zsh — tracked regression test, extended further by plan 01-02"
affects: [01-local-filesystem plan 01-02]

actuals:
  tokens: 2490
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "zparseopts long-flag boolean parsing (zmodload zsh/zutil; zparseopts -D -E -F -- -dry-run=opt_dryrun)"
    - "process-substitution find loop (done < <(find ... -print0)) instead of find | while, to keep associative-array state in the current shell"
    - "print -r -- for all script output, avoiding dash-leading strings being parsed as options"
    - "mktemp -d fixture root with a trap-guarded, non-empty/is-directory-checked rm -rf teardown for shell test scripts"

key-files:
  created:
    - dev/local-filesys/tests/test-retain-dir-struct.zsh
  modified:
    - dev/local-filesys/retain-dir-struct-2-sorted.zsh

key-decisions:
  - "LOCALFS-01's subshell diagnosis was empirically disproven for zsh: zsh runs the last element of a pipeline in the current shell (unlike bash/POSIX sh), so the find | while loop was never a subshell and hash matching already worked. The Task 1 conversion to process substitution shipped as hardening (making correctness independent of that non-obvious zsh guarantee and future-proof against a bash port or an added pipeline stage), not as a bug fix."
  - "print of a dash-leading string (e.g. the 52-dash separator) silently prints nothing and exits 0 unless called as `print -r --`; the bare dashes are parsed as option flags. All 8 echo call sites were converted to `print -r --` for this reason, not just for output-style consistency. Plan 01-02 will hit the same trap on 12 more call sites in the sibling scripts."
  - "Chose a manual assert-style zsh test script (TESTING.md Option 3) over bats: bats is not installed on this machine and would add an external dependency nothing else in the repo needs, conflicting with the project's lightweight-tooling constraint."

patterns-established:
  - "Test fixture safety: fixture root created only via mktemp -d, verified non-empty and a real directory before use, and torn down via a trap on EXIT/INT/TERM guarded on that same non-empty/is-directory check. Never accept a fixture root from argv or environment."

requirements-completed: [LOCALFS-01]

coverage:
  - id: D1
    description: "retain-dir-struct-2-sorted.zsh hardened end-to-end: --dry-run flag added, all echo output converted to print -r --, both find loops on process substitution, hash matching still works"
    requirement: "LOCALFS-01"
    verification:
      - kind: integration
        ref: "dev/local-filesys/tests/test-retain-dir-struct.zsh"
        status: pass
    human_judgment: false
  - id: D2
    description: "Tracked, executable regression test locking script 2's matching and dry-run behavior, including duplicate-content, empty-input, and space-in-filename edge cases"
    requirement: "LOCALFS-01"
    verification:
      - kind: integration
        ref: "dev/local-filesys/tests/test-retain-dir-struct.zsh"
        status: pass
    human_judgment: false

duration: 79min
completed: 2026-08-05
status: complete
---

# Phase 01 Plan 01: retain-dir-struct-2-sorted.zsh Hardening + Regression Test Summary

**Hardened retain-dir-struct-2-sorted.zsh with a --dry-run preview flag, print-only output, and process-substitution loops, backed by a tracked 12-assertion zsh regression test — while disproving the LOCALFS-01 subshell bug diagnosis for zsh.**

## Performance

- **Duration:** ~79 min (11:28:42 to 12:47:07 local time between the two task commits; includes a human-verify checkpoint pause between tasks, not continuous active execution)
- **Completed:** 2026-08-05T18:47:23Z
- **Tasks:** 2
- **Files modified:** 2 (1 modified, 1 created)

## Accomplishments

- `retain-dir-struct-2-sorted.zsh` now supports `--dry-run`, previewing every match as `Would copy: <source> -> <destination>` without touching the filesystem
- All 8 `echo` call sites converted to `print -r --`, closing a confirmed trap where a bare `print` of the 52-dash separator silently printed nothing (exit 0) instead of erroring
- The second `find | while` loop converted to `done < <(find ...)` process-substitution form, matching the first loop and removing the script's dependence on zsh's non-obvious last-pipeline-element-runs-in-current-shell rule
- New tracked test `dev/local-filesys/tests/test-retain-dir-struct.zsh`: 12 assertions covering match found, copy-really-happened, non-match reporting, dry-run no-writes, dry-run no-false-claim, duplicate-content (last-writer-wins), empty inputs, separator-line survival, and filenames-with-spaces round-trip
- Empirically disproved the LOCALFS-01 root-cause diagnosis for zsh: verified on zsh 5.9 that the `find | while` loop was never a subshell, so hash matching already succeeded before this plan; documented so the requirement text and CONCERNS.md are not taken at face value in future work

## Task Commits

Each task was committed atomically:

1. **Task 1: retain-dir-struct-2-sorted.zsh end-to-end — process-substitution loop, print-only output, --dry-run** - `d81731a` (feat)
2. **Task 2: Create the tracked regression test locking script 2's matching and dry-run behaviour** - `804b126` (test)

**Plan metadata:** committed as part of this summary's final commit

## Files Created/Modified

- `dev/local-filesys/retain-dir-struct-2-sorted.zsh` - Added `--dry-run` flag via zparseopts, converted second loop to process substitution, converted all 8 `echo` calls to `print -r --`
- `dev/local-filesys/tests/test-retain-dir-struct.zsh` - New tracked, executable regression test (172 lines, 12 assertions, mktemp-based fixtures with trap-guarded teardown)

## Decisions Made

- LOCALFS-01's subshell diagnosis was empirically disproven for zsh: zsh runs the last element of a pipeline in the current shell, so `find | while` was never a subshell in this codebase. Task 1 shipped as hardening (defense against a future bash port or an added pipeline stage), not a bug fix — see plan objective and Task 1 `<action>` for the verification method.
- `print` of a dash-leading string requires `-r --`; a bare `print "---..."` silently prints nothing with exit 0. This is the specific trap the 52-dash-separator assertion in the new test guards against. Plan 01-02 will hit the same trap on 12 more call sites in `retain-dir-struct-1.zsh` and `retain-dir-struct-3-find-sorted.zsh`.
- Manual assert-style zsh test (TESTING.md Option 3) chosen over `bats`: `bats` is not installed on this machine, and adding `bats-core` would introduce an external dependency nothing else in the repo needs.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. The Task 2 acceptance criterion requiring proof the test "genuinely fails when the behaviour breaks" was verified manually during execution: the `--dry-run` guard in `retain-dir-struct-2-sorted.zsh` was temporarily replaced with `(( 0 ))`, the test was run (3 of 12 assertions failed, exit 1), the guard was restored (`git diff` confirmed byte-identical to the committed state), and the test was re-run to confirm all 12 assertions pass again. This verification was not committed as a separate step since it round-tripped the file back to its committed state.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 01-02 can proceed: it extends `dev/local-filesys/tests/test-retain-dir-struct.zsh` with assertions for `retain-dir-struct-1.zsh` and `retain-dir-struct-3-find-sorted.zsh`, and applies the same `echo`→`print -r --` and process-substitution hardening to those two sibling scripts (D-02, D-03 from CONTEXT.md).
- No blockers. The `print -r --` dash-swallowing trap and the last-writer-wins duplicate-hash behavior are now both documented and test-locked, so plan 01-02 has a concrete precedent to follow rather than rediscovering them.

---
*Phase: 01-local-filesystem*
*Completed: 2026-08-05*

## Self-Check: PASSED

All claimed files and commits verified to exist:
- `dev/local-filesys/retain-dir-struct-2-sorted.zsh` — FOUND
- `dev/local-filesys/tests/test-retain-dir-struct.zsh` — FOUND
- Commit `d81731a` — FOUND
- Commit `804b126` — FOUND
