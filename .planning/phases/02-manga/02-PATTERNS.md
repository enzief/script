# Phase 2: Manga - Pattern Map

**Mapped:** 2026-08-06
**Files analyzed:** 2 (1 modified, 1 new)
**Analogs found:** 2 / 2

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `dev/manga/number-pages.zsh` (modify in place) | utility (CLI script) | file-I/O / batch | itself (existing file, surgical edit) | exact — no external analog needed |
| `dev/manga/tests/test-number-pages.zsh` (new) | test | batch / request-response (CLI invoke + assert) | `dev/local-filesys/tests/test-retain-dir-struct.zsh` | exact — same project's only test precedent |

Note: This phase is a two-line surgical edit to an existing script plus one new test file. No new production file is being created, so the "analog" for the edit itself is the surrounding code in the same file (established local convention), not a different file.

## Pattern Assignments

### `dev/manga/number-pages.zsh` (utility, file-I/O/batch) — surgical edit

**Analog:** itself — match the exact surrounding style already in the file. No cross-file pattern borrowing needed; CONTEXT.md D-01/D-02 specify the exact before/after text.

**Current failure-message pattern** (`dev/manga/number-pages.zsh:83-90`):
```zsh
for f in "${image_files[@]}"; do
    dims=$(identify -format '%w %h\n' "$f" 2>/dev/null | head -1)
    if [[ -z "$dims" ]]; then
        echo "Warning: cannot read dimensions for '${f:t}', treating as single page" >&2
        is_double[$f]=0
        (( total_pages++ ))
        continue
    fi
```
Change per D-01: `Warning:` → `Error:` on line 86 only. No other line in this block changes — `is_double[$f]=0`, `(( total_pages++ ))`, and `continue` stay exactly as-is (D-01: "behavior is otherwise unchanged").

**Existing stderr/fatal-error convention elsewhere in same file** (for contrast — do NOT imitate the `exit 1` part, per D-04):
```zsh
# dev/manga/number-pages.zsh:60-63 (fatal — exit 1)
if ! [[ "$chapter" =~ '^[0-9]+$' ]]; then
    echo "Error: chapter '$chapter' is not numeric" >&2
    exit 1
fi
```
This phase's new `Error:` message is deliberately non-fatal — it must NOT gain an `exit 1`. Keep `continue` + exit-0 run-through, matching D-01/D-04.

