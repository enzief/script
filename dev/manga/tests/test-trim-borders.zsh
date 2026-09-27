#!/bin/zsh

# Regression test for trim-borders.zsh.
#
# Manual assert-style test (TESTING.md Option 3) -- no external test framework.
# Run directly: ./dev/manga/tests/test-trim-borders.zsh
# Runs correctly from any working directory; resolves the script under test
# relative to this file's own location.
#
# NOT hermetic: needs the real ImageMagick 7 `magick` binary, because trim
# behavior against real image bytes is exactly what is under test.

SCRIPT_DIR=${0:A:h}
MANGA_DIR=${SCRIPT_DIR:h}
SCRIPT="$MANGA_DIR/trim-borders.zsh"

if ! command -v magick &>/dev/null; then
    print -u2 -r -- "Error: 'magick' (ImageMagick 7) is required to run this suite"
    exit 1
fi

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

assert_eq() {
    # assert_eq <description> <actual> <expected>
    if [[ "$2" == "$3" ]]; then
        _record 0 "$1"
    else
        _record 1 "$1 (got '$2', expected '$3')"
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

# --- Image read helpers ---

img_dims() {
    # img_dims <path> -> "W H"
    magick identify -format '%w %h' "$1" 2>/dev/null
}

img_fmt() {
    # img_fmt <path> -> e.g. PNG, JPEG
    magick identify -format '%m' "$1" 2>/dev/null
}

img_q() {
    # img_q <path> -> JPEG quality, e.g. 87
    magick identify -format '%Q' "$1" 2>/dev/null
}

file_sha() {
    # file_sha <path>
    sha256sum -- "$1" 2>/dev/null | awk '{print $1}'
}

# --- Fixture builder ---

mkpage() {
    # mkpage <path> <bg-color> <content-geometry> [extra magick write args...]
    # Builds an 800x1200 xc:<bg-color> canvas and composites a centered
    # pattern:checkerboard of <content-geometry> on top, then writes <path>.
    # Extra args (e.g. -quality 87) are inserted before the output path.
    # Checkerboard content is non-uniform, so a second trim never shrinks it.
    local dest="$1" bg="$2" geom="$3"
    shift 3
    mkdir -p -- "${dest:h}"
    magick -size 800x1200 "xc:${bg}" \
        \( -size "$geom" pattern:checkerboard \) \
        -gravity center -composite \
        "$@" "$dest" 2>/dev/null
}

run_tb() {
    # run_tb <args...>
    # Runs the script under test with TMPDIR pointed inside the fixture root
    # (so leftover-temp assertions inspect the script's own mktemp dir).
    # Captures stdout/stderr/exit code into TB_OUT/TB_ERR/TB_EXIT.
    local out_file="$FIXROOT/.tb_stdout"
    local err_file="$FIXROOT/.tb_stderr"
    mkdir -p -- "$FIXROOT/tmp"
    TMPDIR="$FIXROOT/tmp" "$SCRIPT" "$@" > "$out_file" 2> "$err_file"
    TB_EXIT=$?
    TB_OUT=$(<"$out_file")
    TB_ERR=$(<"$err_file")
}

# ======================================================================
# Task 1: tracer -- trim in a subdirectory, plus the minimum-size guard
# ======================================================================

TRACER_DIR="$FIXROOT/t-tracer"
mkpage "$TRACER_DIR/sub dir/page 01.png" white 600x900
run_tb "$TRACER_DIR"

assert_contains "Tracer: stdout reports the trim with before/after dims" \
    "$TB_OUT" "Trimmed: 'sub dir/page 01.png' (800x1200 -> 600x900)"
assert_contains "Tracer: summary line matches the contract" \
    "$TB_OUT" "Done: 1 trimmed, 0 no border, 0 skipped, 0 errors."
assert_eq "Tracer: exit code is 0" "$TB_EXIT" "0"
assert_eq "Tracer: result file is 600x900" \
    "$(img_dims "$TRACER_DIR/sub dir/page 01.png")" "600 900"
assert_eq "Tracer: result file is still PNG" \
    "$(img_fmt "$TRACER_DIR/sub dir/page 01.png")" "PNG"

GUARD_DIR="$FIXROOT/t-guard"
mkdir -p -- "$GUARD_DIR"
magick -size 800x1200 xc:white \
    \( -size 600x900 xc:black \) \
    -gravity center -composite \
    "$GUARD_DIR/flat.png" 2>/dev/null
GUARD_SHA_BEFORE=$(file_sha "$GUARD_DIR/flat.png")
run_tb "$GUARD_DIR"
GUARD_SHA_AFTER=$(file_sha "$GUARD_DIR/flat.png")

assert_eq "Guard: flat-interior page is byte-identical after the run" \
    "$GUARD_SHA_AFTER" "$GUARD_SHA_BEFORE"
assert_contains "Guard: stderr carries the Warning: line" \
    "$TB_ERR" "Warning: trim result 1x1 is under 50% of 800x1200, left untouched: 'flat.png'"
assert_contains "Guard: summary counts the skip" \
    "$TB_OUT" "Done: 0 trimmed, 0 no border, 1 skipped, 0 errors."
assert_eq "Guard: exit code is 0" "$TB_EXIT" "0"

TMP_LEFTOVER_1=$(find "$FIXROOT/tmp" -mindepth 1 2>/dev/null | wc -l)
assert_eq "Task1: script's mktemp area is empty after both runs" "$TMP_LEFTOVER_1" "0"
DOTFILE_LEFTOVER_1=$(find "$FIXROOT" -name '.trim-borders.*' 2>/dev/null | wc -l)
assert_eq "Task1: no .trim-borders.* leftovers anywhere under the fixture root" \
    "$DOTFILE_LEFTOVER_1" "0"

# ======================================================================
# Task 2: -e/--edges all|v|h (D-10)
# ======================================================================

EDGE_ALL_DIR="$FIXROOT/t-edge-all"
mkpage "$EDGE_ALL_DIR/page.png" white 600x900
run_tb -e all "$EDGE_ALL_DIR"
assert_eq "Edges all: trims both axes to 600x900" \
    "$(img_dims "$EDGE_ALL_DIR/page.png")" "600 900"
assert_eq "Edges all: exit code is 0" "$TB_EXIT" "0"

EDGE_V_DIR="$FIXROOT/t-edge-v"
mkpage "$EDGE_V_DIR/page.png" white 600x900
run_tb -e v "$EDGE_V_DIR"
assert_eq "Edges v: width unchanged, height trimmed to 800x900" \
    "$(img_dims "$EDGE_V_DIR/page.png")" "800 900"
assert_eq "Edges v: exit code is 0" "$TB_EXIT" "0"

EDGE_H_DIR="$FIXROOT/t-edge-h"
mkpage "$EDGE_H_DIR/page.png" white 600x900
run_tb --edges h "$EDGE_H_DIR"
assert_eq "Edges h (long form): height unchanged, width trimmed to 600x1200" \
    "$(img_dims "$EDGE_H_DIR/page.png")" "600 1200"
assert_eq "Edges h: exit code is 0" "$TB_EXIT" "0"

EDGE_BAD_DIR="$FIXROOT/t-edge-bad"
mkpage "$EDGE_BAD_DIR/page.png" white 600x900
EDGE_BAD_SHA_BEFORE=$(file_sha "$EDGE_BAD_DIR/page.png")
run_tb -e diag "$EDGE_BAD_DIR"
EDGE_BAD_SHA_AFTER=$(file_sha "$EDGE_BAD_DIR/page.png")
assert_eq "Edges diag: exit code is 1" "$TB_EXIT" "1"
assert_contains "Edges diag: stderr names the bad value" \
    "$TB_ERR" "Error: edges 'diag' must be one of: all, v, h"
assert_eq "Edges diag: fixture untouched" "$EDGE_BAD_SHA_AFTER" "$EDGE_BAD_SHA_BEFORE"

run_tb --help
assert_eq "Help: exit code is 0" "$TB_EXIT" "0"
assert_contains "Help: documents 'all' edge mode" \
    "$TB_OUT" "all  trim all four edges (default)"
assert_contains "Help: documents 'v' edge mode" \
    "$TB_OUT" "v    vertical: trim top and bottom edges only"
assert_contains "Help: documents 'h' edge mode" \
    "$TB_OUT" "h    horizontal: trim left and right edges only"

# ======================================================================
# Task 3: full regression sweep
# ======================================================================

MAIN_DIR="$FIXROOT/t-main"
mkdir -p -- "$MAIN_DIR"

mkpage "$MAIN_DIR/black.png" black 600x900

magick -size 800x1200 xc:white \
    \( -size 700x1100 "xc:#808080" \) -gravity center -composite \
    \( -size 660x1060 xc:white \) -gravity center -composite \
    \( -size 600x900 pattern:checkerboard \) -gravity center -composite \
    "$MAIN_DIR/nested.png" 2>/dev/null

mkpage "$MAIN_DIR/page.jpg" white 600x900 -quality 87
PAGE_JPG_Q_BEFORE=$(img_q "$MAIN_DIR/page.jpg")

mkpage "$MAIN_DIR/UP.PNG" white 600x900

mkpage "$MAIN_DIR/mode.png" white 600x900
chmod 640 -- "$MAIN_DIR/mode.png"

magick -size 600x900 pattern:checkerboard "$MAIN_DIR/borderless.png" 2>/dev/null
BORDERLESS_SHA_BEFORE=$(file_sha "$MAIN_DIR/borderless.png")

magick -size 800x1200 xc:white "$MAIN_DIR/blank.png" 2>/dev/null
BLANK_SHA_BEFORE=$(file_sha "$MAIN_DIR/blank.png")

mkpage "$MAIN_DIR/small.png" white 300x400
SMALL_SHA_BEFORE=$(file_sha "$MAIN_DIR/small.png")

magick -size 800x1200 xc:white \
    \( -size 600x900 xc:black \) -gravity center -composite \
    "$MAIN_DIR/flat.png" 2>/dev/null
FLAT_SHA_BEFORE=$(file_sha "$MAIN_DIR/flat.png")

assert_eq "Main: page.jpg source reads Q87 before the run" "$PAGE_JPG_Q_BEFORE" "87"

run_tb "$MAIN_DIR"

assert_contains "Main: summary matches the exact contract" \
    "$TB_OUT" "Done: 5 trimmed, 1 no border, 3 skipped, 0 errors."
assert_eq "Main: exit code is 0" "$TB_EXIT" "0"

assert_eq "Main: black.png trims to 600x900" "$(img_dims "$MAIN_DIR/black.png")" "600 900"
assert_eq "Main: nested.png peels all layers to 600x900" "$(img_dims "$MAIN_DIR/nested.png")" "600 900"

assert_eq "Main: page.jpg stays JPEG" "$(img_fmt "$MAIN_DIR/page.jpg")" "JPEG"
assert_eq "Main: page.jpg keeps source quality 87" "$(img_q "$MAIN_DIR/page.jpg")" "87"
PAGE_JPG_DIMS=($(img_dims "$MAIN_DIR/page.jpg"))
if (( PAGE_JPG_DIMS[1] < 800 && PAGE_JPG_DIMS[2] < 1200 )); then
    _record 0 "Main: page.jpg was actually trimmed (both dims shrank)"
else
    _record 1 "Main: page.jpg was actually trimmed (both dims shrank) (got ${PAGE_JPG_DIMS[1]}x${PAGE_JPG_DIMS[2]})"
fi

assert_eq "Main: UP.PNG stays PNG" "$(img_fmt "$MAIN_DIR/UP.PNG")" "PNG"
assert_eq "Main: UP.PNG trims to 600x900" "$(img_dims "$MAIN_DIR/UP.PNG")" "600 900"

assert_eq "Main: mode.png keeps mode 640" "$(stat -c %a "$MAIN_DIR/mode.png")" "640"
assert_eq "Main: mode.png trims to 600x900" "$(img_dims "$MAIN_DIR/mode.png")" "600 900"

assert_eq "Main: borderless.png byte-identical" "$(file_sha "$MAIN_DIR/borderless.png")" "$BORDERLESS_SHA_BEFORE"
assert_contains "Main: borderless.png reported as no border" "$TB_OUT" "No border: 'borderless.png'"

assert_eq "Main: blank.png byte-identical" "$(file_sha "$MAIN_DIR/blank.png")" "$BLANK_SHA_BEFORE"
assert_contains "Main: blank.png reported with a Warning:" "$TB_ERR" "left untouched: 'blank.png'"

assert_eq "Main: small.png byte-identical (pins the 50% floor)" "$(file_sha "$MAIN_DIR/small.png")" "$SMALL_SHA_BEFORE"
assert_contains "Main: small.png reported with a Warning:" "$TB_ERR" "left untouched: 'small.png'"

assert_eq "Main: flat.png byte-identical" "$(file_sha "$MAIN_DIR/flat.png")" "$FLAT_SHA_BEFORE"
assert_contains "Main: flat.png reported with a Warning:" "$TB_ERR" "left untouched: 'flat.png'"

# Idempotency: PNGs/uppercase-PNGs must not shift on a second run.
typeset -A png_sha_before
for f in "$MAIN_DIR"/*.png "$MAIN_DIR"/*.PNG; do
    [[ -f "$f" ]] || continue
    png_sha_before[$f]=$(file_sha "$f")
done
run_tb "$MAIN_DIR"
idem_ok=1
for f in "${(k)png_sha_before[@]}"; do
    if [[ "$(file_sha "$f")" != "${png_sha_before[$f]}" ]]; then
        idem_ok=0
        print -r -- "  idempotency mismatch: $f"
    fi
done
if (( idem_ok )); then
    _record 0 "Main: second run leaves every PNG byte-identical (idempotent)"
else
    _record 1 "Main: second run leaves every PNG byte-identical (idempotent)"
fi

ERR_DIR="$FIXROOT/t-err"
mkdir -p -- "$ERR_DIR"
print -r -- "not an image" > "$ERR_DIR/bad.png"
mkpage "$ERR_DIR/good.png" white 600x900
run_tb "$ERR_DIR"

assert_eq "Err: exit code is 1" "$TB_EXIT" "1"
assert_contains "Err: stderr reports Error: for bad.png" \
    "$TB_ERR" "Error: cannot read image: 'bad.png'"
assert_eq "Err: good.png still trims to 600x900" "$(img_dims "$ERR_DIR/good.png")" "600 900"
assert_contains "Err: summary matches the exact contract" \
    "$TB_OUT" "Done: 1 trimmed, 0 no border, 0 skipped, 1 errors."

# Argument validation
FUZZ_BAD_DIR="$FIXROOT/t-fuzz-bad"
mkpage "$FUZZ_BAD_DIR/page.png" white 600x900
FUZZ_BAD_SHA=$(file_sha "$FUZZ_BAD_DIR/page.png")
run_tb -f abc "$FUZZ_BAD_DIR"
assert_eq "Arg: -f abc exits 1" "$TB_EXIT" "1"
assert_contains "Arg: -f abc stderr message" "$TB_ERR" "Error: fuzz 'abc' is not numeric"
assert_eq "Arg: -f abc leaves fixture untouched" "$(file_sha "$FUZZ_BAD_DIR/page.png")" "$FUZZ_BAD_SHA"

run_tb
assert_eq "Arg: no positional exits 1" "$TB_EXIT" "1"
assert_contains "Arg: no positional stderr Usage:" "$TB_ERR" "Usage:"

run_tb "$FUZZ_BAD_DIR" extra
assert_eq "Arg: two positionals exits 1" "$TB_EXIT" "1"

run_tb "$FIXROOT/does-not-exist"
assert_eq "Arg: nonexistent dir exits 1" "$TB_EXIT" "1"
assert_contains "Arg: nonexistent dir stderr message" "$TB_ERR" "Error: directory"

EMPTY_DIR="$FIXROOT/t-empty"
mkdir -p -- "$EMPTY_DIR"
run_tb "$EMPTY_DIR"
assert_eq "Arg: empty dir exits 1" "$TB_EXIT" "1"
assert_contains "Arg: empty dir stderr message" "$TB_ERR" "No image files found"

FUZZ_OK_DIR="$FIXROOT/t-fuzz-ok"
mkpage "$FUZZ_OK_DIR/page.png" white 600x900
run_tb --fuzz 5 "$FUZZ_OK_DIR"
assert_eq "Arg: --fuzz 5 exits 0" "$TB_EXIT" "0"
assert_eq "Arg: --fuzz 5 trims to 600x900" "$(img_dims "$FUZZ_OK_DIR/page.png")" "600 900"

FUZZ_DEC_DIR="$FIXROOT/t-fuzz-dec"
mkpage "$FUZZ_DEC_DIR/page.png" white 600x900
run_tb -f 2.5 "$FUZZ_DEC_DIR"
assert_eq "Arg: -f 2.5 exits 0" "$TB_EXIT" "0"

run_tb -h
assert_eq "Arg: -h exits 0" "$TB_EXIT" "0"
assert_contains "Arg: -h stdout has Usage:" "$TB_OUT" "Usage:"

TMP_LEFTOVER_2=$(find "$FIXROOT/tmp" -mindepth 1 2>/dev/null | wc -l)
assert_eq "Final: script's mktemp area is empty" "$TMP_LEFTOVER_2" "0"
DOTFILE_LEFTOVER_2=$(find "$FIXROOT" -name '.trim-borders.*' 2>/dev/null | wc -l)
assert_eq "Final: no .trim-borders.* leftovers anywhere under the fixture root" \
    "$DOTFILE_LEFTOVER_2" "0"

# --- Summary ---
print -r -- "----------------------------------------------------"
print -r -- "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

if (( FAIL_COUNT > 0 )); then
    exit 1
fi
exit 0
