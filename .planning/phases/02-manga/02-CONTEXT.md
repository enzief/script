# Phase 2: Manga - Context

**Gathered:** 2026-08-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Make image-dimension-detection failures in `dev/manga/number-pages.zsh` visibly explicit instead of silently absorbed, without changing the script's control flow (no abort, no skip, no exit-code change). Requirement: MANGA-01.

</domain>

<decisions>
## Implementation Decisions

### Failure visibility
- **D-01:** When `identify` fails to produce dimensions for a file (dev/manga/number-pages.zsh:85), change the per-file message prefix from `Warning:` to `Error:` — behavior is otherwise unchanged: the file is still treated as a single page, the script still continues processing the rest, and the run still exits 0.
- **D-02:** Add a failure count to the closing summary line. Currently: `Renamed ${#image_files} files (${total_pages} pages).` (line 147). When one or more dimension-detection failures occurred during the run, append the count, e.g. `Renamed N files (N pages, M dimension-detection failures).` When zero failures occurred, keep the current wording unchanged.

### Explicitly out of scope for this phase (confirmed, not just deferred)
- **D-03:** Detection scope stays as-is — only "identify produced empty stdout" (`[[ -z "$dims" ]]`, line 85) counts as a failure. `identify`'s exit code (currently discarded via `2>/dev/null`, never checked) and numeric validation of `$w`/`$h` are explicitly NOT being added in this phase.
- **D-04:** Exit code behavior stays as-is — the script exits 0 regardless of whether any files hit a detection failure. Callers must read stderr/stdout, not `$?`, to detect a problem.

### Claude's Discretion
- Exact wording of the summary line's failure clause (e.g. "dimension-detection failures" vs. shorter phrasing) — keep consistent with the existing terse output style.
- Whether to track the failure count in a new variable or derive it from existing state (`is_double` doesn't currently distinguish "guessed" from "detected"; a new counter is likely simplest).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Bug details
- `.planning/codebase/CONCERNS.md` §"Fragile Areas" → "Image Dimension Detection (number-pages.zsh)" — exact fragility description (lines 84-90 in the script), notes no test coverage exists for corrupted/unsupported image formats
- `.planning/codebase/CONCERNS.md` §"Dependencies at Risk" → "ImageMagick / identify (dev/manga/number-pages.zsh)" — notes older ImageMagick versions may not support all formats (AVIF, WEBP); script already warns and continues on unsupported formats (out of scope to change per D-03/D-04)

### Requirements & success criteria
- `.planning/REQUIREMENTS.md` — MANGA-01
- `.planning/ROADMAP.md` §"Phase 2: Manga" — Success criteria: (1) clear error instead of silent failure on dimension-read failure, (2) no regression in renumbering for valid images

### Project policy
- `.planning/PROJECT.md` §"Constraints" → Testing — bug fixes get a tracked test file validating the fix, committed to the repo (no CI). This fix needs a test covering: a file `identify` can't read dimensions for → still renumbered as single page, "Error:" message printed, summary line includes the failure count.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Existing test file from Phase 1 (`dev/local-filesys/tests/test-retain-dir-struct.zsh`) is the project's only precedent test file — manual assert-style zsh script, not bats. No existing test file for `dev/manga/` yet; this phase would create the first one.

### Established Patterns
- Errors go to stderr with `>&2`, exit code 1 for fatal errors (dev/manga/number-pages.zsh:52,61,68,75) — this phase's `Error:` message is non-fatal (deliberately diverges from the fatal-error convention per D-01/D-04; downstream agents should not "fix" this into an exit-1 path).
- Warning/progress messages via `echo`, not `print` — number-pages.zsh uses `echo` throughout (line 84-90 warning included); this phase does not standardize on `print` (that was a Phase 1-scoped decision for the `local-filesys` scripts only, per `01-CONTEXT.md` D-03).

### Integration Points
- None — standalone CLI script, no shared library or sourcing.

</code_context>

<specifics>
## Specific Ideas

- Exact current line to change: `echo "Warning: cannot read dimensions for '${f:t}', treating as single page" >&2` (number-pages.zsh:86) → prefix becomes `Error:`.
- Exact current line to extend: `echo "Renamed ${#image_files} files (${total_pages} pages)."` (number-pages.zsh:147) → append failure count only when > 0.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (Detection-scope hardening and exit-code signaling were raised and explicitly declined for this phase, not deferred as future work — see D-03/D-04.)

### Reviewed Todos (not folded)
None — no pending todos matched this phase.

</deferred>

---

*Phase: 2-Manga*
*Context gathered: 2026-08-06*
