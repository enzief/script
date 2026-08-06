---
phase: 02-manga
plan: 01
subsystem: testing
tags: [zsh, imagemagick, cli, regression-test]

# Dependency graph
requires:
  - phase: 01-local-filesys
    provides: The manual assert-style zsh test pattern (mktemp fixture root, _record/assert_contains/assert_path helpers, trap-guarded cleanup) from dev/local-filesys/tests/test-retain-dir-struct.zsh
provides:
  - "dev/manga/number-pages.zsh reports dimension-detection failures loudly (Error: prefix) and counts them in the closing summary, non-fatally"
  - "dev/manga/'s first tracked regression test, hermetic (no ImageMagick required) via a stub identify"
affects: []

# Actuals (#2632)
actuals:
  tokens: 2623
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Stub identify on PATH (prepended, per-invocation) to make an ImageMagick-dependent zsh script's test hermetic on a machine without ImageMagick installed"

key-files:
  created:
    - dev/manga/tests/test-number-pages.zsh
  modified:
    - dev/manga/number-pages.zsh

key-decisions:
  - "Followed D-01 through D-04 from 02-CONTEXT.md exactly: Warning: -> Error: prefix only, dim_failures counter added, summary conditional only appends the failure clause when count > 0, control flow (continue, exit 0) left untouched"
  - "Test scenarios (A-D plus the Task 1 tracer scenario) exercise both sides of the D-02 zero/non-zero boundary, a real multi-failure count (not a boolean), full renumbering regression including the abbreviated double-page suffix, and both safety prohibitions (non-fatal exit, no stranded .numbering_tmp_* files) behaviorally"

patterns-established:
  - "Hermetic ImageMagick-dependent test via stub identify: mkimg <path> [dims] writes an optional <path>.dims sidecar; stub identify cats it if present, else emits nothing, always exits 0; STUB_BIN is always prepended (never appended) to PATH per-invocation"

requirements-completed: [MANGA-01]

coverage:
  - id: D1
    description: "An unreadable image produces an Error:-prefixed stderr line naming the file, gets counted, and the run still renames every file and exits 0"
    requirement: MANGA-01
    verification:
      - kind: unit
        ref: "dev/manga/tests/test-number-pages.zsh#Task1 scenario (4 assertions)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Closing summary line: zero-failure wording unchanged, non-zero wording gains the dimension-detection failures clause with an accurate count"
    requirement: MANGA-01
    verification:
      - kind: unit
        ref: "dev/manga/tests/test-number-pages.zsh#ScenarioA and ScenarioB"
        status: pass
    human_judgment: false
  - id: D3
    description: "Valid images (including a landscape double-page) still renumber exactly as before: zero-padding, page arithmetic, abbreviated double-page suffix"
    requirement: MANGA-01
    verification:
      - kind: unit
        ref: "dev/manga/tests/test-number-pages.zsh#ScenarioC (9 assertions)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Failure path never becomes fatal and never strands .numbering_tmp_* staging files"
    requirement: MANGA-01
    verification:
      - kind: unit
        ref: "dev/manga/tests/test-number-pages.zsh#ScenarioD"
        status: pass
    human_judgment: false
  - id: D5
    description: "Real ImageMagick behavior on a genuinely corrupt file (not just the stub's modeled contract) — explicitly out of scope for the automated suite per the plan's environment_finding"
    verification: []
    human_judgment: true
    rationale: "The stub models identify's output contract (empty stdout), not real ImageMagick's behavior on a genuinely corrupt file. This machine has no ImageMagick installed, so it cannot be automated here; the plan's <human-check> defers this to end-of-phase verification on a scratch copy of a real chapter."

duration: 6min
completed: 2026-08-06
status: complete
---

# Phase 2 Plan 01: Manga Dimension-Detection Failures Summary

**`number-pages.zsh` now reports unreadable-image dimension failures with an `Error:`-prefixed stderr line and a summary failure count, staying non-fatal; backed by the first tracked test for `dev/manga/`, hermetic via a stub `identify`.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-08-06T12:27:00Z
- **Completed:** 2026-08-06T12:33:06Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `dev/manga/number-pages.zsh`'s empty-dims branch now prints `Error:` (was `Warning:`) and increments a new `dim_failures` counter, still non-fatal — same `continue`, same exit 0
- Closing summary line conditionally appends `, N dimension-detection failures` only when `N > 0`; the zero-failure wording is byte-identical to before
- New `dev/manga/tests/test-number-pages.zsh` (24 assertions, all passing): one unreadable file end-to-end, the zero-failure boundary, a real two-failure count, full renumbering regression (including the double-page abbreviated suffix), and both safety prohibitions asserted behaviorally
- Test runs hermetically with no ImageMagick installed, via a stub `identify` prepended to `PATH` per invocation, fixture root exclusively from `mktemp -d`

## Task Commits

Each task was committed atomically:

1. **Task 1: End-to-end "a dimension-detection failure is visible" — one path only** - `b6ab47e` (feat)
2. **Task 2: Expand coverage — zero-failure boundary, multi-failure count, and the no-regression guarantee** - `85e5649` (test)

**Plan metadata:** (this commit)

## Files Created/Modified
- `dev/manga/number-pages.zsh` - Error: prefix on the empty-dims branch, `dim_failures` counter, conditional summary clause
- `dev/manga/tests/test-number-pages.zsh` - New hermetic regression test (stub `identify`, 24 assertions across 5 scenarios)

## Decisions Made
None beyond what CONTEXT.md D-01 through D-04 already locked — plan executed as specified. The one open discretion point (exact wording of the failure clause; new counter vs. deriving from existing state) was resolved by the plan itself (`dim_failures`, "N dimension-detection failures") and implemented as written.

## Deviations from Plan

None — plan executed exactly as written. One observation, not a deviation: the plan's acceptance-criteria command `grep -c 'print' dev/manga/number-pages.zsh` returns `4`, not `0`, because it substring-matches the four pre-existing `printf` calls (lines 65, 126, 127, 135) that were already in the file before this phase and are untouched by it. The actual intent — the script keeps using `echo`, not the zsh `print` builtin, unchanged from before this phase — holds: `grep -cw 'print'` (word-boundary) or `grep -c '\bprint\b'` returns `0`, and no `print` builtin call was introduced. Not fixed, since fixing a verification-command wording issue isn't in scope for this task and the underlying behavior it was meant to check is correct.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- MANGA-01 satisfied; Phase 2 (Manga) has no further plans in its wave
- `dev/manga/` now has its first tracked test, matching PROJECT.md's testing constraint
- The plan's optional `<human-check>` (real ImageMagick against a genuinely corrupt file in a scratch copy of a real chapter) is deferred to end-of-phase verification, as the plan specifies — not required for this plan's completion

---
*Phase: 02-manga*
*Completed: 2026-08-06*

## Self-Check: PASSED

- FOUND: dev/manga/number-pages.zsh
- FOUND: dev/manga/tests/test-number-pages.zsh
- FOUND: b6ab47e (git log)
- FOUND: 85e5649 (git log)
