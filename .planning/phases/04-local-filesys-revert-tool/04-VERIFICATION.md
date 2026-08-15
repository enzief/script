---
phase: 04-local-filesys-revert-tool
verified: 2026-08-15T00:00:00Z
status: passed
score: 14/14 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 4: Local Filesystem Revert Tool Verification Report

**Phase Goal:** Build a symmetric shadow-swap workflow for `dev/local-filesys/`: a "home" tree holds real files at some paths and hash-only shadow placeholders at others (for files currently living in one or more arbitrary, user-supplied "target" trees). `revert` pulls files matching home's shadows back into home, swapping the shadow out to the target tree at the exact spot the file came from; `revert-revert` performs the identical swap in reverse for a true round trip — no location metadata is ever stored, only name+hash matching. This completes the gap the `retain-dir-struct-*.zsh` pipeline (1/2/3) has always had: none of those scripts ever `mv`/relocate real data files, only read/index them.
**Verified:** 2026-08-15
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Unique-name match swap: real file moves to shadow's exact path, shadow moves to real file's vacated path | ✓ VERIFIED | `retain-dir-struct-4-revert.zsh:96-186` (two-`mv` sequence); Test Case A/F confirm both destinations, suite run: `Case F: ok.jpg real file lands at home tree` etc. all PASS |
| 2 | Relocated shadow is byte-identical to the original — no hash recomputed, no shadow regenerated | ✓ VERIFIED | Script never rewrites shadow content, only `mv`s it (line 172/185); test asserts via `assert_equal` on shadow bytes (Case A, Case K) — all PASS |
| 3 | Hash mismatch on unique match → stderr error, no move, run continues | ✓ VERIFIED | `retain-dir-struct-4-revert.zsh:142-148`; Case F `mismatch shadow untouched` / `mismatch candidate untouched` — PASS |
| 4 | Genuine ambiguous duplicates (2+ hash-matching candidates) → stderr ambiguous error, nothing moves, run continues | ✓ VERIFIED | Lines 130-138; Case F `collide-ambig.jpg` — `Error: ambiguous match for collide-ambig.jpg.txt`, both candidates untouched — PASS |
| 5 | Name collision where exactly one candidate's hash matches → resolves and swaps | ✓ VERIFIED | Lines 125-139; Case F `collide-resolve` cases — PASS |
| 6 | No name match → reported and skipped, run continues | ✓ VERIFIED | Lines 104-108; Case F `nomatch.jpg.txt` — PASS |
| 7 | Swap never overwrites an existing file — occupied destination errors, nothing moves | ✓ VERIFIED | Lines 152-158; Case C — PASS |
| 8 | Partially-completed swap is rolled back (never both, never neither) | ✓ VERIFIED | Lines 172-183, mv-stub forces second `mv` to fail; Case G asserts both paths restored — PASS |
| 9 | Non-shadow `.txt` (first field not 64-hex) is left untouched | ✓ VERIFIED | Lines 65-72; Case B `notes.txt` still present, `Ignored 1 non-shadow .txt file(s)` — PASS |
| 10 | `--dry-run` previews swaps/skips/errors and performs zero filesystem writes | ✓ VERIFIED | Lines 160-164, 194-198; Case I asserts tree snapshot (relpath+sha256) unchanged across dry run — PASS |
| 11 | Dry run and the following real run report the same outcome set (accurate, not partial preview) | ✓ VERIFIED | Case I asserts dry-run `Totals:` equals real-run `Totals:` over same fixture — PASS |
| 12 | Reversed-roles run restores every real file and shadow byte-for-byte — true round trip, no location metadata | ✓ VERIFIED | Case K: `SCRIPT4 H T` then `SCRIPT4 T H`, both trees' snapshots equal pre-run snapshots, shadow bytes unchanged — PASS |
| 13 | Shadows resolve across 2+ target trees; a basename colliding across two different target trees is ambiguous | ✓ VERIFIED | Case L (per-tree placement across T1/T2), Case M (cross-tree collision → ambiguous error, nothing moves) — PASS |
| 14 | Names/dirs containing spaces survive a full round trip unchanged | ✓ VERIFIED | Case N — PASS |

