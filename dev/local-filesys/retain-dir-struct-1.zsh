#!/bin/zsh

# Check for arguments
if [[ $# -ne 2 ]]; then
    print -u2 -r -- "Usage: $0 <source_directory> <target_shadow_directory>"
    exit 1
fi

SRCDIR=${1%/}  # Remove trailing slash
TGTDIR=${2%/}

# Create target if it doesn't exist
mkdir -p "$TGTDIR"

print -r -- "Creating Shadow Map in '$TGTDIR'..."

# Find all files in the source
# Using -print0 to handle filenames with spaces safely
find "$SRCDIR" -type f -print0 | while IFS= read -r -d '' srcfile; do

    # Calculate the path relative to the source root
    relpath="${srcfile#$SRCDIR/}"

    # Define the destination "pointer" file path
    shadowfile="$TGTDIR/${relpath}.txt"

    # Recreate the subdirectory structure in the target
    mkdir -p "$(dirname "$shadowfile")"

    # Generate the hash and write it to the pointer file
    # We use sha256sum (standard on Linux)
    print -r -- "Hashing: $relpath"
    sha256sum "$srcfile" > "$shadowfile"

done

print -r -- "---"
print -r -- "Shadow Map Complete!"
