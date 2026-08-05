#!/bin/zsh

# Check for arguments
if [[ $# -ne 2 ]]; then
    print -u2 -r -- "Usage: $0 <shadow_dir> <original_data_dir>"
    exit 1
fi

SHADOWDIR=${1%/}
DATADIR=${2%/}

# Validation
[[ ! -d "$SHADOWDIR" ]] && { print -u2 -r -- "Error: Shadow dir not found."; exit 1 }
[[ ! -d "$DATADIR" ]] && { print -u2 -r -- "Error: Original data dir not found."; exit 1 }

print -r -- "Mapping original files based on Shadow Map hashes..."
print -r -- "----------------------------------------------------"

# 1. First, we build a lookup table of the ACTUAL files to avoid
# re-hashing the whole drive for every single pointer.
# This saves massive amounts of time on exFAT.
declare -A file_map
print -r -- "Building index of $DATADIR (this may take a moment)..."

while IFS= read -r -d '' file; do
    # Get hash of the actual file
    hash=$(sha256sum "$file" | awk '{print $1}')
    # Store in associative array: [hash]=absolute_path
    file_map[$hash]=$(realpath "$file")
done < <(find "$DATADIR" -type f -print0)

print -r -- "Index built. Matching shadow files..."
print -r -- "----------------------------------------------------"

# 2. Iterate through shadow directory to find matches
while IFS= read -r -d '' shadow; do

    # Get the hash stored inside the shadow text file
    stored_hash=$(awk '{print $1}' "$shadow")

    # Check if that hash exists in our map
    if [[ -n "${file_map[$stored_hash]}" ]]; then
        print -r -- "SHADOW: ${shadow#$SHADOWDIR/}"
        print -r -- "REAL  : ${file_map[$stored_hash]}"
        print ""
    else
        print -r -- "SHADOW: ${shadow#$SHADOWDIR/}"
        print -r -- "RESULT: No matching file found in $DATADIR"
        print ""
    fi
done < <(find "$SHADOWDIR" -type f -name "*.txt" -print0)
