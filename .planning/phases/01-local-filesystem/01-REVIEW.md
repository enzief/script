---
phase: 01-local-filesystem
reviewed: 2026-08-05T19:07:42Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - dev/local-filesys/retain-dir-struct-1.zsh
  - dev/local-filesys/retain-dir-struct-2-sorted.zsh
  - dev/local-filesys/retain-dir-struct-3-find-sorted.zsh
  - dev/local-filesys/tests/test-retain-dir-struct.zsh
findings:
  critical: 2
  warning: 1
  info: 4
  total: 7
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-08-05T19:07:42Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the four files that make up phase 01 (local-filesystem hardening: process-substitution
loops, print-only output, `--dry-run`, and the new regression test). The `echo`→`print -r --`
conversion is complete and correct in all three scripts (verified: zero remaining `echo` calls).
The new test suite (29 assertions) passes cleanly against the current code and is generally
well-constructed (temp-dir fixtures via `mktemp`, guarded `trap cleanup`, stdout/stderr
separation for error-path assertions).

However, two behavior-correctness bugs were found and confirmed by direct execution:
`retain-dir-struct-1.zsh` and `retain-dir-struct-2-sorted.zsh` report success and exit 0 even
when their required input directories do not exist (they simply skip all work silently), and
`--dry-run` in `retain-dir-struct-2-sorted.zsh` still creates the destination directory and
prints a "Done! ... created" success message despite claiming to preview only. Both bugs are
outside the new test suite's coverage. `retain-dir-struct-1.zsh` was also left on the old
`find | while` pipe form while its siblings were converted to process substitution, contradicting
the phase's own stated goal (and the test file's header comment, which claims the conversion was
applied "across all three").

## Critical Issues

### CR-01: Missing source-directory validation causes silent false-success reporting

**File:** `dev/local-filesys/retain-dir-struct-1.zsh:4-19` and `dev/local-filesys/retain-dir-struct-2-sorted.zsh:11-18,64`

**Issue:** Neither script validates that its source directory argument(s) actually exist before
running. `retain-dir-struct-3-find-sorted.zsh` does this correctly (lines 13-14: `[[ ! -d
"$SHADOWDIR" ]] && { ... exit 1 }`), but scripts 1 and 2 only check argument *count*, not
existence. When a nonexistent path is passed, the underlying `find` prints "No such file or
directory" to stderr and produces zero output, the loop body never executes, and the script
still reports success and exits 0.

Confirmed by direct execution:
```
$ ./retain-dir-struct-1.zsh /tmp/does_not_exist /tmp/out
Creating Shadow Map in '/tmp/out'...
find: ‘/tmp/does_not_exist’: No such file or directory
---
Shadow Map Complete!
$ echo $?
0
```
```
$ ./retain-dir-struct-2-sorted.zsh /tmp/no_reorg /tmp/no_old_shadow /tmp/new
Indexing old shadow files...
find: ‘/tmp/no_old_shadow’: No such file or directory
Indexing complete. Syncing to new structure...
----------------------------------------------------
find: ‘/tmp/no_reorg’: No such file or directory
----------------------------------------------------
Done! New shadow structure created at: /tmp/new
$ echo $?
0
```
Given the project's stated Core Value ("these scripts move, rename, and reorganize real files
... correctness matters more than feature breadth"), a user who mistypes a path and trusts the
"Complete!"/"Done!" message could proceed to delete or reorganize the real source directory
believing a shadow map/sync was created, when nothing happened.

**Fix:** Add the same fail-fast validation already used in script 3, before any work begins:
```zsh
# retain-dir-struct-1.zsh, after SRCDIR/TGTDIR assignment
[[ ! -d "$SRCDIR" ]] && { print -u2 -r -- "Error: Source dir not found."; exit 1 }
```
```zsh
# retain-dir-struct-2-sorted.zsh, after REORG_DIR/OLD_SHADOW/NEW_SHADOW assignment
[[ ! -d "$REORG_DIR" ]] && { print -u2 -r -- "Error: Reorganized data dir not found."; exit 1 }
[[ ! -d "$OLD_SHADOW" ]] && { print -u2 -r -- "Error: Old shadow dir not found."; exit 1 }
```

### CR-02: `--dry-run` still writes to disk and prints a misleading success message

**File:** `dev/local-filesys/retain-dir-struct-2-sorted.zsh:21,66-67`

**Issue:** `--dry-run` is meant to preview changes without touching the filesystem, but two
statements are not gated by `DRY_RUN`:
- Line 21: `mkdir -p "$NEW_SHADOW"` runs unconditionally, before the dry-run check, so the
  destination root directory is created on disk even in dry-run mode.
- Line 67: `print -r -- "Done! New shadow structure created at: $NEW_SHADOW"` runs unconditionally
  and misleadingly claims a structure was "created" even when `--dry-run` performed zero copies.

Confirmed by direct execution:
```
$ ./retain-dir-struct-2-sorted.zsh --dry-run reorg old_shadow new_shadow_out
...
Done! New shadow structure created at: new_shadow_out
$ [[ -d new_shadow_out ]] && echo "DIRECTORY WAS CREATED DESPITE --dry-run"
DIRECTORY WAS CREATED DESPITE --dry-run
```
This is a correctness bug in the phase's own headline deliverable (`--dry-run`), and the new test
suite does not catch it — it only asserts zero *files* under the new shadow root
(`test-retain-dir-struct.zsh:168-173`), not that the root directory itself, and the final message,
correctly reflect dry-run semantics.

