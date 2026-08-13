#!/bin/zsh

# Regression test for the rename-remote-files-*.zsh pair: the size-based
# match/shadow/sync pipeline (script 1) and the shadow-driven reversion
# (script 2), driven end-to-end against a stubbed rclone manifest.
#
# Manual assert-style test (TESTING.md Option 3) -- no external test
# framework. Run directly: ./dev/remote/tests/test-rename-remote-files.zsh
# Runs correctly from any working directory; resolves the scripts under
# test relative to this file's own location.
#
# Hermetic: a fixture-owned stub `rclone` is prepended to PATH for every
# invocation of script 1, so no test path ever reaches the real `rclone`
# binary, the developer's rclone configuration, or the network. The stub
# is never appended -- only prepended -- because rclone is installed on
# this machine and an appended stub could fall through to the real remote.

# Resolve scripts under test relative to this file, not the caller's cwd
SCRIPT_DIR=${0:A:h}
REMOTE_DIR=${SCRIPT_DIR:h}
SCRIPT1="$REMOTE_DIR/rename-remote-files-1-match-remote.zsh"
SCRIPT2="$REMOTE_DIR/rename-remote-files-2-rename-local.zsh"

if [[ ! -x "$SCRIPT1" ]]; then
    print -u2 -r -- "Error: $SCRIPT1 not found or not executable"
    exit 1
fi
if [[ ! -x "$SCRIPT2" ]]; then
    print -u2 -r -- "Error: $SCRIPT2 not found or not executable"
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

# --- Fixture-owned stub rclone directory (prepended to PATH, never appended) ---
STUB_BIN="$FIXROOT/bin"
mkdir -p "$STUB_BIN"

TEST_REMOTE_NAME="suitetestremote"
TEST_REMOTE_PATH="suite/test/path"

make_stub_rclone() {
    # make_stub_rclone <manifest-json-file>
    # Writes an executable `rclone` into STUB_BIN that records its full argv
    # as one line in $FIXROOT/rclone.args and emits the contents of the
    # named manifest file, always exiting 0.
    local manifest_file="$1"
    {
        print -r -- '#!/bin/zsh'
        print -r -- "print -r -- \"\$@\" >> \"$FIXROOT/rclone.args\""
        print -r -- "cat \"$manifest_file\""
        print -r -- 'exit 0'
    } > "$STUB_BIN/rclone"
    chmod +x "$STUB_BIN/rclone"
}

mkfile() {
    # mkfile <path> <size-bytes> -- creates a file of an exact byte length
    mkdir -p "${1:h}"
    head -c "$2" /dev/zero > "$1"
}

run_s1() {
    # run_s1 <src> <shadow> <sync> -- runs script 1 with STUB_BIN prepended
    # to PATH and REMOTE_NAME/REMOTE_PATH supplied from the fixture values.
    # Sets S1_OUT, S1_ERR, S1_EXIT.
    local out_file="$FIXROOT/.s1_stdout"
    local err_file="$FIXROOT/.s1_stderr"
    PATH="$STUB_BIN:$PATH" REMOTE_NAME="$TEST_REMOTE_NAME" REMOTE_PATH="$TEST_REMOTE_PATH" \
        "$SCRIPT1" "$1" "$2" "$3" > "$out_file" 2> "$err_file"
    S1_EXIT=$?
    S1_OUT=$(<"$out_file")
    S1_ERR=$(<"$err_file")
}

run_s2() {
    # run_s2 <shadow> <sync> -- runs script 2. Sets S2_OUT, S2_ERR, S2_EXIT.
    local out_file="$FIXROOT/.s2_stdout"
    local err_file="$FIXROOT/.s2_stderr"
    "$SCRIPT2" "$1" "$2" > "$out_file" 2> "$err_file"
    S2_EXIT=$?
    S2_OUT=$(<"$out_file")
    S2_ERR=$(<"$err_file")
}

# ======================================================================
# Task 1: end-to-end round trip -- match, shadow, sync, revert
# ======================================================================

RT_SRC="$FIXROOT/rt_src"
RT_SHADOW="$FIXROOT/rt_shadow"
RT_SYNC="$FIXROOT/rt_sync"