**Score:** 14/14 truths verified (0 present-but-behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `dev/local-filesys/retain-dir-struct-4-revert.zsh` | Bidirectional shadow/real-file swap CLI, mode 0755, contains `sha256sum`, ≥70 lines | ✓ VERIFIED | 203 lines, mode `-rwxrwxr-x`, contains `sha256sum` calls at lines 126/143 |
| `dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh` | Tracked assert-style regression suite, mode 0755, contains `PASS_COUNT`, ≥120 lines | ✓ VERIFIED | 624 lines, mode `-rwxrwxr-x`, `PASS_COUNT` present, suite runs and reports `Results: 74 passed, 0 failed` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| test suite | `retain-dir-struct-4-revert.zsh` | `SCRIPT4` resolved via `${0:A:h}`, invoked 21 times | ✓ WIRED | `SCRIPT4="$LOCALFS_DIR/retain-dir-struct-4-revert.zsh"` (line 18), invoked throughout test cases |
| test suite | `retain-dir-struct-1.zsh` | `SCRIPT1` generates real shadow fixtures | ✓ WIRED | `SCRIPT1="$LOCALFS_DIR/retain-dir-struct-1.zsh"` (line 17), used 3 times to produce genuine `sha256sum`-format shadows |
| `retain-dir-struct-4-revert.zsh` | shadow format from `retain-dir-struct-1.zsh` | 64-hex first-field discriminator, `awk 'NR==1{print $1; exit}'` | ✓ WIRED | Lines 66-67; matches the exact `sha256sum` output format script 1 produces |
| `retain-dir-struct-4-revert.zsh` | `retain-dir-struct-2-sorted.zsh` `--dry-run` idiom | `zparseopts -D -E -F -- -dry-run=opt_dryrun` reused verbatim | ✓ WIRED | Lines 16-17, matches Phase 1 precedent |

### Behavioral Spot-Checks / Test Execution

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full revert-tool suite passes | `./dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh` | `Results: 74 passed, 0 failed` | ✓ PASS |
| Pre-existing scripts 1-3 suite unregressed | `./dev/local-filesys/tests/test-retain-dir-struct.zsh` | `Results: 29 passed, 0 failed` | ✓ PASS |
| No `echo` calls in code lines | `grep -v '^\s*#' ... \| grep -cw echo` | `0` | ✓ PASS |
| No `mkdir` in swap script | `grep -v '^\s*#' ... \| grep -cw mkdir` | `0` | ✓ PASS |
| Process-substitution loops used, not pipe form | `grep -Eq 'done < <\(find '` / pipe-form absent | present / absent | ✓ PASS |
| No `mv -f`/`mv -n` | `grep -Eq 'mv +-[fn]'` | absent | ✓ PASS |
| All 4 commits per plan summary exist in git history | `git cat-file -e <hash>` × 7 | all present | ✓ PASS |
| Working tree clean for the two files | `git status --porcelain dev/local-filesys/` | empty | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| LOCALFS-05 | 04-01, 04-02 | Shadow/real-file swap tool with name+hash matching, mandatory verification, error-out-never-guess, dry-run, true round trip | ✓ SATISFIED | All 14 truths above verified against a passing, non-trivial test suite; `REQUIREMENTS.md` traceability table already marks LOCALFS-05 Complete / Phase 4, consistent with actual code state |

No orphaned requirements — LOCALFS-05 is the only requirement mapped to Phase 4 in `REQUIREMENTS.md`, and it appears in both plans' frontmatter.

### Anti-Patterns Found

No blocker or debt-marker anti-patterns (`TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER`) found in either file.

Two **pre-existing, already-documented** correctness edge cases were flagged by `04-REVIEW.md` (code review, severity: warning, not critical) and independently confirmed by reading the script:

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `retain-dir-struct-4-revert.zsh` | 87, 123 (name index / collision pass) | Overlapping or duplicate target-tree arguments are not de-duplicated before counting, so the same physical file can be double-counted and reported as a false "ambiguous match" | ⚠️ WARNING | Fails safe (no data moves, no data loss) but a legitimate revert can be incorrectly blocked when a user passes overlapping/duplicate target-tree roots. Not covered by any must-have truth in either plan and explicitly called out as an untested gap in `04-REVIEW.md` IN-03. |
| `retain-dir-struct-4-revert.zsh` | 143 | `sha256sum -- "$real_src"` is unredirected; if a candidate is claimed by an earlier shadow in the same run (basename+hash collision across two shadows with only one physical candidate), the raw `sha256sum: ... No such file or directory` bypasses the script's own `Error:` formatting and the subsequent report is mislabeled "hash mismatch" | ⚠️ WARNING | Cosmetic/diagnostic-quality issue only — no data moves, no data loss, still fails safe with a non-zero exit and an `error_count` increment. Not covered by any must-have truth. |

These do not block phase completion: they fail safe (no file is ever moved incorrectly), are outside the scope of every must-have truth defined in the two plans, and were already surfaced with concrete fixes in `04-REVIEW.md` for a follow-up if desired.

### Human Verification Required

None. Every must-have truth is a scriptable, deterministic filesystem behavior and is covered by a passing automated test in the tracked suite (74/74 assertions). No visual, real-time, or external-service behavior is involved in this phase.

### Gaps Summary

No gaps. All 14 must-have truths across both plans (04-01, 04-02) are verified against real, passing tests — not just claimed in SUMMARY.md. Both required artifacts exist, are substantive, and are wired (the test suite genuinely invokes the script under test and a real upstream script for fixture generation). The pre-existing `retain-dir-struct-*` (1/2/3) suite is unregressed (29/29). LOCALFS-05 is satisfied and correctly traced in `REQUIREMENTS.md`. The two code-review warnings (WR-01, WR-02) are real, already-documented correctness edge cases that fail safe and fall outside the scope of every must-have truth — worth a follow-up but not a blocker to this phase's goal.

---

_Verified: 2026-08-15_
_Verifier: Claude (gsd-verifier)_
