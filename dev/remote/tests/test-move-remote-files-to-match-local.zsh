#!/bin/zsh

# Regression test for move-remote-files-to-match-local.zsh: reconciles a
# MEGA remote subtree's layout to match one or more local target
# directories via server-side `rclone moveto`, matching remote files to
# local candidates by size only and skipping any size that is ambiguous
# on either side.
#
# Manual assert-style test (TESTING.md Option 3) -- no external test
# framework. Run directly:
#   ./dev/remote/tests/test-move-remote-files-to-match-local.zsh
# Runs correctly from any working directory; resolves the script under
# test relative to this file's own location.
#
# Hermetic: a fixture-owned stub `rclone` is prepended to PATH for every
# invocation of the script under test, so no test path ever reaches the
# real `rclone` binary, the developer's rclone configuration, or the
# network. The stub is never appended -- only prepended -- because
# rclone is installed on this machine (~/.local/bin/rclone) and an
# appended stub could fall through to the real remote. TEST_REMOTE_NAME
# below is a value that cannot correspond to any real configured remote.

# Resolve the script under test relative to this file, not the caller's cwd
SCRIPT_DIR=${0:A:h}
REMOTE_DIR=${SCRIPT_DIR:h}
SCRIPT="$REMOTE_DIR/move-remote-files-to-match-local.zsh"

if [[ ! -x "$SCRIPT" ]]; then
    print -u2 -r -- "Error: $SCRIPT not found or not executable"
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

