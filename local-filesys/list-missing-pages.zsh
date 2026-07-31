#!/bin/zsh

# Check for two directory arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <version1_dir> <version2_dir>"
    exit 1
fi

# Enable extended globbing for case-insensitive matching
setopt extended_glob

dir1=$1
dir2=$2

# Associative arrays for storage
typeset -A v1_counts
typeset -A v2_counts

# Helper function for 3-digit extraction
get_chap_num() {
    echo "$1" | grep -oP '(?<![0-9])[0-9]{3}(?![0-9])' | head -1
}

# Scan Version 1
for d in $dir1/*(/); do
    num=$(get_chap_num "${d:t}")
    if [[ -z $num ]]; then continue; fi
    # Count images
    files=($d/*.(#i)(jpg|jpeg|png|webp)(N))
    v1_counts[$num]=${#files}
done

# Scan Version 2
for d in $dir2/*(/); do
    num=$(get_chap_num "${d:t}")
    if [[ -z $num ]]; then continue; fi
    files=($d/*.(#i)(jpg|jpeg|png|webp)(N))
    v2_counts[$num]=${#files}
done

# Collect all unique keys
all_keys=(${(k)v1_counts} ${(k)v2_counts})
# Deduplicate keys
typeset -U all_keys

echo "------------------------------------------------------------"
printf "%-12s | %-12s | %-12s | %-10s\n" "Chapter ID" "Ver 1 (pg)" "Ver 2 (pg)" "Difference"
echo "------------------------------------------------------------"

# Sort keys numerically and iterate
for n in ${(n)all_keys}; do
    c1=${v1_counts[$n]:-0}
    c2=${v2_counts[$n]:-0}

    if [[ $c1 -eq 0 ]]; then
        diff="Missing in V1"
    elif [[ $c2 -eq 0 ]]; then
        diff="Missing in V2"
    elif [[ $c1 -eq $c2 ]]; then
        diff="Match"
    else
        val=$((c1 - c2))
        [[ $c1 -gt $c2 ]] && diff="+$val (V1 > V2)" || diff="$val (V2 > V1)"
    fi

    printf "%-12s | %-12s | %-12s | %-10s\n" "$n" "$c1" "$c2" "$diff"
done
