# Roadmap: iswi-script

## Overview

A bug-fix/consistency pass across three independent topic folders of personal zsh scripts. There is no build-toward-done arc and no dependency ordering between phases — each phase covers one topic folder (Local Filesystem, Manga, Remote) and is "done" when its existing scripts work reliably for their current use cases.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: Local Filesystem** - Fix subshell variable-scope bugs and standardize output commands in the `local-filesys` scripts (completed 2026-08-05)
- [x] **Phase 2: Manga** - Add explicit error handling around image-dimension detection in the `manga` scripts (completed 2026-08-06)
- [ ] **Phase 3: Remote** - Fix the remote matching bug, add dependency checks, validate shadow-file variables, and remove hardcoded config from the `remote` scripts

## Phase Details

### Phase 1: Local Filesystem

**Goal**: `local-filesys` scripts behave correctly and consistently
**Mode:** mvp
**Depends on**: Nothing (independent topic phase)
**Requirements**: LOCALFS-01, LOCALFS-02, LOCALFS-03
**Success Criteria** (what must be TRUE):

  1. `retain-dir-struct-2-sorted.zsh` correctly finds hash matches via `shadow_map` instead of every lookup silently returning empty
  2. `retain-dir-struct-3-find-sorted.zsh` correctly finds hash matches via `file_map` instead of every lookup silently returning empty
  3. `retain-dir-struct-1.zsh` uses `print` consistently for all output, with no remaining `echo` calls

**Plans**: 2/2 plans executed
**Wave 1**

- [x] 01-01-PLAN.md — `retain-dir-struct-2-sorted.zsh` end-to-end: process-substitution loops, `print`-only output, `--dry-run` flag, plus the tracked regression test

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md — `retain-dir-struct-3-find-sorted.zsh` and `retain-dir-struct-1.zsh`: process-substitution lookup loop, `print`-only output, stderr for errors, test extended to all three scripts

> **Planning note (2026-08-05):** the subshell variable-scope premise behind success criteria 1 and 2 was empirically disproven during planning — zsh runs the last element of a pipeline in the current shell, so both lookups already work today. Criteria 1 and 2 are already TRUE before any code change; the plans deliver the loop conversion as hardening. See `01-01-PLAN.md` objective for the evidence. Criteria wording left unchanged pending developer review.

### Phase 2: Manga

**Goal**: `manga` scripts remain reliable and handle image-dimension detection failures explicitly
**Mode:** mvp
**Depends on**: Nothing (independent topic phase)
**Requirements**: MANGA-01
**Success Criteria** (what must be TRUE):

  1. `number-pages.zsh` reports a clear error when `identify`/ImageMagick fails to read an image's dimensions, instead of failing silently
  2. `number-pages.zsh` still correctly renumbers pages for valid images (no regression from the added error handling)

**Plans**: 1 plan
**Wave 1**

- [x] 02-01-PLAN.md — `number-pages.zsh` dimension-failure visibility end-to-end: `Error:` prefix, `dim_failures` counter in the summary line, plus the first tracked test for `dev/manga/` (hermetic, stub `identify`, no ImageMagick required)

> **Planning note (2026-08-06):** ImageMagick is not installed on this machine (`identify`, `convert`, `magick` all absent), and `number-pages.zsh` exits 1 at its dependency check without it. The phase test therefore supplies its own `identify` stub on `PATH` rather than depending on a real ImageMagick install — prototyped against the unmodified script during planning. Consequence: the test proves the script's behavior given `identify`'s output contract, not what real ImageMagick emits for a corrupt file. That gap is in-scope-by-omission per `02-CONTEXT.md` D-03, which explicitly declines to check `identify`'s exit code this phase.

### Phase 3: Remote

