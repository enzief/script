#!/bin/zsh

zmodload zsh/zutil
zparseopts -D -E -F -- s:=opt_s n:=opt_n h=opt_h -help=opt_h || exit 1

if (( ${#opt_h} )); then
    cat <<'EOF'
Rename image files in a directory to sequential manga page numbers.

Usage: number-pages.zsh [-s suffix] [-n start] [dir] [chapter]

Options:
  -s suffix  Appended to filename with '-' separator (default: none)
  -n start   Starting page number (default: 1)

Arguments:
  dir        Directory containing image files (default: .)
  chapter    Chapter number, must be numeric (default: dir basename)

Output format:
  <chapter>_<page>.<ext>              single page
  <chapter>_<page>-<suffix>.<ext>     single page with suffix
  <chapter>_<page1-x>.<ext>           double page
  <chapter>_<page1-x>-<suffix>.<ext>  double page with suffix

  Chapter is zero-padded to 3 digits. Page numbers are zero-padded to
  the width needed for the total page count (minimum 2 digits).

  Double pages (width > height) consume two page numbers. The second
  number is abbreviated to its shortest distinguishing suffix:
    pages 04,05  -> 04-5
    pages 09,10  -> 09-10
    pages 99,100 -> 099-100

Examples:
  number-pages.zsh                     # dir=., chapter from dir name
  number-pages.zsh -s web              # suffix only, rest defaulted
  number-pages.zsh -n 5                # start numbering from page 5
  number-pages.zsh ch42/ 42            # explicit chapter
  number-pages.zsh -s web -n 3 ch42/   # combine flags

Requires: ImageMagick (identify)
Supports: jpg, jpeg, png, webp, gif, bmp, tiff, tif, avif
EOF
    exit 0
fi

suffix="${opt_s[2]:-}"
start_page="${opt_n[2]:-1}"

if ! [[ "$start_page" =~ '^[0-9]+$' ]]; then
    echo "Error: start page '$start_page' is not numeric" >&2
    exit 1
fi

dir="${1:-.}"
dir="${dir%/}"
chapter="${2:-${dir:t}}"

if ! [[ "$chapter" =~ '^[0-9]+$' ]]; then
    echo "Error: chapter '$chapter' is not numeric" >&2
    exit 1
fi

chapter_padded=$(printf '%03d' "$chapter")

if ! command -v identify &>/dev/null; then
    echo "Error: 'identify' (ImageMagick) is required" >&2
    exit 1
fi

image_files=("$dir"/*.(jpg|jpeg|png|webp|gif|bmp|tiff|tif|avif)(Nn))

if (( ${#image_files} == 0 )); then
    echo "No image files found in '$dir'" >&2
    exit 1
fi

# First pass: detect double pages (width > height), calculate total page count
typeset -A is_double
total_pages=0
dim_failures=0

for f in "${image_files[@]}"; do
    dims=$(identify -format '%w %h\n' "$f" 2>/dev/null | head -1)
    if [[ -z "$dims" ]]; then
        echo "Error: cannot read dimensions for '${f:t}', treating as single page" >&2
        is_double[$f]=0
        (( total_pages++ ))
        (( dim_failures++ ))
        continue
    fi
    w="${dims%% *}"
    h="${dims##* }"
    if (( w > h )); then
        is_double[$f]=1
        (( total_pages += 2 ))
    else
        is_double[$f]=0
        (( total_pages++ ))
    fi
done

last_page=$(( start_page - 1 + total_pages ))
page_width=${#last_page}
(( page_width < 2 )) && page_width=2

# Stage 1: rename to temp files to avoid collisions
typeset -a temp_files orig_exts

for i in {1..${#image_files}}; do
    ext="${image_files[$i]:e}"
    tmp="${dir}/.numbering_tmp_${i}.${ext}"
    mv -- "${image_files[$i]}" "$tmp" || { echo "Error: failed to stage '${image_files[$i]:t}'" >&2; exit 1; }
    temp_files+=("$tmp")
    orig_exts+=("$ext")
done

# Stage 2: assign page numbers and rename to final names
page=$start_page
for i in {1..${#temp_files}}; do
    ext="${orig_exts[$i]}"
    orig="${image_files[$i]}"

    if (( is_double[$orig] )); then
        p1=$(printf "%0${page_width}d" "$page")
        p2=$(printf "%0${page_width}d" "$(( page + 1 ))")
        j=0
        while (( j < ${#p1} - 1 )) && [[ "${p1:$j:1}" == "${p2:$j:1}" ]]; do
            (( j++ ))
        done
        page_part="${p1}-${p2:$j}"
        (( page += 2 ))
    else
        page_part=$(printf "%0${page_width}d" "$page")
        (( page++ ))
    fi

    if [[ -n "$suffix" ]]; then
        new_name="${chapter_padded}_${page_part}-${suffix}.${ext}"
    else
        new_name="${chapter_padded}_${page_part}.${ext}"
    fi

    echo "${orig:t} -> ${new_name}"
    mv -- "${temp_files[$i]}" "${dir}/${new_name}"
done

if (( dim_failures > 0 )); then
    echo "Renamed ${#image_files} files (${total_pages} pages, ${dim_failures} dimension-detection failures)."
else
    echo "Renamed ${#image_files} files (${total_pages} pages)."
fi
