# Phase 1: Local Filesystem - Pattern Map

**Mapped:** 2026-08-05
**Files analyzed:** 4 (3 modified scripts + 1 new test file)
**Analogs found:** 4 / 4 (3 are self-referential fixes within the same file; 1 external analog for flag parsing)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `local-filesys/retain-dir-struct-2-sorted.zsh` | utility (file sync) | CRUD / file-I/O | itself, lines 22-28 (working process-substitution loop) | exact (self-analog) |
| `local-filesys/retain-dir-struct-3-find-sorted.zsh` | utility (diagnostic/lookup) | file-I/O | `retain-dir-struct-2-sorted.zsh` lines 22-28 | role-match |
| `local-filesys/retain-dir-struct-1.zsh` | utility (indexing) | file-I/O | `retain-dir-struct-3-find-sorted.zsh` (print-only output style) | role-match |
| `local-filesys/retain-dir-struct-2-sorted.zsh` (`--dry-run` flag addition) | utility (CLI flag parsing) | request-response (CLI args) | `manga/number-pages.zsh` lines 1-4 (`zparseopts`) | role-match |
| `local-filesys/tests/*.zsh` (new) | test | batch (fixture-driven assertions) | none in repo — no existing test framework or file | no analog (greenfield) |

## Pattern Assignments

### `local-filesys/retain-dir-struct-2-sorted.zsh` — fix second loop's subshell bug (D-01)

**Analog:** same file, first loop (lines 22-28) — already works correctly via process substitution.

**Working pattern to replicate** (lines 17-28):
```zsh
# 1. Build a lookup table of existing shadow files
# Map: [Hash] -> [Path to the .txt file]
declare -A shadow_map
echo "Indexing old shadow files..."

while IFS= read -r -d '' shadow_file; do
    # Extract the hash from the first column of the text file
    hash=$(awk '{print $1}' "$shadow_file")
    if [[ -n "$hash" ]]; then
        shadow_map[$hash]="$shadow_file"
    fi
done < <(find "$OLD_SHADOW" -type f -name "*.txt" -print0)
```
Key mechanism: `done < <(find ... -print0)` (process substitution) keeps the `while` loop in the *current* shell, so `shadow_map[$hash]="$shadow_file"` mutations are visible after the loop exits.

