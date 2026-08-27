#!/bin/zsh

# retain-dir-struct-4-revert-multi.zsh -- bidirectional shadow/real-file swap.
#
# Resolves each hash-only shadow .txt file found under one or more --shadow
# roots (the format retain-dir-struct-1.zsh produces: sha256sum output
# redirected to a .txt file named "<relpath>.txt") against the real file it
# stands in for, by searching one or more --target roots. The real file's
# name (minus the .txt suffix) locates candidates; the shadow's stored hash
# verifies the match. On a verified match, the shadow and the real file swap
# positions via two `mv` calls -- the shadow is relocated byte-for-byte,
# never deleted and regenerated. See
# .planning/phases/04-local-filesys-revert-tool/04-CONTEXT.md for the full
# design (D-01 through D-09).

zmodload zsh/zutil
zparseopts -D -E -F -- -shadow+:=opt_shadow -target+:=opt_target -dry-run=opt_dryrun || exit 1

DRY_RUN=0
(( ${#opt_dryrun} )) && DRY_RUN=1

# usage() -- printed on stderr, single line, then exits 1. Called by each
# of the three guards below (empty --shadow, empty --target, leftover bare
# positional word).
usage() {
    print -u2 -r -- "Usage: $0 [--dry-run] --shadow <dir> [--shadow <dir>...] --target <dir> [--target <dir>...]"
    exit 1
}

# opt_shadow/opt_target hold ALTERNATING flag/value pairs from zparseopts
# +:= (e.g. --shadow /a --shadow /b => (--shadow /a --shadow /b)), so
# values live at indices 2, 4, 6, ... -- extraction strides by 2 rather
# than copying the array wholesale, which would treat the literal string
# "--shadow" as a tree root.
typeset -a SHADOW_TREES
SHADOW_TREES=()
for (( i = 2; i <= ${#opt_shadow[@]}; i += 2 )); do
    SHADOW_TREES+=("${opt_shadow[$i]%/}")
done

typeset -a TARGET_TREES
TARGET_TREES=()
for (( i = 2; i <= ${#opt_target[@]}; i += 2 )); do
    TARGET_TREES+=("${opt_target[$i]%/}")
done

(( ${#SHADOW_TREES[@]} == 0 )) && usage
(( ${#TARGET_TREES[@]} == 0 )) && usage
# zparseopts leaves unrecognised bare words in $@ without erroring -- a
# leftover here means a caller typed the old positional form and would
# otherwise get a silent partial run over only the flagged roots.
(( $# > 0 )) && usage

# Shadow roots are read-only sources and are never auto-created.
for s in "${SHADOW_TREES[@]}"; do
    [[ ! -d "$s" ]] && { print -u2 -r -- "Error: Shadow tree not found: $s"; exit 1 }
done

# Resolve every root to its canonical absolute path before the overlap
# check -- two different relative spellings of the same directory must not
# slip past this guard. -m tolerates a target root that does not exist yet
# (plain realpath -- would fail and store an empty string, silently
# weakening the overlap comparison below); shadow roots stay strict since
# their existence is already a hard prerequisite, enforced above.
typeset -a SHADOW_TREES_ABS
SHADOW_TREES_ABS=()
for s in "${SHADOW_TREES[@]}"; do
    SHADOW_TREES_ABS+=("$(realpath -- "$s")")
done

typeset -a TARGET_TREES_ABS
TARGET_TREES_ABS=()
for t in "${TARGET_TREES[@]}"; do
    TARGET_TREES_ABS+=("$(realpath -m -- "$t")")
done

# roots_overlap <abs_a> <abs_b> -- true when the two are equal or either
# contains the other.
roots_overlap() {
    local a="$1" b="$2"
    [[ "$a" == "$b" || "$a/" == "$b/"* || "$b/" == "$a/"* ]]
}

# reject_overlap <abs_a> <abs_b> -- prints the shared error and exits 1.
reject_overlap() {
    print -u2 -r -- "Error: Overlapping tree roots: $1 and $2"
    exit 1
}

# Axis 1: shadow vs shadow -- nested or equal shadow roots would enumerate
# the same shadow file twice: the first pass swaps it, the second pass
# reads a now-vacated source (awk noise, empty stored_hash) and finds the
# destination occupied, so a legitimate swap is reported as an error.
for (( i = 1; i <= ${#SHADOW_TREES_ABS[@]}; i++ )); do
    for (( j = i + 1; j <= ${#SHADOW_TREES_ABS[@]}; j++ )); do
        if roots_overlap "${SHADOW_TREES_ABS[$i]}" "${SHADOW_TREES_ABS[$j]}"; then
            reject_overlap "${SHADOW_TREES_ABS[$i]}" "${SHADOW_TREES_ABS[$j]}"
        fi
    done
done

# Axis 2: target vs target -- nested or equal target roots double-count
# every basename in name_count, pushing otherwise-unique matches down the
# collision branch where the same physical file appears twice among the
# candidates and both hash-match, producing a false ambiguous-match error.
for (( i = 1; i <= ${#TARGET_TREES_ABS[@]}; i++ )); do
    for (( j = i + 1; j <= ${#TARGET_TREES_ABS[@]}; j++ )); do
        if roots_overlap "${TARGET_TREES_ABS[$i]}" "${TARGET_TREES_ABS[$j]}"; then
            reject_overlap "${TARGET_TREES_ABS[$i]}" "${TARGET_TREES_ABS[$j]}"
        fi
    done
done

# Axis 3: shadow vs target (full cross-product, shadow first in the
# rejection message, matching today's argument order) -- a shadow root
# inside a target root (or vice versa) makes shadow files themselves swap
# candidates and can relocate a shadow onto its own tree.
for s in "${SHADOW_TREES_ABS[@]}"; do
    for t in "${TARGET_TREES_ABS[@]}"; do
        if roots_overlap "$s" "$t"; then
            reject_overlap "$s" "$t"
        fi
    done
done

# A target tree that does not exist yet is a legitimate swap destination --
# create it for real, or report it under --dry-run, mirroring the
# `mkdir -p "$TGTDIR"` convention in retain-dir-struct-1.zsh. Placed after
# the overlap guard above so a rejected root is never mkdir'd.
for t in "${TARGET_TREES[@]}"; do
    [[ -d "$t" ]] && continue
    if (( DRY_RUN )); then
        print -r -- "Would create target tree: $t"
    else
        if ! mkdir -p -- "$t"; then
            print -u2 -r -- "Error: failed to create target tree: $t"
            exit 1
        fi
        print -r -- "Created target tree: $t"
    fi
done

# Only trees that actually exist on disk (post-create-or-report) may be
# handed to find -- an empty path-argument list makes find silently search
# the invoking shell's cwd instead of nothing.
typeset -a TARGET_TREES_EXISTING
TARGET_TREES_EXISTING=()
for t in "${TARGET_TREES[@]}"; do
    [[ -d "$t" ]] && TARGET_TREES_EXISTING+=("$t")
done

# --- What counts as a shadow: a .txt file whose first field is a 64-char
# lowercase hex hash. Anything else (a real prose .txt data file elsewhere
# in the project) is left strictly untouched. Discovery runs once per
# shadow root; shadow_roots is appended in lockstep with shadow_files so
# the main loop below can strip shadow_rel against the root each shadow
# actually came from (display-only; never used to build a destination
# path). nonshadow_count is declared once before the outer loop, so the
# tally accumulates across every shadow root rather than resetting per
# root. No empty-array guard is needed here: SHADOW_TREES is non-empty by
# the usage guard above and every element exists by the existence check
# above, so find always receives exactly one real path per iteration.
typeset -a shadow_files shadow_roots
shadow_files=()
shadow_roots=()
nonshadow_count=0

for s in "${SHADOW_TREES[@]}"; do
    while IFS= read -r -d '' candidate; do
        first_field=$(awk 'NR==1{print $1; exit}' "$candidate")
        if [[ "$first_field" =~ '^[0-9a-f]{64}$' ]]; then
            shadow_files+=("$candidate")
            shadow_roots+=("$s")
        else
            (( nonshadow_count++ ))
        fi
    done < <(find "$s" -type f -name "*.txt" -print0)
done

# --- Name index over all target trees, built in one pass before the shadow
# loop. Keyed by basename, not relative path: after a swap the shadow and
# the real file no longer share a relative path, so basename is the only
# stable link (D-01 stores no location metadata).
declare -A name_count
declare -A name_first

if (( ${#TARGET_TREES_EXISTING[@]} )); then
    while IFS= read -r -d '' f; do
        base="${f:t}"
        (( name_count[$base]++ ))
        if [[ -z "${name_first[$base]}" ]]; then
            name_first[$base]=$(realpath -- "$f")
        fi
    done < <(find "${TARGET_TREES_EXISTING[@]}" -type f -print0)
fi

print -r -- "Reverting shadows from ${#SHADOW_TREES[@]} shadow tree(s) against ${#TARGET_TREES[@]} target tree(s)..."
print -r -- "----------------------------------------------------"

swap_count=0
skip_count=0
error_count=0

for (( i = 1; i <= ${#shadow_files[@]}; i++ )); do
    shadow="${shadow_files[$i]}"
    shadow_root="${shadow_roots[$i]}"
    shadow_rel="${shadow#$shadow_root/}"
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
        if (( ${#TARGET_TREES_EXISTING[@]} )); then
            while IFS= read -r -d '' f; do
                if [[ "${f:t}" == "$base" ]]; then
                    candidates+=("$(realpath -- "$f")")
                fi
            done < <(find "${TARGET_TREES_EXISTING[@]}" -type f -print0)
        fi

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

    if (( DRY_RUN )); then
        print -r -- "Would swap: $shadow_rel -> $real_src"
        (( swap_count++ ))
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
if (( DRY_RUN )); then
    print -r -- "Dry run complete. No files were moved."
else
    print -r -- "Done! Swap complete."
fi

if (( error_count > 0 )); then
    exit 1
fi
exit 0
