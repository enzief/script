#!/bin/zsh

# Regression test for number-pages.zsh: dimension-detection failures are
# reported loudly (Error: prefix, counted in the closing summary) without
# changing the script's control flow (no abort, no skip, no exit-code
# change), and valid images still renumber exactly as before.
#
# Manual assert-style test (TESTING.md Option 3) -- no external test framework.
# Run directly: ./dev/manga/tests/test-number-pages.zsh
# Runs correctly from any working directory; resolves the script under test
# relative to this file's own location.
#
# Hermetic: no ImageMagick required. A stub `identify` is placed on PATH for
# the duration of each script invocation, satisfying the script's dependency
# check and letting the test choose per-file whether dimensions are readable.

# Resolve script under test relative to this file, not the caller's cwd
SCRIPT_DIR=${0:A:h}
MANGA_DIR=${SCRIPT_DIR:h}
SCRIPT="$MANGA_DIR/number-pages.zsh"

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

# --- Stub `identify`: makes the test hermetic, no ImageMagick required ---
# Takes its LAST positional argument as the file path and cats "<file>.dims"
# when that sidecar exists, emitting nothing otherwise. Always exits 0.
STUB_BIN="$FIXROOT/bin"
mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/identify" <<'STUB'
#!/bin/zsh
file="${@[-1]}"
if [[ -f "${file}.dims" ]]; then
    cat -- "${file}.dims"
fi
exit 0
STUB
chmod +x "$STUB_BIN/identify"

# --- Fixture helpers ---

mkimg() {
    # mkimg <path> [dims]
    # Writes a one-byte placeholder image file. When <dims> is supplied
    # (e.g. "1600 1200"), also writes a ".dims" sidecar the stub identify
    # reads. Omitting <dims> means the stub emits nothing for that file --
    # exactly the [[ -z "$dims" ]] condition under test.
    local path="$1" dims="$2"
    print -r -- "placeholder" > "$path"
    if [[ -n "$dims" ]]; then
        print -r -- "$dims" > "${path}.dims"
    fi
}

run_np() {
    # run_np <dir> <chapter>
    # Invokes the script under test with STUB_BIN prepended to PATH (never
    # appended -- this makes the stub win even on a machine that does have
    # ImageMagick, keeping the test deterministic everywhere). Captures
    # stdout/stderr/exit code into NP_OUT/NP_ERR/NP_EXIT.
    local d="$1" ch="$2"
    local out_file="$FIXROOT/.np_stdout"
    local err_file="$FIXROOT/.np_stderr"
    PATH="$STUB_BIN:$PATH" "$SCRIPT" "$d" "$ch" > "$out_file" 2> "$err_file"
    NP_EXIT=$?
    NP_OUT=$(<"$out_file")
    NP_ERR=$(<"$err_file")
}

# --- Task 1: one unreadable image among readable ones -- the proven slice ---
T1_DIR="$FIXROOT/t1"
mkdir -p "$T1_DIR"
mkimg "$T1_DIR/01.jpg" "800 1200"
mkimg "$T1_DIR/02.jpg" "1600 1200"
mkimg "$T1_DIR/03.jpg"
run_np "$T1_DIR" 42

assert_contains "Task1: stderr reports Error: for unreadable file 03.jpg" \
    "$NP_ERR" "Error: cannot read dimensions for '03.jpg'"

if [[ "$NP_ERR" != *"Warning:"* ]]; then
    _record 0 "Task1: stderr does not contain the pre-change Warning: prefix"
else
    _record 1 "Task1: stderr does not contain the pre-change Warning: prefix"
fi

assert_contains "Task1: summary reports 3 files, 4 pages, 1 dimension-detection failure" \
    "$NP_OUT" "Renamed 3 files (4 pages, 1 dimension-detection failures)."

if [[ "$NP_EXIT" == "0" ]]; then
    _record 0 "Task1: exit code is 0"
else
    _record 1 "Task1: exit code is 0 (got $NP_EXIT)"
fi

# --- Scenario A: zero-failure boundary (other side of D-02's threshold) ---
A_DIR="$FIXROOT/t2a"
mkdir -p "$A_DIR"
mkimg "$A_DIR/01.jpg" "800 1200"
mkimg "$A_DIR/02.jpg" "800 1200"
run_np "$A_DIR" 7

assert_contains "ScenarioA: summary is the pre-change wording, byte for byte" \
    "$NP_OUT" "Renamed 2 files (2 pages)."

if [[ "$NP_OUT" != *"dimension-detection failures"* ]]; then
    _record 0 "ScenarioA: summary does not carry the failure clause"
else
    _record 1 "ScenarioA: summary does not carry the failure clause"
fi

if [[ "$NP_ERR" != *"Error:"* ]]; then
    _record 0 "ScenarioA: stderr contains no Error: line"
else
    _record 1 "ScenarioA: stderr contains no Error: line"
