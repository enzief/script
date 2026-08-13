---
phase: 03-remote
plan: 01
subsystem: remote
tags: [zsh, rclone, jq, process-substitution, preflight, testing]

# Dependency graph
requires:
  - phase: 01-local-filesystem
    provides: process-substitution loop convention and manual assert-style test pattern this plan reuses
provides:
  - Hermetic regression suite for dev/remote/ (dev/remote/tests/test-rename-remote-files.zsh, 35 assertions)
  - Process-substitution match loop in rename-remote-files-1-match-remote.zsh (consistency hardening, not a bug fix)
  - rclone/jq preflight checks on script 1, failing before any filesystem mutation
  - REMOTE_NAME/REMOTE_PATH required as environment variables, no hardcoded literal, no fallback
affects: [03-02 (REMOTE-03 shadow-file validation on rename-remote-files-2-rename-local.zsh)]

# Actuals (#2632)
actuals:
  tokens: 3760
  tasks: 2
  commits: 4

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Process-substitution match loop (`done < <(find ... -print0)`) applied to rename-remote-files-1-match-remote.zsh, matching the dev/local-filesys/ convention"
    - "Fixture-owned stub rclone prepended to PATH for hermetic testing, argv recorded to a fixture file for later assertion"
    - "GNU coreutils `env -u VAR` used to remove a single environment variable for one invocation, proving independent preflight checks"

key-files:
  created:
    - dev/remote/tests/test-rename-remote-files.zsh
  modified:
    - dev/remote/rename-remote-files-1-match-remote.zsh

key-decisions:
  - "D-01 honored: the diagnosed subshell bug does not exist in zsh (verified empirically); the loop conversion ships as hardening, not a fix"
  - "D-02 honored: size-collision behavior (first-write-wins into remote_map) left untouched, no warning added"
  - "D-03 honored: preflight dependency checks added to script 1 only; script 2 untouched"
  - "D-06 honored: REMOTE_NAME/REMOTE_PATH required from environment, no default, fail fast"

patterns-established:
  - "Preflight blocks (dependency checks, then required-env-var checks) sit between the argument-count check and the argument-to-path mapping, so a failed check never reaches realpath/mkdir/the manifest fetch"

requirements-completed: [REMOTE-01, REMOTE-02, REMOTE-04]

coverage:
  - id: D1
    description: "First hermetic regression suite for dev/remote/ proving the match->shadow->sync->revert pipeline end-to-end against a stubbed rclone manifest, plus process-substitution hardening of the match loop"
    requirement: "REMOTE-01"
    verification:
      - kind: integration
        ref: "dev/remote/tests/test-rename-remote-files.zsh (round-trip section, 20 assertions)"
        status: pass
    human_judgment: false
  - id: D2
    description: "rclone/jq preflight checks and required REMOTE_NAME/REMOTE_PATH environment configuration on script 1, both failing before any filesystem mutation, with no remote-name/path literal left in the file"
    requirement: "REMOTE-02"
    verification:
      - kind: integration
        ref: "dev/remote/tests/test-rename-remote-files.zsh (preflight + empty-input section, 15 assertions)"
        status: pass
    human_judgment: false
  - id: D3
    description: "No remote-name or remote-path literal remains in the file; both values are required from the environment and proven (via recorded stub argv) to actually reach the rclone invocation, not merely pass a presence check"
    requirement: "REMOTE-04"
    verification:
      - kind: integration
        ref: "dev/remote/tests/test-rename-remote-files.zsh (Round trip: rclone stub received the configured remote spec / stdout manifest-fetch line names the configured remote spec)"
        status: pass
    human_judgment: false

duration: 6min (Task 2 active work; Task 1 completed and committed in a prior session before a human-verify checkpoint)
completed: 2026-08-13
status: complete
---

# Phase 03 Plan 01: Remote Hermetic Test Suite + Preflight Hardening Summary

**First tracked test suite for `dev/remote/` (35 assertions, zero network access) plus `rclone`/`jq`/`REMOTE_NAME`/`REMOTE_PATH` preflight checks on script 1 that fail before any file is touched.**

## Performance

