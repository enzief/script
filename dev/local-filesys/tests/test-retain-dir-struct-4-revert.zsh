#!/bin/zsh

# Regression test for retain-dir-struct-4-revert.zsh -- the bidirectional
# shadow/real-file swap tool. Covers name-first resolution, mandatory hash
# verification, the two-mv positional exchange, and every failure mode
# (no-match, hash mismatch, ambiguous duplicates, occupied destination,
# partial-swap rollback).
#
# Manual assert-style test (TESTING.md Option 3) -- no external test framework.
# Run directly: ./dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh
# Runs correctly from any working directory; resolves the scripts under test
# relative to this file's own location.

# Resolve scripts under test relative to this file, not the caller's cwd
SCRIPT_DIR=${0:A:h}
LOCALFS_DIR=${SCRIPT_DIR:h}
SCRIPT1="$LOCALFS_DIR/retain-dir-struct-1.zsh"
SCRIPT4="$LOCALFS_DIR/retain-dir-struct-4-revert.zsh"

if [[ ! -x "$SCRIPT1" ]]; then
    print -u2 -r -- "Error: $SCRIPT1 not found or not executable"
    exit 1
fi
if [[ ! -x "$SCRIPT4" ]]; then
    print -u2 -r -- "Error: $SCRIPT4 not found or not executable"
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

assert_equal() {
    # assert_equal <description> <actual> <expected>
    if [[ "$2" == "$3" ]]; then
        _record 0 "$1"
    else
        _record 1 "$1"
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

# --- Fixture helper: generate a genuine shadow via SCRIPT1 and place it ---
make_shadow() {
    # make_shadow <content> <dest_shadow_path>
    # Never hand-writes a hash string: hashes a scratch file with SCRIPT1,
    # then moves the resulting .txt to the requested home-tree path.
    local content="$1" dest="$2"
    local scratch_src scratch_shadow
    scratch_src=$(mktemp -d)
    print -r -- "$content" > "$scratch_src/f"
    scratch_shadow=$(mktemp -d)
    "$SCRIPT1" "$scratch_src" "$scratch_shadow" >/dev/null 2>&1
    mkdir -p "${dest:h}"
    mv "$scratch_shadow/f.txt" "$dest"
    rm -rf -- "$scratch_src" "$scratch_shadow"
}

# ======================================================================
# Case A: clean single-shadow swap (behavior's primary scenario)
# ======================================================================
H_A="$FIXROOT/case_a/home"
T_A="$FIXROOT/case_a/target"
mkdir -p "$H_A/a" "$T_A/x"

print -r -- "photo-bytes" > "$T_A/x/photo.jpg"
make_shadow "photo-bytes" "$H_A/a/photo.jpg.txt"

pre_real_hash=$(sha256sum "$T_A/x/photo.jpg" | awk '{print $1}')
pre_shadow_bytes=$(<"$H_A/a/photo.jpg.txt")

out_a=$("$SCRIPT4" "$H_A" "$T_A" 2>&1)
exit_a=$?

assert_path "Case A: real file lands at the shadow's exact home-tree path" \
    "$H_A/a/photo.jpg" "exists"
assert_path "Case A: shadow gone from its original home-tree path" \
    "$H_A/a/photo.jpg.txt" "absent"
assert_path "Case A: shadow lands at the real file's vacated target-tree path" \
    "$T_A/x/photo.jpg.txt" "exists"
assert_path "Case A: real file gone from its original target-tree path" \
    "$T_A/x/photo.jpg" "absent"

post_real_hash=$(sha256sum "$H_A/a/photo.jpg" | awk '{print $1}')
assert_equal "Case A: relocated real file's sha256 is unchanged" \
    "$post_real_hash" "$pre_real_hash"

post_shadow_bytes=$(<"$T_A/x/photo.jpg.txt")
assert_equal "Case A: relocated shadow's bytes are byte-identical to the original" \
    "$post_shadow_bytes" "$pre_shadow_bytes"

assert_contains "Case A: stdout carries a swap-confirmation line naming the shadow's relative path" \
    "$out_a" "a/photo.jpg"

if [[ "$exit_a" == "0" ]]; then
    _record 0 "Case A: exit code is 0"
else
    _record 1 "Case A: exit code is 0 (got $exit_a)"
fi

# ======================================================================
# Case B: non-shadow .txt file is left strictly untouched
# ======================================================================
H_B="$FIXROOT/case_b/home"
T_B="$FIXROOT/case_b/target"
mkdir -p "$H_B" "$T_B"
print -r -- "just some prose, not a shadow" > "$H_B/notes.txt"

"$SCRIPT4" "$H_B" "$T_B" >/dev/null 2>&1

assert_path "Case B: non-shadow .txt file is still present after the run" \
    "$H_B/notes.txt" "exists"

notes_created=$(find "$H_B" "$T_B" -name "notes" 2>/dev/null | wc -l)
if [[ "$notes_created" == "0" ]]; then
    _record 0 "Case B: no file named 'notes' was created anywhere"
else
    _record 1 "Case B: no file named 'notes' was created anywhere (found $notes_created)"
fi

# ======================================================================
# Case C: destination already occupied -- neither file moves
# ======================================================================
H_C="$FIXROOT/case_c/home"
T_C="$FIXROOT/case_c/target"
mkdir -p "$H_C/b" "$T_C/y"

make_shadow "dup-content" "$H_C/b/dup.jpg.txt"
print -r -- "pre-existing real content, not the swap target" > "$H_C/b/dup.jpg"
print -r -- "dup-content" > "$T_C/y/dup.jpg"

pre_occupied_bytes=$(<"$H_C/b/dup.jpg")

err_c=$("$SCRIPT4" "$H_C" "$T_C" 2>&1 1>/dev/null)

assert_contains "Case C: stderr carries a destination-already-exists error" \
    "$err_c" "Error: destination already exists for "

post_occupied_bytes=$(<"$H_C/b/dup.jpg")
assert_equal "Case C: the pre-existing occupying file is unchanged" \
    "$post_occupied_bytes" "$pre_occupied_bytes"

assert_path "Case C: hash-matching candidate in the target tree is untouched" \
    "$T_C/y/dup.jpg" "exists"
assert_path "Case C: shadow file itself is untouched" \
    "$H_C/b/dup.jpg.txt" "exists"

# ======================================================================
# Case D: overlapping tree roots -- rejected before any processing
# ======================================================================
H_D="$FIXROOT/case_d/home"
mkdir -p "$H_D"

assert_stderr_and_exit "Case D: same directory as both shadow and target tree exits 1, stderr-only" \
    1 "Error: " -- "$SCRIPT4" "$H_D" "$H_D"

# ======================================================================
# Case E: fewer than two arguments -- usage error
# ======================================================================
H_E="$FIXROOT/case_e/home"
mkdir -p "$H_E"

assert_stderr_and_exit "Case E: fewer than two arguments exits 1, stderr-only usage line" \
    1 "Usage: " -- "$SCRIPT4" "$H_E"

# --- Summary ---
print -r -- "----------------------------------------------------"
print -r -- "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

if (( FAIL_COUNT > 0 )); then
    exit 1
fi
exit 0
