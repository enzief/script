# Codebase Structure

**Analysis Date:** 2026-08-05

## Directory Layout

```
script/
├── manga/                                    # Manga page numbering utilities
│   └── number-pages.zsh                      # Rename images to sequential page numbers
│
├── local-filesys/                            # Local filesystem operations
│   ├── retain-dir-struct-1.zsh               # Stage 1: Create shadow map (hash-based)
│   ├── retain-dir-struct-2-sorted.zsh        # Stage 2: Sync shadow files to new structure
│   └── retain-dir-struct-3-find-sorted.zsh   # Stage 3: Map shadow files back to originals
│
├── remote/                                   # Remote file synchronization (MEGA)
│   ├── rename-remote-files-1-match-remote.zsh      # Stage 1: Match local to remote, create sync
│   └── rename-remote-files-2-rename-local.zsh      # Stage 2: Revert files, trigger renames
│
└── .planning/
    └── codebase/                             # Architecture documentation
        ├── ARCHITECTURE.md                   # System design and patterns
        └── STRUCTURE.md                      # This file
```

## Directory Purposes

**`manga/`:**
- Purpose: Manga image processing and sequential numbering
- Contains: zsh scripts for renaming image files in manga chapters
- Key files: `number-pages.zsh`

**`local-filesys/`:**
- Purpose: Local filesystem indexing, hashing, and reorganization workflows
- Contains: Three-stage pipeline for creating and maintaining shadow maps (hash-based file metadata)
- Key files: `retain-dir-struct-1.zsh` (index), `retain-dir-struct-2-sorted.zsh` (sync), `retain-dir-struct-3-find-sorted.zsh` (verify)

**`remote/`:**
- Purpose: Remote file synchronization with MEGA cloud storage
- Contains: Two-stage pipeline for matching, staging, and reverting files
- Key files: `rename-remote-files-1-match-remote.zsh` (match), `rename-remote-files-2-rename-local.zsh` (revert)

**`.planning/codebase/`:**
- Purpose: Architecture and structure documentation
- Contains: ARCHITECTURE.md, STRUCTURE.md
- Generated: By gsd-map-codebase agent
- Committed: Yes

## Key File Locations

**Entry Points:**
- `manga/number-pages.zsh`: Main manga numbering script
- `local-filesys/retain-dir-struct-1.zsh`: Local FS indexing start
- `remote/rename-remote-files-1-match-remote.zsh`: Remote sync start

**Configuration:**
- No dedicated config files; all scripts use command-line arguments
- Hardcoded config in `remote/rename-remote-files-1-match-remote.zsh` (lines 5-6): `REMOTE_NAME="mega"`, `REMOTE_PATH="devicesync/2019"`

**Core Logic:**
- Manga: `manga/number-pages.zsh` lines 79-145 (main algorithm: image dimension detection, page numbering, renaming)
- Local FS: `local-filesys/retain-dir-struct-1.zsh` lines 17-35 (main loop: find files, calculate hash, write shadow)
- Remote: `remote/rename-remote-files-1-match-remote.zsh` lines 24-70 (main loop: match by size, create shadow, move to sync)

**Utilities:**
- No dedicated utility scripts; all logic embedded in domain-specific scripts
- Helper functions: None (scripts are procedural, no function definitions)

## Naming Conventions

**Files:**
- Format: `<action>[-<variant>][-<descriptor>].zsh`
- Examples:
  - `number-pages.zsh` - Single action, no variants
  - `retain-dir-struct-1.zsh`, `retain-dir-struct-2-sorted.zsh`, `retain-dir-struct-3-find-sorted.zsh` - Numbered stages with optional descriptor
  - `rename-remote-files-1-match-remote.zsh`, `rename-remote-files-2-rename-local.zsh` - Numbered stages with descriptors
- Pattern: Lowercase, hyphen-separated, .zsh extension

**Directories:**
- Format: `<domain>/` (singular or plural noun)
- Examples: `manga/`, `local-filesys/`, `remote/`, `.planning/`
- Pattern: Lowercase, hyphen-separated for multi-word names

**Variables:**
- Input args: UPPERCASE with underscores (`SRCDIR`, `TGTDIR`, `LOCAL_SRC_ABS`, `REMOTE_NAME`)
- Options/flags: Lowercase with `opt_` prefix (`opt_s`, `opt_n`, `opt_h`)
- Temporary/internal: Lowercase with underscores (`rel_path`, `current_hash`, `shadow_map`)
- Arrays: Lowercase plural (`image_files`, `temp_files`, `orig_exts`, `all_keys`)
- Associative arrays: Lowercase with `_map` suffix (`is_double`, `shadow_map`, `remote_map`, `file_map`)

