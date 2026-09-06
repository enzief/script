# Phase 3: Remote - Pattern Map

**Mapped:** 2026-08-07
**Files analyzed:** 3 (2 modified scripts + 1 new test file)
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|---------------|
| `dev/remote/rename-remote-files-1-match-remote.zsh` (modify) | utility/CLI script | batch/CRUD (file scan + match + move) | itself (in-place hardening); dependency-check style from `dev/manga/number-pages.zsh` | exact (self) + role-match (dep checks) |
| `dev/remote/rename-remote-files-2-rename-local.zsh` (modify) | utility/CLI script | batch (sourced metadata + move) | itself (in-place validation); warn-and-continue style already present in same file | exact (self) |
| `dev/remote/tests/test-rename-remote-files.zsh` (new) | test | batch/assert-style | `dev/local-filesys/tests/test-retain-dir-struct.zsh` | exact |

These are targeted edits to two existing scripts plus one new test file that follows an established test-suite pattern. No net-new "role" (controller/component/etc.) is introduced — everything reuses conventions already present in this codebase.

## Pattern Assignments

### `dev/remote/rename-remote-files-1-match-remote.zsh` (D-03 dependency checks, D-06 env var config, D-01 process-substitution hardening)

**Analog for dependency checks:** `dev/manga/number-pages.zsh` lines 67-70

```zsh
if ! command -v identify &>/dev/null; then
    echo "Error: 'identify' (ImageMagick) is required" >&2
    exit 1
fi
```

Apply the same shape twice (rclone, jq), placed near the top of the script before first use (before the `REMOTE_JSON=$(rclone lsjson ...)` call at line 22, i.e. right after/instead of the current hardcoded config block):

```zsh
if ! command -v rclone &>/dev/null; then
    echo "Error: 'rclone' is required" >&2
    exit 1
fi
if ! command -v jq &>/dev/null; then
    echo "Error: 'jq' is required" >&2
    exit 1
fi
```

**Env var config (D-06):** replace the hardcoded block at lines 3-6:

```zsh
# --- Configuration ---
# Hardcoded remote name per your request
REMOTE_NAME="mega"
REMOTE_PATH="devicesync/2019"
```

with a required-env-var check using the same fail-fast stderr+exit-1 convention as the dependency checks above:

```zsh
if [[ -z "$REMOTE_NAME" ]]; then
    echo "Error: REMOTE_NAME environment variable is required" >&2
    exit 1
fi
if [[ -z "$REMOTE_PATH" ]]; then
    echo "Error: REMOTE_PATH environment variable is required" >&2
    exit 1
fi
```

No default fallback — matches D-06's explicit "fail fast, no silent fallback."

**Process-substitution pattern for D-01 hardening (if confirmed as hardening-only, not a functional fix):** existing precedent already used 5 times in `dev/local-filesys/*.zsh`, e.g. `dev/local-filesys/retain-dir-struct-1.zsh:38`:

```zsh
done < <(find "$SRCDIR" -type f -print0)
```

Applied to this script's loop at line 38 (`find "$LOCAL_SRC_ABS" -type f -print0 | while IFS= read -r -d '' local_file; do ... done`), the fix is to convert to:

```zsh
while IFS= read -r -d '' local_file; do
    ...
done < <(find "$LOCAL_SRC_ABS" -type f -print0)
```

This mirrors `dev/local-filesys/retain-dir-struct-1.zsh` lines 30-38 structurally (build the `while read` loop body first, then feed it via `< <(find ...)` at the end) — do not treat as a functional bug fix per D-01 unless empirical verification during planning shows the array actually is unreadable (it is expected not to be, per the Phase 1 precedent).

**Existing error-message style to match** (already in this script, keep consistent tone for new errors):

```zsh
echo "--- Fetching remote manifest from ${REMOTE_NAME}:${REMOTE_PATH} ---"
```

