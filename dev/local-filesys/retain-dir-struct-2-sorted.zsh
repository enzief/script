#!/bin/zsh

# Usage: ./sync_shadows.zsh <reorganized_dir> <old_shadow_dir> <new_shadow_dir>

zmodload zsh/zutil
zparseopts -D -E -F -- -dry-run=opt_dryrun || exit 1

DRY_RUN=0
(( ${#opt_dryrun} )) && DRY_RUN=1

if [[ $# -ne 3 ]]; then
    print -u2 -r -- "Usage: $0 [--dry-run] <reorganized_data_dir> <old_shadow_dir> <new_shadow_output_dir>"
    exit 1
fi

REORG_DIR=${1%/}
OLD_SHADOW=${2%/}
NEW_SHADOW=${3%/}

# Create the new shadow root
mkdir -p "$NEW_SHADOW"

# 1. Build a lookup table of existing shadow files
# Map: [Hash] -> [Path to the .txt file]
declare -A shadow_map
print -r -- "Indexing old shadow files..."

while IFS= read -r -d '' shadow_file; do
    # Extract the hash from the first column of the text file
    hash=$(awk '{print $1}' "$shadow_file")
    if [[ -n "$hash" ]]; then
        shadow_map[$hash]="$shadow_file"
    fi
done < <(find "$OLD_SHADOW" -type f -name "*.txt" -print0)

print -r -- "Indexing complete. Syncing to new structure..."
print -r -- "----------------------------------------------------"

# 2. Walk through the reorganized data
while IFS= read -r -d '' real_file; do

    # Calculate the current file's hash
    current_hash=$(sha256sum "$real_file" | awk '{print $1}')

    # Determine the relative path of the real file to mirror it in the new shadow dir
    rel_path="${real_file#$REORG_DIR/}"
    target_shadow_path="$NEW_SHADOW/${rel_path}.txt"

    # Check if we have a shadow file for this hash
    if [[ -n "${shadow_map[$current_hash]}" ]]; then
        if (( DRY_RUN )); then
            print -r -- "Would copy: ${shadow_map[$current_hash]} -> $target_shadow_path"
        else
            # Create the subdirectories in the new shadow location
            mkdir -p "$(dirname "$target_shadow_path")"

            # Copy the original shadow file to the new location
            cp "${shadow_map[$current_hash]}" "$target_shadow_path"
            print -r -- "Matched & Placed: $rel_path"
        fi
    else
        print -r -- "No shadow found for: $rel_path (Hash: $current_hash)"
    fi
done < <(find "$REORG_DIR" -type f -not -path "*/.*" -print0)

print -r -- "----------------------------------------------------"
print -r -- "Done! New shadow structure created at: $NEW_SHADOW"
