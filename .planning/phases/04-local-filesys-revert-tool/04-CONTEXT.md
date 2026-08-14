# Phase 4: local-filesys revert tool - Context

**Gathered:** 2026-08-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Build a symmetric shadow-swap workflow for `dev/local-filesys/`: a "home" tree holds real files at some paths and hash-only shadow placeholders at others (for files currently living elsewhere); one or more arbitrary, user-supplied "target" trees hold the mirror image. `revert` pulls files matching home's shadows back into home from the target tree(s), swapping the shadow out to the target tree at the exact spot the file came from. `revert-revert` performs the identical swap in reverse, achieving a true round trip. This completes the gap the `retain-dir-struct-*.zsh` pipeline (1/2/3) has always had: none of those scripts ever `mv`/relocate real data files, only read/index them. Originates from a Phase 1 deferred idea and the backlog note captured 2026-08-05.

</domain>

<decisions>
## Implementation Decisions

### Shadow format & tree model
- **D-01:** Shadow files stay hash-only `.txt`, same content/format `retain-dir-struct-1.zsh` already produces (`sha256sum` output redirected to a `.txt` file), named as the original relative path + `.txt` suffix — no location metadata is ever stored in a shadow.
- **D-02:** Home and target trees are structurally symmetric: any given relative path in either tree holds either the real file or its shadow placeholder — never both, never neither (an untracked path in the target tree with no corresponding shadow anywhere is simply outside this tool's concern, see Claude's Discretion).

### Matching mechanism
- **D-03:** Resolve a shadow to its real file primarily by **name** (the shadow's filename, minus `.txt`, is the file's original relative path — search the user-supplied target tree(s) for a file with that same name/relative path first), not a blind hash-scan of every file. Hash is used to disambiguate when more than one candidate shares that name.
- **D-04:** Even on a **unique** name match (no collision), always verify the file's hash against the hash recorded in the shadow before moving it. A mismatch is treated the same as a failed/ambiguous match (see D-05) — **Reversibility:** reversible — this is a runtime safety check, easy to relax later if it proves too strict in practice.
- **D-05:** An ambiguous match (same name, and by hash more than one genuine duplicate) or a hash-verification failure → **error out on that item**; do not guess or auto-resolve. Matches the project's "correctness matters more than feature breadth" value, given this operation physically relocates real files (unlike the read-only `retain-dir-struct-3-find-sorted.zsh`, which just reports "no match" and continues).
- **D-06:** A shadow with no name match anywhere in the given target tree(s) at all → skip with a report message and continue the run, mirroring `retain-dir-struct-3-find-sorted.zsh`'s existing "No matching file found" convention. Not treated as fatal.

### Swap mechanics
- **D-07:** The relocation is a genuine **two-way swap**, not delete-then-recreate: the existing shadow file is `mv`'d from its current tree into the spot the real file is vacating (same file, same hash content, nothing recomputed), while the real file is `mv`'d into the spot the shadow is vacating. Explicitly rejected: deleting the shadow and writing a brand-new one with a freshly computed hash — avoids a redundant hash recompute and guarantees the shadow's recorded hash can never drift from what it already asserted.
- **D-08:** `revert-revert` is not a separately-designed operation — it is the exact same swap, run with home and target-tree roles reversed. It reads the shadows `revert` just left behind in the target tree (per D-07), matches them against the now-real files sitting in home (per D-03/D-04), and swaps them back out. This is what makes a "true round trip" possible with zero stored location metadata anywhere (per D-01) — the round-trip destination is always wherever the shadow currently sits, nothing more.

