# Phase 4: local-filesys revert tool - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-13
**Phase:** 4-local-filesys revert tool
**Areas discussed:** Overall workflow shape, target-tree shadow symmetry, ambiguous-match handling, dry-run, swap mechanics, name-vs-hash matching, hash verification

---

## Overall workflow shape (freeform)

The pre-set gray-area options (Move safety/dry-run, Destination collision, Duplicate-hash resolution, Unmatched items) were superseded almost immediately — the user's first "Other" answer described a materially different, bidirectional workflow that didn't match the backlog note's one-directional framing.

**User's description (verbatim intent):** "implement a workflow: move files from a dir to several other dirs manually, leaving trace of each (shadow) in the original dir, and the revert script/instructions to move them back as needed, and a further revert-revert script to move them to the dirs again (might be shadowing them there before running the revert)."

Claude reflected this back as a 3-step model (distribute manually → revert → revert-revert) and asked 4 clarifying questions in plain text (per the "Other" freeform handling rule).

**User's answers:**
- "home" dirs are not singular — it's a whole dir tree, not one flat directory
- in the current tree, paths without a shadow are the ones needing deletion once real files return — i.e. shadow and real file occupy the same relative-path slot, mutually exclusive
- shadows are hash-only; location is always a scanning result, never stored
- target trees are arbitrary, user-supplied as input
- revert-revert does a true round trip
- "update the roadmap" — Phase 4's Goal in ROADMAP.md should be rewritten to match this fuller model

**Notes:** This single exchange re-scoped the phase from "one-directional shadow map replay" (backlog's original framing) to "symmetric bidirectional shadow-swap between a home tree and arbitrary target trees." ROADMAP.md Phase 4 Goal was rewritten accordingly (see git commit).

---

## TargetShadow — who creates the shadow revert-revert needs?

| Option | Description | Selected |
|--------|-------------|----------|
| Revert creates it automatically | When revert pulls a file into home, it drops a fresh shadow at the exact spot it took the file from | ✓ |
| Run retain-dir-struct-1.zsh on the target tree first | Separate manual/scripted step | |
| I'll describe another way | — | |

**User's choice:** Revert creates it automatically.
**Notes:** This is what makes a stored-nothing, true round trip possible (D-08 in CONTEXT.md).

---

## MultiTarget — ambiguous hash match across target tree(s)

| Option | Description | Selected |
|--------|-------------|----------|
| Error out — resolved manually | Abort that item, don't guess | ✓ |
| Skip with a warning, continue | Log and move on | |
| I'll describe another way | — | |

**User's choice:** Error out — ambiguous match resolved manually.

---

## DryRun — should revert/revert-revert support --dry-run?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, both scripts get --dry-run | Matches Phase 1 D-04 precedent | ✓ |
| No — skip it for this pass | | |
| I'll describe another way | — | |

**User's choice:** Yes, both scripts get `--dry-run`.

---

## Swap mechanics (freeform, raised during a "Done" check)

**User's correction:** "revert should swap shadow - file instead of deleting and creating same shadow."

**Notes:** Claude had been assuming delete-shadow-then-write-new-shadow. The user clarified this must be a genuine two-way `mv` swap: the existing shadow file itself relocates (same content, same hash, no recompute) while the real file moves the other way. Captured as D-07 in CONTEXT.md.

---

## Name-vs-hash matching (freeform, raised during a second "Done" check)

**User's correction:** "the shadow has same name as the file + .txt so that scanning is most likely name matching. the hash content is to distinguish files with same name."

**Notes:** This corrected an implicit assumption carried over from `retain-dir-struct-3-find-sorted.zsh`'s blind hash-index-everything approach. The user clarified matching should be name-first (cheap, uses the shadow filename's already-encoded relative path), with hash reserved for disambiguating same-named candidates. Captured as D-03 in CONTEXT.md; this also refines (not replaces) the MultiTarget decision above — the "ambiguous match" case is now specifically "same name AND same hash found more than once."

---

## Verify — should hash be checked on a unique (non-colliding) name match too?

| Option | Description | Selected |
|--------|-------------|----------|
| Always verify hash, even on a unique name match | Safety-first — catches stale/wrong shadows | ✓ |
| Trust a unique name match, hash only for collisions | Faster, skips redundant hashing | |

**User's choice:** Always verify hash, even on a unique name match.
**Notes:** Captured as D-04 in CONTEXT.md; a mismatch is treated the same as an ambiguous/failed match (D-05).

---

## Claude's Discretion

- Whether this ships as one reversible script or two separate scripts (`revert` / `revert-revert`) — architecture choice deferred to planning, given the confirmed symmetry
- Real files in the target tree with no corresponding shadow anywhere — left untouched, out of scope
- Exact name-first search mechanism (e.g. `find -name` before hashing)
- Test coverage scope/fixtures (tracked test file required per project policy; minimum cases noted in CONTEXT.md)

## Deferred Ideas

None new — this phase itself is the realization of the Phase 1 deferred idea ("Reverse/undo command file for `retain-dir-struct-1.zsh`"), now expanded per this discussion.