Section-header echoes (`--- ... ---`) are this script's convention for progress; keep new dependency/config errors as plain `Error: ... >&2` without the `---` decoration, matching `number-pages.zsh`'s error style, not the section-header style.

---

### `dev/remote/rename-remote-files-2-rename-local.zsh` (D-04 shadow-var validation)

**Analog for warn-and-continue shape:** same file, lines 39-40 (already present, no cross-file lookup needed):

```zsh
    else
        echo "warning: file not found in sync dir: $MATCHED_REMOTE_PATH"
    fi
```

**Insertion point:** immediately after `source "$shadow_file"` at line 21. New validation follows the same warn-and-continue shape but uses `Error:` prefix per D-04 (not `warning:`, to distinguish "malformed shadow file" from "expected runtime state"):

```zsh
    source "$shadow_file"

    if [[ -z "$ORIGINAL_LOCAL_PATH" || -z "$MATCHED_REMOTE_PATH" ]]; then
        echo "Error: shadow file missing required variables, skipping: $shadow_file" >&2
        continue
    fi
```

`continue` inside the `while ... do ... done < <(find ...)` loop skips just this shadow file and proceeds to the next — same non-aborting behavior as the existing lines 39-40 warning, per D-04.

Note this script also uses `find | while` at line 17 without process substitution; D-01/discretion only calls for the fix in script 1, and CONTEXT.md's `<specifics>` section does not flag script 2's loop for the same hardening — leave as-is unless the planner decides parity is warranted (not requested).

---

### `dev/remote/tests/test-rename-remote-files.zsh` (new, test)

**Analog:** `dev/local-filesys/tests/test-retain-dir-struct.zsh` (full file, 1-80+ lines read; only precedent test file in the repo)

**Structural pattern to copy:**

1. **Header comment** (lines 1-11) — explain what's under test, note "Manual assert-style test (TESTING.md Option 3) — no external test framework," note it runs correctly from any cwd.

2. **Self-locating script resolution** (lines 13-18):
```zsh
SCRIPT_DIR=${0:A:h}
LOCALFS_DIR=${SCRIPT_DIR:h}
SCRIPT2="$LOCALFS_DIR/retain-dir-struct-2-sorted.zsh"
```
Adapt for `dev/remote/`:
```zsh
SCRIPT_DIR=${0:A:h}
REMOTE_DIR=${SCRIPT_DIR:h}
SCRIPT1="$REMOTE_DIR/rename-remote-files-1-match-remote.zsh"
SCRIPT2="$REMOTE_DIR/rename-remote-files-2-rename-local.zsh"
```

3. **Executable-existence guard** (lines 20-31):
```zsh
if [[ ! -x "$SCRIPT2" ]]; then
    print -u2 -r -- "Error: $SCRIPT2 not found or not executable"
    exit 1
fi
```

4. **Pass/fail bookkeeping** (lines 33-46):
```zsh
PASS_COUNT=0
FAIL_COUNT=0

_record() {
    if [[ "$1" == "0" ]]; then
        print -r -- "PASS: $2"
        (( PASS_COUNT++ ))
    else
        print -r -- "FAIL: $2"
        (( FAIL_COUNT++ ))
    fi
}
```

