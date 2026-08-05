# iswi-script

## What This Is

A personal collection of independent zsh quality-of-life scripts, organized by topic of interest (currently: `local-filesys`, `manga`, `remote`). Each script solves one small file-management problem — directory-structure retention, manga page numbering, missing-page detection, remote (MEGA via rclone) file renaming. There is no product arc: scripts get added whenever a new need comes up, on no particular schedule.

## Core Value

Each script does its one job correctly and safely — these scripts move, rename, and reorganize real files (including on a remote MEGA store), so correctness matters more than feature breadth or polish.

## Requirements

### Validated

- ✓ Directory-structure retention/reorganization for local files (3 variants: basic, sorted, find-based) — existing
- ✓ Missing manga page detection by comparing two chapter/version directories — existing
- ✓ Sequential manga page renumbering with chapter/suffix support — existing
- ✓ Remote (MEGA via rclone) file matching and renaming to mirror local structure (2-step: match, then rename) — existing
- ✓ `local-filesys` scripts behave correctly and consistently — Phase 01 (process-substitution loops replacing subshell-fragile pipes, `print -r --` output standardization across all three scripts, `--dry-run` preview on `retain-dir-struct-2-sorted.zsh`, 29-assertion regression test)

### Active

- [ ] `manga` scripts remain reliable and get usability polish (explicit error handling around `identify`/ImageMagick calls)
- [ ] `remote` scripts behave correctly and safely (fix the subshell scope bug in `rename-remote-files-1-match-remote.zsh` that makes matching always fail; add `command -v` checks for `rclone`/`jq`; validate sourced shadow-file variables before use in `rename-remote-files-2-rename-local.zsh`; move hardcoded remote name/path out of plaintext)
- [ ] New topics/scripts get added ad hoc as new needs arise (open-ended — no fixed set)

### Out of Scope

- A unifying roadmap or MVP arc across topics — scripts are independent tools with no shared end goal, each topic-phase just needs to reach "works reliably"
- GUI, packaging, or distribution — single-user CLI tools run directly from this repo, not shipped to others
- CI pipeline — tests run locally on demand, not on every push; no CI service configured

## Context

- Runs on the user's personal Linux workstation (zsh shell), used for managing manga collections and syncing/reorganizing files between local storage and a MEGA remote (via `rclone`).
- Codebase already mapped in `.planning/codebase/` (7 docs). `CONCERNS.md` is the key input here — it flags 3 real subshell variable-scope bugs (lookups that silently return empty because an associative array is populated in one subshell and read in another), missing dependency checks (`rclone`, `jq`, `identify`), a hardcoded remote path/name, and zero test coverage across all scripts.
- No package manager or dependency manifest — dependencies (`rclone`, `jq`, ImageMagick) are assumed present on the host, not declared.

## Constraints

- **Tech stack**: zsh only, no new languages/runtimes — matches the existing scripts and the user's environment
- **Process**: Lightweight otherwise — fix real bugs and rough edges, no speculative abstraction beyond what's needed
- **Testing**: Bug fixes get a tracked test file (e.g. bats) validating the fix, committed to the repo — reverses the initial "no test suite" call; the local-filesys subshell bugs went unnoticed for a long time with no way to catch a regression
- **Scope per phase**: Each topic-phase is "done" when its existing scripts work reliably for their current use cases — not when new capabilities are added

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| One phase per topic folder, no dependency ordering between phases | Scripts are unrelated tools grouped only by subject area; there's no natural build sequence | Phase 01 followed this — independent from Phase 02/03 |
| Existing scripts marked Validated, but their bugs are in-scope Active work | User wants correctness/consistency/usability fixes now, not just documentation of what exists | Phase 01: the assumed subshell root cause was actually a misdiagnosis (zsh runs the last pipeline element in the current shell, unlike bash), so the fix shipped as hardening; code review then found and fixed 2 real bugs the original diagnosis missed (silent false-success on a missing source dir, `--dry-run` still writing to disk) |
| New topics added later via `/gsd-phase`, not pre-planned | User doesn't know future topics yet — they'll emerge organically | — Pending |
| Reversed: bug fixes now get a tracked test suite (project-wide) | Decided during Phase 1 discussion — subshell bugs went undetected for a long time; a tracked test file catches regressions without needing full CI | Delivered in Phase 01: 29-assertion `dev/local-filesys/tests/test-retain-dir-struct.zsh` covering all three scripts |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-08-05 after Phase 01*