**Functions:**
- No named functions defined; all scripts are procedural
- Helper utilities: Defined inline as needed (e.g., `get_chap_num()` in `list-missing-pages.zsh`)

## Where to Add New Code

**New Feature (Domain-Specific):**
1. Create new `.zsh` file in appropriate directory:
   - Manga-related: `manga/<action>.zsh`
   - Local FS-related: `local-filesys/<action>.zsh`
   - Remote-related: `remote/<action>.zsh`
2. Follow naming convention: `<action>[-<variant>][-<descriptor>].zsh`
3. Include usage help block at top (see `number-pages.zsh` lines 7-44 for pattern)
4. Add argument parsing via `zparseopts` (see `number-pages.zsh` lines 4-5)

**New Processing Pipeline:**
1. Create Stage 1 script: `<domain>/step-1-<descriptor>.zsh` (output metadata/staging)
2. Create Stage 2 script: `<domain>/step-2-<descriptor>.zsh` (perform operations using Stage 1 output)
3. Optionally Stage 3: `<domain>/step-3-<descriptor>.zsh` (verification/reversal)

**Utilities & Helpers:**
1. For file I/O helpers: Add as function definition at top of scripts (no separate utility file needed)
2. For common patterns: Document in ARCHITECTURE.md for consistency; copy pattern into new scripts
3. No shared library approach yet; scripts are currently independent

**Testing:**
- No test directory exists
- To add tests: Create `tests/` directory at repo root, add `test-*.zsh` scripts
- Follow pattern: Source the target script, set up test fixtures, run functions, verify output

## Special Directories

**`.git/`:**
- Purpose: Git version control
- Generated: Yes (git init)
- Committed: Yes

**`.planning/`:**
- Purpose: Project planning and documentation (created by gsd orchestrator)
- Contains: Subdirectories for milestones, phases, and codebase analysis
- Generated: Yes (by gsd tools)
- Committed: Yes (with exceptions for sensitive planning files)

**`.planning/codebase/`:**
- Purpose: Architecture and structure documentation for codebase
- Contains: ARCHITECTURE.md, STRUCTURE.md, STACK.md, INTEGRATIONS.md, CONVENTIONS.md, TESTING.md, CONCERNS.md (as generated)
- Generated: Yes (by gsd-map-codebase agent)
- Committed: Yes

## File Groupings by Purpose

**Metadata Creation (Stage 1 scripts):**
- `local-filesys/retain-dir-struct-1.zsh` - Creates shadow map from source
- `remote/rename-remote-files-1-match-remote.zsh` - Creates shadow map and sync structure

**Metadata Application (Stage 2+ scripts):**
- `local-filesys/retain-dir-struct-2-sorted.zsh` - Uses shadow map to sync new structure
- `local-filesys/retain-dir-struct-3-find-sorted.zsh` - Uses shadow map to verify/map files
- `remote/rename-remote-files-2-rename-local.zsh` - Uses shadow map to revert files

**Standalone Operations:**
- `manga/number-pages.zsh` - Complete operation (no multi-stage dependency)
- `local-filesys/list-missing-pages.zsh` - Comparison utility (no dependencies)

## Dependencies & Import Relationships

**No imports or sources between scripts** - each script is standalone and self-contained.

**External dependencies:**
- `number-pages.zsh` requires: `identify` (ImageMagick)
- `retain-dir-struct-*.zsh` require: `sha256sum`, `find`, standard zsh
- `list-missing-pages.zsh` requires: `grep`, standard zsh
- `rename-remote-files-1-*.zsh` requires: `rclone`, `jq`, `stat`
- `rename-remote-files-2-*.zsh` requires: standard zsh

**Shadow file format** (created by Stage 1, consumed by Stage 2+):
- Location: `<shadow_dir>/<relative_path>.txt`
- Format (local FS): First line contains hash from `sha256sum` output: `<hash> <path>`
- Format (remote): Contains shell variables: `ORIGINAL_LOCAL_PATH=...`, `MATCHED_REMOTE_PATH=...`, `FILE_SIZE_BYTES=...`, `PROCESSED_AT=...`

---

*Structure analysis: 2026-08-05*
