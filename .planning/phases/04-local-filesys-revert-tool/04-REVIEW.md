---
phase: 04-local-filesys-revert-tool
reviewed: 2026-08-15T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - dev/local-filesys/retain-dir-struct-4-revert.zsh
  - dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-08-15T00:00:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

`retain-dir-struct-4-revert.zsh` is a careful piece of work: variables are consistently quoted, `-print0`/`read -r -d ''` is used throughout, the mandatory hash-verification and destination-occupied checks are correctly ordered ahead of any `mv`, and the partial-swap rollback (D-02) is sound for the failure mode it targets. The accompanying test file matches the implementation's documented behavior closely and includes a genuinely useful `mv`-stub technique to force the rollback path.

No critical/security-class issues were found (no injection, no eval, no hardcoded secrets, no unsafe deserialization). The issues below are correctness edge cases in the name/hash-matching algorithm that the current design and test suite do not fully cover, plus minor duplication.

## Warnings

### WR-01: Overlapping or duplicate target-tree arguments double-count files, causing false "ambiguous match" errors

**File:** `dev/local-filesys/retain-dir-struct-4-revert.zsh:37-56` (validation), `:81-87` (name index), `:119-128` (collision resolution)

**Issue:** The script validates that the shadow tree does not overlap with any target tree (lines 51-56), but it never checks target trees against *each other*. Since multiple target trees are an advertised, tested feature (see test Case L), a user can pass two target-tree arguments where one is a subdirectory of another, or accidentally pass the same tree twice. In that case `find "${TARGET_TREES[@]}" -type f -print0` (line 87, and again at line 123 for the disambiguation pass) enumerates the same physical file once per root it's reachable from. This inflates `name_count[$base]` past 1 even though only one real file exists, forcing every such shadow into the collision-resolution branch, where the same file (same path, same hash) is collected twice into `candidates`/`matches` — producing `${#matches[@]} > 1` and an incorrect `Error: ambiguous match` for a file that is not actually ambiguous. No file is moved (safe), but a legitimate revert is silently blocked with a misleading message.

**Fix:** Either reject overlapping/duplicate target trees the same way the shadow/target overlap is rejected, or de-duplicate by canonical path before counting/matching, e.g.:
```zsh
# after building TARGET_TREES_ABS
typeset -A seen_target
typeset -a TARGET_TREES_DEDUP
for i in {1..${#TARGET_TREES_ABS[@]}}; do
    t=${TARGET_TREES_ABS[$i]}
    [[ -n "${seen_target[$t]}" ]] && continue
    seen_target[$t]=1
    TARGET_TREES_DEDUP+=("${TARGET_TREES[$i]}")
done
# also reject pairwise nesting the way SHADOW_TREE vs target is rejected
```

### WR-02: Stale/missing candidate produces an unredirected raw error and a misleading "hash mismatch" message

**File:** `dev/local-filesys/retain-dir-struct-4-revert.zsh:78-87, 110-111, 143`

**Issue:** `name_first` (the basename -> real-file-path index) is built once, before the swap loop runs (lines 78-87), and is treated as authoritative for the rest of the run (line 111: `real_src="${name_first[$base]}"`). If two shadows under `SHADOW_TREE` share the same basename and the same stored hash (e.g. two byte-identical filler/cover pages hashed into differently-named shadow subdirectories, but only one physical candidate exists in the target tree so `candidate_count == 1` for both), the first shadow's swap consumes and relocates the real file. The second shadow's cached `real_src` now points at a path that no longer holds the real file (it now holds a shadow). `sha256sum -- "$real_src"` at line 143 is not redirected, so on a vanished file it prints its own raw `sha256sum: <path>: No such file or directory` straight to the script's stderr, bypassing the script's own `Error: ...` formatting, and `cand_hash` becomes empty, which then gets reported as `Error: hash mismatch for ...` — a misleading diagnosis (the file wasn't corrupted/mismatched, it was already claimed by a sibling shadow this run).

**Fix:** Guard the hash step with an explicit existence check and a clearer message, e.g.:
```zsh
if [[ ! -e "$real_src" ]]; then
    print -u2 -r -- "Error: candidate for $shadow_rel already claimed by another shadow this run ($real_src)"
    (( error_count++ ))
    continue
fi
cand_hash=$(sha256sum -- "$real_src" 2>/dev/null | awk '{print $1}')
```

## Info

### IN-01: Repeated hash/field-extraction idioms could be factored into helper functions

**File:** `dev/local-filesys/retain-dir-struct-4-revert.zsh:66, 98, 126, 143`

**Issue:** `awk 'NR==1{print $1; exit}' "$file"` appears twice (lines 66, 98) and `sha256sum -- "$X" | awk '{print $1}'` appears twice more (lines 126, 143). The project convention elsewhere (`get_chap_num` in `list-missing-pages.zsh`) is to name small, single-purpose helper functions for exactly this kind of repeated extraction.

**Fix:**
```zsh
shadow_hash() { awk 'NR==1{print $1; exit}' "$1" }
file_hash()   { sha256sum -- "$1" | awk '{print $1}' }
```

### IN-02: Redundant hash recomputation after collision disambiguation

**File:** `dev/local-filesys/retain-dir-struct-4-revert.zsh:125-139, 142-148`

**Issue:** When `candidate_count > 1`, the collision loop already computes `cand_hash` for every candidate and only keeps the ones matching `stored_hash` in `matches` (lines 125-128). The subsequent "mandatory hash verification" block (lines 142-148) then recomputes the hash for `matches[1]` a second time, even though it is provably already a hash match. Harmless (not a correctness bug — the comment at line 142 flags this as intentional for the *unique-name* path) but it's needless duplicate work specifically for the collision path and slightly obscures that the verification is actually redundant there.

**Fix:** Skip the line-143 recomputation when `real_src` came from the collision branch (it was already verified), or restructure so a single `verify_hash` helper is called exactly once per accepted candidate.

### IN-03: No test covers nested (non-identical) tree-root overlap or duplicate target trees

**File:** `dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh:234-241` (Case D)

**Issue:** Case D only exercises the exact-same-directory overlap (`$SCRIPT4 "$H_D" "$H_D"`). It does not test the case where a target tree is a strict subdirectory of the shadow tree (still an overlap the validation code is supposed to catch per the `"$t/" == "$SHADOW_TREE_ABS/"*` branch), nor does it cover WR-01's scenario (two target-tree arguments that overlap or duplicate each other). Both are reachable through documented multi-target-tree usage and are currently unverified.

**Fix:** Add a case with `mkdir -p "$H/sub"` used as a second target tree nested under the shadow tree, and a case passing the same target tree twice (or two overlapping target trees) over a fixture with exactly one real candidate, asserting the swap still succeeds rather than reporting a spurious ambiguous match.

---

_Reviewed: 2026-08-15T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