**Current summary line** (`dev/manga/number-pages.zsh:147`):
```zsh
echo "Renamed ${#image_files} files (${total_pages} pages)."
```
Per D-02, extend to conditionally append a failure clause when a new failure counter (introduced in the loop above, e.g. `dim_failures`) is > 0:
```zsh
if (( dim_failures > 0 )); then
    echo "Renamed ${#image_files} files (${total_pages} pages, ${dim_failures} dimension-detection failures)."
else
    echo "Renamed ${#image_files} files (${total_pages} pages)."
fi
```
Counter style matches existing script conventions: plain `typeset`/bare variable + `(( var++ ))`, same as `total_pages` on line 88/95/98 — no associative array needed (CONTEXT.md Claude's Discretion recommends a new counter over deriving from `is_double`).

**Style notes carried from rest of file:**
- Uses `echo`, not `print`, throughout (do not convert — Phase 1's `print` standardization was scoped to `local-filesys` only, per 02-CONTEXT.md code_context).
- All error/warning output goes to `>&2`.
- No named function extraction — file has no helper functions; keep the fix inline in the existing `for` loop and at the existing summary line.

---

### `dev/manga/tests/test-number-pages.zsh` (test, new file)

**Analog:** `dev/local-filesys/tests/test-retain-dir-struct.zsh` (the project's only test precedent — manual assert-style zsh, no framework, per PROJECT.md Constraints/Testing and 02-CONTEXT.md code_context).

**Header/self-location pattern** (lines 1-18):
```zsh
#!/bin/zsh

# Regression test for <script under test>: <one-line description of what's covered>.
#
# Manual assert-style test (TESTING.md Option 3) -- no external test framework.
# Run directly: ./dev/manga/tests/test-number-pages.zsh
# Runs correctly from any working directory; resolves the scripts under test
# relative to this file's own location.

# Resolve script under test relative to this file, not the caller's cwd
SCRIPT_DIR=${0:A:h}
MANGA_DIR=${SCRIPT_DIR:h}
SCRIPT="$MANGA_DIR/number-pages.zsh"

if [[ ! -x "$SCRIPT" ]]; then
    print -u2 -r -- "Error: $SCRIPT not found or not executable"
    exit 1
fi
```

**Pass/fail bookkeeping + assert helpers** (lines 33-85, copy verbatim):
```zsh
PASS_COUNT=0
FAIL_COUNT=0

_record() {
    # _record <ok:0|1> <description>
    if [[ "$1" == "0" ]]; then
        print -r -- "PASS: $2"
        (( PASS_COUNT++ ))
    else
        print -r -- "FAIL: $2"
        (( FAIL_COUNT++ ))
    fi
}

assert_contains() {
    # assert_contains <description> <haystack> <needle>
    if [[ "$2" == *"$3"* ]]; then
        _record 0 "$1"
    else
        _record 1 "$1"
    fi
}
```
Directly reusable for this phase's assertions: "Error: cannot read dimensions" appears in captured stderr, and the summary line contains "dimension-detection failures" only when a bad file was included.

**Fixture root pattern (mktemp, guarded teardown)** (lines 87-99, copy verbatim):
```zsh
FIXROOT=$(mktemp -d)
if [[ -z "$FIXROOT" || ! -d "$FIXROOT" ]]; then
    print -u2 -r -- "Error: mktemp -d did not produce a usable directory"
    exit 1
fi

cleanup() {
    if [[ -n "$FIXROOT" && -d "$FIXROOT" ]]; then
        rm -rf -- "$FIXROOT"
    fi
}
trap cleanup EXIT INT TERM
```

**Building a fixture image that `identify` cannot read dimensions for** (no existing analog — this is new territory not covered by the local-filesys test). Simplest approach consistent with project's "no speculative complexity" convention: write a file with an image extension but non-image/corrupt content, e.g.:
```zsh
SRC="$FIXROOT/src"
mkdir -p "$SRC"
print -r -- "not a real image" > "$SRC/broken.jpg"
```
`identify -format '%w %h\n' "$SRC/broken.jpg" 2>/dev/null` will produce empty stdout, triggering the `[[ -z "$dims" ]]` branch under test — this exercises exactly the code path CONTEXT.md D-01/D-02 target, without needing a real corrupted-image fixture asset.

**Capturing stdout/stderr separately + exit code** (lines 66-85, `assert_stderr_and_exit`, reusable pattern for verifying the Error: line reaches stderr and the run still exits 0):
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
Note: `number-pages.zsh` writes its per-file rename lines and the summary line to **stdout**, not just stderr (see line 143 `echo "${orig:t} -> ${new_name}"` and line 147 summary) — unlike the local-filesys scripts' error-only invocations that `assert_stderr_and_exit` was built for. For this phase's test, capture stdout and stderr separately (same two-file capture technique) but assert on stdout content (summary line) and stderr content (Error: message) independently, rather than reusing `assert_stderr_and_exit` unmodified — it assumes stdout is empty, which won't hold here since a successful run always prints progress + summary to stdout.

**Summary/report footer** (lines 333-340, copy verbatim):
```zsh
print -r -- "----------------------------------------------------"
print -r -- "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

if (( FAIL_COUNT > 0 )); then
    exit 1
fi
exit 0
```

---

## Shared Patterns

### Error/Warning output convention
**Source:** `dev/manga/number-pages.zsh` (existing, throughout) and codebase-wide per CLAUDE.md "Error Handling" conventions.
**Apply to:** The two-line edit in `number-pages.zsh`.
```zsh
echo "Error: <message>" >&2
```
Non-fatal in this specific case (no `exit 1` follows) — this is a deliberate, CONTEXT.md-confirmed divergence from the fatal-error convention used elsewhere in the same file (lines 61, 68, 75, 112). Do not add `exit 1`.

### Manual assert-style test structure
**Source:** `dev/local-filesys/tests/test-retain-dir-struct.zsh` (the project's only test precedent, per PROJECT.md Constraints)
**Apply to:** `dev/manga/tests/test-number-pages.zsh`
- `#!/bin/zsh` shebang, self-locating `SCRIPT_DIR=${0:A:h}` header comment block explaining what's covered and how to run it directly.
- `_record`, `assert_contains`, `assert_path`-style helpers (adapt as needed; `assert_path` may be reusable if the test also checks the renamed file still exists as a single page).
- `mktemp -d` fixture root with `trap cleanup EXIT INT TERM`, never accept fixture path from argv/env.
- Terminal summary line + `exit 1` if any failures, `exit 0` otherwise.

## No Analog Found

None — both files have strong analogs (the edit target's own surrounding code, and the project's one existing test file).

## Metadata

**Analog search scope:** `dev/manga/`, `dev/local-filesys/`, `dev/local-filesys/tests/`
**Files scanned:** 9 (all `.zsh`/executable files under `dev/`)
**Pattern extraction date:** 2026-08-06