### Move safety
- **D-09:** Both `revert` and `revert-revert` support a `--dry-run` flag (preview only, no `mv`), matching the Phase 1 D-04 precedent set on `retain-dir-struct-2-sorted.zsh` (added specifically because that script's copies were about to run for real for the first time — same situation applies here, for `mv` instead of `cp`, and for two scripts instead of one).

### Claude's Discretion
- Whether this ships as one script invocable in either direction (given D-08's confirmed symmetry) or two separate scripts — an architecture choice for planning/research, not locked by the user. The backlog's candidate name `retain-dir-struct-4-revert.zsh` remains a reasonable starting point for at least the "revert" direction if two scripts are chosen.
- Real files sitting in the target tree with no corresponding shadow anywhere are left untouched — out of scope for this phase (per D-02, only shadow-vs-real pairs are this tool's concern).
- Exact search mechanism for name-first matching (e.g. `find -name` before any hashing) — implementation detail, follow whatever is simplest and consistent with the codebase's existing `find ... -print0` safe-iteration convention.
- Test coverage: per `PROJECT.md` §Constraints (Testing), new tooling this consequential should get a tracked test file following the manual assert-style pattern already used in `dev/local-filesys/tests/test-retain-dir-struct.zsh` — fixture scope is Claude's discretion at planning time, but should exercise: a clean unique-name swap round trip, a hash-mismatch-on-unique-name error case, and an ambiguous-multiple-candidates error case, at minimum.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Origin & precedent
- `.planning/phases/01-local-filesystem/01-CONTEXT.md` §`<deferred>` — the original deferred idea: "Reverse/undo command file for `retain-dir-struct-1.zsh`" — this phase realizes it, now expanded to a bidirectional swap per this discussion
- `.planning/codebase/CONCERNS.md` §"Missing Critical Features" → "No Rollback Capability" — the broader gap this phase's model addresses, previously only flagged in the `dev/remote/` context
- `.planning/ROADMAP.md` §"Phase 1: Local Filesystem" D-04 — the `--dry-run` precedent D-09 extends to this phase's two new scripts

### Closest existing analog
- `dev/remote/rename-remote-files-2-rename-local.zsh` — the only other script in the codebase that `mv`s real files driven by shadow metadata (sourced `MATCHED_REMOTE_PATH`/`ORIGINAL_LOCAL_PATH` variables); this phase's design deliberately diverges from it by storing **no** location metadata in the shadow at all (per D-01), relying entirely on name+hash matching instead

### Existing local-filesys scripts (behavior/format this phase must stay consistent with)
- `dev/local-filesys/retain-dir-struct-1.zsh` — shadow file format/content this phase's shadows must match exactly (`sha256sum` output, `.txt` suffix on the relative path)
- `dev/local-filesys/retain-dir-struct-3-find-sorted.zsh` — the "No matching file found" message convention D-06 mirrors; also the file-map/hash-index build pattern (`declare -A`, `find ... -print0` safe iteration) this phase's matching logic should follow

### Requirements & project policy
- `.planning/REQUIREMENTS.md` — no existing requirement code covers this; planning should add one (e.g. `LOCALFS-05`) under Local Filesystem
- `.planning/PROJECT.md` §"Constraints" → Testing — tracked test file required, no CI (informs the Claude's Discretion test-coverage note above)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `dev/local-filesys/retain-dir-struct-3-find-sorted.zsh` lines 22-30 — working hash-index-build pattern (`declare -A file_map`, `find ... -print0` loop, `sha256sum | awk '{print $1}'`) — reusable for the fallback/disambiguation hashing step once name-matching narrows candidates
- `dev/local-filesys/retain-dir-struct-2-sorted.zsh` lines 5-9 — working `--dry-run` flag pattern (`zparseopts` + `opt_dryrun`) to reuse for D-09
- `dev/remote/rename-remote-files-2-rename-local.zsh` lines 17-52 — the closest existing "read shadow metadata, mv real file, warn-and-continue on no-match" control flow shape, though its shadow format (sourced shell variables) differs from this phase's hash-only `.txt` format

### Established Patterns
- Output: `print -r --` throughout (Phase 1 D-03 standardized all `dev/local-filesys/*.zsh` scripts on this)
- Safe iteration: `while IFS= read -r -d '' var; do ... done < <(find ... -print0)` process-substitution form, not `find | while` pipes
- Errors to stderr with `>&2`, `exit 1` for fatal/setup errors; warn-and-continue (non-fatal) for per-item soft failures during batch processing

### Integration Points
- None — standalone CLI scripts, no shared library or sourcing between `dev/local-filesys/*.zsh` files

</code_context>

<specifics>
## Specific Ideas

- Shadow filename convention to preserve exactly: `${TGTDIR}/${relpath}.txt` where `relpath` is the file's path relative to its tree root (established in `retain-dir-struct-1.zsh:25-28`)
- The swap must be implemented as literal `mv` operations exchanging the shadow and the real file's positions — not a delete-then-regenerate sequence (D-07)

</specifics>

<deferred>
## Deferred Ideas

None new beyond the phase's own origin (already noted in Canonical References — the Phase 1 deferred idea this phase directly fulfills).

### Reviewed Todos (not folded)
None — `todo.match-phase` returned 0 matches for this phase.

</deferred>

---

*Phase: 4-local-filesys revert tool*
*Context gathered: 2026-08-13*
