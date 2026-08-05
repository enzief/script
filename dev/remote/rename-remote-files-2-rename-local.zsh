#!/bin/zsh

# --- Argument Mapping ---
if [[ $# -lt 2 ]]; then
    echo "usage: $0 <shadow_dir> <sync_dir>"
    echo "example: $0 ./metadata ./megasync_folder"
    exit 1
fi

SHADOW_DIR_ABS=$(realpath "$1")
SYNC_DIR_ABS=$(realpath "$2")

echo "--- starting reversion process ---"
echo "note: ensure megasync is running and status is green/synced before proceeding."

# Find all shadow .txt files
find "$SHADOW_DIR_ABS" -type f -name "*.txt" -print0 | while IFS= read -r -d '' shadow_file; do

    # Source the machine-readable shadow file to load variables:
    # $ORIGINAL_LOCAL_PATH and $MATCHED_REMOTE_PATH
    source "$shadow_file"

    # Define the current location in the sync folder
    current_sync_loc="$SYNC_DIR_ABS/$MATCHED_REMOTE_PATH"

    if [[ -f "$current_sync_loc" ]]; then
        echo "reverting: $MATCHED_REMOTE_PATH -> ${ORIGINAL_LOCAL_PATH:t}"

        # 1. Recreate the original directory structure
        mkdir -p "${ORIGINAL_LOCAL_PATH:h}"

        # 2. Move the file back to its original home
        # This move triggers the 'Rename' event on the MEGA server
        mv "$current_sync_loc" "$ORIGINAL_LOCAL_PATH"

        # 3. Optional: Small delay to prevent hitting API rate limits
        # if you have thousands of files.
        # sleep 0.05
    else
        echo "warning: file not found in sync dir: $MATCHED_REMOTE_PATH"
    fi
done

echo "--- reversion complete ---"
echo "check the megasync transfer list; it should show 'renaming' metadata updates."
