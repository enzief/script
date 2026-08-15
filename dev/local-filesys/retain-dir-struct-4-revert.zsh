#!/bin/zsh

# retain-dir-struct-4-revert.zsh -- bidirectional shadow/real-file swap.
#
# Resolves each hash-only shadow .txt file under <shadow_tree> (the format
# retain-dir-struct-1.zsh produces: sha256sum output redirected to a .txt
# file named "<relpath>.txt") against the real file it stands in for, by
# searching one or more <target_tree> roots. The real file's name (minus the
# .txt suffix) locates candidates; the shadow's stored hash verifies the
# match. On a verified match, the shadow and the real file swap positions
# via two `mv` calls -- the shadow is relocated byte-for-byte, never deleted
# and regenerated. See
# .planning/phases/04-local-filesys-revert-tool/04-CONTEXT.md for the full
# design (D-01 through D-09).

if [[ $# -lt 2 ]]; then
    print -u2 -r -- "Usage: $0 <shadow_tree> <target_tree> [<target_tree>...]"
    exit 1
fi

SHADOW_TREE=${1%/}
shift

typeset -a TARGET_TREES
TARGET_TREES=()
for t in "$@"; do
    TARGET_TREES+=("${t%/}")
done

[[ ! -d "$SHADOW_TREE" ]] && { print -u2 -r -- "Error: Shadow tree not found: $SHADOW_TREE"; exit 1 }
for t in "${TARGET_TREES[@]}"; do
    [[ ! -d "$t" ]] && { print -u2 -r -- "Error: Target tree not found: $t"; exit 1 }
done

# Resolve every root to its canonical absolute path before the overlap
# check -- two different relative spellings of the same directory must not
# slip past this guard.
SHADOW_TREE_ABS=$(realpath -- "$SHADOW_TREE")
typeset -a TARGET_TREES_ABS
TARGET_TREES_ABS=()
for t in "${TARGET_TREES[@]}"; do
    TARGET_TREES_ABS+=("$(realpath -- "$t")")
done

for t in "${TARGET_TREES_ABS[@]}"; do
    if [[ "$t" == "$SHADOW_TREE_ABS" || "$t/" == "$SHADOW_TREE_ABS/"* || "$SHADOW_TREE_ABS/" == "$t/"* ]]; then
        print -u2 -r -- "Error: Overlapping tree roots: $SHADOW_TREE_ABS and $t"
        exit 1
    fi
done

# --- What counts as a shadow: a .txt file whose first field is a 64-char
# lowercase hex hash. Anything else (a real prose .txt data file elsewhere
# in the project) is left strictly untouched.
typeset -a shadow_files
shadow_files=()
nonshadow_count=0

while IFS= read -r -d '' candidate; do
    first_field=$(awk 'NR==1{print $1; exit}' "$candidate")
    if [[ "$first_field" =~ '^[0-9a-f]{64}$' ]]; then
        shadow_files+=("$candidate")
    else
        (( nonshadow_count++ ))
    fi
done < <(find "$SHADOW_TREE" -type f -name "*.txt" -print0)

# --- Name index over all target trees, built in one pass before the shadow
# loop. Keyed by basename, not relative path: after a swap the shadow and
# the real file no longer share a relative path, so basename is the only
# stable link (D-01 stores no location metadata).
declare -A name_count
declare -A name_first

while IFS= read -r -d '' f; do
    base="${f:t}"
    (( name_count[$base]++ ))
    if [[ -z "${name_first[$base]}" ]]; then
        name_first[$base]=$(realpath -- "$f")
    fi
done < <(find "${TARGET_TREES[@]}" -type f -print0)

print -r -- "Reverting shadows from '$SHADOW_TREE' against ${#TARGET_TREES[@]} target tree(s)..."
print -r -- "----------------------------------------------------"

swap_count=0
skip_count=0
error_count=0

for shadow in "${shadow_files[@]}"; do
    shadow_rel="${shadow#$SHADOW_TREE/}"
    stored_hash=$(awk 'NR==1{print $1; exit}' "$shadow")
    dest_real="${shadow%.txt}"
    base="${dest_real:t}"

    candidate_count=${name_count[$base]:-0}

    if (( candidate_count == 0 )); then
        print -r -- "No matching file found for: $shadow_rel"
        (( skip_count++ ))
        continue
    fi

    if (( candidate_count == 1 )); then
        real_src="${name_first[$base]}"
    else
        # Name collision: disambiguate by hash (D-03). Collect the actual
        # candidates with a targeted second pass -- only for basenames that
        # actually collide, so the common case still costs one traversal.
        typeset -a candidates matches
        candidates=()
        matches=()
        while IFS= read -r -d '' f; do
            if [[ "${f:t}" == "$base" ]]; then
                candidates+=("$(realpath -- "$f")")
            fi
        done < <(find "${TARGET_TREES[@]}" -type f -print0)

        for cand in "${candidates[@]}"; do
            cand_hash=$(sha256sum -- "$cand" | awk '{print $1}')
            [[ "$cand_hash" == "$stored_hash" ]] && matches+=("$cand")
        done

        if (( ${#matches[@]} == 0 )); then
            print -u2 -r -- "Error: hash mismatch for $shadow_rel (no candidate among $candidate_count matches the stored hash)"
            (( error_count++ ))
            continue
        elif (( ${#matches[@]} > 1 )); then
            print -u2 -r -- "Error: ambiguous match for $shadow_rel (${#matches[@]} hash-matching candidates)"
            (( error_count++ ))
            continue
        fi
        real_src="${matches[1]}"
    fi

    # Mandatory hash verification (D-04) -- even on a unique name match.
    cand_hash=$(sha256sum -- "$real_src" | awk '{print $1}')
    if [[ "$cand_hash" != "$stored_hash" ]]; then
        print -u2 -r -- "Error: hash mismatch for $shadow_rel (candidate: $real_src)"
        (( error_count++ ))
        continue
    fi

    dest_shadow="${real_src}.txt"

    if [[ -e "$dest_real" || -e "$dest_shadow" ]]; then
        occupied="$dest_real"
        [[ -e "$dest_shadow" ]] && occupied="$dest_shadow"
        print -u2 -r -- "Error: destination already exists for $shadow_rel ($occupied)"
        (( error_count++ ))
        continue
    fi

    if ! mv -- "$real_src" "$dest_real"; then
        print -u2 -r -- "Error: move failed for $shadow_rel ($real_src -> $dest_real)"
        (( error_count++ ))
        continue
    fi

    if ! mv -- "$shadow" "$dest_shadow"; then
        # Restore the pre-swap state (D-02 invariant: never both, never
        # neither). The rollback destination is provably vacant -- it's
        # exactly what the failed move above would have filled.
        if mv -- "$dest_real" "$real_src"; then
            print -u2 -r -- "Error: shadow move failed for $shadow_rel; rolled back"
        else
            print -u2 -r -- "Error: shadow move failed for $shadow_rel; ROLLBACK FAILED -- manually check $dest_real and $real_src"
        fi
        (( error_count++ ))
        continue
    fi

    print -r -- "Swapped: $shadow_rel -> $real_src"
    (( swap_count++ ))
done

print -r -- "----------------------------------------------------"
print -r -- "Totals: $swap_count swapped, $skip_count skipped, $error_count errors"
if (( nonshadow_count > 0 )); then
    print -r -- "Ignored $nonshadow_count non-shadow .txt file(s)"
fi
print -r -- "Done! Swap complete."

if (( error_count > 0 )); then
    exit 1
fi
exit 0
