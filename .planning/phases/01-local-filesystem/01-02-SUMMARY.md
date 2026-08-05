---
phase: 01-local-filesystem
plan: 02
subsystem: local-filesys
tags: [zsh, shell-scripting, testing, shadow-map, hash-matching, print-standardization]

# Dependency graph
requires:
  - phase: 01-local-filesystem plan 01
    provides: "print -r -- output style, process-substitution loop pattern, and the tracked mktemp-based test file (test-retain-dir-struct.zsh) with its guarded EXIT trap"
provides:
  - "retain-dir-struct-3-find-sorted.zsh with a process-substitution lookup loop, print -r -- output throughout, and stderr-routed usage/validation errors"
  - "retain-dir-struct-1.zsh with print -r -- output throughout and stderr-routed usage message"
  - "dev/local-filesys/tests/test-retain-dir-struct.zsh extended to cover scripts 1 and 3, plus a script1-then-script3 round trip, with a reusable stdout/stderr split-capture assertion helper"
affects: [any future local-filesys phase touching retain-dir-struct-*.zsh]

actuals:
  tokens: 3117
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "process-substitution find loop (done < <(find ... -print0)) applied to script 3's lookup loop, matching script 2's precedent from plan 01-01"
    - "print -r -- for every output call site that could interpolate a value or emit a dash-leading string"
    - "print -u2 -r -- for usage/validation errors, routing them to stderr per project convention"
    - "stdout/stderr split-capture assertion helper (assert_stderr_and_exit) added to the shared test file, following the same minimal capture-compare-record shape as the existing assert_contains/assert_path helpers"

key-files:
  created: []
  modified:
    - dev/local-filesys/retain-dir-struct-3-find-sorted.zsh
    - dev/local-filesys/retain-dir-struct-1.zsh
    - dev/local-filesys/tests/test-retain-dir-struct.zsh

key-decisions:
  - "LOCALFS-02's subshell diagnosis was empirically disproven for zsh, same as LOCALFS-01 in plan 01-01: zsh runs the last element of a pipeline in the current shell, so retain-dir-struct-3-find-sorted.zsh's file_map lookup loop already resolved correctly before this plan. The process-substitution conversion shipped as hardening (removing the file's dependence on that non-obvious zsh guarantee, future-proofing against a bash port or an added pipeline stage) — not as a bug fix. Task 1's action and this summary avoid describing it as a fix."
  - "PATTERNS.md understated script 3's echo usage as zero ('already uses print throughout — no D-03 changes needed here'). It was wrong: print appeared only in the final lookup loop; the file made 8 echo calls (usage, both validation errors, both index-building progress lines, both separator lines). All 8 were in scope for D-03 and were converted."
  - "The dash-swallowing trap from plan 01-01 (a bare print of a dash-leading string parses the dashes as option flags, printing nothing with exit 0) recurred on 12 more call sites across the two sibling scripts — 8 in script 3, 4 in script 1 (including the 3-dash '---' separator). All converted to print -r --, and both the 52-dash and 3-dash separator counts are now exact-count-asserted in the test, not just presence-asserted, to guard specifically against a silent re-introduction of this trap."
  - "Flagged assumption EDGE-LOCALFS-03-unclassified (carried in this plan's must_haves) is resolved: LOCALFS-03 (script 1's output-style requirement) had no data-shape edge dimension beyond the dash-leading-string case, which is exactly the '---' separator-count assertion the test now enforces. No further edge case was found or needed for this requirement."

patterns-established:
  - "Exact-count (not presence-only) assertions on separator lines, since the failure mode for the dash-swallowing trap is a silently-empty line where the separator should be — a presence check alone would not catch it."
  - "assert_stderr_and_exit(<description>, <expected_exit>, <stderr_needle>, --, <command...>): captures stdout/stderr to files under the shared FIXROOT, asserts stdout is empty, stderr contains the needle, and exit code matches, in one call — reusable for any future stderr-routing assertion in this test file."

requirements-completed: [LOCALFS-02, LOCALFS-03]

coverage:
  - id: D1
    description: "retain-dir-struct-3-find-sorted.zsh hardened: lookup loop on process substitution, all 8 echo calls converted to print -r --, usage and both validation errors routed to stderr, remains free of cp/mv/rm"
    requirement: "LOCALFS-02"
    verification:
      - kind: integration
        ref: "dev/local-filesys/tests/test-retain-dir-struct.zsh"
        status: pass
    human_judgment: false
  - id: D2
    description: "retain-dir-struct-1.zsh output-only conversion: all 4 echo calls and the existing print call converted to print -r --, usage routed to stderr, no logic lines changed"
    requirement: "LOCALFS-03"
    verification:
      - kind: integration
        ref: "dev/local-filesys/tests/test-retain-dir-struct.zsh"
        status: pass
    human_judgment: false
  - id: D3
    description: "Regression test extended with 17 new assertions (29 total) covering script 3 match/non-match/duplicate-content/empty-inputs/stderr-routing/read-only/separators, script 1 shadow-creation/hash-format/separator/stderr-usage, and a script1-then-script3 round trip; verified to genuinely fail on all three seeded regressions named in the plan's acceptance criteria"
    requirement: "LOCALFS-02"
    verification:
      - kind: integration
        ref: "dev/local-filesys/tests/test-retain-dir-struct.zsh (29/29 pass, verified from repo root and /tmp)"
        status: pass
    human_judgment: false

duration: 4min
completed: 2026-08-05
status: complete
---

