---
phase: 01-local-filesystem
verified: 2026-08-05T19:18:36Z
status: passed
score: 16/17 must-haves verified
behavior_unverified: 0
overrides_applied: 0
behavior_unverified_items: []
human_verification:

  - test: "Interrupt retain-dir-struct-2-sorted.zsh mid-run (Ctrl-C) against a real fixture tree, then re-run the identical command over the same inputs; separately, run two instances concurrently against the same new-shadow-root target."
    expected: "Interrupted run leaves a partially-populated new shadow tree with no rollback (accepted, not a bug); re-running the same command is idempotent because cp overwrites identical content; concurrent runs writing the same new shadow root are not claimed safe (accepted risk, single-user tool per T-01-04 in 01-01-PLAN.md's threat model)."
    why_human: "This is a `verification: backstop` truth in 01-01-PLAN.md's must_haves — explicitly non-inferable from static code inspection. It describes accepted behavior/risk (interrupt safety, idempotency, concurrency) that requires live process interruption and concurrent execution to observe, which a verifier must not simulate via grep/presence checks alone."
---

# Phase 1: Local Filesystem Verification Report

**Phase Goal:** `local-filesys` scripts behave correctly and consistently
**Verified:** 2026-08-05T19:18:36Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Note on phase mode

ROADMAP.md marks this phase `Mode: mvp`, but the phase goal text (`` `local-filesys` scripts behave correctly and consistently ``) does not match the User Story format (`As a ..., I want to ..., so that ....`) required for MVP-mode verification — confirmed via `gsd-tools query user-story.validate` returning `false`. Per the MVP-mode verification guard, this report does **not** attempt a User Flow Coverage table against a non-conforming goal; it falls back to standard goal-backward verification using ROADMAP Success Criteria (the roadmap contract, always authoritative per Step 2a) merged with both plans' `must_haves` frontmatter. This mismatch is worth the developer's attention (run `/gsd mvp-phase 1` to reformat the goal, or clear the `mode: mvp` flag) but is a metadata/process issue, not a code-correctness gap, so it does not affect the status below.

## Important: verified against POST-REVIEW-FIX code, not the SUMMARYs' original claims

Both SUMMARY.md files describe the state of the code as of their own commits (`d81731a`/`804b126` for plan 01-01, `32dcc06`/`3f5fda9`/`70aa32b` for plan 01-02). A code-review cycle ran afterward (`01-REVIEW.md`) and found two critical correctness bugs plus one warning, all fixed in three follow-up commits (`ef1fa12`, `9b1bf6b`, `9802246`, documented in `01-REVIEW-FIX.md`). This report verifies the **current working tree**, confirming all three fixes are actually present and functioning, not just claimed:

