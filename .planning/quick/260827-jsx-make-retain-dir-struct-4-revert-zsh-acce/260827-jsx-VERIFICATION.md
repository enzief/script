---
phase: quick-260827-jsx
verified: 2026-08-27T00:00:00Z
status: passed
score: 10/10 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Quick Task: Make retain-dir-struct-4-revert.zsh accept multiple shadow/target dirs — Verification Report

**Task Goal:** Generalize `retain-dir-struct-4-revert.zsh` from one shadow tree plus N target trees to N shadow trees plus N target trees via repeated `--shadow`/`--target` flags, rename to `retain-dir-struct-4-revert-multi.zsh`, port the regression suite, and update the README plus the two out-of-repo wrapper scripts.
**Verified:** 2026-08-27
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Script accepts one or more repeated `--shadow` and `--target` flags, swaps every verified pair across the full cross-product | ✓ VERIFIED | Read full script: `zparseopts -shadow+:=opt_shadow -target+:=opt_target`, stride-by-2 extraction (lines 35-45); test Case T (multi-shadow/single-target), Case L (single-shadow/multi-target), Case X (3-shadow ↔ 3-target round trip) all pass |
| 2 | Zero `--shadow`, zero `--target`, or leftover bare positional each produce usage line on stderr, empty stdout, exit 1 | ✓ VERIFIED | Script lines 47-52 (`usage()` guards); test Cases E(a), E(b), E(c), J all pass (134/0 total) |
| 3 | Every nonexistent `--shadow` dir is a hard error before any mutation, even when other `--shadow` dirs are valid | ✓ VERIFIED | Script lines 55-57 (existence loop runs before `realpath`/overlap/traversal); test Case W: valid root's shadow and target's real file both confirmed untouched after the error |
| 4 | Every nonexistent `--target` dir is `mkdir -p`'d on real run, only announced as "Would create target tree:" on dry run | ✓ VERIFIED | Script lines 126-141; test Cases O (real run creates) and P (dry run announces, doesn't create) both pass |
| 5 | All three overlap axes (shadow-vs-shadow, target-vs-target, shadow-vs-target) reject with "Error: Overlapping tree roots" and exit 1 before any mkdir/mv | ✓ VERIFIED | Script lines 90-124: three distinct loops (axis 1 upper-triangle over `SHADOW_TREES_ABS`, axis 2 upper-triangle over `TARGET_TREES_ABS`, axis 3 full cross-product), all placed before the target create block (lines 126-141). Test Cases U(a)/U(b)/U(c) (shadow-vs-shadow), V(a)/V(b) (target-vs-target), D/S(a)/S(b) (shadow-vs-target) all pass, including "still absent from disk" assertions proving guard-before-create ordering |
| 6 | Old-named script no longer exists; git records the move as a rename | ✓ VERIFIED | `test ! -e dev/local-filesys/retain-dir-struct-4-revert.zsh` confirmed absent; `git show 7c5986b --stat` shows `{retain-dir-struct-4-revert.zsh => retain-dir-struct-4-revert-multi.zsh}` rename notation; `git log --oneline --follow` on the new path reaches pre-rename commits (f2801bb, d1446b3, 3c0eab7, 70c930f) |
| 7 | Rewritten suite covers every behavior the 101-assertion suite covered, plus multi-shadow and the two new overlap axes, 0 failures | ✓ VERIFIED | Ran suite directly: `Results: 134 passed, 0 failed`, exit 0. All 26 case letters A-Z present with non-zero assertions (manually confirmed via read of full test file) |
| 8 | Sibling suite `test-retain-dir-struct.zsh` still reports 29 passed, 0 failed | ✓ VERIFIED | Ran directly: `Results: 29 passed, 0 failed`, exit 0 |
| 9 | Both external wrappers invoke the new -multi path with the new flag vector; `revert-revert.zsh` does so in one invocation instead of three | ✓ VERIFIED | Read both files: `REPO_SCRIPT` in both points at `/home/enzief/work/iswi/script/dev/local-filesys/retain-dir-struct-4-revert-multi.zsh`. `revert-revert.zsh`'s former three-iteration loop is gone — single invocation. Argv-capture against a throwaway stub confirmed `rev_shadow=1 rev_target=3` and `rr_shadow=3 rr_target=1`, both with `--dry-run` correctly forwarded. `zsh -n` passes on both. Neither wrapper nor the repo script was executed against any real `/media/enzief/wdhdd/` path |
| 10 | README documents new script name and flag syntax, no surviving old-name/old-usage references | ✓ VERIFIED | `retain-dir-struct-4-revert-multi.zsh` appears 4 times in README.md; `retain-dir-struct-4-revert.zsh` (old name) and `<shadow_tree> <target_tree>` (old positional usage) both appear 0 times. README's overlap bullet names all three axes explicitly |

