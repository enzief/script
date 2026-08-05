#!/bin/zsh

# Regression test for retain-dir-struct-2-sorted.zsh (hash-matched shadow sync,
# --dry-run preview, print-only output, process-substitution loops).
#
# Manual assert-style test (TESTING.md Option 3) -- no external test framework.
# Run directly: ./dev/local-filesys/tests/test-retain-dir-struct.zsh
# Runs correctly from any working directory; resolves the scripts under test
# relative to this file's own location.

# Resolve scripts under test relative to this file, not the caller's cwd
SCRIPT_DIR=${0:A:h}
LOCALFS_DIR=${SCRIPT_DIR:h}
SCRIPT2="$LOCALFS_DIR/retain-dir-struct-2-sorted.zsh"
SCRIPT1="$LOCALFS_DIR/retain-dir-struct-1.zsh"

if [[ ! -x "$SCRIPT2" ]]; then
    print -u2 -r -- "Error: $SCRIPT2 not found or not executable"
    exit 1
fi
if [[ ! -x "$SCRIPT1" ]]; then
    print -u2 -r -- "Error: $SCRIPT1 not found or not executable"
    exit 1
fi

# --- Pass/fail bookkeeping ---
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

assert_path() {
    # assert_path <description> <path> <exists|absent>
    if [[ "$3" == "exists" ]]; then
        if [[ -e "$2" ]]; then _record 0 "$1"; else _record 1 "$1"; fi
    else
        if [[ ! -e "$2" ]]; then _record 0 "$1"; else _record 1 "$1"; fi
    fi
}

# --- Fixture root: mktemp only, never accepted from argv/env, guarded teardown ---
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

# --- Build source tree ---
SRC="$FIXROOT/src"
mkdir -p "$SRC/subdir" "$SRC/space dir"
print -r -- "line A" > "$SRC/fileA.txt"
print -r -- "line A" > "$SRC/subdir/fileA-dup.txt"
print -r -- "space content" > "$SRC/space dir/file with space.txt"

# --- Build old shadow tree from the source tree (script 1, already-validated) ---
OLD_SHADOW="$FIXROOT/old_shadow"
"$SCRIPT1" "$SRC" "$OLD_SHADOW" >/dev/null 2>&1

# --- Build reorganized tree ---
REORG="$FIXROOT/reorg"
mkdir -p "$REORG/space dir"
cp "$SRC/fileA.txt" "$REORG/fileA-renamed.txt"
cp "$SRC/subdir/fileA-dup.txt" "$REORG/fileA-dup-renamed.txt"
cp "$SRC/space dir/file with space.txt" "$REORG/space dir/file with space.txt"
print -r -- "orphan content" > "$REORG/orphan.txt"

# --- Real run ---
NEW_SHADOW_REAL="$FIXROOT/new_shadow_real"
output_real=$("$SCRIPT2" "$REORG" "$OLD_SHADOW" "$NEW_SHADOW_REAL" 2>&1)

# Match found
assert_contains "Real run reports Matched & Placed for renamed file" \
    "$output_real" "Matched & Placed: fileA-renamed.txt"

# Copy really happened
assert_path "Shadow file exists under new shadow root after real run" \
    "$NEW_SHADOW_REAL/fileA-renamed.txt.txt" "exists"

# Non-match reported
assert_contains "Real run reports No shadow found for orphan file" \
    "$output_real" "No shadow found for: orphan.txt"

# Duplicate content: both destinations receive a shadow file
assert_path "Duplicate-content destination 1 has a shadow file" \
    "$NEW_SHADOW_REAL/fileA-renamed.txt.txt" "exists"
assert_path "Duplicate-content destination 2 has a shadow file" \
    "$NEW_SHADOW_REAL/fileA-dup-renamed.txt.txt" "exists"

# Filenames with spaces round-trip through the shadow tree
assert_path "Space-containing filename round-trips through shadow tree" \
    "$NEW_SHADOW_REAL/space dir/file with space.txt.txt" "exists"

# Separator lines survive (catches a naive echo-to-print conversion that
# silently swallows a dash-leading string)
sep_count=$(print -r -- "$output_real" | grep -c '^-\{52\}$')
if [[ "$sep_count" == "2" ]]; then
    _record 0 "Real run emits exactly two 52-dash separator lines"
else
    _record 1 "Real run emits exactly two 52-dash separator lines (got $sep_count)"
fi

# --- Dry run against the same fixtures ---
NEW_SHADOW_DRY="$FIXROOT/new_shadow_dry"
output_dry=$("$SCRIPT2" --dry-run "$REORG" "$OLD_SHADOW" "$NEW_SHADOW_DRY" 2>&1)

assert_contains "Dry run reports Would copy for the matched file" \
    "$output_dry" "Would copy: "

if [[ "$output_dry" != *"Matched & Placed: "* ]]; then
    _record 0 "Dry run does not claim to have copied anything"
else
    _record 1 "Dry run does not claim to have copied anything"
fi

dry_file_count=$(find "$NEW_SHADOW_DRY" -type f 2>/dev/null | wc -l)
if [[ "$dry_file_count" == "0" ]]; then
    _record 0 "Dry run leaves zero files under the new shadow root"
else
    _record 1 "Dry run leaves zero files under the new shadow root (found $dry_file_count)"
fi

# --- Empty inputs ---
EMPTY_REORG="$FIXROOT/empty_reorg"
EMPTY_OLD_SHADOW="$FIXROOT/empty_old_shadow"
EMPTY_NEW_SHADOW="$FIXROOT/empty_new_shadow"
mkdir -p "$EMPTY_REORG" "$EMPTY_OLD_SHADOW"

"$SCRIPT2" "$EMPTY_REORG" "$EMPTY_OLD_SHADOW" "$EMPTY_NEW_SHADOW" >/dev/null 2>&1
empty_exit=$?

if [[ "$empty_exit" == "0" ]]; then
    _record 0 "Empty-inputs run exits 0"
else
    _record 1 "Empty-inputs run exits 0 (got $empty_exit)"
fi

assert_path "Empty-inputs run creates the new shadow root" \
    "$EMPTY_NEW_SHADOW" "exists"

# --- Summary ---
print -r -- "----------------------------------------------------"
print -r -- "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

if (( FAIL_COUNT > 0 )); then
    exit 1
fi
exit 0
