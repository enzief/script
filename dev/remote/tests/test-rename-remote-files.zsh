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

write_shadow() {
    # write_shadow <shadow-path> <original-local-path> <matched-remote-path>
    # Writes a well-formed shadow file by hand, in the same KEY="value" form
    # script 1 emits, so fixtures can place a malformed file among valid
    # ones without running script 1.
    mkdir -p "${1:h}"
    {
        print -r -- "ORIGINAL_LOCAL_PATH=\"$2\""
        print -r -- "MATCHED_REMOTE_PATH=\"$3\""
    } > "$1"
}

write_bad_shadow() {
    # write_bad_shadow <shadow-path> [mode]
    # Writes a shadow file that must fail script 2's validation. mode:
    #   comment        (default) -- a comment-only file, sets nothing
    #   empty                    -- a zero-byte file
    #   blank-original           -- ORIGINAL_LOCAL_PATH="" ; MATCHED_REMOTE_PATH set
    #   blank-matched            -- MATCHED_REMOTE_PATH="" ; ORIGINAL_LOCAL_PATH set
    local shadow_path="$1" mode="${2:-comment}"
    mkdir -p "${shadow_path:h}"
    case "$mode" in
        empty)
            : > "$shadow_path"
            ;;
        blank-original)
            {
                print -r -- 'ORIGINAL_LOCAL_PATH=""'
                print -r -- 'MATCHED_REMOTE_PATH="remoteprefix/blank-original.jpg"'
            } > "$shadow_path"
            ;;
        blank-matched)
            {
                print -r -- "ORIGINAL_LOCAL_PATH=\"$FIXROOT/blank_matched_orig.jpg\""
                print -r -- 'MATCHED_REMOTE_PATH=""'
            } > "$shadow_path"
            ;;
        *)
            print -r -- '# not a valid shadow file' > "$shadow_path"
            ;;
    esac
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

rt_rclone_args=$(<"$FIXROOT/rclone.args")
assert_contains "Round trip: rclone stub received the configured remote spec" \
    "$rt_rclone_args" "${TEST_REMOTE_NAME}:${TEST_REMOTE_PATH}"
assert_contains "Round trip: stdout manifest-fetch line names the configured remote spec" \
    "$S1_OUT" "${TEST_REMOTE_NAME}:${TEST_REMOTE_PATH}"

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

# ======================================================================
# Task 2: preflight -- missing rclone/jq, missing REMOTE_NAME/REMOTE_PATH,
# no mutation on preflight failure, empty-input edges
# ======================================================================

# --- Missing rclone: PATH points at a directory that exists but is empty ---
EMPTY_BIN="$FIXROOT/empty_bin"
mkdir -p "$EMPTY_BIN"

assert_stderr_and_exit "Preflight: missing rclone exits 1, stderr names rclone, stdout empty" 1 "rclone" -- \
    env PATH="$EMPTY_BIN" "$SCRIPT1" "$FIXROOT/pf_dummy1" "$FIXROOT/pf_dummy2" "$FIXROOT/pf_dummy3"

# --- Missing jq: PATH points at STUB_BIN, which holds only the stub rclone ---
assert_stderr_and_exit "Preflight: missing jq exits 1, stderr names jq, stdout empty" 1 "jq" -- \
    env PATH="$STUB_BIN" "$SCRIPT1" "$FIXROOT/pf_dummy1" "$FIXROOT/pf_dummy2" "$FIXROOT/pf_dummy3"

# --- Missing REMOTE_NAME / REMOTE_PATH, plus no-mutation-on-failure ---
PF_SRC="$FIXROOT/pf_src"
PF_SHADOW="$FIXROOT/pf_shadow"
PF_SYNC="$FIXROOT/pf_sync"
mkfile "$PF_SRC/known.jpg" 7

assert_stderr_and_exit "Preflight: missing REMOTE_NAME exits 1, stderr names REMOTE_NAME, stdout empty" 1 "REMOTE_NAME" -- \
    env -u REMOTE_NAME PATH="$STUB_BIN:$PATH" REMOTE_PATH="$TEST_REMOTE_PATH" \
    "$SCRIPT1" "$PF_SRC" "$PF_SHADOW" "$PF_SYNC"

assert_path "Preflight: no mutation -- source file still present after missing-REMOTE_NAME failure" \
    "$PF_SRC/known.jpg" "exists"
