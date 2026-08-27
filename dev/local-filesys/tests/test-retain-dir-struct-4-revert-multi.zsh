#!/bin/zsh

# Regression test for retain-dir-struct-4-revert-multi.zsh -- the bidirectional
# shadow/real-file swap tool. Covers name-first resolution, mandatory hash
# verification, the two-mv positional exchange, and every failure mode
# (no-match, hash mismatch, ambiguous duplicates, occupied destination,
# partial-swap rollback).
#
# Manual assert-style test (TESTING.md Option 3) -- no external test framework.
# Run directly: ./dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh
# Runs correctly from any working directory; resolves the scripts under test
# relative to this file's own location.

# Resolve scripts under test relative to this file, not the caller's cwd
SCRIPT_DIR=${0:A:h}
LOCALFS_DIR=${SCRIPT_DIR:h}
SCRIPT1="$LOCALFS_DIR/retain-dir-struct-1.zsh"
SCRIPT4="$LOCALFS_DIR/retain-dir-struct-4-revert-multi.zsh"

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

# --- Tree-snapshot helper: sorted "relpath sha256" listing for a whole
# tree. Used to prove filesystem state -- not output text -- is unchanged
# across a dry run, and byte-exact across a there-and-back round trip.
tree_snapshot() {
    # tree_snapshot <dir>
    local dir="$1"
    local rel h
    while IFS= read -r -d '' f; do
        rel="${f#$dir/}"
        h=$(sha256sum -- "$f" | awk '{print $1}')
        print -r -- "$rel $h"
    done < <(find "$dir" -type f -print0) | sort
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

if [[ "$out_a" != *"Ignored "* ]]; then
    _record 0 "Case A: no Ignored line when non-shadow count is zero"
else
    _record 1 "Case A: no Ignored line when non-shadow count is zero"
fi

# ======================================================================
# Case B: non-shadow .txt file is left strictly untouched
# ======================================================================
H_B="$FIXROOT/case_b/home"
T_B="$FIXROOT/case_b/target"
mkdir -p "$H_B" "$T_B"
print -r -- "just some prose, not a shadow" > "$H_B/notes.txt"

out_b=$("$SCRIPT4" "$H_B" "$T_B" 2>&1)

assert_path "Case B: non-shadow .txt file is still present after the run" \
    "$H_B/notes.txt" "exists"

notes_created=$(find "$H_B" "$T_B" -name "notes" 2>/dev/null | wc -l)
if [[ "$notes_created" == "0" ]]; then
    _record 0 "Case B: no file named 'notes' was created anywhere"
else
    _record 1 "Case B: no file named 'notes' was created anywhere (found $notes_created)"
fi

assert_contains "Case B: closing summary reports the Ignored non-shadow count" \
    "$out_b" "Ignored 1 non-shadow .txt file(s)"

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

# ======================================================================
# Case F: one run, five shadows -- hash-disambiguated resolution, ambiguous
# duplicates, hash mismatch, and no-match all in the same batch, proving a
# sibling shadow always continues past an errored or skipped one (D-03,
# D-04, D-05, D-06).
# ======================================================================
H_F="$FIXROOT/case_f/home"
T_F="$FIXROOT/case_f/target"
mkdir -p "$H_F" "$T_F/x" "$T_F/y" "$T_F/p1" "$T_F/p2" "$T_F/q1" "$T_F/q2"

# ok.jpg: clean unique match -- the sibling that must still swap
make_shadow "ok-content" "$H_F/ok.jpg.txt"
print -r -- "ok-content" > "$T_F/x/ok.jpg"

# mismatch.jpg: unique name match, but the candidate's content doesn't
# match the shadow's stored hash
make_shadow "correct-content" "$H_F/mismatch.jpg.txt"
print -r -- "wrong-content" > "$T_F/y/mismatch.jpg"

# nomatch.jpg: no candidate anywhere in the target tree
make_shadow "orphan-content" "$H_F/nomatch.jpg.txt"

# collide-resolve.jpg: two same-named candidates, exactly one matches the
# stored hash -- resolves and swaps against that one
make_shadow "resolve-content-A" "$H_F/collide-resolve.jpg.txt"
print -r -- "resolve-content-A" > "$T_F/p1/collide-resolve.jpg"
print -r -- "resolve-content-B" > "$T_F/p2/collide-resolve.jpg"

# collide-ambig.jpg: two same-named candidates, identical content, both
# match the stored hash -- genuine ambiguity, errors out
make_shadow "ambig-content" "$H_F/collide-ambig.jpg.txt"
print -r -- "ambig-content" > "$T_F/q1/collide-ambig.jpg"
print -r -- "ambig-content" > "$T_F/q2/collide-ambig.jpg"

out_f=$("$SCRIPT4" "$H_F" "$T_F" 2>&1)
exit_f=$?

# ok.jpg swaps successfully
assert_path "Case F: ok.jpg real file lands at home tree" \
    "$H_F/ok.jpg" "exists"
assert_path "Case F: ok.jpg shadow gone from home tree" \
    "$H_F/ok.jpg.txt" "absent"
assert_path "Case F: ok.jpg shadow lands at vacated target-tree path" \
    "$T_F/x/ok.jpg.txt" "exists"

# mismatch.jpg errors, neither file moves
assert_contains "Case F: hash mismatch reports error naming mismatch.jpg.txt" \
    "$out_f" "Error: hash mismatch for mismatch.jpg.txt"
assert_path "Case F: mismatch shadow untouched" \
    "$H_F/mismatch.jpg.txt" "exists"
assert_path "Case F: mismatch candidate untouched" \
    "$T_F/y/mismatch.jpg" "exists"

# nomatch.jpg skips and is reported
assert_contains "Case F: no-match reports skip line naming nomatch.jpg.txt" \
    "$out_f" "No matching file found for: nomatch.jpg.txt"

# collide-resolve.jpg resolves to the one hash-matching candidate
assert_path "Case F: collide-resolve real file lands at home tree" \
    "$H_F/collide-resolve.jpg" "exists"
resolve_content=$(<"$H_F/collide-resolve.jpg")
assert_equal "Case F: collide-resolve real file content is the hash-matching candidate's" \
    "$resolve_content" "resolve-content-A"
assert_path "Case F: collide-resolve matching candidate's slot now holds the shadow" \
    "$T_F/p1/collide-resolve.jpg.txt" "exists"
assert_path "Case F: collide-resolve non-matching candidate is untouched" \
    "$T_F/p2/collide-resolve.jpg" "exists"

# collide-ambig.jpg: two hash-matching duplicates -- ambiguous error, neither moves
assert_contains "Case F: ambiguous duplicates report ambiguous-match error" \
    "$out_f" "Error: ambiguous match for collide-ambig.jpg.txt"
assert_path "Case F: collide-ambig candidate 1 untouched" \
    "$T_F/q1/collide-ambig.jpg" "exists"
assert_path "Case F: collide-ambig candidate 2 untouched" \
    "$T_F/q2/collide-ambig.jpg" "exists"
assert_path "Case F: collide-ambig shadow untouched" \
    "$H_F/collide-ambig.jpg.txt" "exists"

assert_contains "Case F: closing summary reports Totals" \
    "$out_f" "Totals: "

if [[ "$exit_f" == "1" ]]; then
    _record 0 "Case F: run exits 1 when at least one item errored"
else
    _record 1 "Case F: run exits 1 when at least one item errored (got $exit_f)"
fi

# ======================================================================
# Case G: partially-completed swap is rolled back to its pre-swap state
# (D-02 invariant: never both, never neither). A fixture-owned `mv` stub is
# prepended to PATH for this single invocation only -- it delegates to the
# real `mv` on its first call (the real-file move) and fails on its second
# (the shadow move), forcing the exact partial-failure this task must
# recover from.
# ======================================================================
H_G="$FIXROOT/case_g/home"
T_G="$FIXROOT/case_g/target"
mkdir -p "$H_G" "$T_G/z"

make_shadow "content-f" "$H_G/f.jpg.txt"
print -r -- "content-f" > "$T_G/z/f.jpg"

STUB_BIN="$FIXROOT/stubbin"
mkdir -p "$STUB_BIN"
MV_CALL_COUNT_FILE="$FIXROOT/.mv_call_count"
print -r -- "0" > "$MV_CALL_COUNT_FILE"
REAL_MV=$(command -v mv)
{
    print -r -- '#!/bin/zsh'
    print -r -- "count=\$(<\"$MV_CALL_COUNT_FILE\")"
    print -r -- "(( count++ ))"
    print -r -- "print -r -- \"\$count\" > \"$MV_CALL_COUNT_FILE\""
    print -r -- "if (( count == 2 )); then"
    print -r -- "    exit 1"
    print -r -- "else"
    print -r -- "    exec \"$REAL_MV\" \"\$@\""
    print -r -- "fi"
} > "$STUB_BIN/mv"
chmod +x "$STUB_BIN/mv"

err_g=$(env PATH="$STUB_BIN:$PATH" "$SCRIPT4" "$H_G" "$T_G" 2>&1 1>/dev/null)

assert_path "Case G: real file rolled back to its original target-tree path" \
    "$T_G/z/f.jpg" "exists"
assert_path "Case G: real file not left at the shadow's home-tree path after rollback" \
    "$H_G/f.jpg" "absent"
assert_path "Case G: shadow still at its original home-tree path" \
    "$H_G/f.jpg.txt" "exists"
assert_path "Case G: no shadow left behind at the real file's target-tree path" \
    "$T_G/z/f.jpg.txt" "absent"
assert_contains "Case G: stderr carries a shadow-move-failure error" \
    "$err_g" "Error: shadow move failed for "

# ======================================================================
# Case H: a run containing only skips (no matches, no errors) exits 0
# ======================================================================
H_H="$FIXROOT/case_h/home"
T_H="$FIXROOT/case_h/target"
mkdir -p "$H_H" "$T_H"

make_shadow "orphan-only-content" "$H_H/orphan.jpg.txt"

out_h=$("$SCRIPT4" "$H_H" "$T_H" 2>&1)
exit_h=$?

assert_contains "Case H: skip-only run reports the no-match line" \
    "$out_h" "No matching file found for: orphan.jpg.txt"

if [[ "$exit_h" == "0" ]]; then
    _record 0 "Case H: skip-only run exits 0"
else
    _record 1 "Case H: skip-only run exits 0 (got $exit_h)"
fi

# ======================================================================
# Case I: --dry-run previews the exact set of swaps, skips, and errors a
# real run over the same fixture would produce, and leaves both trees
# byte-for-byte unchanged (D-09, T-04-07, T-04-08).
# ======================================================================
H_I="$FIXROOT/case_i/home"
T_I="$FIXROOT/case_i/target"
mkdir -p "$H_I" "$T_I/x" "$T_I/y" "$T_I/q1" "$T_I/q2"

# ok.jpg: clean unique match -- the swap the dry run must preview
make_shadow "ok-i-content" "$H_I/ok.jpg.txt"
print -r -- "ok-i-content" > "$T_I/x/ok.jpg"

# mismatch.jpg: unique name match, wrong content
make_shadow "correct-i-content" "$H_I/mismatch.jpg.txt"
print -r -- "wrong-i-content" > "$T_I/y/mismatch.jpg"

# nomatch.jpg: no candidate anywhere in the target tree
make_shadow "orphan-i-content" "$H_I/nomatch.jpg.txt"

# ambig.jpg: two identical-content candidates, both match the stored hash
make_shadow "ambig-i-content" "$H_I/ambig.jpg.txt"
print -r -- "ambig-i-content" > "$T_I/q1/ambig.jpg"
print -r -- "ambig-i-content" > "$T_I/q2/ambig.jpg"

pre_snapshot_h_i=$(tree_snapshot "$H_I")
pre_snapshot_t_i=$(tree_snapshot "$T_I")

out_dry_i=$("$SCRIPT4" --dry-run "$H_I" "$T_I" 2>&1)
exit_dry_i=$?

post_snapshot_h_i=$(tree_snapshot "$H_I")
post_snapshot_t_i=$(tree_snapshot "$T_I")

assert_equal "Case I: home tree snapshot unchanged across dry run" \
    "$post_snapshot_h_i" "$pre_snapshot_h_i"
assert_equal "Case I: target tree snapshot unchanged across dry run" \
    "$post_snapshot_t_i" "$pre_snapshot_t_i"

assert_contains "Case I: dry run previews the clean match with a Would swap line" \
    "$out_dry_i" "Would swap: ok.jpg.txt"

if [[ "$out_dry_i" != *"Swapped: "* ]]; then
    _record 0 "Case I: dry run prints no Swapped confirmation line"
else
    _record 1 "Case I: dry run prints no Swapped confirmation line"
fi

assert_contains "Case I: dry run reports the same hash-mismatch error the real run would" \
    "$out_dry_i" "Error: hash mismatch for mismatch.jpg.txt"
assert_contains "Case I: dry run reports the same no-match skip the real run would" \
    "$out_dry_i" "No matching file found for: nomatch.jpg.txt"
assert_contains "Case I: dry run reports the same ambiguous-match error the real run would" \
    "$out_dry_i" "Error: ambiguous match for ambig.jpg.txt"

assert_contains "Case I: dry run closing line states no files were moved" \
    "$out_dry_i" "Dry run complete. No files were moved."

if [[ "$exit_dry_i" == "1" ]]; then
    _record 0 "Case I: dry run exits 1 when it reports at least one errored item"
else
    _record 1 "Case I: dry run exits 1 when it reports at least one errored item (got $exit_dry_i)"
fi

# Same fixture, run for real -- since the dry run wrote nothing, the trees
# are still in their pre-run state. The real run's Totals must equal the
# dry run's exactly (preview accuracy, not just preview presence).
dry_totals_i=$(print -r -- "$out_dry_i" | grep '^Totals: ')
out_real_i=$("$SCRIPT4" "$H_I" "$T_I" 2>&1)
real_totals_i=$(print -r -- "$out_real_i" | grep '^Totals: ')
assert_equal "Case I: dry run Totals equal the real run's Totals over the same fixture" \
    "$dry_totals_i" "$real_totals_i"

# ======================================================================
# Case J: --dry-run with no tree arguments -- usage error, stderr-only,
# empty stdout, exit 1.
# ======================================================================
assert_stderr_and_exit "Case J: --dry-run alone with no tree args exits 1, stderr-only usage line naming the flag" \
    1 "--dry-run" -- "$SCRIPT4" "--dry-run"

# ======================================================================
# Case K: true round trip -- SCRIPT4 H T followed by SCRIPT4 T H returns
# both trees to their exact pre-run state, with the shadow carried across
# byte-for-byte rather than regenerated (D-08).
# ======================================================================
H_K="$FIXROOT/case_k/home"
T_K="$FIXROOT/case_k/target"
mkdir -p "$H_K/a" "$T_K/x"

print -r -- "roundtrip-bytes" > "$T_K/x/round.jpg"
make_shadow "roundtrip-bytes" "$H_K/a/round.jpg.txt"

pre_shadow_bytes_k=$(<"$H_K/a/round.jpg.txt")
pre_snapshot_h_k=$(tree_snapshot "$H_K")
pre_snapshot_t_k=$(tree_snapshot "$T_K")

"$SCRIPT4" "$H_K" "$T_K" >/dev/null 2>&1

# Intermediate state: the first hop must put the real file under home and
# the shadow under target -- a failure here tells you which direction of
# the round trip broke.
assert_path "Case K: after first hop, real file is under home tree" \
    "$H_K/a/round.jpg" "exists"
assert_path "Case K: after first hop, shadow is under target tree" \
    "$T_K/x/round.jpg.txt" "exists"
assert_path "Case K: after first hop, home tree no longer holds the shadow" \
    "$H_K/a/round.jpg.txt" "absent"
assert_path "Case K: after first hop, target tree no longer holds the real file" \
    "$T_K/x/round.jpg" "absent"

"$SCRIPT4" "$T_K" "$H_K" >/dev/null 2>&1

post_snapshot_h_k=$(tree_snapshot "$H_K")
post_snapshot_t_k=$(tree_snapshot "$T_K")
post_shadow_bytes_k=$(<"$H_K/a/round.jpg.txt")

assert_equal "Case K: home tree snapshot is identical to its pre-round-trip state" \
    "$post_snapshot_h_k" "$pre_snapshot_h_k"
assert_equal "Case K: target tree snapshot is identical to its pre-round-trip state" \
    "$post_snapshot_t_k" "$pre_snapshot_t_k"
assert_equal "Case K: shadow's bytes are unchanged after both hops" \
    "$post_shadow_bytes_k" "$pre_shadow_bytes_k"

# ======================================================================
# Case L: multiple target trees -- each shadow lands in the specific tree
# its own match came from, not merely "some" tree (D-03).
# ======================================================================
H_L="$FIXROOT/case_l/home"
T1_L="$FIXROOT/case_l/target1"
T2_L="$FIXROOT/case_l/target2"
mkdir -p "$H_L" "$T1_L/one" "$T2_L/two"

make_shadow "content-one" "$H_L/one.jpg.txt"
print -r -- "content-one" > "$T1_L/one/one.jpg"

make_shadow "content-two" "$H_L/two.jpg.txt"
print -r -- "content-two" > "$T2_L/two/two.jpg"

"$SCRIPT4" "$H_L" "$T1_L" "$T2_L" >/dev/null 2>&1

assert_path "Case L: one.jpg real file lands at home tree" \
    "$H_L/one.jpg" "exists"
assert_path "Case L: one.jpg shadow lands in target1, the tree its match came from" \
    "$T1_L/one/one.jpg.txt" "exists"
assert_path "Case L: one.jpg shadow does not land in target2" \
    "$T2_L/one.jpg.txt" "absent"

assert_path "Case L: two.jpg real file lands at home tree" \
    "$H_L/two.jpg" "exists"
assert_path "Case L: two.jpg shadow lands in target2, the tree its match came from" \
    "$T2_L/two/two.jpg.txt" "exists"
assert_path "Case L: two.jpg shadow does not land in target1" \
    "$T1_L/two.jpg.txt" "absent"

# ======================================================================
# Case M: a basename with identical content colliding across two different
# target trees is ambiguous -- errors out, nothing moves (D-05 extended
# across multiple target-tree roots).
# ======================================================================
H_M="$FIXROOT/case_m/home"
T1_M="$FIXROOT/case_m/target1"
T2_M="$FIXROOT/case_m/target2"
mkdir -p "$H_M" "$T1_M/p" "$T2_M/p"

make_shadow "cross-ambig-content" "$H_M/cross.jpg.txt"
print -r -- "cross-ambig-content" > "$T1_M/p/cross.jpg"
print -r -- "cross-ambig-content" > "$T2_M/p/cross.jpg"

err_m=$("$SCRIPT4" "$H_M" "$T1_M" "$T2_M" 2>&1 1>/dev/null)

assert_contains "Case M: cross-tree basename collision reports ambiguous-match error" \
    "$err_m" "Error: ambiguous match for cross.jpg.txt"
assert_path "Case M: shadow untouched after cross-tree ambiguity" \
    "$H_M/cross.jpg.txt" "exists"
assert_path "Case M: target1 candidate untouched" \
    "$T1_M/p/cross.jpg" "exists"
assert_path "Case M: target2 candidate untouched" \
    "$T2_M/p/cross.jpg" "exists"

# ======================================================================
# Case N: directory and file names containing spaces survive a full round
# trip unchanged, mirroring test-retain-dir-struct.zsh's "space dir" /
# "file with space.txt" fixture naming.
# ======================================================================
H_N="$FIXROOT/case_n/home"
T_N="$FIXROOT/case_n/target"
mkdir -p "$H_N/space dir" "$T_N/other space dir"

print -r -- "space content" > "$T_N/other space dir/file with space.jpg"
make_shadow "space content" "$H_N/space dir/file with space.jpg.txt"

pre_snapshot_h_n=$(tree_snapshot "$H_N")
pre_snapshot_t_n=$(tree_snapshot "$T_N")

"$SCRIPT4" "$H_N" "$T_N" >/dev/null 2>&1

assert_path "Case N: spaces -- real file lands at home tree path containing a space" \
    "$H_N/space dir/file with space.jpg" "exists"
assert_path "Case N: spaces -- shadow lands at target tree path containing a space" \
    "$T_N/other space dir/file with space.jpg.txt" "exists"

"$SCRIPT4" "$T_N" "$H_N" >/dev/null 2>&1

post_snapshot_h_n=$(tree_snapshot "$H_N")
post_snapshot_t_n=$(tree_snapshot "$T_N")

assert_equal "Case N: spaces -- home tree snapshot identical to pre-round-trip state" \
    "$post_snapshot_h_n" "$pre_snapshot_h_n"
assert_equal "Case N: spaces -- target tree snapshot identical to pre-round-trip state" \
    "$post_snapshot_t_n" "$pre_snapshot_t_n"

# ======================================================================
# Case O: real run creates a missing target tree (T-dfl-01/03, no weakened
# overlap guard involved -- this target tree does not overlap the shadow
# tree at all, it simply does not exist yet).
# ======================================================================
H_O="$FIXROOT/case_o/home"
T1_O="$FIXROOT/case_o/target1"
T2_O="$FIXROOT/case_o/target2_missing"
mkdir -p "$H_O" "$T1_O/x"

# shadow 1: matches a real file already present in target1 (existing tree)
print -r -- "case-o-content-1" > "$T1_O/x/one.jpg"
make_shadow "case-o-content-1" "$H_O/one.jpg.txt"

# shadow 2: no match anywhere -- just proves the run completes normally
make_shadow "case-o-content-2" "$H_O/two.jpg.txt"

"$SCRIPT4" "$H_O" "$T1_O" "$T2_O" >"$FIXROOT/.case_o_stdout" 2>"$FIXROOT/.case_o_stderr"
exit_o=$?
out_o=$(<"$FIXROOT/.case_o_stdout")
err_o=$(<"$FIXROOT/.case_o_stderr")

assert_path "Case O: missing target tree exists on disk after a real run" \
    "$T2_O" "exists"
assert_contains "Case O: stdout carries a Created target tree line naming the missing tree" \
    "$out_o" "Created target tree: $T2_O"
assert_path "Case O: first shadow's real file landed in the home tree" \
    "$H_O/one.jpg" "exists"
assert_path "Case O: first shadow's shadow landed in target1 (existing tree)" \
    "$T1_O/x/one.jpg.txt" "exists"
assert_contains "Case O: second shadow reports the no-match skip line" \
    "$out_o" "No matching file found for: two.jpg.txt"

if [[ -z "$err_o" ]]; then
    _record 0 "Case O: stderr is empty"
else
    _record 1 "Case O: stderr is empty (got: $err_o)"
fi

if [[ "$exit_o" == "0" ]]; then
    _record 0 "Case O: exit code is 0"
else
    _record 1 "Case O: exit code is 0 (got $exit_o)"
fi

# ======================================================================
# Case P: dry run reports but does not create a missing target tree
# (T-dfl-04). Same fixture shape as Case O.
# ======================================================================
H_P="$FIXROOT/case_p/home"
T1_P="$FIXROOT/case_p/target1"
T2_P="$FIXROOT/case_p/target2_missing"
mkdir -p "$H_P" "$T1_P/x"

print -r -- "case-p-content-1" > "$T1_P/x/one.jpg"
make_shadow "case-p-content-1" "$H_P/one.jpg.txt"

pre_snapshot_h_p=$(tree_snapshot "$H_P")
pre_snapshot_t1_p=$(tree_snapshot "$T1_P")

"$SCRIPT4" --dry-run "$H_P" "$T1_P" "$T2_P" >"$FIXROOT/.case_p_stdout" 2>"$FIXROOT/.case_p_stderr"
out_p=$(<"$FIXROOT/.case_p_stdout")
err_p=$(<"$FIXROOT/.case_p_stderr")

post_snapshot_h_p=$(tree_snapshot "$H_P")
post_snapshot_t1_p=$(tree_snapshot "$T1_P")

assert_contains "Case P: stdout carries a Would create target tree line naming the missing tree" \
    "$out_p" "Would create target tree: $T2_P"
assert_path "Case P: missing target tree is still absent from disk after the dry run" \
    "$T2_P" "absent"

if [[ "$out_p" != *"Created target tree: "* ]]; then
    _record 0 "Case P: stdout carries no Created target tree line"
else
    _record 1 "Case P: stdout carries no Created target tree line"
fi

assert_contains "Case P: stdout carries the Would swap preview for the match in the surviving tree" \
    "$out_p" "Would swap: one.jpg.txt"

if [[ "$err_p" != *"No such file or directory"* ]]; then
    _record 0 "Case P: stderr contains no No such file or directory noise"
else
    _record 1 "Case P: stderr contains no No such file or directory noise (got: $err_p)"
fi

assert_equal "Case P: home tree snapshot unchanged across the dry run" \
    "$post_snapshot_h_p" "$pre_snapshot_h_p"
assert_equal "Case P: existing target tree snapshot unchanged across the dry run" \
    "$post_snapshot_t1_p" "$pre_snapshot_t1_p"

# ======================================================================
# Case Q: dry run where every target tree is missing must not fall back
# to scanning the cwd (T-dfl-02). Bait directory contains a real file with
# the exact same basename and content hash as the shadow; the run's cwd is
# switched to the bait directory in a subshell so the outer harness cwd is
# unaffected.
# ======================================================================
H_Q="$FIXROOT/case_q/home"
T_Q="$FIXROOT/case_q/target_missing"
BAIT_Q="$FIXROOT/case_q/bait"
mkdir -p "$H_Q" "$BAIT_Q"

make_shadow "case-q-content" "$H_Q/bait.jpg.txt"
print -r -- "case-q-content" > "$BAIT_Q/bait.jpg"

(cd "$BAIT_Q" && "$SCRIPT4" --dry-run "$H_Q" "$T_Q" >"$FIXROOT/.case_q_stdout" 2>"$FIXROOT/.case_q_stderr")
out_q=$(<"$FIXROOT/.case_q_stdout")
err_q=$(<"$FIXROOT/.case_q_stderr")

if [[ "$out_q" != *"Would swap: "* ]]; then
    _record 0 "Case Q: stdout carries no Would swap line (cwd bait not matched)"
else
    _record 1 "Case Q: stdout carries no Would swap line (cwd bait not matched)"
fi

assert_contains "Case Q: stdout carries the no-match skip line for the shadow" \
    "$out_q" "No matching file found for: bait.jpg.txt"
assert_contains "Case Q: stdout carries the Would create target tree line" \
    "$out_q" "Would create target tree: $T_Q"
assert_path "Case Q: missing target tree is still absent from disk" \
    "$T_Q" "absent"
assert_path "Case Q: bait file is untouched" \
    "$BAIT_Q/bait.jpg" "exists"

if [[ "$err_q" != *"No such file or directory"* ]]; then
    _record 0 "Case Q: stderr contains no No such file or directory noise"
else
    _record 1 "Case Q: stderr contains no No such file or directory noise (got: $err_q)"
fi

# ======================================================================
# Case R: missing shadow tree still hard-errors, in both modes (unchanged
# behavior -- must survive the target-tree leniency introduced above).
# ======================================================================
T_R="$FIXROOT/case_r/target"
mkdir -p "$T_R"
SHADOW_R_MISSING="$FIXROOT/case_r/shadow_missing"

assert_stderr_and_exit "Case R: missing shadow tree exits 1 with Shadow tree not found" \
    1 "Error: Shadow tree not found: " -- "$SCRIPT4" "$SHADOW_R_MISSING" "$T_R"

assert_stderr_and_exit "Case R: missing shadow tree exits 1 with Shadow tree not found under --dry-run" \
    1 "Error: Shadow tree not found: " -- "$SCRIPT4" --dry-run "$SHADOW_R_MISSING" "$T_R"

# ======================================================================
# Case S: overlap guard survives and rejects before creating, whether or
# not the target tree exists yet (T-dfl-01). Pins the ordering recorded
# in <design_decision>: the create block must run after the overlap guard.
# ======================================================================

# S(a): target tree nested under the shadow tree, and that nested path does
# not itself exist -- must be rejected and never created, in both modes.
H_SA="$FIXROOT/case_sa/home"
mkdir -p "$H_SA"
T_SA_NESTED_MISSING="$H_SA/nested_missing"

assert_stderr_and_exit "Case S(a): target nested under shadow tree, not yet existing, exits 1 with Overlapping tree roots" \
    1 "Error: Overlapping tree roots" -- "$SCRIPT4" "$H_SA" "$T_SA_NESTED_MISSING"

assert_path "Case S(a): rejected nested target tree is still absent from disk" \
    "$T_SA_NESTED_MISSING" "absent"

assert_stderr_and_exit "Case S(a): same rejection holds under --dry-run" \
    1 "Error: Overlapping tree roots" -- "$SCRIPT4" --dry-run "$H_SA" "$T_SA_NESTED_MISSING"

assert_path "Case S(a): rejected nested target tree is still absent from disk after --dry-run" \
    "$T_SA_NESTED_MISSING" "absent"

# S(b): target tree is an existing directory that is a parent of the
# shadow tree.
T_SB_PARENT="$FIXROOT/case_sb"
H_SB="$T_SB_PARENT/home"
mkdir -p "$H_SB"

assert_stderr_and_exit "Case S(b): target tree that is a parent of the shadow tree exits 1 with Overlapping tree roots" \
    1 "Error: Overlapping tree roots" -- "$SCRIPT4" "$H_SB" "$T_SB_PARENT"

# --- Summary ---
print -r -- "----------------------------------------------------"
print -r -- "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

if (( FAIL_COUNT > 0 )); then
    exit 1
fi
exit 0
