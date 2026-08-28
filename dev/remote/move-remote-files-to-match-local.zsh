#!/bin/zsh

# move-remote-files-to-match-local.zsh -- reconciles a MEGA remote
# subtree's directory structure to match one or more local target
# directories, using server-side `rclone moveto` (metadata-only rename
# on the MEGA backend -- no byte transfer, no MegaSync involvement).
#
# Remote files are matched to local candidates by SIZE ONLY: `rclone
# lsjson --hash` was empirically confirmed to return no hash field for
# the MEGA backend, so content hashing would require downloading every
# file first. Size is therefore the only usable match key, and this
# script never calls `rclone lsjson --hash`. Any size that is ambiguous
# on either side -- shared by more than one remote file, by more than
# one local file, or matched by none -- is skipped and reported rather
# than guessed.
#
# See .planning/quick/260828-e42-add-dev-remote-move-remote-files-to-matc/260828-e42-PLAN.md
# for the full design.

zmodload zsh/zutil
zparseopts -D -E -F -- -target+:=opt_target -dry-run=opt_dryrun || exit 1

DRY_RUN=0
(( ${#opt_dryrun} )) && DRY_RUN=1

usage() {
    print -u2 -r -- "Usage: $0 [--dry-run] --target <local_dir> [--target <local_dir>...]"
    exit 1
}

# opt_target holds ALTERNATING flag/value pairs from zparseopts +:=
# (e.g. --target /a --target /b => (--target /a --target /b)), so values
# live at indices 2, 4, 6, ... -- extraction strides by 2 rather than
# copying the array wholesale, which would treat the literal flag word
# as a directory.
typeset -a TARGET_TREES
TARGET_TREES=()
for (( i = 2; i <= ${#opt_target[@]}; i += 2 )); do
    TARGET_TREES+=("${opt_target[$i]%/}")
done

(( ${#TARGET_TREES[@]} == 0 )) && usage
# zparseopts leaves unrecognised bare words in $@ without erroring -- a
# leftover here means the caller typed a positional form and would
# otherwise get a silent partial run.
(( $# > 0 )) && usage

if ! command -v rclone &>/dev/null; then
    echo "Error: 'rclone' is required" >&2
    exit 1
fi
if ! command -v jq &>/dev/null; then
    echo "Error: 'jq' is required" >&2
    exit 1
fi

if [[ -z "$REMOTE_NAME" ]]; then
    echo "Error: REMOTE_NAME environment variable is required" >&2
    exit 1
fi
if [[ -z "$REMOTE_PATH" ]]; then
    echo "Error: REMOTE_PATH environment variable is required" >&2
    exit 1
fi

# --target directories are real local source-data directories, not swap
# destinations -- a missing one is a hard error, never auto-created.
for t in "${TARGET_TREES[@]}"; do
    [[ ! -d "$t" ]] && { echo "Error: Target directory not found: $t" >&2; exit 1 }
done

# Resolve every root to its canonical absolute form up front; only the
# absolute forms are used from here on, which also removes any
# leading-dash concern from later find/stat arguments.
typeset -a TARGET_TREES_ABS
TARGET_TREES_ABS=()
for t in "${TARGET_TREES[@]}"; do
    TARGET_TREES_ABS+=("$(realpath -- "$t")")
done

# 1. Fetch remote manifest
echo "--- Fetching remote manifest from ${REMOTE_NAME}:${REMOTE_PATH} ---"
REMOTE_JSON=$(rclone lsjson --recursive "${REMOTE_NAME}:${REMOTE_PATH}")
if [[ $? -ne 0 ]]; then
    echo "Error: rclone lsjson failed for ${REMOTE_NAME}:${REMOTE_PATH}" >&2
    exit 1
fi

# 2. Index remote files by size. Tab-delimited jq output rather than the
# space-delimited idiom in rename-remote-files-1-match-remote.zsh, because
# a remote path may contain spaces and a space-split read would mangle a
# leading one.
echo "--- Indexing remote files by size ---"
typeset -a remote_paths remote_sizes
remote_paths=()
remote_sizes=()
typeset -A remote_count remote_first occupied
while IFS=$'\t' read -r s p; do
    [[ -z "$s" || "$s" == "null" ]] && continue
    remote_paths+=("$p")
    remote_sizes+=("$s")
    (( remote_count[$s]++ ))
    [[ -z "${remote_first[$s]}" ]] && remote_first[$s]="$p"
    occupied[$p]=1
done < <(echo "$REMOTE_JSON" | jq -r '.[] | select(.IsDir == false) | "\(.Size)\t\(.Path)"')

# 3. Index local files by size, one pass per target root.
echo "--- Indexing local files by size ---"
typeset -A local_count local_first local_first_root
for root_abs in "${TARGET_TREES_ABS[@]}"; do
    while IFS= read -r -d '' f; do
        sz=$(stat -c %s -- "$f")
        (( local_count[$sz]++ ))
        if [[ -z "${local_first[$sz]}" ]]; then
            local_first[$sz]="$f"
            local_first_root[$sz]="$root_abs"
        fi
    done < <(find "$root_abs" -type f -print0)
done

# 4. Main loop.
moved_count=0
already_count=0
skip_count=0
error_count=0
typeset -a unresolved
unresolved=()

for (( i = 1; i <= ${#remote_paths[@]}; i++ )); do
    R="${remote_paths[$i]}"
    s="${remote_sizes[$i]}"

    rc=${remote_count[$s]:-0}
    lc=${local_count[$s]:-0}

    # Non-unique branches are filled in by Task 2; for now fall through.
    (( rc != 1 || lc != 1 )) && continue

    cand="${local_first[$s]}"
    root_abs="${local_first_root[$s]}"
    # zsh does not re-glob the result of a parameter expansion inside a
    # pattern, so this strip is literal and safe.
    desired="${cand#$root_abs/}"

    [[ "$desired" == "$R" ]] && { (( already_count++ )); continue }

    if (( DRY_RUN )); then
        echo "Would move: $R -> $desired"
        (( moved_count++ ))
        continue
    fi

    dest_dir="${desired:h}"
    if [[ "$dest_dir" != "." ]]; then
        if ! rclone mkdir "${REMOTE_NAME}:${REMOTE_PATH}/${dest_dir}"; then
            msg="Error: rclone mkdir failed for $R (destination dir: $dest_dir)"
            echo "$msg" >&2
            (( error_count++ ))
            unresolved+=("$msg")
            continue
        fi
    fi

    if ! rclone moveto "${REMOTE_NAME}:${REMOTE_PATH}/${R}" "${REMOTE_NAME}:${REMOTE_PATH}/${desired}"; then
        msg="Error: rclone moveto failed for $R -> $desired"
        echo "$msg" >&2
        (( error_count++ ))
        unresolved+=("$msg")
        continue
    fi

    echo "Moved: $R -> $desired"
    (( moved_count++ ))
done

echo "----------------------------------------------------"
echo "Totals: $moved_count moved, $already_count already correct, $skip_count skipped, $error_count errors"
if (( ${#unresolved[@]} > 0 )); then
    echo "Unresolved remote files:"
    for entry in "${unresolved[@]}"; do
        echo "  $entry"
    done
fi
if (( DRY_RUN )); then
    echo "Dry run complete. No files were moved."
else
    echo "Done! Remote reconciliation complete."
fi

if (( error_count > 0 )); then
    exit 1
fi
exit 0
