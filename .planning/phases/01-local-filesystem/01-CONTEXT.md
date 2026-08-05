# Phase 1: Local Filesystem - Context

**Gathered:** 2026-08-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix three subshell variable-scope bugs and standardize output-command style across the `dev/local-filesys/retain-dir-struct-*.zsh` scripts, so shadow-map hash lookups actually succeed instead of silently returning empty. Requirements: LOCALFS-01, LOCALFS-02, LOCALFS-03.

</domain>

<decisions>
## Implementation Decisions

### Bug fix scope
- **D-01:** Fix the subshell variable-scope bug in `retain-dir-struct-2-sorted.zsh` so `shadow_map` lookups succeed inside the `find | while` loop that reads it (currently populated via process substitution in an earlier step, then unreadable in the second loop's subshell).
- **D-02:** Fix the same class of bug in `retain-dir-struct-3-find-sorted.zsh` so `file_map` lookups succeed inside its `find | while` loop.

### Output style
- **D-03:** Standardize all three `retain-dir-struct-*.zsh` scripts on `print` (not just `retain-dir-struct-1.zsh` as LOCALFS-03 literally states) — script 2 currently uses `echo` throughout, script 3 uses `print` throughout, script 1 mixes both. User expanded scope from "script 1 only" to "harmonize all three" since they're already in scope for bug fixes.

### Copy safety
- **D-04:** Add a `--dry-run` flag to `retain-dir-struct-2-sorted.zsh`. This script's `cp` calls have never actually executed due to the bug (every match lookup returned empty) — once fixed, it will copy files for real for the first time. User explicitly wants a real `--dry-run` flag (lists what would be copied, performs no copies), not just a preview print before the real run.

### Test coverage (project-wide policy reversal)
- **D-05:** Add a tracked test file (e.g. bats) for the Phase 1 fixes, covering: `retain-dir-struct-2-sorted.zsh` (shadow_map lookup + `--dry-run` behavior), `retain-dir-struct-3-find-sorted.zsh` (file_map lookup). Use scratch fixture directories/files with known hashes; assert matches are actually found (not just "no crash").
- **D-06:** This reverses the project's original "no test suite / CI" decision (`PROJECT.md` Out of Scope, set during `/gsd-new-project`). New project-wide policy: bug fixes get a tracked test file validating the fix, committed to the repo. No CI service — tests run locally on demand. `PROJECT.md` and `REQUIREMENTS.md` were updated and committed (`32a41e2`) to reflect this before Phase 1 planning starts, since it applies to the Manga and Remote phases too, not just this one.
  — **Reversibility:** reversible — removing tests later doesn't break anything; the risk was in NOT having them (the subshell bugs went undetected for a long time with no way to catch a regression).

### Claude's Discretion
- Exact bug-fix mechanism (process substitution vs. temp file to escape the subshell) — script 2 already uses process substitution successfully for its first loop; prefer the same pattern for the second loop and for script 3's lookup loop, for consistency with the existing codebase pattern, unless it turns out impractical.
- Test framework choice (bats vs. plain assert-based zsh test script) — pick whatever is simplest to set up and matches "lightweight" intent.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Bug details
- `.planning/codebase/CONCERNS.md` §"Subshell Variable Scope in retain-dir-struct-2-sorted.zsh", §"Subshell Variable Scope in retain-dir-struct-3-find-sorted.zsh", §"Mixed Output Commands in retain-dir-struct-1.zsh" — exact bug descriptions, line numbers, and suggested fix approaches this phase must address

### Conventions
- `.planning/codebase/CONVENTIONS.md` §"Logging" — existing project convention: "Use `print` for formatted output... Use `echo` for simple messages" (this phase supersedes that nuance in favor of full standardization on `print` across these three scripts, per D-03)
- `.planning/codebase/CONVENTIONS.md` §"Safety Practices" — established safe-iteration pattern (`find ... -print0 | while IFS= read -r -d ''`) that any subshell-scope fix should preserve

### Project policy
- `.planning/PROJECT.md` §"Constraints" — updated Testing constraint (tracked test files required for bug fixes, no CI)
- `.planning/REQUIREMENTS.md` — LOCALFS-01, LOCALFS-02, LOCALFS-03 (v1 requirements this phase covers)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `retain-dir-struct-2-sorted.zsh` lines 22-28 — working process-substitution pattern (`while ... done < <(find ... -print0)`) already used for the first indexing loop; reuse this pattern to fix the second loop's subshell bug rather than introducing a new mechanism (e.g. temp files).

### Established Patterns
- Safe file iteration: `find ... -print0 | while IFS= read -r -d '' var; do ... done` (or the process-substitution variant to avoid subshells) — used consistently across `dev/local-filesys/*.zsh`.
- Associative arrays declared with `declare -A`, named descriptively (`shadow_map`, `file_map`).
- Argument validation and usage messages at the top of each script, before main logic.
- Errors go to stderr with `>&2`, exit code 1.

### Integration Points
- None — these are standalone CLI scripts invoked directly, no shared library or sourcing between them.

</code_context>

<specifics>
## Specific Ideas

- `retain-dir-struct-2-sorted.zsh --dry-run` should list every match it *would* copy (source shadow file → destination path) without performing the `cp`, mirroring the existing "Matched & Placed" / "No shadow found" output style (now standardized on `print`).
- Test fixtures should be small, throwaway scratch directories with a handful of files and known/precomputed hashes — enough to exercise the match/no-match paths, not a stress test.

</specifics>

<deferred>
## Deferred Ideas

- **Reverse/undo command file for `retain-dir-struct-1.zsh`** — user suggested the shadow-map creation script should also output a file containing the reverse command for potential future use. This is a new rollback capability, not a fix to LOCALFS-01/02/03 — `retain-dir-struct-1.zsh` doesn't rename or move anything today, so this would be net-new tooling. Belongs in its own future phase/idea, not this bug-fix pass. (Related: `CONCERNS.md` §"Missing Critical Features" already flags "No Rollback Capability" as a broader gap, currently in the Remote scripts' context.)

### Reviewed Todos (not folded)
None — no pending todos matched this phase.

</deferred>

---

*Phase: 1-Local Filesystem*
*Context gathered: 2026-08-05*
