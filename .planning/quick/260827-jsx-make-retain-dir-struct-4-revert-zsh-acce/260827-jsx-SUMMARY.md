---
phase: quick-260827-jsx
plan: 01
subsystem: local-filesys
tags: [zsh, revert-tool, multi-root, overlap-guard, regression-suite]
status: complete
dependency-graph:
  requires: [LOCALFS-05 (Phase 04 revert tool)]
  provides: [retain-dir-struct-4-revert-multi.zsh flag interface]
  affects: [dev/local-filesys/README.md, external wrapper scripts on /media/enzief/wdhdd]
tech-stack:
  added: []
  patterns:
    - "zparseopts +:= repeated-flag arrays, stride-extracted by 2 to skip the alternating flag literal"
    - "three-axis overlap guard (shadow-vs-shadow, target-vs-target, shadow-vs-target) via a shared roots_overlap/reject_overlap helper pair"
    - "parallel shadow_files/shadow_roots arrays with an indexed main loop, so shadow_rel strips against the root each shadow actually came from"
key-files:
  created: []
  modified:
    - dev/local-filesys/retain-dir-struct-4-revert-multi.zsh (renamed from retain-dir-struct-4-revert.zsh, then rewritten to N-shadow/N-target flag interface)
    - dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh (renamed and rewritten, 26 case letters, 134 assertions)
    - dev/local-filesys/README.md
    - /media/enzief/wdhdd/mega_wdhdd/devicesync/_deviceshadow/iphone-F2LN2G1MFF9R/revert.zsh (outside this repo, not committed here)
    - /media/enzief/wdhdd/mega_wdhdd/devicesync/_deviceshadow/iphone-F2LN2G1MFF9R/revert-revert.zsh (outside this repo, not committed here)
decisions:
  - "Task ordering: rename-only commit, then RED test rewrite, then GREEN script rewrite, then README/wrapper updates -- keeps git rename detection intact and gives an honest, checkable RED state"
  - "shadow_rel stays root-relative via a parallel shadow_roots array rather than a single shared root; cross-root relative-path display collisions are accepted (the Swapped: line's absolute half remains traceable)"
  - "Overlap checking is a two-line helper (roots_overlap/reject_overlap) plus three explicit loops, one per axis, rather than one fused loop -- keeps each axis independently greppable and testable"
metrics:
  duration: ~55min
  completed: 2026-08-27
actuals:
  tokens: 9500
  tasks: 4
  commits: 4
---

# Phase quick-260827-jsx Plan 01: Multi-root retain-dir-struct-4-revert Summary

Generalized `retain-dir-struct-4-revert.zsh` from one shadow tree plus N target trees (positional args) to N shadow trees plus N target trees (repeated `--shadow`/`--target` flags), renamed it to `retain-dir-struct-4-revert-multi.zsh`, ported its 101-assertion regression suite to the new interface with 33 additional assertions covering multi-shadow discovery and two new overlap axes, and updated the README plus both out-of-repo wrapper scripts that drive it — collapsing `revert-revert.zsh`'s three-iteration loop into a single invocation.

## What Was Built

- **`dev/local-filesys/retain-dir-struct-4-revert-multi.zsh`** — renamed via `git mv` (history preserved, `git log --follow` reaches all pre-rename commits) then rewritten: `zparseopts -shadow+:=opt_shadow -target+:=opt_target -dry-run=opt_dryrun`, stride-by-2 extraction of the alternating flag/value arrays, a `usage()` guard covering empty `--shadow`, empty `--target`, and any leftover bare positional word, a per-root shadow-existence check, a `roots_overlap`/`reject_overlap` helper pair driving three explicit overlap loops (shadow-vs-shadow upper triangle, target-vs-target upper triangle, shadow-vs-target cross-product) placed before the target create-or-report block, and multi-root shadow discovery via a per-root `find` loop appending to parallel `shadow_files`/`shadow_roots` arrays consumed by an indexed main loop. Real-file resolution, mandatory hash verification, the two-`mv` swap, and rollback-on-partial-failure are unchanged.
- **`dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh`** — renamed then rewritten against the flag interface. All 19 ported case letters (A-D, F-I, K-S) keep their original assertions with invocations spelled out as explicit `--shadow`/`--target` flags. Case E is repurposed as three usage-error assertions (shadow-only, target-only, trailing positional). Case J is repurposed as the `--dry-run`-with-no-roots usage check. Seven new cases (T-Z) cover: multi-shadow discovery with per-root real-file placement and cross-root Ignored-tally aggregation (T); the shadow-vs-shadow overlap axis in equal, parent-first, and child-first forms (U); the target-vs-target overlap axis in equal and not-yet-existing-nested forms (V); a missing shadow root among several, proving the existence check fires before any traversal (W); the full multi-shadow↔multi-target round trip matching the real wrappers' shape, with hop 2 as a single 3-shadow invocation (X); flag-ordering independence (Y); and spaces surviving the `+:=` array extraction (Z). 134 total assertions, 0 failures.
- **`dev/local-filesys/README.md`** — workflow step 5, its usage block, the behavior subsection, and the script-3-vs-script-4 comparison bullet all renamed to `retain-dir-struct-4-revert-multi.zsh` with the new flag syntax. The overlapping-roots bullet now names all three axes and states rejection happens before any directory is created or file moved; a new bullet states every shadow tree must already exist while a missing target tree is created (or announced under `--dry-run`).
- **External wrapper scripts** (`/media/enzief/wdhdd/mega_wdhdd/devicesync/_deviceshadow/iphone-F2LN2G1MFF9R/revert.zsh` and `revert-revert.zsh`, outside this git repo) — both repointed at the renamed script. `revert.zsh` now builds a `target_args` array and invokes once with one `--shadow` flag and three `--target` flags. `revert-revert.zsh`'s former three-iteration loop (with its `failed` exit-code accumulator) is replaced by a single invocation carrying three `--shadow` flags (one per former target tree) and one `--target` flag (this directory) — verified via argv-capture against a throwaway stub, confirmed `rev_shadow=1 rev_target=3` and `rr_shadow=3 rr_target=1`, both with `--dry-run` correctly forwarded.

