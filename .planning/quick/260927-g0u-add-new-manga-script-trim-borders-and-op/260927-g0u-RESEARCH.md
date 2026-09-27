# Trim Borders Script — Research

**Researched:** 2026-09-27
**Domain:** ImageMagick border trimming (zsh CLI script)
**Confidence:** HIGH — every claim below was reproduced against synthetic test images generated in this session (`/tmp/claude-1000/trimtest/`), not taken from memory or docs alone.

## Summary

The current `trim_borders.sh` has a **live, reproduced, data-destroying bug**: its loop-exit condition (`new_w -ge orig_w && new_h -ge orig_h`) does not guard against a trim collapsing the image to 1×1 (which ImageMagick does whenever a working copy becomes visually near-uniform after the real border is gone — e.g. a solid black gutter or flat-color panel). Running the script's exact logic against a plain single-white-border 800×1200 PNG in this session **overwrote it with a 1×1 JPEG**. This is not an edge case reachable only under pathological input — a manga page with any large flat-color region after its border is removed triggers it.

The BMP round-trip and repeated `identify` calls are also unnecessary. ImageMagick's `-format "%w %h" -write` combo lets one `magick` invocation perform a crop step **and** report the resulting size, so the per-iteration cost drops from 3 process spawns (trim + 2×identify) to 1. The `-fill white -opaque black` black-border workaround is not just redundant — it is actively dangerous: plain `-trim` already auto-detects the corner pixel as background regardless of whether it's black or white, and the `-opaque` swap corrupts images whose *content* is white (turning border-plus-content into one undifferentiated white blob, which also collapses to 1×1).

**Primary recommendation:** keep a bounded loop (nested borders genuinely require repeated trims — verified), but (1) replace each iteration's 3 processes with 1 via `-write`+`-format`, (2) drop the black/white two-pass split entirely (plain `-trim` handles both), (3) add a minimum-size guard before ever overwriting the source, and (4) preserve the source's own container format and quality instead of hardcoding JPEG output into whatever extension the original file had.

## Architectural Responsibility Map

Single-tier CLI script — no client/server split applies.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Border detection & crop | CLI script (ImageMagick subprocess) | — | Local file processing tool, no service boundary |

## Findings by Focus Question

### 1. Single `magick` invocation, and is the loop actually needed?

**A single `-trim` is NOT sufficient for nested borders — verified.** Built a 3-layer synthetic image (white background → gray frame → white margin → black content). A single `-trim` only strips the outermost layer:

```
$ magick nested_border.png -fuzz 3% -format "%@" info:
641x961+80+120                                    # only removes outer white bg
```

