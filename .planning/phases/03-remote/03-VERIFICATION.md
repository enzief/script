---
phase: 03-remote
verified: 2026-08-13T12:47:20Z
status: passed
score: 20/20 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification:

  - test: "On a scratch copy only: export the real REMOTE_NAME/REMOTE_PATH, run rename-remote-files-1-match-remote.zsh against a small throwaway directory whose files are known to exist on the real MEGA remote, and confirm the match lines name the expected remote filenames. Then run rename-remote-files-2-rename-local.zsh and confirm MegaSync reports rename operations rather than uploads."
    expected: "Real rclone lsjson output's Size/Path fields behave as the size-index code assumes; matches are found and reversion triggers MEGA rename events, not re-uploads."
    why_human: "Requires the real MEGA remote and a running MegaSync client — cannot be exercised by the hermetic test suite (03-01-PLAN.md <human-check>, explicitly deferred to end-of-phase per human_verify_mode: end-of-phase)."

  - test: "On a scratch copy only: take a real shadow tree produced by script 1, truncate one shadow file to zero bytes, and run rename-remote-files-2-rename-local.zsh. Confirm the truncated file is named on stderr and skipped, every other file is reverted, and MegaSync reports rename operations for the reverted files."
    expected: "The zero-byte shadow file produces an Error: line naming it and is skipped; all other shadow files revert normally; MegaSync shows renames, not uploads."
    why_human: "Requires a real script-1-produced shadow tree and a running MegaSync client — cannot be exercised by the hermetic test suite (03-02-PLAN.md <human-check>, explicitly deferred to end-of-phase per human_verify_mode: end-of-phase)."
---

# Phase 3: Remote Verification Report