- **Duration:** Task 1 committed in a prior agent session (tracer + checkpoint); Task 2 took ~6 min of active work in this continuation session
- **Started:** 2026-08-13 (Task 1); resumed 2026-08-13T12:31Z (Task 2)
- **Completed:** 2026-08-13T12:35:43Z (Task 2 commit)
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments
- `dev/remote/tests/test-rename-remote-files.zsh` created: hermetic, cwd-independent, 35-assertion suite covering the full match -> shadow -> sync -> revert round trip, missing-tool preflight, missing-config preflight, no-mutation-on-failure, configuration reaching the rclone call, and both empty-input edges (empty source tree, manifest with zero file entries)
- `rename-remote-files-1-match-remote.zsh`'s match loop converted from a trailing-pipe-into-`while` to the process-substitution form used across `dev/local-filesys/`, body byte-identical (REMOTE-01, hardening per D-01 — the diagnosed subshell bug does not exist in zsh)
- Two preflight blocks added to script 1: `command -v rclone`/`command -v jq` checks, then required-nonempty checks for `REMOTE_NAME`/`REMOTE_PATH` — both sit before `realpath`, both `mkdir -p` calls, and the manifest fetch, so a failed preflight leaves the filesystem untouched (REMOTE-02, REMOTE-04)
- Hardcoded `REMOTE_NAME="mega"` / `REMOTE_PATH="devicesync/2019"` literals deleted; both are now required environment variables with no fallback, and the suite proves (via the recorded stub `rclone` argv) that the values actually reach the `rclone lsjson` call, not merely pass a presence check

## Task Commits

Each task was committed atomically:

1. **Task 1: End-to-end match/shadow/sync/revert round trip (tracer)** - `e475369` (feat) — completed in a prior session, verified via human-verify checkpoint (approved)
2. **Task 2: Preflight — fail before the first `mv` when a tool or the remote configuration is missing** - `fe91ec8` (feat)

**Plan metadata:** (this commit, following SUMMARY.md write)

## Files Created/Modified
- `dev/remote/tests/test-rename-remote-files.zsh` - hermetic regression suite for both remote scripts (created in Task 1, extended in Task 2)
- `dev/remote/rename-remote-files-1-match-remote.zsh` - process-substitution match loop (Task 1); rclone/jq/REMOTE_NAME/REMOTE_PATH preflight checks, hardcoded config literals removed, usage text updated (Task 2)

## Decisions Made
- D-01 (empirically re-verified before implementing, per plan `<environment_finding>`): the `remote_map` lookup was already correct in zsh — the Phase 1 misdiagnosis pattern recurred. The loop conversion shipped as hardening for consistency with `dev/local-filesys/`, not a functional fix.
- D-02: size-collision behavior (last-remote-file-for-a-given-size wins) left untouched — no sorting, no dedup, no warning, per the original author's already-acknowledged trade-off.
- D-03: dependency checks added to script 1 only (`rclone`, `jq` in that order — the suite's absence scenarios depend on this order). Script 2 calls neither tool and was not modified.
- D-06: `REMOTE_NAME`/`REMOTE_PATH` kept as unprefixed identifiers per the CONTEXT.md discretion note (minimal diff), now required with no default and no `:-` fallback anywhere.
- Test-only addition beyond the plan's explicit helper list: `env -u VAR` (GNU coreutils) used to remove exactly one of `REMOTE_NAME`/`REMOTE_PATH` per scenario, proving the two checks are independent rather than one check covering both — a mechanism detail needed to satisfy the plan's own acceptance criteria, not a scope change.

## Deviations from Plan

None - plan executed exactly as written. Both tasks' acceptance criteria were verified directly (grep counts, behavioral assertions, `git diff --stat` scope) and all matched the plan's specified values.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required. The plan's `<human-check>` verification item (running script 1/2 against the real MEGA remote on a scratch copy) is deferred to end-of-phase verification per `human_verify_mode: end-of-phase` in `.planning/config.json`, not part of this plan's automated scope.

## Next Phase Readiness
- REMOTE-01, REMOTE-02, REMOTE-04 closed for `rename-remote-files-1-match-remote.zsh`. REMOTE-03 (shadow-file variable validation in `rename-remote-files-2-rename-local.zsh`, D-04/D-05) remains for `03-02-PLAN.md`.
- The new suite's `run_s1`/`run_s2`/`make_stub_rclone`/`mkfile` fixture helpers and `TEST_REMOTE_NAME`/`TEST_REMOTE_PATH` values are available for `03-02` to extend in place — no rework needed, since Task 1 already supplied `REMOTE_NAME`/`REMOTE_PATH` to `run_s1` before Task 2 made them required.
- No blockers.

---
*Phase: 03-remote*
*Completed: 2026-08-13*

## Self-Check: PASSED

- FOUND: dev/remote/tests/test-rename-remote-files.zsh
- FOUND: dev/remote/rename-remote-files-1-match-remote.zsh
- FOUND: e475369 (Task 1 commit)
- FOUND: fe91ec8 (Task 2 commit)
