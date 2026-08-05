---
phase: 01-local-filesystem
fixed_at: 2026-08-05T19:13:28Z
review_path: .planning/phases/01-local-filesystem/01-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 01: Code Review Fix Report

**Fixed at:** 2026-08-05T19:13:28Z
**Source review:** .planning/phases/01-local-filesystem/01-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3 (CR-01, CR-02, WR-01 — 4 Info findings excluded per fix_scope)
- Fixed: 3
- Skipped: 0

## Fixed Issues

### CR-01: Missing source-directory validation causes silent false-success reporting

**Files modified:** `dev/local-filesys/retain-dir-struct-1.zsh`, `dev/local-filesys/retain-dir-struct-2-sorted.zsh`
**Commit:** ef1fa12
**Applied fix:** Added `[[ ! -d "$SRCDIR" ]] && { print -u2 -r -- "Error: Source dir not found."; exit 1 }` to script 1 right after `SRCDIR`/`TGTDIR` assignment, before `mkdir -p "$TGTDIR"`. Added matching existence checks for `$REORG_DIR` and `$OLD_SHADOW` to script 2 right after argument assignment, before the shadow root is created. Matches the existing validation style already used in `retain-dir-struct-3-find-sorted.zsh`. Manually verified: running script 1 against a nonexistent source dir now prints `Error: Source dir not found.` and exits 1 (previously exited 0 with a false "Complete!" message); same for script 2 against a missing old-shadow dir.

### CR-02: `--dry-run` still writes to disk and prints a misleading success message

**Files modified:** `dev/local-filesys/retain-dir-struct-2-sorted.zsh`
**Commit:** 9b1bf6b
**Applied fix:** Gated `mkdir -p "$NEW_SHADOW"` behind `if (( ! DRY_RUN )); then ... fi` so the destination root is no longer created during dry-run. Gated the final status message behind `if (( DRY_RUN ))` to print `"Dry run complete. No files were copied."` in dry-run mode instead of the misleading `"Done! New shadow structure created at: ..."`. `shadow_map` indexing under `OLD_SHADOW` was left ungated as noted in the review (read-only). Manually verified: `--dry-run` run against fresh temp dirs no longer creates the destination directory and prints the new dry-run message.

### WR-01: `retain-dir-struct-1.zsh` was not converted to process substitution, unlike its siblings

**Files modified:** `dev/local-filesys/retain-dir-struct-1.zsh`
**Commit:** 9802246
**Applied fix:** Converted `find "$SRCDIR" -type f -print0 | while IFS= read -r -d '' srcfile; do ... done` to `while IFS= read -r -d '' srcfile; do ... done < <(find "$SRCDIR" -type f -print0)`, matching the process-substitution pattern already used in scripts 2 and 3. Loop body and logic unchanged.

## Skipped Issues

None — all in-scope findings were fixed.

## Verification

Ran `dev/local-filesys/tests/test-retain-dir-struct.zsh` after all three fixes were applied (inside the isolated fix worktree): **29 passed, 0 failed** — no regressions from the pre-existing green baseline. Additionally manually re-confirmed each of the review's original repro steps now behaves as expected (see per-finding notes above).

---

_Fixed: 2026-08-05T19:13:28Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