count_occurrences() {
    # count_occurrences <haystack> <needle> -- literal substring match,
    # counted per matching line. grep -F is mandatory: this machine's grep
    # is ugrep 7.8.4, which treats an unescaped "$" as a mid-pattern anchor
    # rather than a literal character without -F.
    print -r -- "$1" | grep -c -F -- "$2"
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

TEST_REMOTE_NAME="e42testremote"
TEST_REMOTE_PATH="suite/e42/path"

make_stub_rclone() {
    # make_stub_rclone <manifest-json-file>
    # Writes an executable `rclone` into STUB_BIN that appends its full
    # argv as one line to $FIXROOT/rclone.args, then dispatches on its
    # first argument: `lsjson` emits the named manifest file and exits 0;
    # `mkdir` exits with the contents of $FIXROOT/.mkdir_exit if that file
    # exists, else 0; `moveto` exits with the contents of
    # $FIXROOT/.moveto_exit if that file exists, else 0; anything else
    # exits 0. The failure-injection files are consumed starting in Task 2.
    local manifest_file="$1"
    {
        print -r -- '#!/bin/zsh'
        print -r -- "print -r -- \"\$@\" >> \"$FIXROOT/rclone.args\""
        print -r -- 'case "$1" in'
        print -r -- "  lsjson) cat \"$manifest_file\"; exit 0 ;;"
        print -r -- "  mkdir) [[ -f \"$FIXROOT/.mkdir_exit\" ]] && exit \"\$(cat \"$FIXROOT/.mkdir_exit\")\"; exit 0 ;;"
        print -r -- "  moveto) [[ -f \"$FIXROOT/.moveto_exit\" ]] && exit \"\$(cat \"$FIXROOT/.moveto_exit\")\"; exit 0 ;;"
        print -r -- '  *) exit 0 ;;'
        print -r -- 'esac'
    } > "$STUB_BIN/rclone"
    chmod +x "$STUB_BIN/rclone"
}

mkfile() {
    # mkfile <path> <size-bytes> -- creates a file of an exact byte length
    mkdir -p "${1:h}"
    head -c "$2" /dev/zero > "$1"
}

run_tool() {
    # run_tool <arg...> -- invokes the script under test with STUB_BIN
    # prepended to PATH (never exported/appended) and REMOTE_NAME/
    # REMOTE_PATH supplied from the fixture values. Sets TOOL_OUT,
    # TOOL_ERR, TOOL_EXIT.
    local out_file="$FIXROOT/.tool_stdout"
    local err_file="$FIXROOT/.tool_stderr"
    PATH="$STUB_BIN:$PATH" REMOTE_NAME="$TEST_REMOTE_NAME" REMOTE_PATH="$TEST_REMOTE_PATH" \
        "$SCRIPT" "$@" > "$out_file" 2> "$err_file"
    TOOL_EXIT=$?
    TOOL_OUT=$(<"$out_file")
    TOOL_ERR=$(<"$err_file")
}

reset_args_log() {
    # Truncates the per-case argv log between cases, first folding whatever
    # it held into a cumulative log spanning the whole suite (consumed by
    # Case U in Task 3).
    if [[ -f "$FIXROOT/rclone.args" ]]; then
        cat "$FIXROOT/rclone.args" >> "$FIXROOT/rclone.args.all"
    fi
    : > "$FIXROOT/rclone.args"
}

args_lines() {
    # args_lines <prefix> -- count of logged argv lines whose first word
    # equals the given prefix (e.g. "mkdir", "moveto", "lsjson").
    awk -v p="$1" '$1==p{c++} END{print c+0}' "$FIXROOT/rclone.args"
}

# ======================================================================
# Case A: real run, unique match, misplaced -- one mkdir, one moveto
# ======================================================================
CASE_A_MANIFEST="$FIXROOT/case_a_manifest.json"
cat > "$CASE_A_MANIFEST" <<'JSON'
[
  {"Path":"orig","Name":"orig","Size":-1,"IsDir":true},
  {"Path":"orig/IMG_0739.JPG","Name":"IMG_0739.JPG","Size":11,"IsDir":false}
]
JSON

CASE_A_TARGET="$FIXROOT/case_a/target"
mkfile "$CASE_A_TARGET/2019/IMG_0739.JPG" 11

make_stub_rclone "$CASE_A_MANIFEST"
reset_args_log
run_tool --target "$CASE_A_TARGET"
totals_real_a="$(print -r -- "$TOOL_OUT" | grep '^Totals: ')"

if [[ "$TOOL_EXIT" == "0" ]]; then
    _record 0 "Case A: exits 0"
else
    _record 1 "Case A: exits 0 (got $TOOL_EXIT)"
fi

assert_contains "Case A: stdout reports the move" \
    "$TOOL_OUT" "Moved: orig/IMG_0739.JPG -> 2019/IMG_0739.JPG"

mkdir_lines_a=$(args_lines mkdir)
moveto_lines_a=$(args_lines moveto)
assert_equal "Case A: exactly one mkdir logged" "$mkdir_lines_a" "1"
assert_equal "Case A: exactly one moveto logged" "$moveto_lines_a" "1"

mkdir_line_a=$(grep -F -- 'mkdir ' "$FIXROOT/rclone.args" | head -1)
assert_contains "Case A: mkdir names the 2019 destination dir" \
    "$mkdir_line_a" "${TEST_REMOTE_NAME}:${TEST_REMOTE_PATH}/2019"

moveto_line_a=$(grep -F -- 'moveto ' "$FIXROOT/rclone.args" | head -1)
assert_contains "Case A: moveto source operand names orig/IMG_0739.JPG" \
    "$moveto_line_a" "${TEST_REMOTE_NAME}:${TEST_REMOTE_PATH}/orig/IMG_0739.JPG"
assert_contains "Case A: moveto destination operand names 2019/IMG_0739.JPG" \
    "$moveto_line_a" "${TEST_REMOTE_NAME}:${TEST_REMOTE_PATH}/2019/IMG_0739.JPG"

mkdir_pos_a=$(grep -n -F -- 'mkdir ' "$FIXROOT/rclone.args" | head -1 | cut -d: -f1)
moveto_pos_a=$(grep -n -F -- 'moveto ' "$FIXROOT/rclone.args" | head -1 | cut -d: -f1)
if (( mkdir_pos_a < moveto_pos_a )); then
    _record 0 "Case A: mkdir is logged before moveto"
else
    _record 1 "Case A: mkdir is logged before moveto"
fi

# ======================================================================
# Case B: dry run over the identical fixture -- only lsjson is called,
# and the Totals line matches Case A's real-run Totals line byte for byte
# ======================================================================
reset_args_log
run_tool --dry-run --target "$CASE_A_TARGET"
totals_dry_b="$(print -r -- "$TOOL_OUT" | grep '^Totals: ')"

assert_contains "Case B: stdout reports the would-move" \
    "$TOOL_OUT" "Would move: orig/IMG_0739.JPG -> 2019/IMG_0739.JPG"

if [[ "$TOOL_OUT" != *"Moved: "* ]]; then
    _record 0 "Case B: stdout contains no Moved: line"
else
    _record 1 "Case B: stdout contains no Moved: line"
fi

args_total_lines_b=$(wc -l < "$FIXROOT/rclone.args")
assert_equal "Case B: argv log contains exactly one line" "$args_total_lines_b" "1"

first_line_b=$(head -1 "$FIXROOT/rclone.args")
assert_contains "Case B: the single logged line begins with lsjson" "$first_line_b" "lsjson"

mkdir_lines_b=$(args_lines mkdir)
moveto_lines_b=$(args_lines moveto)
assert_equal "Case B: zero mkdir logged" "$mkdir_lines_b" "0"
assert_equal "Case B: zero moveto logged" "$moveto_lines_b" "0"

assert_contains "Case B: closes with the dry-run message" \
    "$TOOL_OUT" "Dry run complete. No files were moved."

assert_equal "Case B: dry run Totals line equals Case A's real-run Totals line" \
    "$totals_dry_b" "$totals_real_a"

# ======================================================================
# Case B2: destination sits at the remote root -- moveto is logged but
# NO mkdir is logged (zsh's ${desired:h} returns "." for a bare filename,
# which must be suppressed rather than passed to `rclone mkdir`)
# ======================================================================
CASE_B2_MANIFEST="$FIXROOT/case_b2_manifest.json"
cat > "$CASE_B2_MANIFEST" <<'JSON'
[
  {"Path":"orig/IMG_0740.JPG","Name":"IMG_0740.JPG","Size":13,"IsDir":false}
]
JSON

CASE_B2_TARGET="$FIXROOT/case_b2/target"
mkfile "$CASE_B2_TARGET/IMG_0740.JPG" 13

make_stub_rclone "$CASE_B2_MANIFEST"
reset_args_log
run_tool --target "$CASE_B2_TARGET"

moveto_lines_b2=$(args_lines moveto)
mkdir_lines_b2=$(args_lines mkdir)
assert_equal "Case B2: exactly one moveto logged" "$moveto_lines_b2" "1"
assert_equal "Case B2: zero mkdir logged for a root-level destination" "$mkdir_lines_b2" "0"
assert_contains "Case B2: stdout reports the move to the remote root" \
    "$TOOL_OUT" "Moved: orig/IMG_0740.JPG -> IMG_0740.JPG"

# ======================================================================
# Case Z: hermeticity, asserted over the cumulative argv log -- every
# invocation across the whole suite so far names only the fixture remote,
# never the real 'mega:' remote or any other remote spec.
# ======================================================================
reset_args_log
cumulative_z=$(<"$FIXROOT/rclone.args.all")

if [[ "$cumulative_z" != *"mega:"* ]]; then
    _record 0 "Case Z: cumulative argv log never names the real 'mega:' remote"
else
    _record 1 "Case Z: cumulative argv log never names the real 'mega:' remote"
fi

z_bad_lines=$(print -r -- "$cumulative_z" | grep -v -F -- "${TEST_REMOTE_NAME}:" | grep -c -F -- ':')
if [[ "$z_bad_lines" == "0" ]]; then
    _record 0 "Case Z: every colon-bearing argv line names only the fixture remote"
else
    _record 1 "Case Z: every colon-bearing argv line names only the fixture remote (found $z_bad_lines other line(s))"
fi

if [[ "$TEST_REMOTE_NAME" != "mega" && "$TEST_REMOTE_NAME" != "" ]]; then
    _record 0 "Case Z: TEST_REMOTE_NAME is a value that cannot exist in any real rclone config"
else
    _record 1 "Case Z: TEST_REMOTE_NAME is a value that cannot exist in any real rclone config"
fi

# --- Summary ---
print -r -- "----------------------------------------------------"
print -r -- "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

if (( FAIL_COUNT > 0 )); then
    exit 1
fi
exit 0
