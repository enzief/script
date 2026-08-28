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

# --- Failure-injection helpers (Task 2): force the stub's mkdir/moveto
# dispatch to a non-zero exit for the next run, then clear afterward so a
# forced failure can never leak into a later case. ---
set_mkdir_exit() {
    print -r -- "$1" > "$FIXROOT/.mkdir_exit"
}

set_moveto_exit() {
    print -r -- "$1" > "$FIXROOT/.moveto_exit"
}

reset_failure_injection() {
    rm -f "$FIXROOT/.mkdir_exit" "$FIXROOT/.moveto_exit"
}

make_stub_rclone_tabbed() {
    # make_stub_rclone_tabbed <manifest-json-file>
    # Variant of make_stub_rclone (Task 3, Case S) that logs each
    # invocation as "<argc>\t<arg1>\t<arg2>\t..." instead of a plain
    # space-joined line, so a test can verify argument COUNT, not just
    # substring presence -- needed to prove an operand containing an
    # embedded space survived as a single argv word rather than being
    # split into two by the time it reached rclone.
    local manifest_file="$1"
    {
        print -r -- '#!/bin/zsh'
        print -r -- "{ print -rn -- \"\$#\"; for a in \"\$@\"; do print -rn -- \$'\t'\"\$a\"; done; print; } >> \"$FIXROOT/rclone.args\""
        print -r -- 'case "$1" in'
        print -r -- "  lsjson) cat \"$manifest_file\"; exit 0 ;;"
        print -r -- "  mkdir) [[ -f \"$FIXROOT/.mkdir_exit\" ]] && exit \"\$(cat \"$FIXROOT/.mkdir_exit\")\"; exit 0 ;;"
        print -r -- "  moveto) [[ -f \"$FIXROOT/.moveto_exit\" ]] && exit \"\$(cat \"$FIXROOT/.moveto_exit\")\"; exit 0 ;;"
        print -r -- '  *) exit 0 ;;'
        print -r -- 'esac'
    } > "$STUB_BIN/rclone"
    chmod +x "$STUB_BIN/rclone"
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

# ======================================================================
# Case C: already correct -- counted only, no per-file line
# ======================================================================
CASE_C_MANIFEST="$FIXROOT/case_c_manifest.json"
cat > "$CASE_C_MANIFEST" <<'JSON'
[
  {"Path":"2019/IMG.JPG","Name":"IMG.JPG","Size":11,"IsDir":false}
]
JSON
CASE_C_TARGET="$FIXROOT/case_c/target"
mkfile "$CASE_C_TARGET/2019/IMG.JPG" 11

make_stub_rclone "$CASE_C_MANIFEST"
reset_args_log
reset_failure_injection
run_tool --target "$CASE_C_TARGET"

if [[ "$TOOL_EXIT" == "0" ]]; then
    _record 0 "Case C: exits 0"
else
    _record 1 "Case C: exits 0 (got $TOOL_EXIT)"
fi
totals_c=$(print -r -- "$TOOL_OUT" | grep '^Totals: ')
assert_contains "Case C: Totals reports 1 already correct" "$totals_c" "1 already correct"
assert_contains "Case C: Totals reports 0 moved" "$totals_c" "0 moved"
mkdir_lines_c=$(args_lines mkdir)
moveto_lines_c=$(args_lines moveto)
assert_equal "Case C: zero mkdir logged" "$mkdir_lines_c" "0"
assert_equal "Case C: zero moveto logged" "$moveto_lines_c" "0"
if [[ "$TOOL_OUT" != *"Moved: "* ]]; then
    _record 0 "Case C: stdout has no Moved: line"
else
    _record 1 "Case C: stdout has no Moved: line"
fi
if [[ "$TOOL_OUT" != *"Skip: "* ]]; then
    _record 0 "Case C: stdout has no Skip: line"
else
    _record 1 "Case C: stdout has no Skip: line"
fi

# ======================================================================
# Case D: local-side collision -- two local files share the remote-unique
# file's size
# ======================================================================
CASE_D_MANIFEST="$FIXROOT/case_d_manifest.json"
cat > "$CASE_D_MANIFEST" <<'JSON'
[
  {"Path":"orig/d.JPG","Name":"d.JPG","Size":11,"IsDir":false}
]
JSON
CASE_D_TARGET="$FIXROOT/case_d/target"
mkfile "$CASE_D_TARGET/one/x.JPG" 11
mkfile "$CASE_D_TARGET/two/y.JPG" 11

make_stub_rclone "$CASE_D_MANIFEST"
reset_args_log
run_tool --target "$CASE_D_TARGET"

assert_contains "Case D: stdout skips on local-side size collision" \
    "$TOOL_OUT" "Skip: orig/d.JPG (size 11: 2 local files share this size)"
moveto_lines_d=$(args_lines moveto)
assert_equal "Case D: zero moveto logged" "$moveto_lines_d" "0"
if [[ "$TOOL_EXIT" == "0" ]]; then
    _record 0 "Case D: exits 0"
else
    _record 1 "Case D: exits 0 (got $TOOL_EXIT)"
fi

# ======================================================================
# Case E: remote-side collision -- two remote files share a size that is
# unique on the local side; both remote paths are reported
# ======================================================================
CASE_E_MANIFEST="$FIXROOT/case_e_manifest.json"
cat > "$CASE_E_MANIFEST" <<'JSON'
[
  {"Path":"orig/e1.JPG","Name":"e1.JPG","Size":11,"IsDir":false},
  {"Path":"orig/e2.JPG","Name":"e2.JPG","Size":11,"IsDir":false}
]
JSON
CASE_E_TARGET="$FIXROOT/case_e/target"
mkfile "$CASE_E_TARGET/only.JPG" 11

make_stub_rclone "$CASE_E_MANIFEST"
reset_args_log
run_tool --target "$CASE_E_TARGET"

assert_contains "Case E: skip line for first remote-side collision path" \
    "$TOOL_OUT" "Skip: orig/e1.JPG (size 11: 2 remote files share this size)"
assert_contains "Case E: skip line for second remote-side collision path" \
    "$TOOL_OUT" "Skip: orig/e2.JPG (size 11: 2 remote files share this size)"
moveto_lines_e=$(args_lines moveto)
assert_equal "Case E: zero moveto logged" "$moveto_lines_e" "0"
if [[ "$TOOL_EXIT" == "0" ]]; then
    _record 0 "Case E: exits 0"
else
    _record 1 "Case E: exits 0 (got $TOOL_EXIT)"
fi

# ======================================================================
# Case F: no local match for the remote file's size
# ======================================================================
CASE_F_MANIFEST="$FIXROOT/case_f_manifest.json"
cat > "$CASE_F_MANIFEST" <<'JSON'
[
  {"Path":"orig/f.JPG","Name":"f.JPG","Size":99,"IsDir":false}
]
JSON
CASE_F_TARGET="$FIXROOT/case_f/target"
mkdir -p "$CASE_F_TARGET"

make_stub_rclone "$CASE_F_MANIFEST"
reset_args_log
run_tool --target "$CASE_F_TARGET"

assert_contains "Case F: skip line for no local match" \
    "$TOOL_OUT" "Skip: orig/f.JPG (size 99: no local file of this size)"
moveto_lines_f=$(args_lines moveto)
assert_equal "Case F: zero moveto logged" "$moveto_lines_f" "0"
if [[ "$TOOL_EXIT" == "0" ]]; then
    _record 0 "Case F: exits 0"
else
    _record 1 "Case F: exits 0 (got $TOOL_EXIT)"
fi

# ======================================================================
# Case G: destination already occupied on the remote -- the data-loss
# guard. rclone moveto overwrites its destination, so an unguarded run
# here would destroy the file already at 2019/a.JPG.
# ======================================================================
CASE_G_MANIFEST="$FIXROOT/case_g_manifest.json"
cat > "$CASE_G_MANIFEST" <<'JSON'
[
  {"Path":"orig/a.JPG","Name":"a.JPG","Size":11,"IsDir":false},
  {"Path":"2019/a.JPG","Name":"a.JPG","Size":22,"IsDir":false}
]
JSON
CASE_G_TARGET="$FIXROOT/case_g/target"
mkfile "$CASE_G_TARGET/2019/a.JPG" 11

make_stub_rclone "$CASE_G_MANIFEST"
reset_args_log
run_tool --target "$CASE_G_TARGET"

assert_contains "Case G: stderr reports the destination-already-occupied refusal" \
    "$TOOL_ERR" "Error: destination already occupied on the remote for orig/a.JPG (2019/a.JPG)"
moveto_lines_g=$(args_lines moveto)
assert_equal "Case G: zero moveto logged" "$moveto_lines_g" "0"
if [[ "$TOOL_EXIT" == "1" ]]; then
    _record 0 "Case G: exits 1"
else
    _record 1 "Case G: exits 1 (got $TOOL_EXIT)"
fi

# ======================================================================
# Case H: per-item rclone failure, warn-and-continue (DD-05)
# ======================================================================

# --- H1: moveto fails for every item; two independent unique matches ---
CASE_H_MANIFEST="$FIXROOT/case_h_manifest.json"
cat > "$CASE_H_MANIFEST" <<'JSON'
[
  {"Path":"orig/h1.JPG","Name":"h1.JPG","Size":31,"IsDir":false},
  {"Path":"orig/h2.JPG","Name":"h2.JPG","Size":32,"IsDir":false}
]
JSON
CASE_H_TARGET="$FIXROOT/case_h/target"
mkfile "$CASE_H_TARGET/new/h1.JPG" 31
mkfile "$CASE_H_TARGET/new/h2.JPG" 32

make_stub_rclone "$CASE_H_MANIFEST"
reset_args_log
set_moveto_exit 1
run_tool --target "$CASE_H_TARGET"
reset_failure_injection

assert_contains "Case H: stderr reports moveto-failed for h1" \
    "$TOOL_ERR" "Error: rclone moveto failed for orig/h1.JPG -> new/h1.JPG"
assert_contains "Case H: stderr reports moveto-failed for h2" \
    "$TOOL_ERR" "Error: rclone moveto failed for orig/h2.JPG -> new/h2.JPG"
totals_h=$(print -r -- "$TOOL_OUT" | grep '^Totals: ')
assert_contains "Case H: Totals reports 2 errors" "$totals_h" "2 errors"
assert_contains "Case H: Totals reports 0 moved" "$totals_h" "0 moved"
if [[ "$TOOL_EXIT" == "1" ]]; then
    _record 0 "Case H: exits 1"
else
    _record 1 "Case H: exits 1 (got $TOOL_EXIT)"
fi

# --- H2: mkdir fails; the move must never be attempted afterward ---
CASE_H2_MANIFEST="$FIXROOT/case_h2_manifest.json"
cat > "$CASE_H2_MANIFEST" <<'JSON'
[
  {"Path":"orig/h3.JPG","Name":"h3.JPG","Size":33,"IsDir":false}
]
JSON
CASE_H2_TARGET="$FIXROOT/case_h2/target"
mkfile "$CASE_H2_TARGET/new/h3.JPG" 33

make_stub_rclone "$CASE_H2_MANIFEST"
reset_args_log
set_mkdir_exit 1
run_tool --target "$CASE_H2_TARGET"
reset_failure_injection

assert_contains "Case H2: stderr reports mkdir-failed" \
    "$TOOL_ERR" "Error: rclone mkdir failed for orig/h3.JPG (destination dir: new)"
moveto_lines_h2=$(args_lines moveto)
assert_equal "Case H2: no moveto logged after a failed mkdir" "$moveto_lines_h2" "0"
if [[ "$TOOL_EXIT" == "1" ]]; then
    _record 0 "Case H2: exits 1"
else
    _record 1 "Case H2: exits 1 (got $TOOL_EXIT)"
fi

# ======================================================================
# Case I: mixed recap -- one clean move, one no-local-match skip, one
# destination-occupied error, all in a single run
# ======================================================================
CASE_I_MANIFEST="$FIXROOT/case_i_manifest.json"
cat > "$CASE_I_MANIFEST" <<'JSON'
[
  {"Path":"orig/i-move.JPG","Name":"i-move.JPG","Size":41,"IsDir":false},
  {"Path":"orig/i-nomatch.JPG","Name":"i-nomatch.JPG","Size":42,"IsDir":false},
  {"Path":"orig/i-occ.JPG","Name":"i-occ.JPG","Size":43,"IsDir":false},
  {"Path":"already/i-occ.JPG","Name":"i-occ.JPG","Size":44,"IsDir":false}
]
JSON
CASE_I_TARGET="$FIXROOT/case_i/target"
mkfile "$CASE_I_TARGET/new/i-move.JPG" 41
mkfile "$CASE_I_TARGET/already/i-occ.JPG" 43

make_stub_rclone "$CASE_I_MANIFEST"
reset_args_log
reset_failure_injection
run_tool --target "$CASE_I_TARGET"

assert_contains "Case I: recap header appears in stdout" \
    "$TOOL_OUT" "Unresolved remote files:"
assert_contains "Case I: recap names the no-match skip with its indented reason" \
    "$TOOL_OUT" "  Skip: orig/i-nomatch.JPG (size 42: no local file of this size)"
assert_contains "Case I: recap names the occupied error with its indented reason" \
    "$TOOL_OUT" "  Error: destination already occupied on the remote for orig/i-occ.JPG (already/i-occ.JPG)"
assert_contains "Case I: stderr still carries the un-indented occupied error inline" \
    "$TOOL_ERR" "Error: destination already occupied on the remote for orig/i-occ.JPG (already/i-occ.JPG)"

nomatch_occurrences_i=$(count_occurrences "$TOOL_OUT" "Skip: orig/i-nomatch.JPG (size 42: no local file of this size)")
assert_equal "Case I: no-match reason appears twice in stdout, byte-identical" \
    "$nomatch_occurrences_i" "2"

recap_section_i=$(print -r -- "$TOOL_OUT" | awk '/^Unresolved remote files:$/{f=1;next} f && /^  /')
if [[ "$recap_section_i" != *"i-move.JPG"* ]]; then
    _record 0 "Case I: recap section does not name the successfully-moved path"
else
    _record 1 "Case I: recap section does not name the successfully-moved path (got: $recap_section_i)"
fi

recap_and_after_i=$(print -r -- "$TOOL_OUT" | awk '/^Unresolved remote files:$/{f=1} f')
if [[ "$recap_and_after_i" != *"Totals: "* ]]; then
    _record 0 "Case I: recap header appears after the Totals line"
else
    _record 1 "Case I: recap header appears after the Totals line (got: $recap_and_after_i)"
fi

if [[ "$TOOL_OUT" != "Error: "* && "$TOOL_OUT" != *$'\n'"Error: "* ]]; then
    _record 0 "Case I: no stdout line starts with un-indented 'Error: '"
else
    _record 1 "Case I: no stdout line starts with un-indented 'Error: '"
fi

if [[ "$TOOL_EXIT" == "1" ]]; then
    _record 0 "Case I: exits 1"
else
    _record 1 "Case I: exits 1 (got $TOOL_EXIT)"
fi

# ======================================================================
# Case J: a run with zero skips and zero errors prints no "Unresolved
# remote files:" header at all -- the recap is silent, not empty.
# ======================================================================
CASE_J_MANIFEST="$FIXROOT/case_j_manifest.json"
cat > "$CASE_J_MANIFEST" <<'JSON'
[
  {"Path":"orig/j.JPG","Name":"j.JPG","Size":51,"IsDir":false}
]
JSON
CASE_J_TARGET="$FIXROOT/case_j/target"
mkfile "$CASE_J_TARGET/new/j.JPG" 51

make_stub_rclone "$CASE_J_MANIFEST"
reset_args_log
run_tool --target "$CASE_J_TARGET"

if [[ "$TOOL_OUT" != *"Unresolved remote files:"* ]]; then
    _record 0 "Case J: zero-unresolved run prints no Unresolved remote files header"
else
    _record 1 "Case J: zero-unresolved run prints no Unresolved remote files header"
fi
if [[ "$TOOL_EXIT" == "0" ]]; then
    _record 0 "Case J: zero-unresolved run exits 0"
else
    _record 1 "Case J: zero-unresolved run exits 0 (got $TOOL_EXIT)"
fi

# ======================================================================
# Case K: a dry run over the Case I mixed fixture reports the same
# dispositions as the real run, the recap is printed, and the argv log
# holds only the lsjson line.
# ======================================================================
make_stub_rclone "$CASE_I_MANIFEST"
reset_args_log
run_tool --dry-run --target "$CASE_I_TARGET"

assert_contains "Case K: dry run recap header appears" "$TOOL_OUT" "Unresolved remote files:"
assert_contains "Case K: dry run skip line matches the real run's" \
    "$TOOL_OUT" "Skip: orig/i-nomatch.JPG (size 42: no local file of this size)"
assert_contains "Case K: dry run error line matches the real run's (reported in both modes)" \
    "$TOOL_OUT" "Error: destination already occupied on the remote for orig/i-occ.JPG (already/i-occ.JPG)"

args_total_lines_k=$(wc -l < "$FIXROOT/rclone.args")
assert_equal "Case K: dry run argv log holds only the lsjson line" "$args_total_lines_k" "1"

# ======================================================================
# Case L: preflight negatives -- each fails fast on stderr before any
# network call, with empty stdout, exit 1, and an empty argv log
# afterward (proving the guard precedes the network call).
# ======================================================================
CASE_L_TARGET="$FIXROOT/case_l/target"
mkdir -p "$CASE_L_TARGET"

EMPTY_BIN="$FIXROOT/empty_bin"
mkdir -p "$EMPTY_BIN"

CASE_L_MANIFEST="$FIXROOT/case_l_manifest.json"
cat > "$CASE_L_MANIFEST" <<'JSON'
[]
JSON
make_stub_rclone "$CASE_L_MANIFEST"
reset_args_log

assert_stderr_and_exit "Case L: missing rclone exits 1, stderr names rclone, stdout empty" 1 "'rclone' is required" -- \
    env PATH="$EMPTY_BIN" REMOTE_NAME="$TEST_REMOTE_NAME" REMOTE_PATH="$TEST_REMOTE_PATH" \
    "$SCRIPT" --target "$CASE_L_TARGET"

assert_stderr_and_exit "Case L: missing jq exits 1, stderr names jq, stdout empty" 1 "'jq' is required" -- \
    env PATH="$STUB_BIN" REMOTE_NAME="$TEST_REMOTE_NAME" REMOTE_PATH="$TEST_REMOTE_PATH" \
    "$SCRIPT" --target "$CASE_L_TARGET"

assert_stderr_and_exit "Case L: unset REMOTE_NAME exits 1, stderr names REMOTE_NAME, stdout empty" 1 "REMOTE_NAME environment variable is required" -- \
    env -u REMOTE_NAME PATH="$STUB_BIN:$PATH" REMOTE_PATH="$TEST_REMOTE_PATH" \
    "$SCRIPT" --target "$CASE_L_TARGET"

assert_stderr_and_exit "Case L: unset REMOTE_PATH exits 1, stderr names REMOTE_PATH, stdout empty" 1 "REMOTE_PATH environment variable is required" -- \
    env -u REMOTE_PATH PATH="$STUB_BIN:$PATH" REMOTE_NAME="$TEST_REMOTE_NAME" \
    "$SCRIPT" --target "$CASE_L_TARGET"

assert_stderr_and_exit "Case L: zero --target flags exits 1 with Usage, stdout empty" 1 "Usage:" -- \
    env PATH="$STUB_BIN:$PATH" REMOTE_NAME="$TEST_REMOTE_NAME" REMOTE_PATH="$TEST_REMOTE_PATH" \
    "$SCRIPT"

assert_stderr_and_exit "Case L: --dry-run alone (no --target) exits 1 with Usage, stdout empty" 1 "Usage:" -- \
    env PATH="$STUB_BIN:$PATH" REMOTE_NAME="$TEST_REMOTE_NAME" REMOTE_PATH="$TEST_REMOTE_PATH" \
    "$SCRIPT" --dry-run

assert_stderr_and_exit "Case L: valid --target plus a trailing bare positional word exits 1 with Usage, stdout empty" 1 "Usage:" -- \
    env PATH="$STUB_BIN:$PATH" REMOTE_NAME="$TEST_REMOTE_NAME" REMOTE_PATH="$TEST_REMOTE_PATH" \
    "$SCRIPT" --target "$CASE_L_TARGET" extra_word

assert_stderr_and_exit "Case L: a --target naming a nonexistent directory exits 1, stdout empty" 1 "Target directory not found:" -- \
    env PATH="$STUB_BIN:$PATH" REMOTE_NAME="$TEST_REMOTE_NAME" REMOTE_PATH="$TEST_REMOTE_PATH" \
    "$SCRIPT" --target "$FIXROOT/case_l/does_not_exist"

args_total_lines_l=$(wc -l < "$FIXROOT/rclone.args")
assert_equal "Case L: argv log is empty after all preflight negatives" "$args_total_lines_l" "0"

# ======================================================================
# Case M: overlapping --target directories -- same dir passed twice, and
# a target nested inside another target. Both exit 1, empty stdout,
# empty argv log.
# ======================================================================
CASE_M_SAME="$FIXROOT/case_m/same"
mkdir -p "$CASE_M_SAME"
reset_args_log

assert_stderr_and_exit "Case M: the same directory passed as --target twice exits 1 with the overlap error" 1 "Error: Overlapping target directories:" -- \
    env PATH="$STUB_BIN:$PATH" REMOTE_NAME="$TEST_REMOTE_NAME" REMOTE_PATH="$TEST_REMOTE_PATH" \
    "$SCRIPT" --target "$CASE_M_SAME" --target "$CASE_M_SAME"

CASE_M_OUTER="$FIXROOT/case_m/outer"
CASE_M_INNER="$FIXROOT/case_m/outer/inner"
mkdir -p "$CASE_M_INNER"

assert_stderr_and_exit "Case M: a --target nested inside another --target exits 1 with the overlap error" 1 "Error: Overlapping target directories:" -- \
    env PATH="$STUB_BIN:$PATH" REMOTE_NAME="$TEST_REMOTE_NAME" REMOTE_PATH="$TEST_REMOTE_PATH" \
    "$SCRIPT" --target "$CASE_M_OUTER" --target "$CASE_M_INNER"

args_total_lines_m=$(wc -l < "$FIXROOT/rclone.args")
assert_equal "Case M: argv log is empty after both overlap rejections" "$args_total_lines_m" "0"

# ======================================================================
# Case N: malformed lsjson output -- a non-JSON blob, and a well-formed
# JSON object instead of an array. Both fail fast rather than silently
# reporting a clean zero-work run.
# ======================================================================
CASE_N_TARGET="$FIXROOT/case_n/target"
mkdir -p "$CASE_N_TARGET"

CASE_N_MANIFEST="$FIXROOT/case_n_manifest.json"
print -r -- 'not json at all {{{' > "$CASE_N_MANIFEST"
make_stub_rclone "$CASE_N_MANIFEST"
reset_args_log
run_tool --target "$CASE_N_TARGET"

assert_contains "Case N: non-JSON manifest exits with the not-a-JSON-array error" \
    "$TOOL_ERR" "Error: rclone lsjson did not return a JSON array for"
if [[ "$TOOL_EXIT" == "1" ]]; then
    _record 0 "Case N: exits 1 (non-JSON blob)"
else
    _record 1 "Case N: exits 1 (non-JSON blob) (got $TOOL_EXIT)"
fi
mkdir_lines_n1=$(args_lines mkdir)
moveto_lines_n1=$(args_lines moveto)
assert_equal "Case N: zero mkdir logged (non-JSON blob)" "$mkdir_lines_n1" "0"
assert_equal "Case N: zero moveto logged (non-JSON blob)" "$moveto_lines_n1" "0"

CASE_N2_MANIFEST="$FIXROOT/case_n2_manifest.json"
cat > "$CASE_N2_MANIFEST" <<'JSON'
{"not":"an array"}
JSON
make_stub_rclone "$CASE_N2_MANIFEST"
reset_args_log
run_tool --target "$CASE_N_TARGET"

assert_contains "Case N: a JSON object (not array) exits with the not-a-JSON-array error" \
    "$TOOL_ERR" "Error: rclone lsjson did not return a JSON array for"
if [[ "$TOOL_EXIT" == "1" ]]; then
    _record 0 "Case N: exits 1 (JSON object)"
else
    _record 1 "Case N: exits 1 (JSON object) (got $TOOL_EXIT)"
fi
mkdir_lines_n2=$(args_lines mkdir)
moveto_lines_n2=$(args_lines moveto)
assert_equal "Case N: zero mkdir logged (JSON object)" "$mkdir_lines_n2" "0"
assert_equal "Case N: zero moveto logged (JSON object)" "$moveto_lines_n2" "0"

# ======================================================================
# Case O: empty manifest ([]) is a valid zero-work run
# ======================================================================
CASE_O_MANIFEST="$FIXROOT/case_o_manifest.json"
cat > "$CASE_O_MANIFEST" <<'JSON'
[]
JSON
CASE_O_TARGET="$FIXROOT/case_o/target"
mkdir -p "$CASE_O_TARGET"

make_stub_rclone "$CASE_O_MANIFEST"
reset_args_log
run_tool --target "$CASE_O_TARGET"

if [[ "$TOOL_EXIT" == "0" ]]; then
    _record 0 "Case O: exits 0"
else
    _record 1 "Case O: exits 0 (got $TOOL_EXIT)"
fi
assert_contains "Case O: Totals line reports an all-zero clean run" \
    "$TOOL_OUT" "Totals: 0 moved, 0 already correct, 0 skipped, 0 errors"
mkdir_lines_o=$(args_lines mkdir)
moveto_lines_o=$(args_lines moveto)
assert_equal "Case O: zero mkdir logged" "$mkdir_lines_o" "0"
assert_equal "Case O: zero moveto logged" "$moveto_lines_o" "0"
if [[ "$TOOL_OUT" != *"Unresolved remote files:"* ]]; then
    _record 0 "Case O: no recap header"
else
    _record 1 "Case O: no recap header"
fi

# ======================================================================
# Case P: rclone lsjson itself exits non-zero
# ======================================================================
CASE_P_TARGET="$FIXROOT/case_p/target"
mkdir -p "$CASE_P_TARGET"
{
    print -r -- '#!/bin/zsh'
    print -r -- "print -r -- \"\$@\" >> \"$FIXROOT/rclone.args\""
    print -r -- 'exit 1'
} > "$STUB_BIN/rclone"
chmod +x "$STUB_BIN/rclone"
reset_args_log
run_tool --target "$CASE_P_TARGET"

assert_contains "Case P: lsjson failure exits with the lsjson-failed error" \
    "$TOOL_ERR" "Error: rclone lsjson failed for ${TEST_REMOTE_NAME}:${TEST_REMOTE_PATH}"
if [[ "$TOOL_EXIT" == "1" ]]; then
    _record 0 "Case P: exits 1"
else
    _record 1 "Case P: exits 1 (got $TOOL_EXIT)"
fi
mkdir_lines_p=$(args_lines mkdir)
moveto_lines_p=$(args_lines moveto)
assert_equal "Case P: zero mkdir logged" "$mkdir_lines_p" "0"
assert_equal "Case P: zero moveto logged" "$moveto_lines_p" "0"

# ======================================================================
# Case Q: an empty --target directory (zero files) with a non-empty
# manifest -- every remote file is reported no-local-file-of-this-size,
# and the run does not crash on the empty local index.
# ======================================================================
CASE_Q_MANIFEST="$FIXROOT/case_q_manifest.json"
cat > "$CASE_Q_MANIFEST" <<'JSON'
[
  {"Path":"orig/q1.JPG","Name":"q1.JPG","Size":61,"IsDir":false},
  {"Path":"orig/q2.JPG","Name":"q2.JPG","Size":62,"IsDir":false}
]
JSON
CASE_Q_TARGET="$FIXROOT/case_q/target"
mkdir -p "$CASE_Q_TARGET"

make_stub_rclone "$CASE_Q_MANIFEST"
reset_args_log
run_tool --target "$CASE_Q_TARGET"

if [[ "$TOOL_EXIT" == "0" ]]; then
    _record 0 "Case Q: exits 0"
else
    _record 1 "Case Q: exits 0 (got $TOOL_EXIT)"
fi
assert_contains "Case Q: q1 reported no-local-file-of-this-size" \
    "$TOOL_OUT" "Skip: orig/q1.JPG (size 61: no local file of this size)"
assert_contains "Case Q: q2 reported no-local-file-of-this-size" \
    "$TOOL_OUT" "Skip: orig/q2.JPG (size 62: no local file of this size)"
mkdir_lines_q=$(args_lines mkdir)
moveto_lines_q=$(args_lines moveto)
assert_equal "Case Q: zero mkdir logged" "$mkdir_lines_q" "0"
assert_equal "Case Q: zero moveto logged" "$moveto_lines_q" "0"

# ======================================================================
# Case R: every local file in the target tree collides on size, and the
# manifest's entries share those same sizes -- every remote file skips
# with a stated ambiguity reason.
# ======================================================================
CASE_R_MANIFEST="$FIXROOT/case_r_manifest.json"
cat > "$CASE_R_MANIFEST" <<'JSON'
[
  {"Path":"orig/r1.JPG","Name":"r1.JPG","Size":71,"IsDir":false},
  {"Path":"orig/r2.JPG","Name":"r2.JPG","Size":71,"IsDir":false}
]
JSON
CASE_R_TARGET="$FIXROOT/case_r/target"
mkfile "$CASE_R_TARGET/x.JPG" 71
mkfile "$CASE_R_TARGET/y.JPG" 71
mkfile "$CASE_R_TARGET/z.JPG" 71

make_stub_rclone "$CASE_R_MANIFEST"
reset_args_log
run_tool --target "$CASE_R_TARGET"

if [[ "$TOOL_EXIT" == "0" ]]; then
    _record 0 "Case R: exits 0"
else
    _record 1 "Case R: exits 0 (got $TOOL_EXIT)"
fi
assert_contains "Case R: r1 skipped with a stated ambiguity reason" \
    "$TOOL_OUT" "Skip: orig/r1.JPG (size 71: 2 remote files share this size)"
assert_contains "Case R: r2 skipped with a stated ambiguity reason" \
    "$TOOL_OUT" "Skip: orig/r2.JPG (size 71: 2 remote files share this size)"
mkdir_lines_r=$(args_lines mkdir)
moveto_lines_r=$(args_lines moveto)
assert_equal "Case R: zero mkdir logged" "$mkdir_lines_r" "0"
assert_equal "Case R: zero moveto logged" "$moveto_lines_r" "0"

# ======================================================================
# Case S: spaces -- a remote path with a space, a --target directory
# whose own name contains a space, holding the matched file inside a
# subdirectory whose name also contains a space. Verified with the
# tabbed stub so the moveto operands' argument COUNT is provable, not
# just substring presence.
# ======================================================================
CASE_S_MANIFEST="$FIXROOT/case_s_manifest.json"
cat > "$CASE_S_MANIFEST" <<'JSON'
[
  {"Path":"orig space/img s.JPG","Name":"img s.JPG","Size":81,"IsDir":false}
]
JSON
CASE_S_TARGET="$FIXROOT/case s/target with space"
mkfile "$CASE_S_TARGET/sub space/img s.JPG" 81

make_stub_rclone_tabbed "$CASE_S_MANIFEST"
reset_args_log
run_tool --target "$CASE_S_TARGET"

assert_contains "Case S: stdout reports the move with spaces intact" \
    "$TOOL_OUT" "Moved: orig space/img s.JPG -> sub space/img s.JPG"

moveto_line_s=$(awk -F'\t' '$2=="moveto"{print; exit}' "$FIXROOT/rclone.args")
argc_s=$(print -r -- "$moveto_line_s" | awk -F'\t' '{print $1}')
assert_equal "Case S: moveto receives exactly 3 argv words (moveto + 2 operands, each unsplit)" \
    "$argc_s" "3"
src_operand_s=$(print -r -- "$moveto_line_s" | awk -F'\t' '{print $3}')
dst_operand_s=$(print -r -- "$moveto_line_s" | awk -F'\t' '{print $4}')
assert_equal "Case S: moveto source operand equals the space-bearing remote spec, unsplit" \
    "$src_operand_s" "${TEST_REMOTE_NAME}:${TEST_REMOTE_PATH}/orig space/img s.JPG"
assert_equal "Case S: moveto destination operand equals the space-bearing remote spec, unsplit" \
    "$dst_operand_s" "${TEST_REMOTE_NAME}:${TEST_REMOTE_PATH}/sub space/img s.JPG"

# ======================================================================
# Case T: three --target roots, one match in each -- each destination
# stripped against its OWN root rather than any other.
# ======================================================================
CASE_T_MANIFEST="$FIXROOT/case_t_manifest.json"
cat > "$CASE_T_MANIFEST" <<'JSON'
[
  {"Path":"orig/t1.JPG","Name":"t1.JPG","Size":91,"IsDir":false},
  {"Path":"orig/t2.JPG","Name":"t2.JPG","Size":92,"IsDir":false},
  {"Path":"orig/t3.JPG","Name":"t3.JPG","Size":93,"IsDir":false}
]
JSON
CASE_T_ROOT1="$FIXROOT/case_t/root1"
CASE_T_ROOT2="$FIXROOT/case_t/root2"
CASE_T_ROOT3="$FIXROOT/case_t/root3"
mkfile "$CASE_T_ROOT1/a/t1.JPG" 91
mkfile "$CASE_T_ROOT2/b/t2.JPG" 92
mkfile "$CASE_T_ROOT3/c/t3.JPG" 93

make_stub_rclone "$CASE_T_MANIFEST"
reset_args_log
run_tool --target "$CASE_T_ROOT1" --target "$CASE_T_ROOT2" --target "$CASE_T_ROOT3"

assert_contains "Case T: t1 stripped against its own root1" "$TOOL_OUT" "Moved: orig/t1.JPG -> a/t1.JPG"
assert_contains "Case T: t2 stripped against its own root2" "$TOOL_OUT" "Moved: orig/t2.JPG -> b/t2.JPG"
assert_contains "Case T: t3 stripped against its own root3" "$TOOL_OUT" "Moved: orig/t3.JPG -> c/t3.JPG"
moveto_lines_t=$(args_lines moveto)
assert_equal "Case T: three moveto lines logged, one per target root" "$moveto_lines_t" "3"

# ======================================================================
# Case U: hash never requested -- across the whole suite's cumulative
# argv log, no invocation ever carried a hash flag (DD-01: --hash is
# empirically known to return nothing useful for the MEGA backend).
# ======================================================================
reset_args_log
cumulative_u=$(<"$FIXROOT/rclone.args.all")
u_hash_lines=$(print -r -- "$cumulative_u" | grep -c -F -- '--hash')
assert_equal "Case U: no invocation across the whole suite ever requested a hash flag" "$u_hash_lines" "0"

# --- Summary ---
print -r -- "----------------------------------------------------"
print -r -- "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

if (( FAIL_COUNT > 0 )); then
    exit 1
fi
exit 0