Trimming that result again peels the next layer (gray frame), then again peels the white margin, converging at `501x801` (matches the black rectangle's true bounds) only after **3** trim operations. So the loop's *reason to exist* is real: `-trim`'s background color is auto-detected from the corner pixel of the *current* image, and each call only removes one uniform-colored layer.

**Chaining a fixed N `-fuzz/-trim/+repage` triplet in one `magick` command line works identically to the loop** — confirmed exact same `501x801` result from `magick nested_border.png -fuzz 3% -trim +repage -fuzz 3% -trim +repage -fuzz 3% -trim +repage out.png` (one process, not three). **But this is only safe if N matches (or under-shoots) the real nesting depth.** Over-chaining is destructive: running one *extra* trim past convergence on an already fully-trimmed, visually-uniform image collapses it to 1×1 — reproduced on both the single-layer and 3-layer test images. So a blind fixed-N chain is not an acceptable replacement for the loop; **you still need to check convergence after each real crop**, you just don't need `identify` to do it.

**Recommended one-shot-per-iteration pattern** (verified): `-write` plus `-format` on the same invocation performs the crop AND reports the new size, in one process:

```
$ magick white_border.png -fuzz 3% -trim +repage -write out.png -format "%w %h" info:
601 901
```

This replaces the original's 3 processes/iteration (magick trim + `identify` width + `identify` height) with 1. Compare new W/H (from stdout) against the previous iteration's W/H in zsh; stop when neither shrank, exactly like the current script, but 3x fewer process spawns per iteration and no `identify` parsing.

`-define trim:percent-background=` / `trim:edges` — not usable to answer this: `magick -list define` on this install (7.1.2-18 Q16) did not enumerate a `trim:*` namespace, and IM's own CLI help (`-help trim`) errored (`unrecognized option`) since `-help` is not this binary's flag syntax. Not verified either way; do not rely on it. [ASSUMED — could not confirm the flag exists in this IM version]

`-bordercolor` + `-border 1`: not tested — the corner-pixel autodetection already worked correctly for both white and black borders (see Q2), so this trick (used when the source has NO uniform border at all, e.g. an image that touches all edges) wasn't needed for the manga-scan case and was not verified.

### 2. Black-border detection — is there something better than `-opaque black → white`?

**Yes: nothing. Plain `-trim` already handles it, no preprocessing needed** — verified:

```
$ magick black_border.png -fuzz 3% -trim +repage black_trimmed.png
$ identify -format "%wx%h\n" black_trimmed.png
601x901                     # exactly correct, no -opaque step involved
```

`-trim`'s background color comes from the corner pixel, whatever it is (black, white, gray — anything). The two-pass "try white, if nothing trimmed try `-opaque black→white` then trim" logic in the current script is solving a problem that doesn't exist for `-trim` itself.

**Worse: the `-opaque black → white` step is actively destructive when the image content is white-on-black** (a very ordinary manga case — e.g. a black-bordered scan of a page with white paper). Verified:

```
$ magick black_border.png -fuzz 3% -fill white -opaque black tmp.png
$ magick tmp.png -fuzz 3% -trim +repage out.png
magick: geometry does not contain image ...
$ identify out.png
1x1
```

Turning the border white merges it with the white interior content, leaving no color boundary to trim against, and IM collapses the "fully background" result to 1×1 — same failure mode as the loop-exit bug in Q1/Pitfall 1, just triggered a different way. **Recommendation: delete the `-opaque black` branch entirely.** A single `-trim` loop (or the one-shot-per-iteration pattern from Q1) already covers both colors.

### 3. Lossless JPEG crop (`jpegtran`) vs. re-encode

`jpegtran` is installed (`/usr/bin/jpegtran`), `vips` and `exiftool` are **not** (`command -v vips exiftool` → not found).

**`jpegtran -crop` is lossless but not pixel-exact — it silently rounds to the JPEG's MCU block boundary.** Verified on a 4:4:4-sampled (`1x1,1x1,1x1`) JPEG, whose MCU is 8×8: requesting `-crop 601x918+100+150` produced a **605×924** output, not 601×918 — offset 100 isn't a multiple of 8, so `jpegtran` moved the crop origin to the nearest boundary (96) and grew the box to compensate:

```
$ jpegtran -crop 601x918+100+150 -copy all noisy_border.jpg > jt_out.jpg
$ identify -format "%wx%h\n" jt_out.jpg
605x924
```

`-perfect` (meant to abort rather than silently round) did not error in this build — it produced the same 605×924 output with exit 0, so it is not a reliable "fail loudly if imprecise" guard here. `-trim` (drop non-MCU-aligned edge blocks instead of growing) gave the identical 605×924. Net effect: up to 7px of slack per edge either way, silently.

**Re-encoding at the source's own quality is simpler and visually lossless for a crop-only operation** — verified quality is preserved exactly when passed through explicitly:

```
$ identify -format "%Q\n" source.jpg
90
$ magick source.jpg -fuzz 15% -trim +repage -quality 90 out.jpg
$ identify -format "%Q %wx%h\n" out.jpg
90 601x918
```

Read the source's `%Q` first (`identify -format "%Q" "$IMG"`) and pass it back as `-quality` on write — this avoids IM's default re-encode quality (which is not guaranteed to match the source) without needing `jpegtran`'s MCU caveats or its separate binary/flag surface. Given the project's simplicity-first constraint and the fact that a crop introduces no resampling (only quantization-identical re-encoding), `jpegtran` adds a second tool and an MCU-rounding caveat for a precision gain that doesn't matter for manga page trimming. **Recommendation: skip `jpegtran`, use `magick ... -quality "$(identify -format '%Q' "$IMG")"`.**

**PNG must stay PNG — confirmed by testing, not just noting the bug.** Writing to a filename with a `.png` extension causes `magick` to correctly emit PNG bytes:

```
$ magick nested_border.png -fuzz 3% -trim +repage ... out_keep.png
$ file out_keep.png
out_keep.png: PNG image data, ...
```

The current script's bug is structural, not an ImageMagick limitation: it hardcodes a `.jpg` temp output filename (`TMP_JPG="/tmp/tmp_trim_result.jpg"`) and then `cp`s that JPEG-encoded file over `$IMG` regardless of `$IMG`'s own extension — so a `.png` source ends up containing JPEG bytes under a `.png` name. Fix: pick the temp/output extension from `${IMG:e}` (zsh) and never force JPEG for non-JPEG sources.

### 4. Performance

Old flow (BMP conversion + `identify`-driven loop) vs. new (chained trim, one process per convergence check), sequential, 20 copies of the same test image:

| Flow | Wall time (20 images) | Per-image processes (2-iteration case) |
|---|---|---|
| Old (BMP + per-iteration `identify` x2) | 3.49s | 8 (`convert→bmp`, then per iter: trim+2×identify, plus final jpg) |
| New (single trim invocation, no BMP) | 1.50s | ~3–4 |
| New + `xargs -P4` | 0.40s | same, run 4-wide |

Old→new is a **~2.3x** speedup from dropping the BMP round-trip and collapsing `identify` calls into the same `magick` invocation via `-write`+`-format`; adding `xargs -P4` gives another **~3.7x** on top (**~8.7x** combined) since ImageMagick is single-threaded per invocation and file conversion is embarrassingly parallel across images.

zsh has no built-in parallel-map; the standard option is `find ... -print0 | xargs -0 -P<n> -I{} magick ...` (matches `number-pages.zsh`'s convention of relying on external coreutils, and `xargs -0` handles arbitrary filenames safely). **Caveat if parallelizing:** the current script uses fixed, non-unique temp filenames (`/tmp/tmp_trim_base.bmp` etc. — no PID, no `mktemp`), which is a race condition under `-P>1`. The one-shot approach (no BMP intermediate, no shared temp files at all — `magick` reads/writes directly) sidesteps this rather than requiring per-worker unique temp names.

### 5. Pitfalls

**Pitfall 1 — Loop convergence check does not guard against collapse to 1×1. Reproduced end-to-end, catastrophic.**
Ran the *exact* logic of the current script (same variable names, same comparison) against a plain single-border 800×1200 PNG:
```
iter=1 orig=800x1200 new=601x901   (real border trim)
iter=2 orig=601x901  new=1x1       (interior is a flat color -> IM collapses it)
iter=3 orig=1x1      new=1x1       -> BREAK ("no further shrink")
RESULT saved to orig_test.png: 1x1 JPEG   (was: 800x1200 PNG)
```
The break condition (`new_w -ge orig_w && new_h -ge orig_h`) treats a collapse to 1×1 as "still shrinking, keep going," then treats the resulting stable 1×1 as convergence, and the script happily writes that 1-pixel image over the original file. This triggers on any manga page where the region left after removing the real border contains a large flat-color area (a black gutter, a solid-ink splash panel, a screentone region within the fuzz threshold) — not a rare pathological input. **Any replacement script must add an explicit minimum-size guard** (e.g. reject if resulting W or H falls under some floor like 10px or some fraction of the original) before ever overwriting the source, and must not treat "size stopped increasing" alone as a safe stop condition.

**Pitfall 2 — JPEG noise defeats `-fuzz 3%` (the script's hardcoded default) entirely.**
Built a JPEG with Gaussian noise (simulating scanner/compression artifacts) over a white border. At the script's own fuzz value, **zero trimming occurred**:
```
fuzz 3%:  800x1200+0+0   (no-op — full image, nothing trimmed)
fuzz 5%:  800x1200+0+0
fuzz 8%:  798x1197+2+3   (barely trims)
fuzz 10%: 783x1193+17+7  (still short of the real 601x901 border)
fuzz 15%: 601x918+100+150 (close to correct)
```
There is no single fuzz value that is safe for both clean synthetic borders (3% is already generous there) and real scanned/compressed manga (needs ~15% in this test). A fixed `FUZZ=3` will silently no-op on noisy real-world scans rather than erring — the current script will report "No border trimmed — untouched" in that case, which is at least *safe* (no data loss) but means the tool quietly does nothing on exactly the input it's most likely to be run against. Consider a higher default (evidence here points to something in the 8–15% range for JPEG sources) or making it a CLI flag, and validate against a couple of real scans before picking a final number — this synthetic noise level does not necessarily match the user's actual scan quality. [ASSUMED for the actual value to standardize on — only the *shape* of the problem (3% is too low for compressed sources) is verified]

**Pitfall 3 — EXIF orientation could not be verified in this environment; flag as unresolved, not "fine."**
Attempted to build a JPEG with a real embedded EXIF `Orientation` tag using `magick -set orientation "6"`; `identify -format "%[orientation]"` read back `Undefined` both before and after processing, indicating the tag was never actually embedded by that command (no `exiftool` available in this environment to embed/verify one properly). **Not verified either way in this session.** Known IM behavior from documentation [CITED: ImageMagick.org Usage — Image Orientation]: `-strip` (used by the current script on every save) removes EXIF metadata including `Orientation` without rotating pixel data to match, and `magick` does not auto-rotate on read unless `-auto-orient` is passed. If any real source JPEGs carry a non-1 orientation tag, `-strip`-then-save would visually "un-rotate" them for viewers that previously honored the tag. **Recommendation: add `-auto-orient` before the trim/crop step** so pixel data is baked into display orientation before `-strip` discards the tag — cheap insurance, not verified as currently necessary against this project's actual images.

**Pitfall 4 — Colorspace is preserved through trim/crop.** Verified: a `-colorspace Gray` PNG stayed `Gray` after trim+`-strip`. Not a real risk for this pipeline; noted only because it was explicitly asked about.

**Pitfall 5 — Blank/borderless images collapse the same way as Pitfall 1 and must hit the same guard.** A fully blank white PNG (no border, no content) collapses to `1x1` on the very first trim attempt, with a warning on stderr but **exit code 0**:
```
$ magick blank.png -fuzz 3% -trim +repage out.png; echo $?
magick: geometry does not contain image ... (warning)
0
$ identify out.png
PNG 1x1 ...
```
Exit-code checking alone will not catch this (`magick` returns 0 despite the warning). Must check *dimensions* after processing, not just the process exit status — same fix as Pitfall 1's minimum-size guard covers this too.

**Pitfall 6 — filename safety.** The current `find ... | while read -r IMG` (single variable) does not word-split on spaces (safe for that specific case) but breaks on filenames containing literal newlines and is inconsistent with the project's own established safe pattern (`-print0` / `read -r -d ''`, called out explicitly in `.claude/CLAUDE.md`'s "Safety Practices" conventions, and already used correctly elsewhere in the codebase). `number-pages.zsh` instead uses zsh glob qualifiers (`(Nn)`) rather than `find | while read` at all. Recommend `find ... -print0 | while IFS= read -r -d '' IMG` to match the codebase's documented convention, independent of whether the specific test images here exercised a newline-containing name.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multi-layer border removal | Custom pixel-scanning/bounding-box math | ImageMagick `-trim` (repeated, with a size-comparison guard) | `-trim` already does correct corner-color-relative bounding-box detection per call; verified it handles both black and white borders identically without a color-specific code path |
| Reading current JPEG quality to preserve it on save | Guessing/hardcoding a `-quality` value | `identify -format "%Q" "$IMG"` piped into `-quality` on write | Verified round-trips exactly (Q90 in, Q90 out) with no extra tooling |

## Code Examples

Per-iteration convergence check with one process instead of three (verified working):
```zsh
# Source: verified in this session against ImageMagick 7.1.2-18 Q16
read -r new_w new_h <<< "$(magick "$work" -fuzz 3% -trim +repage -write "$out" -format '%w %h' info: 2>/dev/null)"
```

Preserve JPEG quality on re-encode (verified):
```zsh
# Source: verified in this session
src_q=$(identify -format '%Q' "$IMG" 2>/dev/null)
magick "$work" -strip ${src_q:+-quality "$src_q"} "$out.${IMG:e}"
```

Minimum-size guard before ever overwriting the source (addresses Pitfall 1 & 5 — not present in current script, must be added):
```zsh
# Illustrative — not verified as a complete script, only the underlying check
if (( final_w < 10 || final_h < 10 )); then
  echo "Refusing to save — trim collapsed to ${final_w}x${final_h}: $IMG" >&2
  continue
fi
```

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `magick` | trim/crop | ✓ | 7.1.2-18 Q16 | — |
| `identify` | quality/dims read | ✓ | (bundled with above) | — |
| `jpegtran` | lossless crop (not recommended, see Q3) | ✓ | present | Not used — re-encode at matched `-quality` instead |
| `vips` | alternative fast pipeline | ✗ | — | Not needed — `magick` alone meets the need |
| `exiftool` | EXIF orientation verification | ✗ | — | Could not verify Pitfall 3 in this session; `-auto-orient` recommended defensively |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `trim:percent-background` / `trim:edges` IM defines exist/behave as commonly documented | Q1 | Low — not relied on in the recommended pipeline; purely informational, dropped from the recommendation |
| A2 | A fuzz value "in the 8–15% range" is the right default for this user's real scanned manga | Pitfall 2 | Medium — only tested against one synthetic Gaussian-noise sample, not the user's actual scan corpus; wrong default either misses real borders (too low) or eats real content (too high) — should be confirmed against a few real files before locking in |
| A3 | `-strip` on an EXIF-oriented JPEG causes a visible mis-rotation, and `-auto-orient` fixes it | Pitfall 3 | Low-medium — could not construct a real orientation tag in this sandbox to test directly; if the user's actual scans never carry non-1 orientation (likely, since these are usually flatbed/software-scanned page images, not camera photos), this is moot |

## Open Questions

1. **What fuzz value actually works on the user's real manga scans?**
   - What we know: 3% (current default) fails entirely on synthetic JPEG noise; 15% recovers close-to-correct trim on that synthetic sample.
   - What's unclear: real scan noise characteristics vary by source (scanner vs. phone photo vs. already-recompressed release); the 15% figure is not necessarily the right number for this user's actual files.
   - Recommendation: keep fuzz as a `-f`/env-overridable parameter (matching `number-pages.zsh`'s `-s`/`-n` flag convention) rather than a hardcoded constant, and validate against a handful of the user's real chapter scans before shipping a final default.

## Sources

### Primary (HIGH confidence — verified by running commands in this session)
- ImageMagick 7.1.2-18 Q16 `magick`/`identify` CLI, invoked directly against synthetic test images generated with `magick -size ... xc:...` in `/tmp/claude-1000/trimtest/`
- `jpegtran` (system-installed), invoked directly

### Secondary (MEDIUM confidence)
- ImageMagick Usage documentation on `-trim` / `-auto-orient` behavior [CITED: ImageMagick.org Usage] — general IM behavior claims not independently reproducible in this sandbox (no real EXIF tag available to test against)

## Metadata

**Confidence breakdown:**
- Trim/crop mechanics (single vs. chained vs. looped): HIGH — every claim reproduced against synthetic images this session, including the reproduction of the actual destructive bug
- Performance numbers: HIGH for relative direction and rough magnitude; specific seconds are this-machine/this-sample only, not portable benchmarks
- Fuzz default recommendation: LOW/MEDIUM — only one synthetic noise sample tested, flagged as Assumption A2

**Research date:** 2026-09-27
**Valid until:** No expiry concern — findings are about local CLI tool behavior (ImageMagick 7.1.2), not a fast-moving API/library surface