fi

if [[ "$NP_EXIT" == "0" ]]; then
    _record 0 "ScenarioA: exit code is 0"
else
    _record 1 "ScenarioA: exit code is 0 (got $NP_EXIT)"
fi

# --- Scenario B: count is a real count, not a boolean ---
B_DIR="$FIXROOT/t2b"
mkdir -p "$B_DIR"
mkimg "$B_DIR/01.jpg" "800 1200"
mkimg "$B_DIR/02.jpg"
mkimg "$B_DIR/03.jpg" "800 1200"
mkimg "$B_DIR/04.jpg"
run_np "$B_DIR" 9

assert_contains "ScenarioB: summary reports 2 dimension-detection failures" \
    "$NP_OUT" "2 dimension-detection failures"

assert_contains "ScenarioB: stderr reports Error: for 02.jpg" \
    "$NP_ERR" "Error: cannot read dimensions for '02.jpg'"

assert_contains "ScenarioB: stderr reports Error: for 04.jpg" \
    "$NP_ERR" "Error: cannot read dimensions for '04.jpg'"

if [[ "$NP_EXIT" == "0" ]]; then
    _record 0 "ScenarioB: exit code is 0"
else
    _record 1 "ScenarioB: exit code is 0 (got $NP_EXIT)"
fi

# --- Scenario D: the two safety prohibitions, asserted behaviorally ---
# Reuses Scenario B's directory and its already-captured run (it had
# failures), proving the failure path never became fatal and Stage 1 never
# aborted partway leaving real files stranded as staging files.
if [[ "$NP_EXIT" == "0" ]]; then
    _record 0 "ScenarioD: the failure run still exits 0 (not fatal)"
else
    _record 1 "ScenarioD: the failure run still exits 0 (not fatal) (got $NP_EXIT)"
fi

stray_count=$(find "$B_DIR" -name '.numbering_tmp_*' 2>/dev/null | wc -l)
if [[ "$stray_count" == "0" ]]; then
    _record 0 "ScenarioD: no .numbering_tmp_* staging files remain"
else
    _record 1 "ScenarioD: no .numbering_tmp_* staging files remain (found $stray_count)"
fi

# --- Scenario C: no regression in renumbering (ROADMAP Phase 2 criterion 2) ---
# 01.jpg portrait, 02.jpg landscape (consumes two page numbers), 03.jpg and
# 04.jpg portrait -- all with readable dimensions, chapter 5, default
# start page 1. Expected numbering derived from number-pages.zsh directly:
#   total_pages = 1 + 2 + 1 + 1 = 5 -> page_width = max(2, len("5")) = 2
#   01.jpg -> page 01            -> 005_01.jpg
#   02.jpg -> pages 02-03 (double) -> 005_02-3.jpg (shortest distinguishing suffix)
#   03.jpg -> page 04            -> 005_04.jpg
#   04.jpg -> page 05            -> 005_05.jpg
C_DIR="$FIXROOT/t2c"
mkdir -p "$C_DIR"
mkimg "$C_DIR/01.jpg" "800 1200"
mkimg "$C_DIR/02.jpg" "1600 1200"
mkimg "$C_DIR/03.jpg" "800 1200"
mkimg "$C_DIR/04.jpg" "800 1200"
run_np "$C_DIR" 5

assert_path "ScenarioC: 01.jpg renamed to 005_01.jpg" \
    "$C_DIR/005_01.jpg" "exists"
assert_path "ScenarioC: 02.jpg (landscape) renamed to 005_02-3.jpg" \
    "$C_DIR/005_02-3.jpg" "exists"
assert_path "ScenarioC: 03.jpg renamed to 005_04.jpg" \
    "$C_DIR/005_04.jpg" "exists"
assert_path "ScenarioC: 04.jpg renamed to 005_05.jpg" \
    "$C_DIR/005_05.jpg" "exists"

assert_path "ScenarioC: original 01.jpg no longer exists" \
    "$C_DIR/01.jpg" "absent"
assert_path "ScenarioC: original 02.jpg no longer exists" \
    "$C_DIR/02.jpg" "absent"
assert_path "ScenarioC: original 03.jpg no longer exists" \
    "$C_DIR/03.jpg" "absent"
assert_path "ScenarioC: original 04.jpg no longer exists" \
    "$C_DIR/04.jpg" "absent"

assert_contains "ScenarioC: summary is the zero-failure wording with pages exceeding file count" \
    "$NP_OUT" "Renamed 4 files (5 pages)."

if [[ "$NP_EXIT" == "0" ]]; then
    _record 0 "ScenarioC: exit code is 0"
else
    _record 1 "ScenarioC: exit code is 0 (got $NP_EXIT)"
fi

# --- Summary ---
print -r -- "----------------------------------------------------"
print -r -- "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

if (( FAIL_COUNT > 0 )); then
    exit 1
fi
exit 0
