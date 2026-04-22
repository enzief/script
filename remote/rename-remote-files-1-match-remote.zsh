#!/bin/zsh

# --- Configuration ---
# Hardcoded remote name per your request
REMOTE_NAME="mega"
REMOTE_PATH="devicesync/iphone_F2LN2G1MFF9R/DCIM/100APPLE"
# --- Argument Mapping ---
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <local_src> <shadow_dir> <sync_dir>"
    exit 1
fi

LOCAL_SRC_ABS=$(realpath "$1")
SHADOW_DIR_ABS=$(realpath "$2")
SYNC_DIR_ABS=$(realpath "$3")

mkdir -p "$SHADOW_DIR_ABS"
mkdir -p "$SYNC_DIR_ABS"

# 1. Fetch remote manifest
echo "--- Fetching remote manifest from ${REMOTE_NAME}:${REMOTE_PATH} ---"
REMOTE_JSON=$(rclone lsjson --recursive "${REMOTE_NAME}:${REMOTE_PATH}")

# 2. Build map based on SIZE
# Note: Using size as the primary key. If you have many files with identical
# sizes, this could lead to collisions, but for JPGs it's usually safe.
echo "--- Indexing remote files by size ---"
typeset -A remote_map
while read -r s p; do
    if [[ -n "$s" && "$s" != "null" ]]; then
        remote_map[$s]="$p"
    fi
done < <(echo "$REMOTE_JSON" | jq -r '.[] | select(.IsDir == false) | "\(.Size) \(.Path)"')

# 3. Process local files
echo "--- Processing local files ---"

find "$LOCAL_SRC_ABS" -type f -print0 | while IFS= read -r -d '' local_file; do

    rel_local_path="${local_file#$LOCAL_SRC_ABS/}"

    # Get local file size in bytes
    local_size=$(stat -c %s "$local_file")

    if [[ -n "${remote_map[$local_size]}" ]]; then
        remote_rel_path="${remote_map[$local_size]}"
        remote_filename="${remote_rel_path:t}"

        echo "Match Found (Size: $local_size): $rel_local_path -> $remote_filename"

        # A. Create Shadow: Preserves LOCAL structure
        shadow_file_path="$SHADOW_DIR_ABS/${rel_local_path}.txt"
        mkdir -p "${shadow_file_path:h}"

        {
            echo "ORIGINAL_LOCAL_PATH=\"$local_file\""
            echo "MATCHED_REMOTE_PATH=\"$remote_rel_path\""
            echo "FILE_SIZE_BYTES=\"$local_size\""
            echo "PROCESSED_AT=\"$(date +%s)\""
        } > "$shadow_file_path"

        # B. Move to Sync: Mimics REMOTE structure
        target_sync_path="$SYNC_DIR_ABS/$remote_rel_path"
        mkdir -p "${target_sync_path:h}"

        mv "$local_file" "$target_sync_path"
    else
        echo "No Match: $rel_local_path (Size: $local_size)"
    fi
done

echo "--- Script Complete ---"
