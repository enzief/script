#!/bin/zsh

zmodload zsh/zutil
zparseopts -D -E -F -- f:=opt_f -fuzz:=opt_f e:=opt_e -edges:=opt_e h=opt_h -help=opt_h || exit 1

if (( ${#opt_h} )); then
    cat <<'EOF'
Recursively trim uniform borders from manga page images, in place.

Usage: trim-borders.zsh [-f N] [-e all|v|h] <dir>

Options:
  -f N, --fuzz N   Fuzz percent for border-color matching (default: 3).
                    Raise this for noisy/compressed JPEG scans.
  -e MODE, --edges MODE   Which edges to trim (default: all):
    all  trim all four edges (default)
    v    vertical: trim top and bottom edges only
    h    horizontal: trim left and right edges only

  In v/h mode, the border color is sampled from the image corners, so if
  the untrimmed edges also carry a border, only the outermost layer on
  the selected edges is removed.

Arguments:
  <dir>            Directory to process recursively. Required -- no
                    default, so an accidental run in the wrong directory
                    cannot rewrite images.

Behavior:
  Files are rewritten in place. Each image is trimmed repeatedly until
  nothing more is removed, so nested borders (a frame within a frame)
  peel off one layer at a time. Any uniform border color works -- white,
  black, or anything else. A PNG stays a PNG; a JPEG keeps its source
  quality. Metadata is kept. Images with no border are not rewritten at
  all. If the trimmed result would fall under 50% of the original width
  or height (a flat-interior collapse, a blank page, or a runaway
  over-trim), the file is left untouched and a warning is printed
  instead.

Examples:
  trim-borders.zsh ch42/              # trim every image under ch42/
  trim-borders.zsh -f 10 ch42/        # more tolerant fuzz for noisy scans
  trim-borders.zsh -e v ch42/         # trim top/bottom only
  trim-borders.zsh -e h ch42/         # trim left/right only

Requires: ImageMagick 7 (magick)
Supports: jpg, jpeg, png (any letter case)
EOF
    exit 0
fi

MIN_KEEP_PCT=50  # a trim result under this percent of the original W or H is rejected

fuzz="${opt_f[2]:-3}"
if ! [[ "$fuzz" =~ '^[0-9]+([.][0-9]+)?$' ]]; then
    echo "Error: fuzz '$fuzz' is not numeric" >&2
    exit 1
fi

edges="${opt_e[2]:-all}"
if [[ "$edges" != (all|v|h) ]]; then
    echo "Error: edges '$edges' must be one of: all, v, h" >&2
    exit 1
fi

if (( $# != 1 )); then
    echo "Usage: trim-borders.zsh [-f N] [-e all|v|h] <dir>" >&2
    exit 1
fi

if [[ ! -d "$1" ]]; then
    echo "Error: directory '$1' not found" >&2
    exit 1
fi
dir="${1:A}"

if ! command -v magick &>/dev/null; then
    echo "Error: 'magick' (ImageMagick 7) is required" >&2
    exit 1
fi

case "$edges" in
    v) edge_args=(-define trim:edges=north,south) ;;
    h) edge_args=(-define trim:edges=east,west) ;;
    *) edge_args=() ;;
esac

tmpdir=$(mktemp -d) || { echo "Error: failed to create a temp directory" >&2; exit 1; }
pending=""

cleanup() {
    [[ -n "$pending" ]] && rm -f -- "$pending"
    rm -rf -- "$tmpdir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

typeset -a images
while IFS= read -r -d '' f; do
    images+=("$f")
done < <(find "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) ! -name '.trim-borders.*' -print0)

if (( ${#images} == 0 )); then
    echo "No image files found in '$dir'" >&2
    exit 1
fi

trimmed=0
no_border=0
skipped=0
errors=0

for img in "${images[@]}"; do
    rel="${img#$dir/}"
    ext="${img:e}"

    ident_out=$(magick identify -format '%w %h %Q\n' "$img" 2>/dev/null | head -1)
    read -r ow oh q <<< "$ident_out"
    if ! [[ "$ow" =~ '^[0-9]+$' && "$oh" =~ '^[0-9]+$' ]]; then
        echo "Error: cannot read image: '$rel'" >&2
        (( errors++ ))
        continue
    fi

    src="$img"
    cw=$ow
    ch=$oh
    trim_ok=1

    while true; do
        trim_out=$(magick "$src" "${edge_args[@]}" -fuzz "${fuzz}%" -trim +repage -write "$tmpdir/next.miff" -format '%w %h' info: 2>/dev/null)
        trim_status=$?
        read -r nw nh <<< "$trim_out"
        if (( trim_status != 0 )) || ! [[ "$nw" =~ '^[0-9]+$' && "$nh" =~ '^[0-9]+$' ]]; then
            echo "Error: trim failed: '$rel'" >&2
            (( errors++ ))
            trim_ok=0
            break
        fi
        if (( nw >= cw && nh >= ch )); then
            break
        fi
        mv -f -- "$tmpdir/next.miff" "$tmpdir/work.miff"
        src="$tmpdir/work.miff"
        cw=$nw
        ch=$nh
    done

    (( trim_ok )) || continue

    if [[ "$src" == "$img" ]]; then
        echo "No border: '$rel'"
        (( no_border++ ))
        continue
    fi

    if (( cw * 100 < ow * MIN_KEEP_PCT || ch * 100 < oh * MIN_KEEP_PCT )); then
        echo "Warning: trim result ${cw}x${ch} is under ${MIN_KEEP_PCT}% of ${ow}x${oh}, left untouched: '$rel'" >&2
        (( skipped++ ))
        continue
    fi

    qargs=()
    if [[ "${(L)ext}" == (jpg|jpeg) && -n "$q" ]]; then
        qargs=(-quality "$q")
    fi

    write_ok=1
    magick "$tmpdir/work.miff" "${qargs[@]}" "$tmpdir/out.$ext" 2>/dev/null || write_ok=0

    if (( write_ok )); then
        pending="${img:h}/.trim-borders.$$.$ext"
        if cp -- "$tmpdir/out.$ext" "$pending" 2>/dev/null \
            && chmod --reference="$img" -- "$pending" 2>/dev/null \
            && mv -f -- "$pending" "$img" 2>/dev/null; then
            pending=""
        else
            write_ok=0
        fi
    fi

    if (( write_ok )); then
        echo "Trimmed: '$rel' (${ow}x${oh} -> ${cw}x${ch})"
        (( trimmed++ ))
    else
        rm -f -- "$pending"
        pending=""
        echo "Error: failed to write: '$rel'" >&2
        (( errors++ ))
    fi
done

echo "Done: ${trimmed} trimmed, ${no_border} no border, ${skipped} skipped, ${errors} errors."

(( errors > 0 )) && exit 1
exit 0