assert_path "Preflight: no mutation -- shadow dir not created after missing-REMOTE_NAME failure" \
    "$PF_SHADOW" "absent"
assert_path "Preflight: no mutation -- sync dir not created after missing-REMOTE_NAME failure" \
    "$PF_SYNC" "absent"

assert_stderr_and_exit "Preflight: missing REMOTE_PATH exits 1, stderr names REMOTE_PATH, stdout empty" 1 "REMOTE_PATH" -- \
    env -u REMOTE_PATH PATH="$STUB_BIN:$PATH" REMOTE_NAME="$TEST_REMOTE_NAME" \
    "$SCRIPT1" "$PF_SRC" "$PF_SHADOW" "$PF_SYNC"

# --- Empty source directory: exits 0, both output dirs created, no match lines ---
EMPTY_SRC="$FIXROOT/empty_src"
EMPTY_SHADOW="$FIXROOT/empty_shadow"
EMPTY_SYNC="$FIXROOT/empty_sync"
mkdir -p "$EMPTY_SRC"

run_s1 "$EMPTY_SRC" "$EMPTY_SHADOW" "$EMPTY_SYNC"

if [[ "$S1_EXIT" == "0" ]]; then
    _record 0 "Empty source dir: script 1 exits 0"
else
    _record 1 "Empty source dir: script 1 exits 0 (got $S1_EXIT)"
fi
assert_path "Empty source dir: shadow directory created" "$EMPTY_SHADOW" "exists"
assert_path "Empty source dir: sync directory created" "$EMPTY_SYNC" "exists"
if [[ "$S1_OUT" != *"Match Found"* ]]; then
    _record 0 "Empty source dir: no Match Found line"
else
    _record 1 "Empty source dir: no Match Found line"
fi
if [[ "$S1_OUT" != *"No Match"* ]]; then
    _record 0 "Empty source dir: no No Match line"
else
    _record 1 "Empty source dir: no No Match line"
fi

# --- Manifest with zero file entries (directory entry only): No Match for every local file ---
NOFILES_SRC="$FIXROOT/nofiles_src"
NOFILES_SHADOW="$FIXROOT/nofiles_shadow"
NOFILES_SYNC="$FIXROOT/nofiles_sync"
mkfile "$NOFILES_SRC/onlyfile.jpg" 9

NOFILES_MANIFEST="$FIXROOT/nofiles_manifest.json"
cat > "$NOFILES_MANIFEST" <<'JSON'
[
  {"Path":"remoteprefix","Name":"remoteprefix","Size":-1,"IsDir":true}
]
JSON
make_stub_rclone "$NOFILES_MANIFEST"

run_s1 "$NOFILES_SRC" "$NOFILES_SHADOW" "$NOFILES_SYNC"

if [[ "$S1_EXIT" == "0" ]]; then
    _record 0 "Manifest with no file entries: script 1 exits 0"
else
    _record 1 "Manifest with no file entries: script 1 exits 0 (got $S1_EXIT)"
fi
assert_contains "Manifest with no file entries: reports No Match for the local file" \
    "$S1_OUT" "No Match:"
nofiles_src_remaining=$(find "$NOFILES_SRC" -type f | wc -l)
if [[ "$nofiles_src_remaining" == "1" ]]; then
    _record 0 "Manifest with no file entries: source tree unchanged"
else
    _record 1 "Manifest with no file entries: source tree unchanged (found $nofiles_src_remaining)"
fi

# ======================================================================
# Plan 03-02 Task 1: a malformed shadow file is skipped, not silently
# driven by the previous file's paths (REMOTE-03, D-04, D-05)
# ======================================================================

# --- Comment-only shadow among valid ones ---
MAL1_SHADOW="$FIXROOT/mal1_shadow"
MAL1_SYNC="$FIXROOT/mal1_sync"
MAL1_ORIG1="$FIXROOT/mal1_orig/one.jpg"
MAL1_ORIG2="$FIXROOT/mal1_orig/sub/two.jpg"

