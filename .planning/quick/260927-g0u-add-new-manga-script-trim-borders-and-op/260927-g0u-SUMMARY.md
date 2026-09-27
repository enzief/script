---
phase: quick-260927-g0u
plan: 01
subsystem: manga
tags: [zsh, imagemagick, manga, trim, cli]

requires: []
provides:
  - dev/manga/trim-borders.zsh: recursive in-place border trimmer with -f/--fuzz and -e/--edges, plus a minimum-size guard
  - dev/manga/tests/test-trim-borders.zsh: 66-assertion regression suite against real ImageMagick
affects: [dev/manga/*, any future manga-page preprocessing script]

actuals:
  tokens: 4919
  tasks: 3
  commits: 3
plan_head_before: 80351708c7af68e5bc59f1dfa77d245018fcae98
plan_head_after: 8a57caae535a1edf7ea71223eccf0ffdacdd5397

tech-stack:
  added: []
  patterns:
    - "One magick process per trim iteration via -write <file> -format '%w %h' info:, instead of a separate identify call per dimension"
    - "Atomic write-back: encode into mktemp -d, cp to a hidden same-dir temp, chmod --reference, mv -f over the original"
    - "Minimum-size guard (MIN_KEEP_PCT=50 against the ORIGINAL dims) gates every write-back, rejecting flat-interior/blank/runaway-collapse results"
    - "-e/--edges whitelist (all|v|h) maps to a fixed -define trim:edges=... argv array; user text never reaches magick, because ImageMagick silently ignores an invalid trim:edges value"

key-files:
  created:
    - dev/manga/trim-borders.zsh
    - dev/manga/tests/test-trim-borders.zsh
  modified: []

key-decisions:
  - "zsh's special tied parameter `path` (mirrors $PATH) must never be used as a local variable name inside a function -- shadowing it with `local path=...` silently breaks command lookup (mkdir/magick became 'command not found') inside that function's scope. Renamed the test helper's parameter to `dest`."
  - "Task 3's full regression sweep (JPEG quality/format, PNG uppercase extension, file-mode preservation, 3-layer nested border, idempotency, error path, all argument validation) required zero script changes -- Task 1/2's implementation already satisfied every assertion on the first run."
  - "Per the task's explicit instruction, the human-check verification step (running against a real manga chapter) was not performed in this session; it is recorded below as a pending follow-up for the user."
  - "Executed directly on the main tree at master (no worktree), per explicit dispatch instruction and this project's own git.branching_strategy: \"none\" convention -- consistent with every prior quick task in STATE.md's Quick Tasks Completed table."

requirements-completed: [QUICK-260927-g0u]

duration: 5min
completed: 2026-09-27
status: complete
---

# Quick Task 260927-g0u: Trim Borders Script Summary

**`dev/manga/trim-borders.zsh` replaces the unsafe `trim_borders.sh`: one `magick` process per trim iteration (no BMP round-trip, no color-replacement pass), a 50%-of-original minimum-size guard that reproduces and fixes the old script's 1x1-collapse bug, format/quality/mode preservation, and a whitelisted `-e/--edges all|v|h` option.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-09-27T17:57:27Z
- **Completed:** 2026-09-27T18:02:45Z
- **Tasks:** 3/3
- **Files modified:** 2 created (net), 1 deleted (untracked, no git trace)

## Accomplishments

- `dev/manga/trim-borders.zsh`: recursive, in-place border trimmer. Each trim iteration is one `magick "$src" ... -write "$tmpdir/next.miff" -format '%w %h' info:` call (no `identify` calls, no BMP intermediate).
- Minimum-size guard (`MIN_KEEP_PCT=50`, compared against the ORIGINAL dimensions after the loop converges): a result under 50% of the original width or height is rejected, the original is left byte-identical, and a `Warning:` is printed. This is the fix for the reproduced 1x1-collapse bug documented in the research.
- `-f/--fuzz N` (default 3, decimals accepted) and `-e/--edges all|v|h` (default `all`) are both validated before any file is touched.
- Output format and JPEG quality are preserved from the source (`${img:e}` for extension, source `%Q` for `-quality`); file mode is preserved via `chmod --reference`.
- Atomic write-back: `magick` only ever writes into a `mktemp -d`, the result is copied to a hidden same-dir temp, then `mv -f`'d over the original. EXIT/INT/TERM traps clean up `$tmpdir` and any in-flight `$pending` temp.
- `dev/manga/tests/test-trim-borders.zsh`: 66-assertion regression suite, run against the real `magick` binary (not stubbed, since trim behavior against real image bytes is what's under test).
- `dev/manga/trim_borders.sh` removed (it was untracked, so no `git rm` was needed or possible).

## Task Commits

1. **Task 1: Tracer -- trim a white-bordered PNG in a subdirectory, guard included** - `b87ec02` (feat)
2. **Task 2: `-e/--edges all|v|h` restricts which edges are trimmed (D-10)** - `61b0f47` (feat)
3. **Task 3: Regression coverage for every locked behavior, then delete the old script** - `8a57caa` (test)

_All three commits are code-only, per the constraint excluding docs artifacts from this session's commits._

## Files Created/Modified

- `dev/manga/trim-borders.zsh` - the new trimmer script (`#!/bin/zsh`, executable)
- `dev/manga/tests/test-trim-borders.zsh` - regression suite (`#!/bin/zsh`, executable)
- `dev/manga/trim_borders.sh` - deleted (was untracked; no git history entry for the deletion)

## Decisions Made

- See `key-decisions` in frontmatter. The notable one: zsh's special `path` parameter (tied to `$PATH`) cannot be used as a local variable name — doing so in the test suite's `mkpage` helper broke `mkdir`/`magick` lookup inside that function with a confusing "command not found" error. Renamed to `dest`; not a deviation from the plan's design (the plan didn't specify this variable's name), just a bug caught during Task 1's RED-to-GREEN loop.
- `-define trim:edges=north,south` / `east,west` (the research-verified path) worked exactly as the planner predicted on this machine's ImageMagick 7.1.2-18; the `%@` fallback mentioned in the plan was not needed.

## Deviations from Plan

None - plan executed exactly as written. Task 3 required no script changes (all 66 assertions passed against the Task 1/2 implementation on the first run); this is consistent with the plan's own framing that Tasks 1-2 carry the substantive design decisions and Task 3 is regression coverage.

## Issues Encountered

- The `local path=...` / zsh-special-parameter collision above, caught immediately by the RED test run (`mkdir: command not found`) and fixed before the first GREEN run.

## Pending (explicitly deferred by this session's constraints)

- **Real-corpus verification not run.** The plan's Task 3 `<human-check>` step ("copy one real manga chapter directory to a scratch location and run the script") was intentionally NOT performed in this session, per the dispatch instruction: *"Do not run the script against any real user image directory... the 'try on a real chapter' step is left for the user."* All testing used synthetic ImageMagick fixtures (`pattern:checkerboard` content, `xc:` solid-color borders) in a `mktemp -d` fixture root.
  - **User action needed:** copy one real chapter to a scratch location (never the only copy) and run `dev/manga/trim-borders.zsh <copy>` with the default fuzz (3). Research Pitfall 2 found that 3% fuzz can fail to trim noisy/compressed JPEG scans at all (safe -- it reports `No border:` rather than damaging anything) while 15% was needed on one synthetic noisy sample; if real pages report `No border:` unexpectedly, rerun with `-f 10` or higher.

## Next Steps Readiness

`dev/manga/trim-borders.zsh` and its test suite are complete and self-contained. No other scripts in the repo depend on this one. Ready for the user's real-corpus verification above whenever convenient.

---
*Quick task: 260927-g0u*
*Completed: 2026-09-27*

## Self-Check: PASSED

- FOUND: dev/manga/trim-borders.zsh
- FOUND: dev/manga/tests/test-trim-borders.zsh
- CONFIRMED ABSENT: dev/manga/trim_borders.sh
- FOUND commit: b87ec02
- FOUND commit: 61b0f47
- FOUND commit: 8a57caa
