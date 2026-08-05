#!/bin/zsh

# Regression test for the retain-dir-struct-*.zsh family: hash-matched shadow
# sync (script 2, --dry-run preview), shadow-map creation (script 1), and
# shadow-to-real hash lookup (script 3) -- print-only output and
# process-substitution loops across all three.
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
SCRIPT3="$LOCALFS_DIR/retain-dir-struct-3-find-sorted.zsh"

if [[ ! -x "$SCRIPT2" ]]; then
    print -u2 -r -- "Error: $SCRIPT2 not found or not executable"
    exit 1
fi
if [[ ! -x "$SCRIPT1" ]]; then
    print -u2 -r -- "Error: $SCRIPT1 not found or not executable"
    exit 1
fi
if [[ ! -x "$SCRIPT3" ]]; then
    print -u2 -r -- "Error: $SCRIPT3 not found or not executable"
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

assert_stderr_and_exit() {
    # assert_stderr_and_exit <description> <expected_exit> <stderr_needle> -- <command...>
    # Captures stdout/stderr separately; passes only if stdout is empty,
    # stderr contains <stderr_needle>, and the exit code matches.
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

# --- Script 3 (retain-dir-struct-3-find-sorted.zsh): match + non-match ---
DATA_S3="$FIXROOT/data_s3"
mkdir -p "$DATA_S3"
print -r -- "s3 content one" > "$DATA_S3/f1.txt"

SHADOW_S3="$FIXROOT/shadow_s3"
"$SCRIPT1" "$DATA_S3" "$SHADOW_S3" >/dev/null 2>&1

# Inject a shadow file whose stored hash cannot match anything in DATA_S3
print -r -- "0000000000000000000000000000000000000000000000000000000000000000  nomatch" \
    > "$SHADOW_S3/zz-nomatch.txt"

output_s3=$("$SCRIPT3" "$SHADOW_S3" "$DATA_S3" 2>&1)

assert_contains "Script 3 match reports SHADOW line for real file" \
    "$output_s3" "SHADOW: f1.txt.txt"

expected_real_f1=$(realpath "$DATA_S3/f1.txt")
assert_contains "Script 3 match reports REAL line with the absolute path" \
    "$output_s3" "REAL  : $expected_real_f1"

assert_contains "Script 3 non-match reports no-match message" \
    "$output_s3" "No matching file found in "

# Separator lines survive (catches a naive echo-to-print conversion that
# silently swallows a dash-leading string)
sep_count_s3=$(print -r -- "$output_s3" | grep -c '^-\{52\}$')
if [[ "$sep_count_s3" == "2" ]]; then
    _record 0 "Script 3 emits exactly two 52-dash separator lines"
else
    _record 1 "Script 3 emits exactly two 52-dash separator lines (got $sep_count_s3)"
fi

# --- Script 3: duplicate content collapses to one file_map entry ---
DATA_S3_DUP="$FIXROOT/data_s3_dup"
mkdir -p "$DATA_S3_DUP"
print -r -- "dup content" > "$DATA_S3_DUP/dupA.txt"
print -r -- "dup content" > "$DATA_S3_DUP/dupB.txt"

SHADOW_S3_DUP_SRC="$FIXROOT/shadow_s3_dup_src"
"$SCRIPT1" "$DATA_S3_DUP" "$SHADOW_S3_DUP_SRC" >/dev/null 2>&1

# Only look up ONE of the two identical-hash shadow files
SHADOW_S3_DUP_LOOKUP="$FIXROOT/shadow_s3_dup_lookup"
mkdir -p "$SHADOW_S3_DUP_LOOKUP"
cp "$SHADOW_S3_DUP_SRC/dupA.txt.txt" "$SHADOW_S3_DUP_LOOKUP/"

output_s3_dup=$("$SCRIPT3" "$SHADOW_S3_DUP_LOOKUP" "$DATA_S3_DUP" 2>&1)
real_line_count_dup=$(print -r -- "$output_s3_dup" | grep -c '^REAL  : ')
if [[ "$real_line_count_dup" == "1" ]]; then
    _record 0 "Script 3 duplicate-content shadow resolves to exactly one REAL line"
else
    _record 1 "Script 3 duplicate-content shadow resolves to exactly one REAL line (got $real_line_count_dup)"
fi

# --- Script 3: empty inputs ---
EMPTY_SHADOW_S3="$FIXROOT/empty_shadow_s3"
EMPTY_DATA_S3="$FIXROOT/empty_data_s3"
mkdir -p "$EMPTY_SHADOW_S3" "$EMPTY_DATA_S3"

output_s3_empty=$("$SCRIPT3" "$EMPTY_SHADOW_S3" "$EMPTY_DATA_S3" 2>&1)
empty_s3_exit=$?

if [[ "$empty_s3_exit" == "0" ]]; then
    _record 0 "Script 3 empty-inputs run exits 0"
else
    _record 1 "Script 3 empty-inputs run exits 0 (got $empty_s3_exit)"
fi

if [[ "$output_s3_empty" != *"SHADOW: "* ]]; then
    _record 0 "Script 3 empty-inputs run emits no SHADOW line"
else
    _record 1 "Script 3 empty-inputs run emits no SHADOW line"
fi

# --- Script 3: validation errors reach stderr, not stdout ---
NONEXISTENT_SHADOW_S3="$FIXROOT/does_not_exist_s3"
assert_stderr_and_exit "Script 3 nonexistent shadow dir errors to stderr only" \
    1 "Error: " -- "$SCRIPT3" "$NONEXISTENT_SHADOW_S3" "$DATA_S3"

# --- Script 3: read-only (leaves the data tree untouched) ---
before_count_s3=$(find "$DATA_S3" -type f | wc -l)
before_hash_s3=$(sha256sum "$DATA_S3/f1.txt" | awk '{print $1}')
"$SCRIPT3" "$SHADOW_S3" "$DATA_S3" >/dev/null 2>&1
after_count_s3=$(find "$DATA_S3" -type f | wc -l)
after_hash_s3=$(sha256sum "$DATA_S3/f1.txt" | awk '{print $1}')
if [[ "$before_count_s3" == "$after_count_s3" && "$before_hash_s3" == "$after_hash_s3" ]]; then
    _record 0 "Script 3 is read-only: data tree unchanged after run"
else
    _record 1 "Script 3 is read-only: data tree unchanged after run"
fi

# --- Script 1 (retain-dir-struct-1.zsh): shadow creation ---
SRC_S1="$FIXROOT/src_s1"
mkdir -p "$SRC_S1/sub"
print -r -- "one" > "$SRC_S1/one.txt"
print -r -- "two" > "$SRC_S1/sub/two.txt"

SHADOW_S1="$FIXROOT/shadow_s1"
output_s1=$("$SCRIPT1" "$SRC_S1" "$SHADOW_S1" 2>&1)

assert_path "Script 1 creates shadow file for one.txt" \
    "$SHADOW_S1/one.txt.txt" "exists"
assert_path "Script 1 creates shadow file for sub/two.txt" \
    "$SHADOW_S1/sub/two.txt.txt" "exists"

hash_s1_line=$(<"$SHADOW_S1/one.txt.txt")
hash_s1_hex="${hash_s1_line%% *}"
if [[ "$hash_s1_hex" =~ '^[0-9a-f]{64}$' ]]; then
    _record 0 "Script 1 shadow file contains a 64-char hex hash"
else
    _record 1 "Script 1 shadow file contains a 64-char hex hash (got: $hash_s1_hex)"
fi

# Separator: exactly one three-dash line (catches a naive echo-to-print
# conversion that silently swallows the dash-leading string)
sep_count_s1=$(print -r -- "$output_s1" | grep -c '^---$')
if [[ "$sep_count_s1" == "1" ]]; then
    _record 0 "Script 1 emits exactly one three-dash separator line"
else
    _record 1 "Script 1 emits exactly one three-dash separator line (got $sep_count_s1)"
fi

assert_contains "Script 1 reports Shadow Map Complete" \
    "$output_s1" "Shadow Map Complete!"

# --- Script 1: usage reaches stderr, not stdout ---
assert_stderr_and_exit "Script 1 zero-args usage errors to stderr only" \
    1 "Usage: " -- "$SCRIPT1"

# --- Round trip: script 1 then script 3 over the same tree ---
output_roundtrip=$("$SCRIPT3" "$SHADOW_S1" "$SRC_S1" 2>&1)
expected_real_one=$(realpath "$SRC_S1/one.txt")
expected_real_two=$(realpath "$SRC_S1/sub/two.txt")

assert_contains "Round trip resolves one.txt back to its original file" \
    "$output_roundtrip" "REAL  : $expected_real_one"
assert_contains "Round trip resolves sub/two.txt back to its original file" \
    "$output_roundtrip" "REAL  : $expected_real_two"

# --- Summary ---
print -r -- "----------------------------------------------------"
print -r -- "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

if (( FAIL_COUNT > 0 )); then
    exit 1
fi
exit 0