**Buggy pattern to fix** (lines 33-54, current — piped into a subshell):
```zsh
# 2. Walk through the reorganized data
find "$REORG_DIR" -type f -not -path "*/.*" -print0 | while IFS= read -r -d '' real_file; do

    # Calculate the current file's hash
    current_hash=$(sha256sum "$real_file" | awk '{print $1}')

    # Determine the relative path of the real file to mirror it in the new shadow dir
    rel_path="${real_file#$REORG_DIR/}"
    target_shadow_path="$NEW_SHADOW/${rel_path}.txt"

    # Check if we have a shadow file for this hash
    if [[ -n "${shadow_map[$current_hash]}" ]]; then
        # Create the subdirectories in the new shadow location
        mkdir -p "$(dirname "$target_shadow_path")"

        # Copy the original shadow file to the new location
        cp "${shadow_map[$current_hash]}" "$target_shadow_path"
        echo "Matched & Placed: $rel_path"
    else
        echo "No shadow found for: $rel_path (Hash: $current_hash)"
    fi
done
```
`find ... | while ...` runs the `while` in a subshell inheriting a *read-only snapshot* of `shadow_map` at fork time — reads of `${shadow_map[$current_hash]}` work fine here (it's only writes that would be lost), so the actual defect is not write-loss in this loop but that this loop is structurally the odd one out; converting it to `done < <(find ...)` keeps both loops consistent and future-proofs against anyone adding writes to `shadow_map`/related state inside it. Apply the same `done < <(find "$REORG_DIR" -type f -not -path "*/.*" -print0)` conversion, changing the `find ... | while` to `while ...; done < <(find ...)`.

**Error handling:** none present beyond `[[ -n ... ]]` guard + else branch printing "No shadow found" — preserve this soft-fail style (no `exit 1` inside the loop; failures are per-file warnings only, consistent with `## Error Handling` conventions for "soft errors").

**Output style (D-03):** convert every `echo` in this file (lines 6, 20, 30-31, 50, 52, 56-57) to `print`, matching `retain-dir-struct-3-find-sorted.zsh`'s all-`print` style below.

---

### `local-filesys/retain-dir-struct-3-find-sorted.zsh` — fix lookup loop's subshell bug (D-02)

**Analog:** `retain-dir-struct-2-sorted.zsh` lines 22-28 (process-substitution pattern, per CONTEXT.md D-Claude's Discretion).

**Buggy pattern to fix** (lines 36-51, current):
```zsh
# 2. Iterate through shadow directory to find matches
find "$SHADOWDIR" -type f -name "*.txt" -print0 | while IFS= read -r -d '' shadow; do

    # Get the hash stored inside the shadow text file
    stored_hash=$(awk '{print $1}' "$shadow")

    # Check if that hash exists in our map
    if [[ -n "${file_map[$stored_hash]}" ]]; then
        print "SHADOW: ${shadow#$SHADOWDIR/}"
        print "REAL  : ${file_map[$stored_hash]}"
        print ""
    else
        print "SHADOW: ${shadow#$SHADOWDIR/}"
        print "RESULT: No matching file found in $DATADIR"
        print ""
    fi
done
```
Apply the same fix shape used for script 2: replace `find "$SHADOWDIR" ... -print0 | while ...; do ... done` with `while ...; do ... done < <(find "$SHADOWDIR" -type f -name "*.txt" -print0)`.

**Note on `file_map` population** (lines 22-30, already correct — uses process substitution):
```zsh
while IFS= read -r -d '' file; do
    # Get hash of the actual file
    hash=$(sha256sum "$file" | awk '{print $1}')
    # Store in associative array: [hash]=absolute_path
    file_map[$hash]=$(realpath "$file")
done < <(find "$DATADIR" -type f -print0)
```
This build loop is already correct; only the second (lookup) loop needs the fix. This file already uses `print` throughout — no D-03 output-style changes needed here.

**Validation pattern already in file** (lines 13-14) — reuse as-is for any new argument checks:
```zsh
[[ ! -d "$SHADOWDIR" ]] && { echo "Error: Shadow dir not found."; exit 1 }
[[ ! -d "$DATADIR" ]] && { echo "Error: Original data dir not found."; exit 1 }
```
Note: these two lines use `echo` for the error message despite the rest of the file using `print` — per D-03 ("standardize all three scripts on `print`"), convert these two `echo` calls to `print` as well, and route to stderr (`print -u2` or `>&2`) per the project's `>&2` error convention (currently missing here — flag as a pre-existing gap, but D-03 only mandates echo→print consistency; adding `>&2` is a reasonable minimal companion fix within the same touched lines).

---

### `local-filesys/retain-dir-struct-1.zsh` — output style only (D-03)

**Analog:** `retain-dir-struct-3-find-sorted.zsh` (fully `print`-based) as the target style.

**Current mixed usage to convert** (lines 5-6, 15, 32, 37-38):
```zsh
echo "Usage: $0 <source_directory> <target_shadow_directory>"
...
echo "Creating Shadow Map in '$TGTDIR'..."
...
print "Hashing: $relpath"
...
echo "---"
echo "Shadow Map Complete!"
```
Convert all `echo` → `print`, keeping line 32's existing `print "Hashing: $relpath"` unchanged. No logic changes to this file (no subshell bug here — its single loop already uses process substitution `find ... -print0 | while ...` — note this file's loop is still `find | while` piped form on line 19, not process-substitution form; it works today because it does not need to preserve variable state (`mkdir`/`sha256sum` calls have no cross-iteration state) so it is out of scope for D-01/D-02, which are specifically about `shadow_map`/`file_map` associative-array lookups).

---

### `local-filesys/retain-dir-struct-2-sorted.zsh` — add `--dry-run` flag (D-04)

**Analog:** `manga/number-pages.zsh` lines 1-4 (only script in repo using `zparseopts` for flags).

**Flag-parsing pattern** (`manga/number-pages.zsh` lines 1-4):
```zsh
#!/bin/zsh

zmodload zsh/zutil
zparseopts -D -E -F -- s:=opt_s n:=opt_n h=opt_h -help=opt_h || exit 1
```
and later extraction (line ~49-50 area):
```zsh
suffix="${opt_s[2]:-}"
start_page="${opt_n[2]:-1}"
```

Recommended shape for `--dry-run` (a boolean/no-arg long flag, closest existing example is `-help=opt_h`):
```zsh
zmodload zsh/zutil
zparseopts -D -E -F -- -dry-run=opt_dryrun || exit 1
(( ${#opt_dryrun} )) && DRY_RUN=1
```
Then guard the `cp` call (line 49) with `if (( DRY_RUN )); then print "Would copy: ..."; else cp ...; fi`, reusing the existing "Matched & Placed" / "No shadow found" print style (D-Specifics: dry-run should list source shadow file to destination path, mirroring current output text).

**Note:** this repo's argument-count validation style (`[[ $# -ne 3 ]]`) will need adjusting since `--dry-run` becomes an optional 4th positional-adjacent flag; `zparseopts -D` strips recognized flags from `$@` before the `[[ $# -ne 3 ]]` check runs, so no other logic needs to change if `zparseopts` runs before the argument-count check (mirror `number-pages.zsh`'s ordering: parse flags first, validate remaining positional args second).

---