write_shadow "$MAL1_SHADOW/one.jpg.txt" "$MAL1_ORIG1" "remoteprefix/one-remote.jpg"
write_shadow "$MAL1_SHADOW/sub/two.jpg.txt" "$MAL1_ORIG2" "remoteprefix/sub/two-remote.jpg"
write_bad_shadow "$MAL1_SHADOW/bad.txt" comment
mkfile "$MAL1_SYNC/remoteprefix/one-remote.jpg" 5
mkfile "$MAL1_SYNC/remoteprefix/sub/two-remote.jpg" 6

run_s2 "$MAL1_SHADOW" "$MAL1_SYNC"

if [[ "$S2_EXIT" == "0" ]]; then
    _record 0 "Malformed shadow (comment-only): script 2 exits 0"
else
    _record 1 "Malformed shadow (comment-only): script 2 exits 0 (got $S2_EXIT)"
fi
assert_contains "Malformed shadow (comment-only): stderr has Error: line naming the bad file" \
    "$S2_ERR" "Error:"
assert_contains "Malformed shadow (comment-only): stderr names bad.txt" \
    "$S2_ERR" "bad.txt"
assert_path "Malformed shadow (comment-only): valid file one.jpg restored" \
    "$MAL1_ORIG1" "exists"
assert_path "Malformed shadow (comment-only): valid file two.jpg restored" \
    "$MAL1_ORIG2" "exists"
mal1_sync_remaining=$(find "$MAL1_SYNC" -type f | wc -l)
if [[ "$mal1_sync_remaining" == "0" ]]; then
    _record 0 "Malformed shadow (comment-only): sync tree empty after run"
else
    _record 1 "Malformed shadow (comment-only): sync tree empty after run (found $mal1_sync_remaining)"
fi
if [[ "$S2_OUT" != *"warning: file not found in sync dir:"* ]]; then
    _record 0 "Malformed shadow (comment-only): no stale-inheritance warning line"
else
    _record 1 "Malformed shadow (comment-only): no stale-inheritance warning line"
fi

# --- Zero-byte shadow ---
MAL2_SHADOW="$FIXROOT/mal2_shadow"
MAL2_SYNC="$FIXROOT/mal2_sync"
MAL2_ORIG1="$FIXROOT/mal2_orig/one.jpg"
MAL2_ORIG2="$FIXROOT/mal2_orig/sub/two.jpg"

write_shadow "$MAL2_SHADOW/one.jpg.txt" "$MAL2_ORIG1" "remoteprefix/one-remote.jpg"
write_shadow "$MAL2_SHADOW/sub/two.jpg.txt" "$MAL2_ORIG2" "remoteprefix/sub/two-remote.jpg"
write_bad_shadow "$MAL2_SHADOW/bad.txt" empty
mkfile "$MAL2_SYNC/remoteprefix/one-remote.jpg" 5
mkfile "$MAL2_SYNC/remoteprefix/sub/two-remote.jpg" 6

run_s2 "$MAL2_SHADOW" "$MAL2_SYNC"

if [[ "$S2_EXIT" == "0" ]]; then
    _record 0 "Malformed shadow (zero-byte): script 2 exits 0"
else
    _record 1 "Malformed shadow (zero-byte): script 2 exits 0 (got $S2_EXIT)"
fi
assert_contains "Malformed shadow (zero-byte): stderr has Error: line naming the bad file" \
    "$S2_ERR" "Error:"
assert_contains "Malformed shadow (zero-byte): stderr names bad.txt" \
    "$S2_ERR" "bad.txt"
assert_path "Malformed shadow (zero-byte): valid file one.jpg restored" \
    "$MAL2_ORIG1" "exists"
assert_path "Malformed shadow (zero-byte): valid file two.jpg restored" \
    "$MAL2_ORIG2" "exists"
mal2_sync_remaining=$(find "$MAL2_SYNC" -type f | wc -l)
if [[ "$mal2_sync_remaining" == "0" ]]; then
    _record 0 "Malformed shadow (zero-byte): sync tree empty after run"
else
    _record 1 "Malformed shadow (zero-byte): sync tree empty after run (found $mal2_sync_remaining)"
fi
if [[ "$S2_OUT" != *"warning: file not found in sync dir:"* ]]; then
    _record 0 "Malformed shadow (zero-byte): no stale-inheritance warning line"
else
    _record 1 "Malformed shadow (zero-byte): no stale-inheritance warning line"
fi

