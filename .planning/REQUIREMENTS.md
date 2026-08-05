# Requirements: iswi-script

**Defined:** 2026-08-05
**Core Value:** Each script does its one job correctly and safely — these scripts move, rename, and reorganize real files (including on a remote MEGA store), so correctness matters more than feature breadth or polish.

## v1 Requirements

Requirements for the current bug-fix/consistency pass. Each maps to a topic-phase.

### Local Filesystem

- [x] **LOCALFS-01**: `retain-dir-struct-2-sorted.zsh` correctly matches files by hash — fix the subshell variable-scope bug where `shadow_map` (populated via process substitution) is unreadable in the `find | while` loop that looks it up, causing every lookup to silently fail
- [x] **LOCALFS-02**: `retain-dir-struct-3-find-sorted.zsh` correctly matches files by hash — fix the subshell variable-scope bug where `file_map` (populated in the parent shell) is unreadable in the `find | while` loop that looks it up
- [x] **LOCALFS-03**: `retain-dir-struct-1.zsh` uses consistent output commands (`print`, not a mix of `echo` and `print`)

### Manga

- [ ] **MANGA-01**: `number-pages.zsh` handles image-dimension detection failures explicitly (wrap `identify`/ImageMagick calls in error handling instead of failing silently on unreadable dimensions)

### Remote

- [ ] **REMOTE-01**: `rename-remote-files-1-match-remote.zsh` correctly matches remote files against local shadow data — fix the subshell variable-scope bug where `remote_map` (populated in the parent shell) is unreadable in the `find | while` loop that looks it up, causing every match to report "No Match"
- [ ] **REMOTE-02**: `rename-remote-files-1-match-remote.zsh` and `rename-remote-files-2-rename-local.zsh` fail fast with a clear error when required dependencies (`rclone`, `jq`) are missing, instead of failing cryptically mid-run
- [ ] **REMOTE-03**: `rename-remote-files-2-rename-local.zsh` validates that sourced shadow-file variables (`MATCHED_REMOTE_PATH`, `ORIGINAL_LOCAL_PATH`) are actually set before using them, instead of silently continuing with empty values
- [ ] **REMOTE-04**: Remote configuration (`REMOTE_NAME`, `REMOTE_PATH`) is no longer hardcoded in plaintext in `rename-remote-files-1-match-remote.zsh` — moved to an environment variable or a git-ignored config file

## v2 Requirements

Deferred — acknowledged as valuable but not part of the current bug-fix pass.

### Remote

- **REMOTE-05**: Dry-run/preview mode for `rename-remote-files-*.zsh` before files are actually moved or renamed
- **REMOTE-06**: Re-enable and expose the rate-limiting sleep between remote operations in `rename-remote-files-2-rename-local.zsh` as a configurable option, to avoid MEGA API throttling on large batches

### Local Filesystem

- **LOCALFS-04**: Broader input validation across local-filesys scripts (verify read/write access before processing, reject symlinks where appropriate)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Roadmap-driven feature growth beyond the current bug-fix scope | Topics are independent tools with no shared end goal; new capability ideas become separate future phases via `/gsd-phase`, not scope creep on this pass |
| GUI, packaging, or distribution | Single-user CLI tools run directly from this repo, never shipped to others |
| Parallelization / performance rework (e.g. GNU parallel, incremental hashing) | Not blocking current correctness work; revisit only if a script becomes a real bottleneck in practice |
| CI pipeline | Tests run locally on demand (reversed the earlier "no test suite" call during Phase 1 discussion) — but no CI service is being configured |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| LOCALFS-01 | Phase 1 | Complete |
| LOCALFS-02 | Phase 1 | Complete |
| LOCALFS-03 | Phase 1 | Complete |
| MANGA-01 | Phase 2 | Pending |
| REMOTE-01 | Phase 3 | Pending |
| REMOTE-02 | Phase 3 | Pending |
| REMOTE-03 | Phase 3 | Pending |
| REMOTE-04 | Phase 3 | Pending |

**Coverage:**

- v1 requirements: 8 total
- Mapped to phases: 8 (Phase 1: 3, Phase 2: 1, Phase 3: 4)
- Unmapped: 0 ✓

---
*Requirements defined: 2026-08-05*
*Last updated: 2026-08-05 after initial definition*