# Phase 01 Plan 02: Standardize scripts 1 & 3, extend regression test Summary

**Hardened retain-dir-struct-3-find-sorted.zsh's lookup loop onto process substitution and print -r --, converted retain-dir-struct-1.zsh's remaining echo calls to print -r --, and extended the tracked regression test from 12 to 29 assertions covering both scripts plus a round trip — closing the same dash-swallowing trap discovered in plan 01-01 on 12 more call sites.**

## Performance

- **Duration:** ~4 min (12:51:37 to 12:54:53 local time across the three task commits — a fast, continuous, non-interactive execution with no checkpoints)
- **Completed:** 2026-08-05T18:54:53Z
- **Tasks:** 3
- **Files modified:** 3 (2 scripts, 1 test file)

## Accomplishments

- `retain-dir-struct-3-find-sorted.zsh`'s lookup loop converted from `find | while` to `while ...; done < <(find ...)`, matching the index loop already in the same file
- All 8 `echo` calls in script 3 converted to `print -r --`; usage and both validation errors additionally routed to stderr (`print -u2 -r --`), closing a pre-existing gap flagged in PATTERNS.md
- All 4 `echo` calls in script 1 converted to `print -r --` (plus `-r --` added to its one pre-existing `print` call); usage routed to stderr
- Regression test extended from 12 to 29 assertions: 9 new assertions for script 3 (match, non-match, duplicate-content collapse to one `file_map` entry, empty inputs, stderr-only validation errors, read-only guarantee, exact 52-dash separator count), 6 new for script 1 (shadow creation, 64-char hex hash format, exact 3-dash separator count, stderr-only usage), and 2 for a script1-then-script3 round trip
- Added a reusable `assert_stderr_and_exit` helper to the shared test file for stdout/stderr split-capture assertions, in the same minimal capture-compare-record style as the existing helpers
- Verified the test genuinely goes red for all three seeded regressions named in the plan: a bare `print` on script 3's separator, a bare `print` on script 1's `---` separator, and script 3's stderr error redirected to stdout — each independently reproduced, confirmed as a failure, then reverted with a byte-identical `diff` check

## Task Commits

Each task was committed atomically:

1. **Task 1: retain-dir-struct-3-find-sorted.zsh — process-substitution lookup loop, print-only output, stderr for errors** - `32dcc06` (feat)
2. **Task 2: retain-dir-struct-1.zsh — print-only output** - `3f5fda9` (feat)
3. **Task 3: Extend the regression test to cover scripts 3 and 1** - `70aa32b` (test)

**Plan metadata:** committed as part of this summary's final commit

## Files Created/Modified

- `dev/local-filesys/retain-dir-struct-3-find-sorted.zsh` - Lookup loop moved to process substitution; all 8 `echo` calls converted to `print -r --`; usage and both validation errors routed to stderr; `-r --` added to the final loop's interpolating `print` calls
- `dev/local-filesys/retain-dir-struct-1.zsh` - All 4 `echo` calls converted to `print -r --`; `-r --` added to the existing `print "Hashing: ..."` call; usage routed to stderr; no logic lines changed
- `dev/local-filesys/tests/test-retain-dir-struct.zsh` - Extended in place: `SCRIPT3` reference and existence check added; `assert_stderr_and_exit` helper added; 17 new assertions added across script 3, script 1, and a round-trip section; reused the existing single `mktemp -d` fixture root and `EXIT` trap (no second root or trap introduced)

## Decisions Made

- LOCALFS-02's subshell diagnosis was empirically disproven for zsh, same conclusion as LOCALFS-01 in plan 01-01: the lookup loop in script 3 was never a subshell under zsh, so `file_map` lookups already worked before this plan. The process-substitution conversion is hardening, not a bug fix.
- PATTERNS.md's claim that script 3 needed "no D-03 output-style changes" was incorrect — it had 8 `echo` calls, all now converted. Documented here per the plan's `<output>` instruction so this correction is visible to future work rather than silently absorbed.
- The flagged assumption `EDGE-LOCALFS-03-unclassified` is resolved: LOCALFS-03's only meaningful edge case was the dash-leading-string separator, which the test now exact-count-asserts (1 line of 3 dashes) rather than merely presence-asserts.
- Chose exact dash-count assertions (52 for script 3, 3 for script 1) over presence checks, per the plan's explicit guidance, because the failure mode is a silently-empty line, not a missing line — presence checks would not distinguish the two.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. The three required regression-detection proofs (acceptance criterion (e) on Task 3) were verified manually during execution by seeding each regression individually, confirming the test suite exits 1 with a `FAIL:` line, then restoring the file and confirming a byte-identical `diff` against the pre-seeded version. This is the same verification technique used in plan 01-01's Task 2.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All three `retain-dir-struct-*.zsh` scripts now share one output style (`print -r --`), one error-routing convention (stderr via `print -u2 -r --`), and one process-substitution loop shape wherever an associative array is written inside the loop.
- The single tracked test file (`dev/local-filesys/tests/test-retain-dir-struct.zsh`) covers all three scripts with 29 assertions, runs green from any working directory, and is confirmed to fail correctly on the specific regressions this phase was designed to prevent.
- Phase 01 (local-filesystem) requirements LOCALFS-01, LOCALFS-02, and LOCALFS-03 are now all complete. No blockers for closing out this phase.

---
*Phase: 01-local-filesystem*
*Completed: 2026-08-05*

## Self-Check: PASSED