**Phase Goal:** `remote` scripts behave correctly and safely when matching and renaming files against the MEGA remote
**Verified:** 2026-08-13T12:47:20Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Test suite runs to completion from any cwd, exits 0, zero failures, no network access (REMOTE-01/02/04) | ✓ VERIFIED | Ran `zsh dev/remote/tests/test-rename-remote-files.zsh` from repo root and from `/tmp` — both: `Results: 77 passed, 0 failed`, exit 0. Stub `rclone` prepended to PATH (`STUB_BIN:$PATH`); no real `rclone`/network call in any code path. |
| 2 | Matched local file produces `Match Found (Size: N):` line, shadow file with both vars, file moved to sync dir (REMOTE-01, D-01) | ✓ VERIFIED | Script code (`rename-remote-files-1-match-remote.zsh:60-81`) builds shadow file and `mv`s file; suite's "Round trip" section (lines ~220-280) asserts this and passes. |
| 3 | Unmatched local file produces `No Match:` line, stays in place, no shadow file | ✓ VERIFIED | Script code line 82-83; suite asserts via round-trip and no-files-manifest scenarios (all pass). |
| 4 | Missing `rclone` → Error naming rclone, no stdout, exit 1; missing `jq` → same for jq (REMOTE-02, D-03) | ✓ VERIFIED | Script lines 10-17 (`command -v rclone`, then `command -v jq`, in that order). Suite lines 295-299 (`assert_stderr_and_exit`) — both pass. |
| 5 | `REMOTE_NAME` unset → Error naming it, exit 1; independently for `REMOTE_PATH` (REMOTE-04, D-06) | ✓ VERIFIED | Script lines 19-26. Suite lines 307-317 use `env -u REMOTE_NAME` / `env -u REMOTE_PATH` independently — both pass. |
| 6 | Every preflight failure exits before any filesystem mutation | ✓ VERIFIED | Script: all checks (lines 10-26) precede `realpath`/`mkdir -p` (lines 28-33). Suite lines 312-317 assert source file still present, shadow/sync dirs absent after a missing-REMOTE_NAME failure — pass. |
| 7 | No hardcoded remote-name/path literal; remote spec built from the two env vars (REMOTE-04, D-06) | ✓ VERIFIED | `grep -n "mega\|devicesync"` on both scripts returns only generic UI text ("megasync" running-status note in script 2), no config literal. `REMOTE_NAME`/`REMOTE_PATH` interpolated at line 37 (`${REMOTE_NAME}:${REMOTE_PATH}`). Suite line 261 asserts stub rclone actually received `${TEST_REMOTE_NAME}:${TEST_REMOTE_PATH}` in its argv. |
| 8 | Empty source dir → exit 0, creates both output dirs, no Match/No Match lines | ✓ VERIFIED | Suite lines 322-341 — pass. |
| 9 | Manifest with zero file entries → No Match for every local file, exit 0, source unchanged | ✓ VERIFIED | Suite lines 343-376 — pass. |
| 10 | Suite asserts on content/occurrence counts, not relative line order | ✓ VERIFIED | Suite uses `grep -c` occurrence counts (e.g. line 511 `mal4_error_count=$(grep -c '^Error:' ...)`) and `find \| wc -l` remaining-file counts rather than positional matching. |
| 11 | Shadow file missing both vars → skipped w/ `Error:` line naming it, run continues, exits 0 (REMOTE-03, D-04) | ✓ VERIFIED | Script `rename-remote-files-2-rename-local.zsh:28-31`. Suite malformed-shadow sections — pass. |
| 12 | Shadow file with either var set to empty string → skipped by same path (non-empty check, not just set) (REMOTE-03) | ✓ VERIFIED | Script `[[ -z "$ORIGINAL_LOCAL_PATH" \|\| -z "$MATCHED_REMOTE_PATH" ]]` — empty string triggers `-z`. Suite blank-original/blank-matched scenarios pass. |
| 13 | Malformed file after a well-formed one does not inherit previous values; skip fires regardless of position (REMOTE-03) | ✓ VERIFIED | Script line 22: `unset ORIGINAL_LOCAL_PATH MATCHED_REMOTE_PATH` immediately before `source`, every iteration. Suite "position independence" scenario (a valid, bad, valid, valid mixed order) — pass. Regression guard documented in 03-02-SUMMARY.md: removing the `unset` line dropped the suite to 76/1 failed; restored to 77/0. |
| 14 | Skip behavior is order-independent in the suite's own assertions (REMOTE-03) | ✓ VERIFIED | Suite asserts by content/count (`mal4_error_count=$(grep -c ...)`, restored-file existence checks), not by line position. |
| 15 | Well-formed shadow files in a mixed dir still revert normally, exit 0 (REMOTE-03, D-04) | ✓ VERIFIED | Suite "sibling valid file restored" assertions in malformed-shadow sections — pass. |
| 16 | Empty shadow dir → exit 0, no `Error:` line, creates nothing | ✓ VERIFIED | Suite "Empty shadow dir" section — pass. |
| 17 | Shadow file whose sync-dir file is absent still emits pre-existing `warning: file not found in sync dir:` line and continues (interruption recovery) | ✓ VERIFIED | Script lines 49-50 (`warning: file not found in sync dir: ...`) unchanged. Suite "Interruption recovery" section — pass. |
| 18 | Re-running script 2 over same shadow dir exits 0, warns per already-reverted file, leaves files untouched (REMOTE-03) | ✓ VERIFIED | Suite "Repeat run" section, including sha256sum content-unchanged check — pass. |
| 19 | Script 2 still loads shadow files with `source` (D-05) | ✓ VERIFIED | Script line 26: `source "$shadow_file"` — unchanged mechanism, only presence/non-empty check added. |
| 20 | Suite covers both remote scripts and reports zero failures from any working directory | ✓ VERIFIED | Confirmed via direct execution from repo root and `/tmp` (see truth #1). Suite drives both `run_s1` and `run_s2` helpers throughout. |

**Score:** 20/20 truths verified (0 present-but-behavior-unverified)

Two additional "backstop" truths (one per plan) document an intentionally out-of-scope concurrency/locking guarantee ("no locking is added this phase"). Confirmed by absence of any `flock`/lockfile code in either script (`grep -n "flock\|lockfile\|\.lock"` → no matches) — consistent with the stated non-goal, not counted against the score.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `dev/remote/tests/test-rename-remote-files.zsh` | First tracked test for dev/remote/, hermetic round-trip + preflight coverage, min 150 lines (03-01) / min 230 lines (03-02) | ✓ VERIFIED | 641 lines. Runs hermetically (fixture-owned stub rclone, `mktemp -d` fixture root with trap teardown), 77/77 assertions pass. |
| `dev/remote/rename-remote-files-1-match-remote.zsh` | rclone/jq preflight, required REMOTE_NAME/REMOTE_PATH env config, process-substitution match loop, `command -v rclone` present | ✓ VERIFIED | Contains `command -v rclone` (line 10) and `command -v jq` (line 14); env var checks (lines 19-26); match loop uses `done < <(find ... -print0)` process-substitution form (line 85). |
| `dev/remote/rename-remote-files-2-rename-local.zsh` | Per-iteration variable reset + non-empty validation, skip without abort, contains `unset ORIGINAL_LOCAL_PATH MATCHED_REMOTE_PATH` | ✓ VERIFIED | Line 22: `unset ORIGINAL_LOCAL_PATH MATCHED_REMOTE_PATH`; lines 28-31: non-empty check with `continue`. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| Script 1 env config check | Script 1 `rclone lsjson` invocation | `REMOTE_NAME`/`REMOTE_PATH` interpolated into remote spec | ✓ WIRED | Line 37: `rclone lsjson --recursive "${REMOTE_NAME}:${REMOTE_PATH}"`. Suite proves actual argv reaching the stub rclone contains the configured spec (line 261). |
| Test suite | Script 1 | Fixture stub `rclone` prepended to PATH, config vars supplied | ✓ WIRED | `run_s1` helper (grep confirms usage throughout suite) invokes script 1 with `PATH="$STUB_BIN:$PATH"` and `REMOTE_NAME`/`REMOTE_PATH` set. |
| Script 1 size index (`remote_map`) built before loop | Script 1 per-file lookup inside loop | Associative array populated pre-loop, read inside loop | ✓ WIRED | `typeset -A remote_map` + while-loop populate (lines 43-48) precedes the `find | while` match loop (lines 53-85) that reads `remote_map[$local_size]` (line 60). Confirmed correct by direct test execution (round-trip scenario matches both seeded sizes). |
| Script 2 variable reset before `source` | Script 2 non-empty validation immediately after `source` | Reset makes the emptiness test meaningful on 2nd+ iterations | ✓ WIRED | Lines 22 (`unset`) → 26 (`source`) → 28 (`[[ -z ... ]]`), directly adjacent. Regression guard (manual, documented in 03-02-SUMMARY.md) confirms removing the reset breaks the position-independence test. |
| Test suite `write_shadow`/`write_bad_shadow` helpers | Script 2 | Hand-written shadow fixtures reach validation branches script 1 never produces | ✓ WIRED | Helpers defined at lines 152, 164; used at lines 390-392, 429-431, and throughout malformed-shadow sections; all corresponding assertions pass. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full test suite passes, hermetically, from repo root | `zsh dev/remote/tests/test-rename-remote-files.zsh` | `Results: 77 passed, 0 failed`, exit 0 | ✓ PASS |
| Full test suite passes from an unrelated cwd (cwd-independence claim) | `cd /tmp && zsh .../test-rename-remote-files.zsh` | `Results: 77 passed, 0 failed`, exit 0 | ✓ PASS |
| No debt-marker anti-patterns in modified files | `grep -n -E "TBD\|FIXME\|XXX\|TODO\|HACK\|PLACEHOLDER"` on both scripts + test file | No matches | ✓ PASS |
| No hardcoded remote config literal remains | `grep -n "mega\|devicesync"` on both scripts | Only generic "megasync" usage-text references in script 2 (not config) | ✓ PASS |
| No locking mechanism added (consistent with backstop truth) | `grep -n "flock\|lockfile\|\.lock"` on both scripts | No matches | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| REMOTE-01 | 03-01 | Fix `remote_map` subshell-scope bug so matching reports correctly | ✓ SATISFIED | Empirically re-verified during planning (D-01): the bug did not exist in zsh (last pipeline element runs in current shell). Shipped as process-substitution hardening for consistency, plus the first regression test proving the match→shadow→sync→revert pipeline works end-to-end. Matches the Phase 1 precedent's handling of the identical misdiagnosis pattern (documented in ROADMAP.md planning notes for both phases). |
| REMOTE-02 | 03-01 | Both remote scripts fail fast on missing `rclone`/`jq` | ✓ SATISFIED (documented scope interpretation) | Script 1 has both checks (lines 10-17), proven by suite. Script 2 was intentionally left unmodified — it calls neither `rclone` nor `jq` anywhere in its body (confirmed by reading the file; only `mkdir`/`mv`/`source`). This narrowing from REMOTE-02's literal "both scripts" wording was made explicitly in `03-CONTEXT.md` D-03 before implementation ("interpreting the requirement as 'each script checks what it actually uses'"), not discovered post-hoc — a defensible, transparent interpretation given script 2 has no dependency to check. |
| REMOTE-03 | 03-02 | Script 2 validates sourced shadow vars are set before use | ✓ SATISFIED | Per-iteration `unset` + non-empty check with skip-and-continue implemented and covered by 42 new test assertions (malformed, stale-inheritance, position-independence, empty-input, interruption-recovery, repeat-run). Strengthens beyond the literal requirement by also closing the stale-value-inheritance risk (a malformed file could otherwise silently reuse the previous file's move targets). |
| REMOTE-04 | 03-01 | Remove hardcoded remote config, move to env var or git-ignored config | ✓ SATISFIED | Hardcoded `REMOTE_NAME="mega"`/`REMOTE_PATH="devicesync/2019"` literals removed; both required from environment with fail-fast checks and no fallback. Confirmed no literal remains in the file; confirmed values actually reach the `rclone lsjson` call (not just a presence check) via suite's stub-argv assertion. |

No orphaned requirements — REMOTE-01 through REMOTE-04 all appear in plan frontmatter (`requirements-completed`) and match REQUIREMENTS.md's Phase 3 mapping exactly.

### Anti-Patterns Found

None. `grep` for `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER`/empty-return patterns across both modified scripts and the test file returned no matches.

### Human Verification Required

Both phase plans (03-01, 03-02) contain a `<human-check>` block explicitly deferred to end-of-phase verification per `human_verify_mode: end-of-phase` in `.planning/config.json`. Neither SUMMARY.md claims these were performed — both explicitly state they remain outstanding. This is the end-of-phase verification pass, so they surface now:

### 1. Real-remote match/reversion round trip

**Test:** On a scratch copy only: export the real `REMOTE_NAME`/`REMOTE_PATH`, run `rename-remote-files-1-match-remote.zsh` against a small throwaway directory whose files are known to exist on the real MEGA remote, confirm match lines name the expected remote filenames, then run `rename-remote-files-2-rename-local.zsh` and confirm MegaSync reports rename operations rather than uploads.
**Expected:** Real `rclone lsjson` output's `Size`/`Path` fields behave as the size-index code assumes; matches found; reversion triggers MEGA rename events, not re-uploads.
**Why human:** Requires the real MEGA remote and a running MegaSync client — the hermetic stub cannot prove real-world `rclone`/MEGA field behavior (this is explicitly the one thing 03-01-PLAN.md's `<human-check>` says the stub cannot prove).

### 2. Truncated shadow file against a real shadow tree

**Test:** On a scratch copy only: take a real shadow tree produced by script 1, truncate one shadow file to zero bytes, run `rename-remote-files-2-rename-local.zsh`, confirm the truncated file is named on stderr and skipped, every other file is reverted, and MegaSync reports rename operations for the reverted files.
**Expected:** Zero-byte shadow file produces an `Error:` line naming it and is skipped; all other files revert normally; MegaSync shows renames, not uploads.
**Why human:** Requires a real script-1-produced shadow tree and a running MegaSync client, external to the hermetic test environment.

### Gaps Summary

No gaps found. All 20 must-have truths across both plans are verified against the actual codebase (not just SUMMARY.md claims): read both modified scripts directly, confirmed preflight/validation logic matches the described behavior, and independently executed the 77-assertion test suite twice (from the repo root and from an unrelated cwd) to confirm the claimed pass count, exit code, and hermeticity rather than trusting the SUMMARY's reported numbers. Requirements REMOTE-01 through REMOTE-04 are all satisfied, with REMOTE-02's "both scripts" wording narrowed to script 1 only via an explicit, pre-implementation `03-CONTEXT.md` decision (D-03) rather than a silent omission. The only remaining items are the two real-MEGA-remote `<human-check>` verifications both plans deliberately deferred to this end-of-phase pass — these need a human with access to the real remote and MegaSync client to close out.

---

*Verified: 2026-08-13T12:47:20Z*
*Verifier: Claude (gsd-verifier)*