**Goal**: `remote` scripts behave correctly and safely when matching and renaming files against the MEGA remote
**Mode:** mvp
**Depends on**: Nothing (independent topic phase)
**Requirements**: REMOTE-01, REMOTE-02, REMOTE-03, REMOTE-04
**Success Criteria** (what must be TRUE):

  1. `rename-remote-files-1-match-remote.zsh` correctly reports matches via `remote_map` instead of every file reporting "No Match"
  2. Both remote scripts fail fast with a clear error message when `rclone` or `jq` is missing, instead of failing cryptically mid-run
  3. `rename-remote-files-2-rename-local.zsh` validates that `MATCHED_REMOTE_PATH` and `ORIGINAL_LOCAL_PATH` are set before using them, instead of silently continuing with empty values
  4. Remote name/path configuration is read from an environment variable or a git-ignored config file, with no hardcoded plaintext remote config left in `rename-remote-files-1-match-remote.zsh`

**Plans**: 2 plans
**Wave 1**

- [ ] 03-01-PLAN.md — `rename-remote-files-1-match-remote.zsh` end-to-end: the first tracked test for `dev/remote/` (hermetic round-trip, stub `rclone`, real `jq`), `rclone`/`jq` preflight checks, required `REMOTE_NAME`/`REMOTE_PATH` environment config replacing the hardcoded literals, and the process-substitution match loop

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 03-02-PLAN.md — `rename-remote-files-2-rename-local.zsh`: per-iteration reset of the sourced variables plus non-empty validation with skip-and-continue, and the reversion path's empty-input, missing-sync-file, and repeat-run coverage

> **Planning note (2026-08-07):** two findings from planning, both needing a developer look.
> **(1)** Success criterion 1's premise was empirically disproven, exactly as in Phase 1. zsh runs
> the last element of a pipeline in the current shell, so `remote_map` is readable — and writable —
> inside the `find | while` loop. The unmodified script was run against a fixture tree with a
> stubbed `rclone` and printed `Match Found` for both seeded sizes, wrote both shadow files, and
> moved both files; script 2 then reverted them. Criterion 1 is already TRUE before any code
> change; plan 03-01 ships the loop conversion as hardening and the regression test as the real
> deliverable. See the `03-01-PLAN.md` objective for the evidence. Criterion wording left unchanged
> pending developer review.
> **(2)** Success criterion 2 says *both* remote scripts must fail fast on a missing `rclone` or
> `jq`, but `rename-remote-files-2-rename-local.zsh` invokes neither tool anywhere in its body. Per
> `03-CONTEXT.md` D-03 the checks are added to script 1 only, reading REMOTE-02 as "each script
> checks what it actually uses". Criterion 2 as written cannot be satisfied literally without
> adding a dead check.
> **(3)** Planning also found a defect REMOTE-03's wording does not cover: because the loop body
> shares one variable scope, a malformed shadow file inherits the *previous* file's
> `ORIGINAL_LOCAL_PATH` and `MATCHED_REMOTE_PATH`, so a bare presence check would pass and the
> script would move the wrong file. Plan 03-02 resets both variables per iteration, which is what
> makes the requested validation non-vacuous.

## Backlog

### Phase 999.1: local-filesys revert tool — move real files to match shadow map (BACKLOG)

**Goal:** [Captured for future planning]
**Requirements:** TBD
**Plans:** 0 plans

Plans:

- [ ] TBD (promote with /gsd-review-backlog when ready)

Captured 2026-08-05 during Phase 01 discussion: the `retain-dir-struct-*.zsh` pipeline (1/2/3) only tracks file identity via a shadow hash tree — none of them ever `mv` the real data files. Script 1 creates the shadow map, script 2 re-syncs the shadow tree after a manual reorganization, script 3 is a read-only lookup. There's no tool that goes the other direction: given the shadow map, physically move/rename the real files to match wherever their shadow pointer says they should be. `dev/remote/` has an equivalent for its own pipeline (`rename-remote-files-2-rename-local.zsh` actually moves files); `local-filesys` does not. `CONCERNS.md` already flags this gap indirectly ("What's not tested: end-to-end workflows (e.g., create shadow → reorganize → sync → revert)" — the "revert" step has no implementation). Candidate name: `retain-dir-struct-4-revert.zsh`.

## Progress

**Execution Order:**
Phases have no dependency ordering — they are independent topic-phases and may be executed in any order. Default numeric order: 1 → 2 → 3.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Local Filesystem | 2/2 | Complete    | 2026-08-05 |
| 2. Manga | 1/1 | Complete    | 2026-08-06 |
| 3. Remote | 0/2 | Not started | - |
