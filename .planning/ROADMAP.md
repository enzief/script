# Roadmap: iswi-script

## Overview

A bug-fix/consistency pass across three independent topic folders of personal zsh scripts. There is no build-toward-done arc and no dependency ordering between phases — each phase covers one topic folder (Local Filesystem, Manga, Remote) and is "done" when its existing scripts work reliably for their current use cases.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 1: Local Filesystem** - Fix subshell variable-scope bugs and standardize output commands in the `local-filesys` scripts
- [ ] **Phase 2: Manga** - Add explicit error handling around image-dimension detection in the `manga` scripts
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

**Plans**: TBD

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

**Plans**: TBD

## Progress

**Execution Order:**
Phases have no dependency ordering — they are independent topic-phases and may be executed in any order. Default numeric order: 1 → 2 → 3.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Local Filesystem | 2/2 | In Progress|  |
| 2. Manga | 0/TBD | Not started | - |
| 3. Remote | 0/TBD | Not started | - |