- **CR-01** (scripts 1 & 2 reported false success on a missing source directory) — confirmed fixed by direct execution below.
- **CR-02** (`--dry-run` still created the destination root directory and printed a "Done! ... created" message) — confirmed fixed by direct execution below.
- **WR-01** (`retain-dir-struct-1.zsh` was left on `find | while` while its siblings were converted to process substitution) — confirmed fixed; `retain-dir-struct-1.zsh` now uses `done < <(find ...)`.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Script 2 (`retain-dir-struct-2-sorted.zsh`) hash matching via `shadow_map` works correctly end-to-end (ROADMAP SC1; plan 01-01 T1) | ✓ VERIFIED | Test suite: `Matched & Placed: fileA-renamed.txt` + shadow file exists under new root (2 PASS). Manually re-ran: real fixture run produces matches. |
| 2 | Script 2 `--dry-run` previews without mutating the filesystem, including not creating the destination root dir and not printing a false "created" message (plan 01-01 T2 + prohibition "MUST NOT create/copy/modify/delete"; closes CR-02) | ✓ VERIFIED | Test suite: `Would copy:`, no `Matched & Placed:`, zero files under dry-run root (3 PASS). Manual direct execution (post-fix): `--dry-run` against fresh temp dirs prints "Dry run complete. No files were copied." and the destination directory is **not** created (`DIR NOT CREATED (GOOD)`). |
| 3 | Script 2 emits all output via `print -r --`, zero `echo` calls remain, both 52-dash separators survive | ✓ VERIFIED | `grep -cE 'echo[[:space:]]'` (excluding comments) = 0. Test asserts exactly two 52-dash lines (1 PASS). |
| 4 | Both `find`-driven loops in script 2 use process substitution, no longer depend on zsh's last-pipeline-element rule | ✓ VERIFIED | `grep -cE 'done < <\(find'` = 2 (was 1); `find .* \| while` count = 0. |
| 5 | A tracked, runnable test file exists that fails if hash matching regresses, and covers all three scripts | ✓ VERIFIED | `dev/local-filesys/tests/test-retain-dir-struct.zsh`, 341 lines, 29 assertions, executable, committed. Ran from repo root and from `/tmp`: both exit 0, 29 passed / 0 failed. SUMMARY documents independently reproduced red-then-green verification for each of 5 seeded regressions across both plans. |
| 6 | Duplicate content in script 2 (two source files, same hash): both destinations still receive a shadow file (last-writer-wins on the winning original path) | ✓ VERIFIED | Test asserts both `fileA-renamed.txt.txt` and `fileA-dup-renamed.txt.txt` exist (2 PASS). |
| 7 | Empty inputs to script 2: exits 0, creates the new shadow root, no crash | ✓ VERIFIED | Test: empty-inputs run exits 0, new shadow root created (2 PASS). |
| 8 | Scripts 1 and 2 fail fast with a clear stderr error when a required source directory does not exist, instead of silently reporting success (closes CR-01) | ✓ VERIFIED | Manual direct execution (post-fix): script 1 against nonexistent source → `Error: Source dir not found.` on stderr, exit 1, no stdout. Script 2 against nonexistent old-shadow dir → `Error: Old shadow dir not found.` on stderr, exit 1, no stdout. |
| 9 | Script 3 (`retain-dir-struct-3-find-sorted.zsh`) hash matching via `file_map` works correctly end-to-end, prints `SHADOW:`/`REAL  :` pairs with absolute real paths (ROADMAP SC2; plan 01-02 T10) | ✓ VERIFIED | Test: `SHADOW: f1.txt.txt` + `REAL  : <realpath>` (2 PASS); round-trip section resolves script-1-created shadows back to originals (2 PASS). |
| 10 | Script 3 emits all output via `print -r --` (zero `echo`), usage and both validation errors routed to stderr | ✓ VERIFIED | `grep -cE 'echo[[:space:]]'` = 0. Manual: nonexistent shadow dir → error text on stderr only, exit 1 (also test-asserted, 1 PASS). |
| 11 | Script 3's lookup loop uses process substitution | ✓ VERIFIED | `grep -cE 'done < <\(find'` in script 3 = 2 (index loop + lookup loop); no `find \| while` remains. |
| 12 | Script 3 remains a read-only diagnostic — no file-mutating commands added | ✓ VERIFIED | `grep -cE '(cp\|mv\|rm)[[:space:]]'` (excluding comments) = 0. Test: data tree file count and hash unchanged after a run (1 PASS). |
| 13 | Script 3 duplicate-content and empty-input handling correct | ✓ VERIFIED | Test: duplicate content collapses to exactly one `REAL  :` line (1 PASS); empty inputs exit 0 with no `SHADOW:` line (2 PASS). |
| 14 | Script 1 (`retain-dir-struct-1.zsh`) emits all output via `print`, zero `echo` calls remain, usage routed to stderr (ROADMAP SC3) | ✓ VERIFIED | `grep -cE 'echo[[:space:]]'` = 0. Manual + test: zero-arg invocation → `Usage: ` on stderr only, exit 1 (1 PASS). Three-dash separator survives (1 PASS). |
| 15 | Script 1 now also uses process substitution for its `find` loop (post-summary fix WR-01, closing the inconsistency the code review flagged against the phase's own stated goal) | ✓ VERIFIED | `grep -cE 'done < <\(find'` in script 1 = 1; `find \| while` count = 0. Confirmed by reading current file content directly. |
| 16 | Test fixture teardown is guarded — never deletes a path it didn't create itself via `mktemp -d` | ✓ VERIFIED | `dev/local-filesys/tests/test-retain-dir-struct.zsh`: `FIXROOT=$(mktemp -d)` checked non-empty and a real directory before use; single `trap cleanup EXIT INT TERM`; `cleanup()` re-checks `-n "$FIXROOT" && -d "$FIXROOT"` before `rm -rf --`. `git status --porcelain` after a run shows no stray files under `dev/local-filesys/`. |
| 17 | An interrupted run leaves a partially-populated shadow tree with no rollback (accepted); re-running the same command is idempotent; concurrent runs against the same target are not guaranteed safe (plan 01-01, `verification: backstop`) | ⚠️ Needs human confirmation | Explicitly marked `verification: backstop` in 01-01-PLAN.md must_haves — describes runtime interrupt/concurrency behavior that cannot be inferred from static code inspection. See Human Verification section. |

**Score:** 16/17 truths verified (1 routed to human verification per its own `backstop` classification)

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `dev/local-filesys/retain-dir-struct-2-sorted.zsh` | Hash-matched shadow sync, `--dry-run`, print-only, process-substitution loops | ✓ VERIFIED | Exists, substantive, wired into test file. `verify.artifacts` tool: passed. |
| `dev/local-filesys/retain-dir-struct-3-find-sorted.zsh` | Read-only hash lookup, print-only, process-substitution loop | ✓ VERIFIED | Exists, substantive, wired into test file. `verify.artifacts` tool: passed. |
| `dev/local-filesys/retain-dir-struct-1.zsh` | Shadow map creation, print-only output | ✓ VERIFIED | Exists, substantive, wired into test file. `verify.artifacts` tool: passed. |
| `dev/local-filesys/tests/test-retain-dir-struct.zsh` | Tracked regression test covering all three scripts, ≥70 lines | ✓ VERIFIED | 341 lines, 29 assertions, executable, committed, `verify.artifacts` tool: passed. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `tests/test-retain-dir-struct.zsh` | `retain-dir-struct-2-sorted.zsh` | invokes script, greps output/shadow tree | ✓ WIRED | `SCRIPT2="$LOCALFS_DIR/retain-dir-struct-2-sorted.zsh"` at line 16; invoked and asserted against throughout. (Automated `verify.key-links` tool reported a false negative here due to a regex-escaping artifact in its own pattern string — manually confirmed via direct grep.) |
| `retain-dir-struct-2-sorted.zsh` | `shadow_map` lookup | process-substitution loop reads `shadow_map` populated in the current shell | ✓ WIRED | `done < <(find "$OLD_SHADOW" ...)` at line 40 populates `shadow_map`; `done < <(find "$REORG_DIR" ...)` at line 70 reads it — both in the current shell, same associative array. |
| `tests/test-retain-dir-struct.zsh` | `retain-dir-struct-3-find-sorted.zsh` | invokes script, greps SHADOW/REAL pairs | ✓ WIRED | `SCRIPT3="$LOCALFS_DIR/retain-dir-struct-3-find-sorted.zsh"` at line 18; invoked and asserted against in the script-3 and round-trip sections. |
| `retain-dir-struct-3-find-sorted.zsh` | `file_map` lookup | lookup loop reads `file_map` populated by the index loop, process substitution | ✓ WIRED | `done < <(find "$DATADIR" ...)` at line 30 populates `file_map`; `done < <(find "$SHADOWDIR" ...)` at line 51 reads it. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full regression suite (29 assertions) from repo root | `./dev/local-filesys/tests/test-retain-dir-struct.zsh` | `Results: 29 passed, 0 failed`, exit 0 | ✓ PASS |
| Full regression suite from a different cwd | `cd /tmp && .../test-retain-dir-struct.zsh` | `Results: 29 passed, 0 failed`, exit 0 | ✓ PASS |
| CR-01 fix: script 1 against missing source dir | `./retain-dir-struct-1.zsh /tmp/does_not_exist /tmp/out` | stderr `Error: Source dir not found.`, exit 1, empty stdout | ✓ PASS |
| CR-01 fix: script 2 against missing old-shadow dir | `./retain-dir-struct-2-sorted.zsh reorg no_old_shadow new` | stderr `Error: Old shadow dir not found.`, exit 1, empty stdout | ✓ PASS |
| CR-02 fix: `--dry-run` does not create destination root | `./retain-dir-struct-2-sorted.zsh --dry-run reorg2 old_shadow2 new_dry` | exit 0, prints "Dry run complete. No files were copied.", `new_dry` directory not created | ✓ PASS |
| Unrecognized flag rejected | `./retain-dir-struct-2-sorted.zsh --bogus a b c` | exit 1 (zparseopts internal message on stderr — see IN-02 below) | ✓ PASS (functionally; message format is an unfixed Info-level nit) |
| Zero `echo` calls across all three scripts | `grep -cE 'echo[[:space:]]'` per file (excluding comments) | `0`, `0`, `0` | ✓ PASS |
| Process-substitution loops present in all three scripts | `grep -cE 'done < <\(find'` per file | 1 (script 1), 2 (script 2), 2 (script 3) | ✓ PASS |
| Script 3 stays free of mutating commands | `grep -cE '(cp\|mv\|rm)[[:space:]]'` | `0` | ✓ PASS |
| Working tree clean after test run | `git status --porcelain -- dev/local-filesys/` | no output | ✓ PASS |
| All referenced commits exist | `git cat-file -e <hash>` for 8 commits | all `OK` | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| LOCALFS-01 | 01-01-PLAN.md | Fix (reframed as harden) `shadow_map` lookup subshell dependency in script 2 | ✓ SATISFIED | Process substitution confirmed (truth #4); matching confirmed via test + manual run (truth #1). |
| LOCALFS-02 | 01-02-PLAN.md | Fix (reframed as harden) `file_map` lookup subshell dependency in script 3 | ✓ SATISFIED | Process substitution confirmed (truth #11); matching confirmed via test + manual run (truth #9). |
| LOCALFS-03 | 01-02-PLAN.md | Script 1 uses `print` consistently, no `echo` | ✓ SATISFIED | Zero `echo` calls confirmed (truth #14); ROADMAP SC3 directly satisfied. |

No orphaned requirements: `.planning/REQUIREMENTS.md` maps exactly LOCALFS-01/02/03 to Phase 1, and both plans' frontmatter `requirements:` fields together cover the same three IDs.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `dev/local-filesys/tests/test-retain-dir-struct.zsh` | whole file | Does not exercise CR-01 (missing-source-dir validation on scripts 1/2) or CR-02 (`--dry-run` not creating destination root / correct final message) | ⚠️ Warning | Both behaviors were confirmed correct by this verification's manual spot-checks, but neither is locked by the automated regression suite. `01-REVIEW.md` flagged this itself as IN-03 and it was explicitly excluded from the fix pass's scope (Info-level, 4 Info findings excluded per `01-REVIEW-FIX.md`). A future edit could silently reintroduce either bug with the test suite staying green. Recommend a follow-up plan or quick-fix to add these two assertion groups, mirroring the existing `assert_stderr_and_exit` pattern already used for script 3. |
| `dev/local-filesys/retain-dir-struct-2-sorted.zsh` | 3 | Header comment usage string doesn't mention `--dry-run` (disagrees with the actual `print -u2` usage text on line 12) | ℹ️ Info | Cosmetic only (`01-REVIEW.md` IN-01, unfixed, explicitly Info-level and out of fix scope). |
| `dev/local-filesys/retain-dir-struct-2-sorted.zsh` | 6 | `zparseopts -F` on an unrecognized flag prints its own internal message (`...:zparseopts:6: bad option: --bogus`) to stderr instead of a project-style `Error:`/`Usage:` line | ℹ️ Info | Functionally correct (still exits 1), just format-inconsistent with the rest of the codebase (`01-REVIEW.md` IN-02, unfixed, explicitly Info-level and out of fix scope). |
| — | — | No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers found in any of the four phase files | — | Clean |

## Human Verification Required

### 1. Interrupt / idempotency / concurrency behavior of `retain-dir-struct-2-sorted.zsh`

**Test:** Start a real run of `retain-dir-struct-2-sorted.zsh` against a fixture tree with enough files that it takes a few seconds, interrupt it with Ctrl-C partway through, then re-run the identical command over the same inputs. Separately, start two instances of the script concurrently against the same new-shadow-root target.

**Expected:** The interrupted run leaves a partially-populated new shadow tree with no rollback (this is accepted, not a bug — the script has no transaction/rollback mechanism). The re-run is idempotent: `cp` overwrites existing shadow files with identical content, so re-running to completion produces the same final state as an uninterrupted run. Concurrent runs against the same target are not claimed safe (accepted risk for a single-user local tool per `01-01-PLAN.md`'s threat register, T-01-04).

**Why human:** This truth is explicitly marked `verification: backstop` in `01-01-PLAN.md`'s `must_haves.truths` — the plan itself flags it as non-inferable from static code inspection. It describes live-process interrupt timing and concurrent filesystem access, which cannot be safely or meaningfully simulated by grep/presence checks. Per the verifier's `insufficient_spec` handling for backstop truths, this is surfaced rather than assumed true or false.

## Gaps Summary

No blocking gaps. All 16 statically/dynamically verifiable truths pass, including the two post-review critical fixes (CR-01, CR-02) and the one warning fix (WR-01) — all three confirmed present and functioning in the current working tree, not just claimed in SUMMARY.md. The one remaining item (#17, backstop-classified interrupt/idempotency/concurrency behavior) is routed to human verification per its own explicit non-inferable classification, not because any check failed.

One warning-level (non-blocking) finding: the regression test suite does not yet cover the two critical-bug fixes applied during code review (CR-01, CR-02), a gap the review itself flagged (IN-03) and explicitly deferred. The behaviors are manually confirmed correct as of this verification, but nothing prevents a future regression from going undetected by the automated suite. Recommend closing this in a follow-up quick-fix.

Two cosmetic Info-level findings (stale usage comment, non-project-style `zparseopts` error message) remain unfixed by design (excluded from the review-fix scope) and do not affect correctness.

---

_Verified: 2026-08-05T19:18:36Z_
_Verifier: Claude (gsd-verifier)_
