# Phase 4: local-filesys revert tool - Pattern Map

**Mapped:** 2026-08-13
**Files analyzed:** 2 (script implementation is one-or-two-file architecture choice, deferred to planner per CONTEXT.md Claude's Discretion; test file is separately scoped)
**Analogs found:** 2 / 2

## File Classification

Per CONTEXT.md Claude's Discretion, the planner decides whether this ships as one bidirectional script or two (`revert` + `revert-revert`). Either way, the underlying role/data-flow classification and analog set are identical — a single row covers both cases.

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `dev/local-filesys/retain-dir-struct-4-revert.zsh` (or split into `-revert`/`-revert-revert`) | utility (CLI batch mover) | CRUD (relocate: mv real file + mv shadow, i.e. two-way update) | `dev/remote/rename-remote-files-2-rename-local.zsh` (control flow shape) + `dev/local-filesys/retain-dir-struct-3-find-sorted.zsh` (hash-index/matching mechanics) | role-match (composite of two analogs — no single existing script does both name-driven matching AND `mv`-based relocation) |
| `dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh` (new test file, or added to existing `test-retain-dir-struct.zsh`) | test | batch (fixture-driven assert-style) | `dev/local-filesys/tests/test-retain-dir-struct.zsh` | exact |

## Pattern Assignments

### `dev/local-filesys/retain-dir-struct-4-revert.zsh` (utility, CRUD/relocate)

No single existing script combines "match candidates by name, disambiguate/verify by hash, then `mv` two files in a swap." Compose from three analogs below.

**Analog 1 — control flow shape (shadow-driven mv, warn-and-continue):** `dev/remote/rename-remote-files-2-rename-local.zsh`

Argument handling (lines 1-11):
```zsh
#!/bin/zsh

# --- Argument Mapping ---
if [[ $# -lt 2 ]]; then
    echo "usage: $0 <shadow_dir> <sync_dir>"
    echo "example: $0 ./metadata ./megasync_folder"
    exit 1
fi

SHADOW_DIR_ABS=$(realpath "$1")
SYNC_DIR_ABS=$(realpath "$2")
```
Note: this script uses `echo`/no `-u2` for errors — this phase must instead follow the `dev/local-filesys/*` convention (`print -u2 -r --`, see Shared Patterns below), not this script's own error style.

Core mv-driven relocation loop, safe-iteration and skip-on-no-match convention (lines 16-52):
```zsh
find "$SHADOW_DIR_ABS" -type f -name "*.txt" -print0 | while IFS= read -r -d '' shadow_file; do

    unset ORIGINAL_LOCAL_PATH MATCHED_REMOTE_PATH
    source "$shadow_file"

    if [[ -z "$ORIGINAL_LOCAL_PATH" || -z "$MATCHED_REMOTE_PATH" ]]; then
        echo "Error: shadow file missing required variables, skipping: $shadow_file" >&2
        continue
    fi

    current_sync_loc="$SYNC_DIR_ABS/$MATCHED_REMOTE_PATH"

    if [[ -f "$current_sync_loc" ]]; then
        echo "reverting: $MATCHED_REMOTE_PATH -> ${ORIGINAL_LOCAL_PATH:t}"
        mkdir -p "${ORIGINAL_LOCAL_PATH:h}"
        mv "$current_sync_loc" "$ORIGINAL_LOCAL_PATH"
    else
        echo "warning: file not found in sync dir: $MATCHED_REMOTE_PATH"
    fi
done
```
**Deliberate divergence (per D-01/D-03):** this phase's shadow format is hash-only `.txt` (from `retain-dir-struct-1.zsh`), not sourced shell variables — do NOT `source` the shadow file. Instead read the hash with `awk '{print $1}'` (see Analog 2) and derive the target relative path from the shadow's own filename (strip `.txt` suffix), per D-01/D-03. Use `find ... -print0` piped into `while` via process substitution (`< <(find ...)`), matching the `dev/local-filesys/*` convention — NOT the `find | while` pipe form this remote script uses (that form runs the loop in a subshell, losing variable state; `dev/local-filesys/*` avoids this).

**Analog 2 — hash-index build & matching pattern:** `dev/local-filesys/retain-dir-struct-3-find-sorted.zsh`

Hash-index build (lines 22-30):
```zsh
declare -A file_map
print -r -- "Building index of $DATADIR (this may take a moment)..."

while IFS= read -r -d '' file; do
    hash=$(sha256sum "$file" | awk '{print $1}')
    file_map[$hash]=$(realpath "$file")
done < <(find "$DATADIR" -type f -print0)
```
Reading a shadow's stored hash (line 39):
```zsh
stored_hash=$(awk '{print $1}' "$shadow")
```
Match/no-match reporting convention (lines 42-50) — D-06 explicitly mirrors this "No matching file found" message:
```zsh
if [[ -n "${file_map[$stored_hash]}" ]]; then
    print -r -- "SHADOW: ${shadow#$SHADOWDIR/}"
    print -r -- "REAL  : ${file_map[$stored_hash]}"
    print ""
else
    print -r -- "SHADOW: ${shadow#$SHADOWDIR/}"
    print -r -- "RESULT: No matching file found in $DATADIR"
    print ""
fi
```
**Adaptation needed:** this phase's primary lookup key is NAME, not hash (D-03) — build a name-indexed map (or use `find -name` directly per-shadow, per CONTEXT.md discretion note) first, falling back to hash only to disambiguate collisions or to verify (D-04). Use `declare -A` with an array-of-candidates value (e.g. newline- or NUL-joined) if more than one file can share a name, to support ambiguity detection (D-05).

**Analog 3 — `--dry-run` flag pattern:** `dev/local-filesys/retain-dir-struct-2-sorted.zsh` lines 5-9, 21, 25-27, 57-66, 73-77
```zsh
zmodload zsh/zutil
zparseopts -D -E -F -- -dry-run=opt_dryrun || exit 1

DRY_RUN=0
(( ${#opt_dryrun} )) && DRY_RUN=1
...
if (( ! DRY_RUN )); then
    mkdir -p "$NEW_SHADOW"
fi
...
if (( DRY_RUN )); then
    print -r -- "Would copy: ${shadow_map[$current_hash]} -> $target_shadow_path"
else
    mkdir -p "$(dirname "$target_shadow_path")"
    cp "${shadow_map[$current_hash]}" "$target_shadow_path"
    print -r -- "Matched & Placed: $rel_path"
fi
...
if (( DRY_RUN )); then
    print -r -- "Dry run complete. No files were copied."
else
    print -r -- "Done! New shadow structure created at: $NEW_SHADOW"
fi
```
Apply directly for D-09 — same flag name/parse idiom, adapted to gate `mv` calls instead of `cp`.

**Shadow-file format to replicate exactly (D-01):** `dev/local-filesys/retain-dir-struct-1.zsh` lines 9-10, 25-38
```zsh
SRCDIR=${1%/}  # Remove trailing slash
TGTDIR=${2%/}
...
while IFS= read -r -d '' srcfile; do
    relpath="${srcfile#$SRCDIR/}"
    shadowfile="$TGTDIR/${relpath}.txt"
    mkdir -p "$(dirname "$shadowfile")"
    sha256sum "$srcfile" > "$shadowfile"
done < <(find "$SRCDIR" -type f -print0)
```
This phase's shadows are `.txt` = relative path + `.txt`, containing raw `sha256sum` output — never write a shadow in any other format; the swap moves the existing shadow file byte-for-byte (D-07), it never regenerates one with this pattern. This excerpt is reference-only for understanding the format your matching code must parse.

**Argument validation pattern (apply directly, adjusted for N target trees):** `dev/local-filesys/retain-dir-struct-2-sorted.zsh` lines 11-22
```zsh
if [[ $# -ne 3 ]]; then
    print -u2 -r -- "Usage: $0 [--dry-run] <reorganized_data_dir> <old_shadow_dir> <new_shadow_output_dir>"
    exit 1
fi

REORG_DIR=${1%/}
OLD_SHADOW=${2%/}
NEW_SHADOW=${3%/}

[[ ! -d "$REORG_DIR" ]] && { print -u2 -r -- "Error: Reorganized data dir not found."; exit 1 }
[[ ! -d "$OLD_SHADOW" ]] && { print -u2 -r -- "Error: Old shadow dir not found."; exit 1 }
```

---

### `dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh` (test, batch)

**Analog:** `dev/local-filesys/tests/test-retain-dir-struct.zsh` (exact match — reuse its full harness wholesale, do not reinvent)

Harness setup to copy verbatim (lines 13-99):
```zsh
SCRIPT_DIR=${0:A:h}
LOCALFS_DIR=${SCRIPT_DIR:h}
SCRIPT2="$LOCALFS_DIR/retain-dir-struct-2-sorted.zsh"
...
PASS_COUNT=0
FAIL_COUNT=0

_record() {
    if [[ "$1" == "0" ]]; then
        print -r -- "PASS: $2"
        (( PASS_COUNT++ ))
    else
        print -r -- "FAIL: $2"
        (( FAIL_COUNT++ ))
    fi
}

assert_contains() { ... }
assert_path() { ... }
assert_stderr_and_exit() { ... }

FIXROOT=$(mktemp -d)
[[ -z "$FIXROOT" || ! -d "$FIXROOT" ]] && { print -u2 -r -- "Error: mktemp -d did not produce a usable directory"; exit 1 }

cleanup() { [[ -n "$FIXROOT" && -d "$FIXROOT" ]] && rm -rf -- "$FIXROOT" }
trap cleanup EXIT INT TERM
```
Fixture-building style (lines 101-119) — build home/target trees with real files + shadows the same way this file builds `SRC`/`OLD_SHADOW`/`REORG`, using `mkdir -p`, `print -r --  > file`, and calling `retain-dir-struct-1.zsh` to generate real shadow fixtures rather than hand-writing hash strings (except where you deliberately need a mismatched/injected hash — see `zz-nomatch.txt` injection at line 202-203 for that pattern).

Required test cases per CONTEXT.md Claude's Discretion (minimum): clean unique-name swap round trip, hash-mismatch-on-unique-name error case, ambiguous-multiple-candidates error case. Use `assert_stderr_and_exit` (lines 66-85) for the two error cases — it already validates stdout is empty, stderr contains a needle, and exit code matches, which fits D-05's "error out on that item" requirement.

Summary/exit block to reuse verbatim (lines 333-340):
```zsh
print -r -- "----------------------------------------------------"
print -r -- "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

if (( FAIL_COUNT > 0 )); then
    exit 1
fi
exit 0
```

## Shared Patterns

### Output convention
**Source:** all `dev/local-filesys/*.zsh` scripts (Phase 1 D-03)
**Apply to:** the new revert script(s)
```zsh
print -r -- "message"        # stdout
print -u2 -r -- "Error: ..."  # stderr
```
Do NOT use `echo` (that is `dev/remote/rename-remote-files-2-rename-local.zsh`'s older, inconsistent style — explicitly not to be copied).

### Safe iteration
**Source:** `dev/local-filesys/retain-dir-struct-1.zsh`, `-2-sorted.zsh`, `-3-find-sorted.zsh` (all three)
**Apply to:** any loop over shadow files or target-tree files
```zsh
while IFS= read -r -d '' var; do
    ...
done < <(find "$DIR" -type f -print0)
```
Never use `find | while` (pipe form runs subshell — breaks variable persistence, as seen in the remote analog).

### Error handling
**Source:** `dev/local-filesys/retain-dir-struct-2-sorted.zsh` lines 11-22, `-3-find-sorted.zsh` lines 13-14
**Apply to:** argument/precondition validation at script start
```zsh
if [[ $# -ne N ]]; then
    print -u2 -r -- "Usage: $0 ..."
    exit 1
fi
[[ ! -d "$DIR" ]] && { print -u2 -r -- "Error: ... not found."; exit 1 }
```
**Apply to:** per-item soft failures (no-match) — warn and `continue`, not fatal (D-06). **Apply to:** hash-mismatch / ambiguous-match — error and skip that single item while continuing the batch (D-05), following the same warn-and-continue shape but with an "Error:" prefix per project convention (mismatch is a stronger signal than "no match" but still per-item, not fatal to the whole run, since D-05 says "error out on that item" not "abort the script").

### `--dry-run` flag
**Source:** `dev/local-filesys/retain-dir-struct-2-sorted.zsh` lines 5-9 (see full excerpt above)
**Apply to:** both directions (revert and revert-revert), per D-09

## No Analog Found

None — CONTEXT.md's canonical refs already identify the exact analog set; every required pattern (shadow format, hash-index, dry-run, mv-driven relocation, warn-and-continue, test harness) has a direct precedent in the codebase. The only genuinely new logic is the name-first-then-hash-disambiguation matching algorithm (D-03/D-04/D-05) and the true two-file swap (D-07) — no existing script does either, so the planner should treat that matching/swap core as original logic composed from the hash-index and mv-loop analogs above, not copied from any single file.

## Metadata

**Analog search scope:** `dev/local-filesys/`, `dev/remote/`
**Files scanned:** `retain-dir-struct-1.zsh`, `retain-dir-struct-2-sorted.zsh`, `retain-dir-struct-3-find-sorted.zsh`, `rename-remote-files-1-match-remote.zsh`, `rename-remote-files-2-rename-local.zsh`, `tests/test-retain-dir-struct.zsh`
**Pattern extraction date:** 2026-08-13
</content>
</invoke>
