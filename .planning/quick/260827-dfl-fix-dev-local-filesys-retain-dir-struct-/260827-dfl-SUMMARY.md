---
phase: quick-260827-dfl
plan: 01
subsystem: local-filesys
tags: [zsh, find, realpath, mkdir, tdd]

# Dependency graph
requires:
  - phase: 04-local-filesys-revert-tool
    provides: dev/local-filesys/retain-dir-struct-4-revert.zsh (bidirectional shadow/real-file swap tool)
provides:
  - "retain-dir-struct-4-revert.zsh creates a not-yet-existing <target_tree> instead of aborting the whole invocation"
affects: [local-filesys]

# Actuals (#2632)
actuals:
  tokens: 3197
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "mkdir -p on a caller-supplied root only after the overlap guard has run, never before"
    - "realpath -m -- for lexical resolution of a root that may not exist yet, kept separate from a strict realpath -- on a root whose existence is a hard prerequisite"
    - "filtered array (TARGET_TREES_EXISTING) plus explicit (( ${#arr[@]} )) guard around every find invocation that takes that array as its path-argument list, preventing an empty argument list from making find silently scan the cwd"

key-files:
  created: []
  modified:
    - dev/local-filesys/retain-dir-struct-4-revert.zsh
    - dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh

key-decisions:
  - "Overlap guard runs before the create-or-report block (not after), so a target tree that resolves onto or into the shadow tree is rejected before mkdir ever runs on it -- prevents stray directory creation inside/onto the shadow tree on a rejected root"
  - "realpath -m -- used only for TARGET_TREES_ABS; SHADOW_TREE_ABS keeps plain realpath -- since shadow-tree existence remains a hard, unchanged prerequisite"

patterns-established:
  - "Empty-path-argument find guard: never expand an array as find's path arguments without first checking (( ${#arr[@]} )) -- find with zero path args searches the invoking shell's cwd instead of nothing"

requirements-completed: [LOCALFS-05]

coverage:
  - id: D1
    description: "Real run creates a missing target tree and proceeds with the swap instead of exiting 1"
    requirement: LOCALFS-05
    verification:
      - kind: unit
        ref: "dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh#Case O"
        status: pass
      - kind: manual_procedural
        ref: "live real run against /tmp/dfl-livecheck: 'Created target tree:' line printed, directory present after run, stderr empty, exit 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Dry run announces the would-be creation and leaves the filesystem byte-for-byte unchanged"
    requirement: LOCALFS-05
    verification:
      - kind: unit
        ref: "dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh#Case P"
        status: pass
      - kind: manual_procedural
        ref: "live dry run against /tmp/dfl-livecheck-dry: 'Would create target tree:' line printed, directory absent after run"
        status: pass
    human_judgment: false
  - id: D3
    description: "A run whose target trees are all missing performs no find traversal and never falls back to scanning the invoking shell's cwd"
    requirement: LOCALFS-05
    verification:
      - kind: unit
        ref: "dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh#Case Q"
        status: pass
    human_judgment: false
  - id: D4
    description: "Missing shadow tree still hard-errors in both modes; overlap guard still rejects an overlapping target root before it can be created"
    requirement: LOCALFS-05
    verification:
      - kind: unit
        ref: "dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh#Case R,S"
        status: pass
    human_judgment: false

duration: ~20min
completed: 2026-08-27
status: complete
---

# Quick Task 260827-dfl: Local-Filesys Revert Tool Missing-Target-Tree Fix Summary

**`retain-dir-struct-4-revert.zsh` now creates a not-yet-existing `<target_tree>` (real `mkdir -p`, or a preview line under `--dry-run`) instead of aborting the whole invocation, with the overlap guard and dry-run non-destructiveness contract both intact.**

## Performance

- **Duration:** ~20 min
- **Tasks:** 2 (RED test assertions, GREEN implementation)
- **Files modified:** 2