# --- Empty-string assignment (non-empty check, not merely set) ---
for blank_mode in blank-original blank-matched; do
    MAL3_SHADOW="$FIXROOT/mal3_${blank_mode}_shadow"
    MAL3_SYNC="$FIXROOT/mal3_${blank_mode}_sync"
    MAL3_ORIG="$FIXROOT/mal3_${blank_mode}_orig/one.jpg"

    write_shadow "$MAL3_SHADOW/one.jpg.txt" "$MAL3_ORIG" "remoteprefix/one-remote.jpg"
    write_bad_shadow "$MAL3_SHADOW/bad.txt" "$blank_mode"
    mkfile "$MAL3_SYNC/remoteprefix/one-remote.jpg" 5

    run_s2 "$MAL3_SHADOW" "$MAL3_SYNC"

    if [[ "$S2_EXIT" == "0" ]]; then
        _record 0 "Malformed shadow ($blank_mode): script 2 exits 0"
    else
        _record 1 "Malformed shadow ($blank_mode): script 2 exits 0 (got $S2_EXIT)"
    fi
    assert_contains "Malformed shadow ($blank_mode): stderr has Error: line naming the bad file" \
        "$S2_ERR" "Error:"
    assert_contains "Malformed shadow ($blank_mode): stderr names bad.txt" \
        "$S2_ERR" "bad.txt"
    assert_path "Malformed shadow ($blank_mode): sibling valid file restored" \
        "$MAL3_ORIG" "exists"
done

# --- Position independence: malformed file among several valid ones, nested
# at varying depths so traversal order cannot be assumed either way.
# Assertions below check content and counts only, never relative order. ---
MAL4_SHADOW="$FIXROOT/mal4_shadow"
MAL4_SYNC="$FIXROOT/mal4_sync"
MAL4_ORIG1="$FIXROOT/mal4_orig/a.jpg"
MAL4_ORIG2="$FIXROOT/mal4_orig/b/b.jpg"
MAL4_ORIG3="$FIXROOT/mal4_orig/c/d/c.jpg"

write_shadow "$MAL4_SHADOW/a.jpg.txt" "$MAL4_ORIG1" "remoteprefix/a-remote.jpg"
write_bad_shadow "$MAL4_SHADOW/b/bad.txt" comment
write_shadow "$MAL4_SHADOW/b/b.jpg.txt" "$MAL4_ORIG2" "remoteprefix/b-remote.jpg"
write_shadow "$MAL4_SHADOW/c/d/c.jpg.txt" "$MAL4_ORIG3" "remoteprefix/c-remote.jpg"
mkfile "$MAL4_SYNC/remoteprefix/a-remote.jpg" 5
mkfile "$MAL4_SYNC/remoteprefix/b-remote.jpg" 6
mkfile "$MAL4_SYNC/remoteprefix/c-remote.jpg" 7

run_s2 "$MAL4_SHADOW" "$MAL4_SYNC"

if [[ "$S2_EXIT" == "0" ]]; then
    _record 0 "Malformed shadow (position independence): script 2 exits 0"
else
    _record 1 "Malformed shadow (position independence): script 2 exits 0 (got $S2_EXIT)"
fi
mal4_error_count=$(grep -c '^Error:' <<< "$S2_ERR")
if [[ "$mal4_error_count" == "1" ]]; then
    _record 0 "Malformed shadow (position independence): exactly one Error: line"
else
    _record 1 "Malformed shadow (position independence): exactly one Error: line (found $mal4_error_count)"
fi
assert_path "Malformed shadow (position independence): a.jpg restored" \
    "$MAL4_ORIG1" "exists"
assert_path "Malformed shadow (position independence): b.jpg restored" \
    "$MAL4_ORIG2" "exists"
assert_path "Malformed shadow (position independence): c.jpg restored" \
    "$MAL4_ORIG3" "exists"
mal4_sync_remaining=$(find "$MAL4_SYNC" -type f | wc -l)
if [[ "$mal4_sync_remaining" == "0" ]]; then
    _record 0 "Malformed shadow (position independence): sync tree empty after run"
else
    _record 1 "Malformed shadow (position independence): sync tree empty after run (found $mal4_sync_remaining)"
fi

# --- Summary ---
print -r -- "----------------------------------------------------"
print -r -- "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

if (( FAIL_COUNT > 0 )); then
    exit 1
fi
exit 0