## Verification

- `zsh -n` passes on the script, the test file, and both external wrapper scripts.
- `./dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh`: 134 passed, 0 failed. All 26 case letters (A-Z) have non-zero assertion counts.
- `./dev/local-filesys/tests/test-retain-dir-struct.zsh` (sibling suite): unchanged at 29 passed, 0 failed.
- `git log --oneline --follow -- dev/local-filesys/retain-dir-struct-4-revert-multi.zsh` reaches commits predating this task (f2801bb, d1446b3, 3c0eab7, 70c930f).
- `dev/local-filesys/retain-dir-struct-4-revert.zsh` and its old test file no longer exist.
- Neither wrapper script nor the repo script was executed against any path under `/media/enzief/wdhdd/` — all wrapper verification used a throwaway argv-capture stub in a `mktemp -d` scratch directory; all script verification used the suite's `mktemp -d` fixtures.
- No file under `.planning/phases/` or `.planning/quick/` other than this task's own directory was modified (`git status --short .planning/` empty before this SUMMARY write).

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

### Notes

- **Worktree was 44 commits behind master with no unique commits of its own.** Before Task 1, the execution worktree branch was fast-forwarded onto master (`git merge --ff-only master`) to pick up Phase 04's completed `retain-dir-struct-4-revert.zsh` and its test, which did not yet exist in the worktree. No divergent history existed on the worktree branch, so the fast-forward was lossless and required no rebase or conflict resolution. Not a plan deviation under Rules 1-4 (no code change), recorded here for traceability since it is unusual environment state.
- File mode on both renamed files reads as `775` (group-writable) rather than the plan's assumed `755` — `git mv` preserved the mode unchanged in both cases; no re-chmod was performed, consistent with the plan's "confirm rather than re-chmod" instruction.
- The plan's Task 3 `<done>` narrative estimated `roots_overlap`/`reject_overlap` grep counts of "at least 7" each, based on an assumed two-calls-per-axis implementation. The shipped implementation uses one call per axis (3 call sites + 1 definition = 4 each), matching design decision D-jsx-3's "two-line helper plus three explicit loops" exactly. This is a documentation-narrative variance, not a functional gap — all structural gates that gate on exact/minimum values the plan treats as hard requirements (`zparseopts_multi=1`, `stride_extraction=2`, `shadow_abs_strict=1`, `target_abs_lenient=1`, `old_scalar_refs=0`, `mkdir_calls=1`, `existing_filter_finds=2`) matched exactly, and the full suite is 134/0 green.

## Known Stubs

None.

## Threat Flags

None — this plan closes out threats T-jsx-01 through T-jsx-12 already registered in the plan's own `<threat_model>`; no new security-relevant surface was introduced beyond what that register covers.

## Self-Check: PASSED

- `dev/local-filesys/retain-dir-struct-4-revert-multi.zsh` — FOUND
- `dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh` — FOUND
- `dev/local-filesys/README.md` — FOUND (modified)
- `/media/enzief/wdhdd/mega_wdhdd/devicesync/_deviceshadow/iphone-F2LN2G1MFF9R/revert.zsh` — FOUND (modified, outside repo)
- `/media/enzief/wdhdd/mega_wdhdd/devicesync/_deviceshadow/iphone-F2LN2G1MFF9R/revert-revert.zsh` — FOUND (modified, outside repo)
- Commit `7c5986b` (rename) — FOUND in `git log --oneline`
- Commit `f0909ad` (RED test) — FOUND in `git log --oneline`
- Commit `0fe5605` (GREEN script) — FOUND in `git log --oneline`
- Commit `64121e5` (README) — FOUND in `git log --oneline`