5. **Assertion helpers** (lines 48-80+): `assert_contains`, `assert_path`, `assert_stderr_and_exit` — the last one is directly reusable for testing the new fail-fast dependency/env-var checks (D-03, D-06) since it captures stdout/stderr separately and checks exit code + stderr substring + empty stdout. Copy verbatim:
```zsh
assert_stderr_and_exit() {
    # assert_stderr_and_exit <description> <expected_exit> <stderr_needle> -- <command...>
    local desc="$1" expected_exit="$2" needle="$3"
    shift 3
    [[ "$1" == "--" ]] && shift
    local out_file="$FIXROOT/.capture_stdout"
    local err_file="$FIXROOT/.capture_stderr"
    "$@" > "$out_file" 2> "$err_file"
    local actual_exit=$?
    local out_content err_content
    out_content=$(<"$out_file")
    err_content=$(<"$err_file")
    if [[ -z "$out_content" && "$err_content" == *"$needle"* && "$actual_exit" == "$expected_exit" ]]; then
        _record 0 "$desc"
    else
        _record 1 "$desc"
    fi
}
```
This directly covers testing: missing `rclone`/`jq` (D-03), missing `REMOTE_NAME`/`REMOTE_PATH` (D-06), and malformed shadow file (D-04, though D-04 continues rather than exits — will need a variant that checks stderr content + exit 0 + continued processing, not `assert_stderr_and_exit`'s exit-code-focused check).

**Test file location:** `dev/remote/tests/test-rename-remote-files.zsh` (mirrors `dev/local-filesys/tests/` and `dev/manga/tests/` sibling `tests/` subdirectory convention — both existing topic dirs have one).

---

## Shared Patterns

### Dependency check (fail-fast, stderr, exit 1)
**Source:** `dev/manga/number-pages.zsh:67-70`
**Apply to:** `rename-remote-files-1-match-remote.zsh` (rclone, jq checks per D-03)
```zsh
if ! command -v <tool> &>/dev/null; then
    echo "Error: '<tool>' is required" >&2
    exit 1
fi
```

### Required-env-var fail-fast (new pattern, same shape as dependency check)
**Source:** derived from the dependency-check convention above + D-06's explicit "no silent fallback" instruction
**Apply to:** `rename-remote-files-1-match-remote.zsh` (REMOTE_NAME, REMOTE_PATH per D-06)
```zsh
if [[ -z "$VAR_NAME" ]]; then
    echo "Error: VAR_NAME environment variable is required" >&2
    exit 1
fi
```

### Warn-and-continue for per-item soft failures
**Source:** `dev/remote/rename-remote-files-2-rename-local.zsh:39-40` (already in the file being modified)
**Apply to:** `rename-remote-files-2-rename-local.zsh` new shadow-var validation (D-04) — same `continue`-based shape, `Error:` prefix instead of `warning:` since this is a malformed-input case rather than expected missing-file state

### Process substitution instead of trailing pipe into `while`
**Source:** `dev/local-filesys/retain-dir-struct-1.zsh:38`, and 4 other occurrences in `dev/local-filesys/*.zsh`
**Apply to:** `rename-remote-files-1-match-remote.zsh:38` loop, only if D-01 is confirmed as hardening (not required if empirical check shows no actual defect — apply for stylistic consistency per D-01's explicit instruction either way)
```zsh
while IFS= read -r -d '' item; do
    ...
done < <(find "$DIR" -type f -print0)
```

### Manual assert-style test file structure
**Source:** `dev/local-filesys/tests/test-retain-dir-struct.zsh` (full file)
**Apply to:** new `dev/remote/tests/test-rename-remote-files.zsh`
Self-locating `SCRIPT_DIR=${0:A:h}`, executable guards, `_record`/`PASS_COUNT`/`FAIL_COUNT` bookkeeping, `assert_contains`/`assert_path`/`assert_stderr_and_exit` helpers — copy verbatim, adapt fixture setup to remote-script inputs (a fake shadow dir with valid/malformed `.txt` files, mocked `rclone`/`jq` absence via `PATH` manipulation for D-03 tests).

## No Analog Found

None — all three files (two modified scripts, one new test) have direct or near-direct analogs already in the codebase. No new architectural role is introduced.

## Metadata

**Analog search scope:** `dev/remote/`, `dev/local-filesys/`, `dev/manga/` (full repo — small codebase, all directories reviewed)
**Files scanned:** 7 (`rename-remote-files-1-match-remote.zsh`, `rename-remote-files-2-rename-local.zsh`, `number-pages.zsh`, `retain-dir-struct-1.zsh`, `retain-dir-struct-2-sorted.zsh`, `retain-dir-struct-3-find-sorted.zsh`, `test-retain-dir-struct.zsh`)
**Pattern extraction date:** 2026-08-07