# One matched file at root (size 11), one matched + nested + space (size 22),
# one unmatched file (size 33).
mkfile "$RT_SRC/alpha.jpg" 11
mkfile "$RT_SRC/sub/beta file.jpg" 22
mkfile "$RT_SRC/gamma.jpg" 33

RT_MANIFEST="$FIXROOT/rt_manifest.json"
cat > "$RT_MANIFEST" <<'JSON'
[
  {"Path":"remoteprefix","Name":"remoteprefix","Size":-1,"IsDir":true},
  {"Path":"remoteprefix/alpha-remote.jpg","Name":"alpha-remote.jpg","Size":11,"IsDir":false},
  {"Path":"remoteprefix/sub/beta-remote.jpg","Name":"beta-remote.jpg","Size":22,"IsDir":false}
]
JSON

make_stub_rclone "$RT_MANIFEST"

run_s1 "$RT_SRC" "$RT_SHADOW" "$RT_SYNC"

if [[ "$S1_EXIT" == "0" ]]; then
    _record 0 "Round trip: script 1 exits 0"
else
    _record 1 "Round trip: script 1 exits 0 (got $S1_EXIT)"
fi

assert_contains "Round trip: stdout reports Match Found for size 11" \
    "$S1_OUT" "Match Found (Size: 11)"
assert_contains "Round trip: stdout reports Match Found for size 22" \
    "$S1_OUT" "Match Found (Size: 22)"
assert_contains "Round trip: stdout reports No Match for size-33 file" \
    "$S1_OUT" "No Match: gamma.jpg (Size: 33)"

assert_path "Round trip: shadow file exists for alpha.jpg" \
    "$RT_SHADOW/alpha.jpg.txt" "exists"
assert_path "Round trip: shadow file exists for nested space-containing beta file.jpg" \
    "$RT_SHADOW/sub/beta file.jpg.txt" "exists"

shadow_contents=$(<"$RT_SHADOW/sub/beta file.jpg.txt")
assert_contains "Round trip: beta shadow file contains ORIGINAL_LOCAL_PATH" \
    "$shadow_contents" "ORIGINAL_LOCAL_PATH="
assert_contains "Round trip: beta shadow file names the matched remote path" \
    "$shadow_contents" "MATCHED_REMOTE_PATH=\"remoteprefix/sub/beta-remote.jpg\""

assert_path "Round trip: alpha.jpg now exists under the sync root at its remote path" \
    "$RT_SYNC/remoteprefix/alpha-remote.jpg" "exists"
assert_path "Round trip: beta file.jpg now exists under the sync root at its remote path" \
    "$RT_SYNC/remoteprefix/sub/beta-remote.jpg" "exists"
assert_path "Round trip: alpha.jpg no longer exists at its original location" \
    "$RT_SRC/alpha.jpg" "absent"
assert_path "Round trip: beta file.jpg no longer exists at its original location" \
    "$RT_SRC/sub/beta file.jpg" "absent"

assert_path "Round trip: gamma.jpg (unmatched) still exists at its original location" \
    "$RT_SRC/gamma.jpg" "exists"
assert_path "Round trip: gamma.jpg has no shadow file" \
    "$RT_SHADOW/gamma.jpg.txt" "absent"

run_s2 "$RT_SHADOW" "$RT_SYNC"

if [[ "$S2_EXIT" == "0" ]]; then
    _record 0 "Round trip: script 2 exits 0"
else
    _record 1 "Round trip: script 2 exits 0 (got $S2_EXIT)"
fi

assert_path "Round trip: alpha.jpg restored to its original absolute path" \
    "$RT_SRC/alpha.jpg" "exists"
assert_path "Round trip: beta file.jpg restored to its original absolute path (space intact)" \
    "$RT_SRC/sub/beta file.jpg" "exists"

rt_sync_remaining=$(find "$RT_SYNC" -type f | wc -l)
if [[ "$rt_sync_remaining" == "0" ]]; then
    _record 0 "Round trip: sync tree holds no files after reversion"
else
    _record 1 "Round trip: sync tree holds no files after reversion (found $rt_sync_remaining)"
fi

# --- Summary ---
print -r -- "----------------------------------------------------"
print -r -- "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

if (( FAIL_COUNT > 0 )); then
    exit 1
fi
exit 0