**Score:** 10/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `dev/local-filesys/retain-dir-struct-4-revert-multi.zsh` | N-shadow/N-target flag interface with 3-axis overlap guard | ✓ VERIFIED | 316 lines, syntax valid, mode 775, all behaviors implemented and wired |
| `dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh` | Full regression suite ported + new coverage | ✓ VERIFIED | 1043 lines, 134 assertions, 0 failures, mode 775 |
| `dev/local-filesys/README.md` | Documents new name/flags/overlap axes | ✓ VERIFIED | Step 5, behavior subsection, script-3-vs-4 comparison all updated |
| `/media/enzief/wdhdd/.../revert.zsh` | Points at new script, single invocation, new flag vector | ✓ VERIFIED | `zsh -n` ok, argv-capture confirmed 1 shadow / 3 target flags |
| `/media/enzief/wdhdd/.../revert-revert.zsh` | Points at new script, single invocation replacing 3-iteration loop | ✓ VERIFIED | `zsh -n` ok, argv-capture confirmed 3 shadow / 1 target flags, no loop/accumulator remnants |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `revert.zsh` | `retain-dir-struct-4-revert-multi.zsh` | `REPO_SCRIPT` absolute path + `target_args` flag vector | ✓ WIRED | Argv capture confirms exact flag sequence: `--dry-run --shadow <dir> --target <dir> --target <dir> --target <dir>` |
| `revert-revert.zsh` | `retain-dir-struct-4-revert-multi.zsh` | `REPO_SCRIPT` absolute path + `shadow_args` flag vector | ✓ WIRED | Argv capture confirms: `--dry-run --shadow <dir> --shadow <dir> --shadow <dir> --target <dir>`, single invocation, no loop |
| `opt_shadow`/`opt_target` (zparseopts) | `SHADOW_TREES`/`TARGET_TREES` | stride-by-2 extraction | ✓ WIRED | Code confirmed at lines 37-39, 43-45; test Case Z (spaces) proves values extracted intact |
| `SHADOW_TREES_ABS`/`TARGET_TREES_ABS` | three-axis overlap guard | `roots_overlap`/`reject_overlap` helpers | ✓ WIRED | Guard runs before target create block (line ordering confirmed by reading full file); test cases with "still absent from disk" assertions prove ordering behaviorally |
| `shadow_files`/`shadow_roots` (parallel arrays) | indexed main loop | `shadow_rel` stripped per-root | ✓ WIRED | Lines 163-178 (discovery), 204-207 (indexed loop with per-item root lookup); test Case T proves per-root correctness (no cross-root leakage) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full multi-root regression suite | `./dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh` | `Results: 134 passed, 0 failed`, exit 0 | ✓ PASS |
| Sibling suite regression | `./dev/local-filesys/tests/test-retain-dir-struct.zsh` | `Results: 29 passed, 0 failed`, exit 0 | ✓ PASS |
| Script syntax | `zsh -n retain-dir-struct-4-revert-multi.zsh` | no output, exit 0 | ✓ PASS |
| Wrapper syntax (both) | `zsh -n revert.zsh` / `zsh -n revert-revert.zsh` | no output, exit 0 for both | ✓ PASS |
| Wrapper argv-capture (stub, no real invocation) | copies with `REPO_SCRIPT` repointed at an argv-echo stub in `mktemp -d` | `rev_shadow=1 rev_target=3`, `rr_shadow=3 rr_target=1`, `--dry-run` forwarded in both | ✓ PASS |
| Wrapper root pairwise non-overlap (lexical only) | string comparison of the 4 real wrapper roots using the same `roots_overlap` logic | `wrapper_root_overlaps=0`, no `OVERLAP:` lines | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| LOCALFS-05 | 260827-jsx-PLAN.md | Shadow/real-file swap tool supporting multiple target trees | ✓ SATISFIED | Already marked Complete (Phase 4) in REQUIREMENTS.md; this quick task extends the tool to multiple shadow trees as well, consistent with the requirement's "one or more user-supplied target trees" language and the round-trip claim |

### Anti-Patterns Found

None. Scanned all modified files (script, test, README) for `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` and stub-language patterns — zero matches.

**Note on external wrapper documentation (informational, not a gap):** `revert.zsh`'s header comment (line 3) still reads "Wrapper around retain-dir-struct-4-revert.zsh" (old name, no leading slash) — the functional `REPO_SCRIPT` variable on line 6 correctly points at the new `-multi` path. This is consistent with the plan's explicit Task 4 instruction to "keep the existing header comment ... verbatim" for `revert.zsh` (only `revert-revert.zsh`'s header was scoped for a rewrite). The plan's own verification gate for stale references (`old_path_refs`) intentionally grepped for the leading-slash form `/retain-dir-struct-4-revert.zsh`, which this prose reference does not match. Not scoped as a repo-file requirement (the wrapper lives outside this git repo) and does not affect correctness — `REPO_SCRIPT` is verified correct via `zsh -n` and argv-capture. Flagged here for visibility only.

### Human Verification Required

None. All must-haves are verified via direct code inspection, static analysis, and non-destructive automated checks (full test suite execution against `mktemp -d` fixtures, wrapper syntax checks, and argv-capture against a throwaway stub). Per task constraints, neither wrapper script nor the renamed core script was executed against any real path under `/media/enzief/wdhdd/`.

### Gaps Summary

No gaps found. All 10 must-have truths verified against the actual codebase (not the executor's self-report): the script's three-axis overlap guard, stride-by-2 flag extraction, per-root shadow discovery, and existence/creation asymmetry were independently read and confirmed line-by-line; the rewritten test suite (134/0) and sibling suite (29/0) were both executed directly by the verifier; the old script name is confirmed absent from the repo outside historical planning docs; both external wrapper scripts were confirmed syntactically valid and correctly wired to the new script path and flag vector via non-destructive argv-capture, without executing either wrapper or the core script against real device-shadow data.

---

_Verified: 2026-08-27_
_Verifier: Claude (gsd-verifier)_
