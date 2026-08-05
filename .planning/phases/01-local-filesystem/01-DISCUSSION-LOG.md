# Phase 1: Local Filesystem - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-05
**Phase:** 1-Local Filesystem
**Areas discussed:** Output Style, Copy Safety, Verify Fix

---

## Output Style

| Option | Description | Selected |
|--------|-------------|----------|
| Harmonize all three | Standardize retain-dir-struct-1/2/3 all on `print` — fixes the cross-script inconsistency (script 2 uses echo, script 3 uses print) while touching the same files already in scope | ✓ |
| Script 1 only | Strictly match LOCALFS-03 wording — leave scripts 2 and 3's echo/print usage as-is | |

**User's choice:** Harmonize all three (Recommended option, as presented)
**Notes:** None.

---

## Copy Safety

| Option | Description | Selected |
|--------|-------------|----------|
| Just fix and trust it | cp is non-destructive, matches lightweight-process preference | |
| Print a plan first | List matches before copying — lightweight preview, not a full dry-run flag | |
| Dry-run flag (free text) | User's own answer, overriding both presented options | ✓ |

**User's choice:** "dry-run flag" (free text, via Other)
**Notes:** User wants an actual `--dry-run` CLI flag on `retain-dir-struct-2-sorted.zsh`, not just a preview print — more explicit/reusable than the "print a plan first" option offered.

---

## Verify Fix

| Option | Description | Selected |
|--------|-------------|----------|
| Manual scratch-dir run | Create throwaway test dirs/files with known hashes, run each fixed script, confirm matches found | |
| Code review only | Review the diff, no execution | |
| Make tracked test suite (free text) | User's own answer, overriding both presented options | ✓ |

**User's choice:** "make tracked test suite" (free text, via Other)
**Notes:** This reversed the project's original "no test suite / CI" decision from `PROJECT.md` Out of Scope. Follow-up question asked whether this was phase-scoped or project-wide — user chose **project-wide policy change**. `PROJECT.md` and `REQUIREMENTS.md` were updated and committed (`32a41e2`) before continuing, since Manga and Remote phases inherit this policy too.

---

## Claude's Discretion

- Exact subshell-bug fix mechanism (process substitution vs. temp file) — reuse the existing process-substitution pattern already working in `retain-dir-struct-2-sorted.zsh`'s first loop, unless impractical.
- Test framework choice (bats vs. plain zsh assertion script) — pick whichever is simplest to set up.

## Deferred Ideas

- **Reverse/undo command output file for `retain-dir-struct-1.zsh`** — raised unprompted alongside the area selections. New rollback capability, not part of LOCALFS-01/02/03. Noted for a future phase; not folded into this bug-fix pass.