**Fix:** Gate both statements on `DRY_RUN`:
```zsh
# don't create the output root until we know we're doing real work
if (( ! DRY_RUN )); then
    mkdir -p "$NEW_SHADOW"
fi
...
print -r -- "----------------------------------------------------"
if (( DRY_RUN )); then
    print -r -- "Dry run complete. No files were copied."
else
    print -r -- "Done! New shadow structure created at: $NEW_SHADOW"
fi
```
(Note: `shadow_map` indexing under `OLD_SHADOW` is read-only and does not need gating.)

## Warnings

### WR-01: `retain-dir-struct-1.zsh` was not converted to process substitution, unlike its siblings

**File:** `dev/local-filesys/retain-dir-struct-1.zsh:19`

**Issue:** Scripts 2 and 3 were converted this phase from `find ... | while ...; done` to
`while ...; done < <(find ...)` specifically to avoid running the loop body in a subshell.
`retain-dir-struct-1.zsh` line 19 is the only remaining pipe-form loop in the trio:
```zsh
find "$SRCDIR" -type f -print0 | while IFS= read -r -d '' srcfile; do
```
This contradicts the phase's stated goal and the new test file's own header comment, which
claims "process-substitution loops across all three." It's currently harmless only because the
loop body sets no variable that needs to survive past the loop — but that's exactly the kind of
invariant that silently breaks the next time someone adds loop-scoped state (a counter, an
accumulated array, an early `exit`). Confirmed empirically that zsh drops loop-local state across
this pipe form:
```
$ zsh -c 'count=0; find /tmp -maxdepth 0 -print0 | while IFS= read -r -d "" f; do count=$((count+1)); done; print "count after pipe-loop: $count"'
count after pipe-loop: 0
```

**Fix:**
```zsh
while IFS= read -r -d '' srcfile; do
    ...
done < <(find "$SRCDIR" -type f -print0)
```

## Info

### IN-01: Stale usage comment in `retain-dir-struct-2-sorted.zsh`

**File:** `dev/local-filesys/retain-dir-struct-2-sorted.zsh:3`
**Issue:** The header comment (`# Usage: ./sync_shadows.zsh <reorganized_dir> <old_shadow_dir>
<new_shadow_dir>`) was not updated to mention `--dry-run`, while the actual `print -u2` usage
string on line 12 was. The two now disagree.
**Fix:** Update the comment to `# Usage: ./sync_shadows.zsh [--dry-run] <reorganized_dir>
<old_shadow_dir> <new_shadow_dir>`.

### IN-02: `zparseopts` failure message is inconsistent with the script's own error-message style

**File:** `dev/local-filesys/retain-dir-struct-2-sorted.zsh:6`
**Issue:** On an unrecognized flag, `zparseopts -F` prints its own message directly to stderr
(e.g. `retain-dir-struct-2-sorted.zsh:zparseopts:6: bad option: --bogus-flag`) before the `|| exit
1` fires. This leaks internal implementation detail (function name, line number) and doesn't
follow the project's `"Error: ..."` / `"Usage: ..."` convention used everywhere else in these
scripts.
**Fix:** Check `zparseopts`'s exit status explicitly and print a project-style message instead of
relying on its built-in stderr output:
```zsh
zparseopts -D -E -F -- -dry-run=opt_dryrun 2>/dev/null || {
    print -u2 -r -- "Usage: $0 [--dry-run] <reorganized_data_dir> <old_shadow_dir> <new_shadow_output_dir>"
    exit 1
}
```

### IN-03: New regression test doesn't cover either Critical finding above

**File:** `dev/local-filesys/tests/test-retain-dir-struct.zsh`
**Issue:** The test suite added this phase exercises the empty-input case for scripts 1-3
(directories that exist but are empty) but never exercises a *missing* directory for scripts 1 or
2 (CR-01), and never asserts that `--dry-run` leaves the destination root directory absent and
prints a dry-run-appropriate final message (CR-02). Both gaps are exactly the class of regression
this suite is meant to catch.
**Fix:** Add cases mirroring the existing `assert_stderr_and_exit` pattern already used for
script 3 (`test-retain-dir-struct.zsh:268-271`) for scripts 1 and 2's missing-directory paths, and
add an `assert_path ... absent` check for `$NEW_SHADOW_DRY` itself (not just files under it) in
the dry-run block.

### IN-04: No external-command dependency checks

**File:** `dev/local-filesys/retain-dir-struct-1.zsh`, `retain-dir-struct-2-sorted.zsh`,
`retain-dir-struct-3-find-sorted.zsh`
**Issue:** None of the three scripts verify `sha256sum`, `find`, `awk`, or `realpath` are
available before use, unlike the project's own documented convention (`command -v tool
&>/dev/null || { ... exit 1 }`, e.g. `dev/manga/number-pages.zsh:67-70`). This is pre-existing
and out of this phase's diff, not a regression, but worth noting since it's flagged in the
project's own architecture docs as a known anti-pattern.
**Fix:** Not required for this phase; consider adding a shared dependency-check block if these
scripts are revisited.

---

_Reviewed: 2026-08-05T19:07:42Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
