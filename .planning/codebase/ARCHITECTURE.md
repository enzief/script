<!-- refreshed: 2026-08-05 -->
# Architecture

**Analysis Date:** 2026-08-05

## System Overview

```text
┌──────────────────────────────────────────────────────────────────────────┐
│                           Entry Points                                    │
│  Manga Renaming  │  Filesystem Indexing  │  Remote Sync Management       │
│ `dev/manga/*`    │  `dev/local-filesys/*` │  `dev/remote/*`              │
└────────┬─────────┴───────────┬────────────┴─────────────┬────────────────┘
         │                     │                          │
         ▼                     ▼                          ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                        Processing Layer                                   │
│  • File scanning & validation (find, stat, identify)                     │
│  • Metadata extraction (hash calculation, dimension detection)           │
│  • Pattern matching (hash-based, size-based lookups)                     │
│  • Directory traversal with state tracking                               │
└────────┬─────────┬──────────────────┬───────────────┬────────────────────┘
         │         │                  │               │
         ▼         ▼                  ▼               ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                    Metadata & Storage Layer                               │
│  Shadow Maps (directory mirroring)  │  Sync Directory Structure          │
│  `.txt` pointer files                │  Reorganized real files            │
│  Hash/Remote path lookups            │  Matches remote structure          │
└──────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                        Output / External                                  │
│  Filesystem operations  │  MEGA remote (via rclone)  │  Local files      │
└──────────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Manga Numbering | Rename image files to sequential page numbers with double-page support | `dev/manga/number-pages.zsh` |
| Local FS Indexing | Create hash-based shadow maps of directory structures | `dev/local-filesys/retain-dir-struct-1.zsh` |
| Shadow Synchronization | Sync shadow files to new directory structures by hash matching | `dev/local-filesys/retain-dir-struct-2-sorted.zsh` |
| File Mapping | Map shadow files back to original files using hash lookups | `dev/local-filesys/retain-dir-struct-3-find-sorted.zsh` |
| Remote Matching | Match local files to remote files by size and create sync structure | `dev/remote/rename-remote-files-1-match-remote.zsh` |
| Remote Reversion | Move files back from sync folder to original locations, triggering remote renames | `dev/remote/rename-remote-files-2-rename-local.zsh` |

## Pattern Overview

**Overall:** Two-stage pipeline with metadata-driven file operations

**Key Characteristics:**
- **Declarative metadata**: All file operations tracked via shadow files (`.txt` pointer files)
- **Multi-pass processing**: Stage 1 creates metadata, Stage 2 performs operations using metadata
- **Safe rename**: Temporary staging directories prevent collision during bulk operations
- **Hash/size-based matching**: Abstract away filename dependencies; match by content signature

## Layers

**Entry Point Layer:**
- Purpose: Parse arguments, validate inputs, establish configuration
- Location: Top 50-100 lines of each script
- Contains: Argument parsing (zparseopts), usage help, environment setup
- Depends on: zsh builtins, zsh/zutil module
- Used by: All downstream operations

**Validation & Discovery Layer:**
- Purpose: Scan filesystem, verify dependencies, collect files
- Location: Middle sections of scripts (line 50-150 typically)
- Contains: `find` commands, `command -v` checks for external tools (identify, jq, rclone), glob patterns
- Depends on: External commands (identify for ImageMagick, rclone, jq)
- Used by: Processing layer

**Processing & Matching Layer:**
- Purpose: Calculate metadata, match files, build lookup tables
- Location: Core algorithm sections (line 80-180 typically)
- Contains: Associative arrays (typeset -A), hash/size calculations, while read loops
- Depends on: sha256sum, stat, identify, jq
- Used by: Metadata generation and operation execution

**Metadata & Output Layer:**
- Purpose: Write shadow files, move files to target locations
- Location: Final sections of scripts (line 100-220 typically)
- Contains: `mkdir -p`, `mv`, file writes with `>` redirection
- Depends on: Filesystem operations
- Used by: External consumers (subsequent pipeline stages)

## Data Flow

### Local Filesystem Indexing (retain-dir-struct-1)

1. User invokes script with source and target directories (`retain-dir-struct-1.zsh <src> <tgt>`)
2. Script walks all files in source using `find "$SRCDIR" -type f`
3. For each file, calculate SHA-256 hash via `sha256sum`
4. Create parallel directory structure in target
5. Write `.txt` shadow file containing hash: `<hash> <original_path>`
6. Result: Shadow directory mirrors source structure with `.txt` files containing hashes

**State Management:** Hashes stored in `.txt` files; directory structure retained exactly; no files moved.

### Shadow File Synchronization (retain-dir-struct-2)

1. User reorganizes data in reorganized directory
2. Script indexes old shadow files, building map: `[hash] -> [path_to_shadow_file]`
3. For each file in reorganized directory, calculate SHA-256
4. Look up hash in shadow map; if found, copy original shadow file to new location mirroring reorganized structure
5. Result: New shadow structure matches reorganized data layout

**State Management:** Shadow files preserve original metadata; matched files marked as "Matched & Placed"; unmatched files logged as "No shadow found".

### File Mapping via Shadows (retain-dir-struct-3)

1. User provides shadow directory and original data directory
2. Script builds index: `[hash] -> [absolute_path]` by hashing all files in data directory
3. For each `.txt` file in shadow directory, extract stored hash
4. Look up hash in file map; if found, print mapping: `SHADOW: <path> -> REAL: <file_path>`
5. Result: Mappings displayed for user review; no files moved

**State Management:** Read-only operation; output is diagnostic mappings.

### Remote File Matching (rename-remote-files-1)

1. User runs script with local source, shadow output, and sync output directories
2. Script fetches remote file manifest via `rclone lsjson --recursive mega:devicesync/2019`
3. Builds map: `[file_size] -> [remote_path]` from JSON
4. For each local file:
   - Get file size via `stat -c %s`
   - Look up size in remote map
   - If match found: create shadow `.txt` with metadata (`ORIGINAL_LOCAL_PATH`, `MATCHED_REMOTE_PATH`, `FILE_SIZE_BYTES`, `PROCESSED_AT`)
   - Move file to sync directory using remote structure: `$SYNC_DIR/$remote_rel_path`
5. Result: Shadow map created; files staged in sync directory mirroring remote structure

**State Management:** Original local paths preserved in shadow metadata; real files moved to sync staging.

### Remote File Reversion (rename-remote-files-2)

1. User runs script with shadow and sync directories (after MEGA sync confirms changes)
2. Script walks all `.txt` shadow files
3. For each shadow file: `source` it to load variables (`ORIGINAL_LOCAL_PATH`, `MATCHED_REMOTE_PATH`)
4. Calculate current location in sync: `$SYNC_DIR/$MATCHED_REMOTE_PATH`
5. If file exists: recreate original directory structure and move file back: `mv $current_sync_loc $ORIGINAL_LOCAL_PATH`
6. Result: Files reverted to original locations; MEGA detects rename events

**State Management:** File moves trigger rename events on MEGA; original directory structure recreated; sync directory becomes empty.

## Key Abstractions

**Shadow Map:**
- Purpose: Create a parallel directory structure with metadata pointers instead of real files
- Examples: `dev/local-filesys/retain-dir-struct-1.zsh`, `dev/remote/rename-remote-files-1-match-remote.zsh`
- Pattern: For each file in source, create `.txt` file at corresponding path in shadow directory containing file hash or remote metadata
- Implementation: `echo "hash content" > "$TGTDIR/${relpath}.txt"`

**Matching Lookup Table:**
- Purpose: Enable O(1) file matching without repeated I/O operations
- Examples: `remote_map[$size]`, `file_map[$hash]`, `shadow_map[$hash]`
- Pattern: Associative arrays (typeset -A) indexed by content signature (hash or size)
- Implementation: `while read -r s p; do remote_map[$s]="$p"; done < <(...)`

**Two-Stage Rename Pipeline:**
- Purpose: Avoid filename collisions during bulk renames
- Examples: `number-pages.zsh` (stage 1: temp files; stage 2: final names)
- Pattern: Stage 1 renames to temporary files (`.numbering_tmp_*`), Stage 2 renames to final names
- Implementation: 
  ```zsh
  # Stage 1: move real files to temp names
  mv "${image_files[$i]}" ".numbering_tmp_${i}.${ext}"
  # Stage 2: move temp files to final names
  mv ".numbering_tmp_${i}.${ext}" "${dir}/${new_name}"
  ```

**Parallel Directory Mirroring:**
- Purpose: Preserve filesystem structure while reorganizing or staging files
- Examples: `dev/local-filesys/retain-dir-struct-2-sorted.zsh` creates new shadow structure matching reorganized data
- Pattern: Extract relative path from source, apply to target: `target_path="${target_root}/${relpath}"`
- Implementation: `mkdir -p "$(dirname "$target_shadow_path")"` then `cp ... "$target_shadow_path"`

## Entry Points

**`dev/manga/number-pages.zsh`:**
- Location: `/home/enzief/work/iswi/script/dev/manga/number-pages.zsh`
- Triggers: Manual invocation with directory and chapter arguments
- Responsibilities: Parse image files, detect double-page spreads, calculate sequential page numbers, rename files with smart padding

**`dev/local-filesys/retain-dir-struct-1.zsh`:**
- Location: `/home/enzief/work/iswi/script/dev/local-filesys/retain-dir-struct-1.zsh`
- Triggers: Manual invocation with source and target directory paths
- Responsibilities: Initial shadow map creation; walk filesystem and hash all files

**`dev/local-filesys/retain-dir-struct-2-sorted.zsh`:**
- Location: `/home/enzief/work/iswi/script/dev/local-filesys/retain-dir-struct-2-sorted.zsh`
- Triggers: Manual invocation after reorganizing data; requires existing shadow from retain-dir-struct-1
- Responsibilities: Sync shadow files to new directory structure; match by hash; preserve metadata

**`dev/local-filesys/retain-dir-struct-3-find-sorted.zsh`:**
- Location: `/home/enzief/work/iswi/script/dev/local-filesys/retain-dir-struct-3-find-sorted.zsh`
- Triggers: Manual invocation with shadow directory and original data directory
- Responsibilities: Read-only diagnostic; map shadow files back to original files; output mappings for verification

**`dev/remote/rename-remote-files-1-match-remote.zsh`:**
- Location: `/home/enzief/work/iswi/script/dev/remote/rename-remote-files-1-match-remote.zsh`
- Triggers: Manual invocation with local source, shadow output, and sync output directories
- Responsibilities: Fetch remote manifest, match local files by size, create shadow metadata, stage files in sync directory

**`dev/remote/rename-remote-files-2-rename-local.zsh`:**
- Location: `/home/enzief/work/iswi/script/dev/remote/rename-remote-files-2-rename-local.zsh`
- Triggers: Manual invocation after MEGA sync confirms changes; requires shadow from rename-remote-files-1
- Responsibilities: Revert files from sync to original locations; trigger rename events on remote

## Architectural Constraints

- **Language:** Pure zsh; no external scripting languages (Python, Perl, Ruby) used
- **Shell options:** Some scripts enable `setopt extended_glob` for case-insensitive globbing (`**/*.(#i)jpg`)
- **External dependencies:**
  - `identify` (ImageMagick) - required by `number-pages.zsh` for image dimension detection
  - `rclone` - required by `rename-remote-files-1-match-remote.zsh` for MEGA interaction
  - `jq` - required by `rename-remote-files-1-match-remote.zsh` for JSON parsing
  - `sha256sum`, `stat`, `find`, `mv`, `mkdir` - standard POSIX utilities
- **Hardcoded values:** Remote name "mega" and path "devicesync/2019" hardcoded in `rename-remote-files-1-match-remote.zsh` (lines 5-6)
- **Error handling:** Scripts exit on missing directories, invalid arguments, or failed commands; no recovery/retry logic
- **Parallelization:** No parallel execution; all operations are sequential
- **Temporary files:** `number-pages.zsh` uses `.numbering_tmp_*` prefix for staging; not cleaned up if interrupted
- **File safety:** Uses `-print0` with `while IFS= read -r -d ''` for safe handling of filenames with spaces

## Anti-Patterns

### Hardcoded Remote Configuration

**What happens:** Remote name "mega" and path "devicesync/2019" are hardcoded in `dev/remote/rename-remote-files-1-match-remote.zsh` (lines 5-6), making the script non-configurable.

**Why it's wrong:** Different users or projects need different remote names and paths. Hardcoding forces script modification or script duplication.

**Do this instead:** Add `-r remote_name` and `-p remote_path` options to argument parsing; fall back to defaults if unspecified. See `number-pages.zsh` (lines 4-5) for zparseopts example.

### Size-Based Matching for Remote Files

**What happens:** `dev/remote/rename-remote-files-1-match-remote.zsh` matches local files to remote by file size alone (line 43: `remote_map[$local_size]`). The comment acknowledges risk: "If you have many files with identical sizes, this could lead to collisions."

**Why it's wrong:** Collisions cause incorrect file mappings, leading to renamed files being reverted to wrong locations. No collision detection or fallback exists.

**Do this instead:** Fall back to hash-based matching if size collisions detected. Example: build secondary lookup by hash; if multiple files have same size, compare hashes before matching.

### No Dependency Validation

**What happens:** `dev/remote/rename-remote-files-1-match-remote.zsh` requires `rclone` and `jq` (lines 22, 33) but doesn't validate they exist before using them.

**Why it's wrong:** Scripts fail with confusing errors (command not found) rather than clear dependency messages.

**Do this instead:** Add check near top of script:
```zsh
command -v rclone &>/dev/null || { echo "Error: rclone required but not found" >&2; exit 1; }
command -v jq &>/dev/null || { echo "Error: jq required but not found" >&2; exit 1; }
```
See `number-pages.zsh` (lines 67-70) for example pattern.

### Unhandled Temporary File Cleanup

**What happens:** `number-pages.zsh` creates `.numbering_tmp_*` files as staging (line 111) but doesn't remove them if script is interrupted or fails during stage 2.

**Why it's wrong:** Temporary files accumulate on interrupted runs; operator must manually clean them up; re-running script fails because temp files already exist.

**Do this instead:** Add trap handler at script start: `trap 'rm -f "${dir}/.numbering_tmp_*"; exit' INT TERM`. This cleans up if interrupted.

### Silent Collisions in Shadow Mapping

**What happens:** In `retain-dir-struct-2-sorted.zsh` (line 44), if multiple files have identical hashes, the shadow_map only stores the last one: `shadow_map[$current_hash]="$shadow_file"` overwrites previous entries.

**Why it's wrong:** Early files with colliding hashes get no match; only the last collision is preserved.

**Do this instead:** Store arrays instead of scalars: `shadow_map[$hash]+=("$shadow_file")`, then handle multiple matches in lookup.

## Error Handling

**Strategy:** Fail-fast with status codes; errors write to stderr; no recovery or retry.

**Patterns:**
- Argument validation: Exit 1 if `[[ $# -ne N ]]` (e.g., `retain-dir-struct-1.zsh` line 4)
- Directory validation: `[[ ! -d "$DIR" ]] && { echo "Error: ..." >&2; exit 1; }` (e.g., `retain-dir-struct-3-find-sorted.zsh` lines 13-14)
- Dependency checks: `command -v tool &>/dev/null || { echo "Error: ..." >&2; exit 1; }` (e.g., `number-pages.zsh` lines 67-70)
- File operation errors: `mv ... || { echo "Error: ..." >&2; exit 1; }` (e.g., `number-pages.zsh` line 112)
- Numeric validation: `[[ "$var" =~ '^[0-9]+$' ]] || { echo "Error: ..." >&2; exit 1; }` (e.g., `number-pages.zsh` lines 51-54)

## Cross-Cutting Concerns

**Logging:** All scripts log progress to stdout; some log warnings to stderr. No structured logging format; messages use natural language.
- Progress: `echo "Processing: $file"`
- Warnings: `echo "Warning: ..." >&2`
- Errors: `echo "Error: ..." >&2`

**Validation:** Input validation happens at script start (argument count, directory existence, numeric ranges). No runtime validation of file contents or metadata integrity.

**Authentication:** Remote operations in `rename-remote-files-*.zsh` assume `rclone` is configured with MEGA credentials; no in-script auth mechanism.

---

*Architecture analysis: 2026-08-05*