## Accomplishments
- Removed the target-tree existence rejection that previously forced a manual `mkdir -p` before every first-time swap into a new tree
- Overlap guard now runs strictly before the create-or-report block, so a rejected root (nested under/over the shadow tree) is never mkdir'd, whether or not it already existed
- `realpath -m --` on target roots keeps the overlap comparison meaningful for roots that don't exist yet, without weakening it (shadow tree keeps plain, strict `realpath --`)
- Both `find` traversal sites (name-index build, basename-collision rescan) now route through `TARGET_TREES_EXISTING`, guarded by `(( ${#TARGET_TREES_EXISTING[@]} ))`, so a run where every target tree is missing performs zero traversals instead of silently scanning the invoking shell's cwd
- Added 27 new regression assertions (Cases O through S) to the existing 74-assertion suite, covering creation, dry-run non-creation, the cwd-fallback hazard, the unchanged shadow-tree hard error, and overlap-guard-before-create ordering

## Task Commits

Each task was committed atomically:

1. **Task 1: Add RED regression assertions for target-tree creation, dry-run non-creation, and guard survival** - `22e1232` (test)
2. **Task 2: Create missing target trees, resolve them lexically, and filter both find traversals** - `f2801bb` (feat)

_TDD plan: RED (test) then GREEN (feat), as required._

## Files Created/Modified
- `dev/local-filesys/retain-dir-struct-4-revert.zsh` - dropped target-tree existence rejection; overlap guard now uses `realpath -m --`; added create-or-report block after the overlap guard; added `TARGET_TREES_EXISTING` filtered array with guarded `find` traversals
- `dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh` - added Cases O-S (27 new assertions) covering real-run creation, dry-run preview, cwd-fallback-hazard, shadow-tree hard error, and overlap-guard ordering

## Decisions Made
- Overlap guard placed before the create block (not after) per the plan's `<design_decision>`: prevents mutating disk (creating a directory nested inside/onto the shadow tree) before a fatal validation failure, and keeps the error path's stdout empty for `assert_stderr_and_exit`-style assertions.
- `realpath -m --` applied only to target roots; shadow-tree resolution stays strict since shadow-tree existence remains a hard prerequisite unrelated to this fix.

## Deviations from Plan

**Worktree branch was stale.** The execution worktree's branch (`worktree-agent-a71daebd8485476d3`) was forked before Phase 03/04 landed on `master` and did not contain `retain-dir-struct-4-revert.zsh` or its test file at all. Verified the worktree branch was a strict ancestor of `master` (`git merge-base --is-ancestor HEAD master`) and fast-forwarded (`git merge --ff-only master`) to bring in the missing files before starting Task 1. No task-scope changes; this is environment setup, not a plan deviation under Rules 1-4.

**SUMMARY.md written to worktree path, not the shared-checkout path named in the task prompt.** The task prompt specified the shared-checkout absolute path (`/home/enzief/work/iswi/script/.planning/quick/...`), but the Write tool enforces worktree isolation and refuses writes outside `/home/enzief/work/iswi/script/.claude/worktrees/agent-a71daebd8485476d3/`. This SUMMARY.md was written at the equivalent path inside the worktree instead; the orchestrator will need to pick it up from there (the same constraint that made the branch fast-forward necessary in the first place, since `.planning/quick/260827-dfl-.../260827-dfl-PLAN.md` itself only exists in the shared checkout, not in this worktree).

Otherwise: None - plan executed exactly as written.

## Issues Encountered
None - all verification gates (RED assertion counts, static-analysis grep gates, full suite reruns, sibling suite, live real/dry-run checks) passed on the first attempt for each task.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
No blockers. `retain-dir-struct-4-revert.zsh` and its test suite (101 assertions, 0 failed) are in a clean, fully green state. Sibling suite (`test-retain-dir-struct.zsh`, 29 assertions) confirmed unaffected.

## Self-Check: PASSED

- FOUND: dev/local-filesys/retain-dir-struct-4-revert.zsh
- FOUND: dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh
- FOUND: commit 22e1232 (test)
- FOUND: commit f2801bb (feat)

---
*Quick task: 260827-dfl*
*Completed: 2026-08-27*