### `local-filesys/tests/*.zsh` (new test file) — greenfield, no analog

**No existing test file or framework found in the repository.** Confirmed via `find` (no `*.bats`, `*test*` files besides `.planning/codebase/TESTING.md`, a documentation file, not a test) and `command -v bats` (not installed on this machine).

**TESTING.md recommendation** (`.planning/codebase/TESTING.md`, "Recommended Testing Framework" section) lists three options: BATS, ShUnit2, or manual assert-based zsh script. Given CONTEXT.md D-06 ("no CI service, tests run locally on demand") and the project's "lightweight" constraint, and that `bats` is **not installed** on this machine, **Option 3 (manual assert-based zsh script) is the pragmatic default** unless the user confirms bats is available/installable — a bats-based test would introduce a new external dependency (`bats-core`) that nothing else in this repo requires (see `## Key Dependencies` — no test-runner listed).

**Suggested location/naming** (per TESTING.md's own "If Tests Were to Be Added" guidance, which the planner should follow since it's the only existing convention on this topic):
- Location: `tests/` directory at repo root, OR co-located under `local-filesys/`
- Naming: `test-retain-dir-struct-2-sorted.zsh`, `test-retain-dir-struct-3-find-sorted.zsh` (or one combined `test-local-filesys.zsh`)

**Manual assert pattern to follow** (from TESTING.md's own example patterns, lines ~68-80, already written in this repo's docs as the intended style):
```bash
# Test argument validation
./local-filesys/retain-dir-struct-3-find-sorted.zsh 2>&1 | grep -q "Usage:"
if [[ $? -eq 0 ]]; then
    echo "PASS: Shows usage on missing args"
else
    echo "FAIL: ..."
fi
```
Extend this shape for the phase's actual requirements (D-05): build small scratch fixture dirs with known files, run the fixed scripts against them, and assert that `shadow_map`/`file_map` lookups actually match (grep stdout for "Matched & Placed:" / "SHADOW:"..."REAL:" rather than "No shadow found"/"No matching file found"), plus a `--dry-run` assertion that no files are copied to the target dir (`[[ ! -e "$target_shadow_path" ]]`) while stdout still reports the match.

**Style conventions to carry over from the rest of the codebase** (`## Naming Patterns`, `## Error Handling` in CLAUDE.md project conventions):
- `kebab-case.zsh` filename
- `#!/bin/zsh` shebang
- Exit 0 on all tests passing, exit 1 if any assertion fails (matches project's existing exit-code convention)
- Use `mktemp -d` for scratch fixture directories, clean up with `rm -rf` in a trap or at end of script (no existing repo example of `mktemp`/`trap` — this is genuinely new territory; keep it minimal, no elaborate cleanup framework)

---

## Shared Patterns

### Safe subshell-free iteration (process substitution)
**Source:** `local-filesys/retain-dir-struct-2-sorted.zsh` lines 22-28
**Apply to:** the two buggy loops (script 2's second loop, script 3's lookup loop)
```zsh
while IFS= read -r -d '' var; do
    ...
done < <(find "$DIR" -type f ... -print0)
```

### Print-only output (D-03 standardization)
**Source:** `local-filesys/retain-dir-struct-3-find-sorted.zsh` (already fully `print`-based)
**Apply to:** all `echo` call sites in scripts 1 and 2, and the two `echo` error lines in script 3 (lines 13-14)

### Associative array declaration
**Source:** `local-filesys/retain-dir-struct-2-sorted.zsh` line 19, `retain-dir-struct-3-find-sorted.zsh` line 22
**Apply to:** no new arrays needed this phase — existing `shadow_map`/`file_map` declarations are unchanged, only their consuming loops move.
```zsh
declare -A shadow_map
```

### CLI flag parsing (for `--dry-run`)
**Source:** `manga/number-pages.zsh` lines 1-4, ~49-50
**Apply to:** `local-filesys/retain-dir-struct-2-sorted.zsh` only (the only file in this phase gaining a new flag)

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `local-filesys/tests/*.zsh` (new) | test | batch/fixture-driven | No test framework or test file exists anywhere in the repo; `bats` not installed on this machine. Planner should follow `.planning/codebase/TESTING.md`'s own "Option 3: Manual + assert script" guidance rather than a codebase analog. |

## Metadata

**Analog search scope:** `local-filesys/`, `manga/`, `remote/`, `.planning/codebase/`
**Files scanned:** `retain-dir-struct-1.zsh`, `retain-dir-struct-2-sorted.zsh`, `retain-dir-struct-3-find-sorted.zsh`, `manga/number-pages.zsh`, `.planning/codebase/TESTING.md`, `.planning/codebase/CONVENTIONS.md` (referenced, not re-read — already summarized in CLAUDE.md)
**Pattern extraction date:** 2026-08-05
</content>
