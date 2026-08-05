<!-- GSD:project-start source:PROJECT.md -->

## Project

**iswi-script**

A personal collection of independent zsh quality-of-life scripts, organized by topic of interest (currently: `local-filesys`, `manga`, `remote`). Each script solves one small file-management problem — directory-structure retention, manga page numbering, missing-page detection, remote (MEGA via rclone) file renaming. There is no product arc: scripts get added whenever a new need comes up, on no particular schedule.

**Core Value:** Each script does its one job correctly and safely — these scripts move, rename, and reorganize real files (including on a remote MEGA store), so correctness matters more than feature breadth or polish.

### Constraints

- **Tech stack**: zsh only, no new languages/runtimes — matches the existing scripts and the user's environment
- **Process**: Lightweight — fix real bugs and rough edges, no speculative abstraction, no test suite unless a specific script proves too risky to change blind
- **Scope per phase**: Each topic-phase is "done" when its existing scripts work reliably for their current use cases — not when new capabilities are added

<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->

## Technology Stack

## Languages

- Shell (Zsh) - All scripts are zsh executables with shebang `#!/bin/zsh`

## Runtime

- Zsh shell (5.x series) as primary interpreter
- Linux kernel (implied by grep `-c` and stat `-c` flags, find `-print0`)
- None (pure shell, no package manager)
- Lockfile: Not applicable

## Frameworks

- No frameworks; pure shell scripting utilities
- Git (version control, referenced in `.git` directory)

## Key Dependencies

- `find` (3.4+) - Recursive file enumeration (`find -type f -print0`)
- `sha256sum` (GNU coreutils) - Cryptographic hashing for file verification
- `stat` (GNU coreutils) - File size retrieval and metadata
- `rclone` (remote file sync) - Cloud storage abstraction layer for MEGA integration (`rclone lsjson`, `rclone` remote named "mega")
- `jq` (JSON processor) - JSON parsing for `rclone lsjson` output
- `ImageMagick` (identify command) - Image dimension detection in `dev/manga/number-pages.zsh`
- `convert` (ImageMagick) - Image rotation utility in `dev/local-filesys/rotate`
- `grep` (pattern matching, with Perl regex via `-oP` flag)
- `awk` (text field extraction)
- `date` (timestamp generation)
- `realpath` (absolute path resolution)
- `mkdir`, `mv`, `cp`, `awk` (standard file operations)

## Configuration

- rclone remote "mega" with path "devicesync/2019" configured in rclone config (referenced in `dev/remote/rename-remote-files-1-match-remote.zsh`)
- No `.env` files or environment variable configuration detected
- MEGA sync folder path passed as runtime argument to scripts
- No build configuration files detected (package.json, Makefile, cargo.toml, etc.)

## Platform Requirements

- Linux system with GNU coreutils (find, sha256sum, stat, grep, awk, date)
- Zsh interpreter installed and available in PATH
- rclone installed and configured with MEGA remote
- ImageMagick installed (identify, convert commands)
- jq JSON processor installed
- MegaSync desktop application running (for file synchronization at OS level)
- Linux filesystem (uses `-c` flag with stat, `-print0` with find — GNU extensions)
- Synchronized MEGA folder (requires MegaSync client running)
- Image files: JPG, JPEG, PNG, WebP, GIF, BMP, TIFF, AVIF

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

## Language & Shell

- ZSH shell script (all files)
- No compiled code, no interpreted languages (Python, JS, etc.)

## Naming Patterns

- Format: `kebab-case.zsh`
- Examples: `number-pages.zsh`, `list-missing-pages.zsh`, `retain-dir-struct-1.zsh`
- Convention: Descriptive action verbs with hyphens separating words
- Format: `snake_case`
- Example: `get_chap_num` in `list-missing-pages.zsh`
- Convention: Lowercase with underscores, descriptive action names
- **Global/Configuration:** `UPPERCASE_WITH_UNDERSCORES`
- **Local/Temporary:** `lowercase_with_underscores`
- **Array Variables:** `variable_name` (same as local convention)
- Declared with `declare -A` or `typeset -A` (equivalent in ZSH)
- Named descriptively: `shadow_map`, `file_map`, `v1_counts`, `v2_counts`, `is_double`
- No formal type system; ZSH treats everything as strings or arrays
- Numeric validation done explicitly with regex: `[[ "$var" =~ '^[0-9]+$' ]]`

## Code Style

- No linting tool configured (no `.eslintrc`, `.prettierrc`, `shfmt`, etc.)
- Hand-formatted with consistent indentation (2-space indentation observed)
- Line length: No strict limit observed; pragmatic based on readability
- Explicitly set when needed using `setopt extended_glob` or `zmodload zsh/zutil`
- See `list-missing-pages.zsh` line 10 and `number-pages.zsh` line 4
- `exit 0` for successful execution
- `exit 1` for errors
- Used consistently throughout all scripts

## Import Organization

- Use `zmodload` for ZSH built-in modules
- No package manager imports (this is shell scripting)
- Explicitly checked before use
- Example in `number-pages.zsh` (lines 67-70):
- Dependencies used across scripts: `identify`, `rclone`, `jq`, `sha256sum`, `find`, `awk`, `grep`

## Error Handling

- **Early Validation:** Check arguments and preconditions at script start
- **Error Messages to STDERR:** Always use `>&2` redirection
- **Exit on Error:** Exit with code 1 immediately after error
- **Soft Errors (Warnings):** Some errors are warnings, processing continues
- **Fail-fast pattern:** Check preconditions (arguments, file existence, command availability) at start
- **Graceful degradation:** Some operations warn but continue (e.g., missing image dimensions)
- **Command safety:** Use error checks after risky operations (`|| { ... exit 1; }`)

## Logging

- **Progress messages:** Direct to stdout using `echo` or `print`
- **Verbose progress:** For long operations, print status of each item
- **Section separators:** Use comment-like output to organize output
- **Error logging:** Always to stderr with `>&2`
- Use `print` for formatted output (with printf specifiers)
- Use `echo` for simple messages
- Always prefix errors with "Error:" for consistency

## Comments

- Comment complex algorithms or non-obvious logic
- Comment each major section with a marker like `# Stage 1:` or `# 1. Fetch remote manifest`
- Mark helper functions with clear purpose
- Comprehensive help text in heredoc at top of script (see `number-pages.zsh` lines 7-44)
- Usage shows: command, options, arguments, output format, examples, dependencies
- Run with `-h` or `--help` flag to display help
- Not applicable to shell scripts
- Function documentation done inline with comments
- Inline comments explain tricky ZSH features:

## Function Design

- `get_chap_num` (list-missing-pages.zsh): 1 function, 2 lines
- Most scripts have 0-1 helper function
- Functions accept positional parameters
- No named parameters or options within functions (simple approach)
- Example: `get_chap_num() { echo "$1" | grep -oP '(?<![0-9])[0-9]{3}(?![0-9])' | head -1 }`
- Functions use `echo` to return strings (piped to calling code or stored in variables)
- Example: `num=$(get_chap_num "${d:t}")`
- Exit codes indicate success/failure at script level

## Module Design

- Each `.zsh` file is an executable script
- Invoked from command line with arguments
- No sourcing of shared libraries observed
- `dev/manga/` - Image file operations (`number-pages.zsh`)
- `dev/local-filesys/` - Local filesystem utilities and shadow mapping:
- `dev/remote/` - Remote file synchronization:

## Variable Expansion & Quoting

- Always quote variables: `"$var"` not `$var`
- Protects against word splitting and globbing
- Observed consistently throughout codebase
- Heavy use of ZSH-specific features:
- `dir="${dir%/}"` - Remove trailing slash from directory
- `chapter="${2:-${dir:t}}"` - Use argument 2 or default to directory name
- `ext="${image_files[$i]:e}"` - Get file extension
- `relpath="${srcfile#$SRCDIR/}"` - Get path relative to root
- `shadowfile="$TGTDIR/${relpath}.txt"` - Build shadow file path
- `print "SHADOW: ${shadow#$SHADOWDIR/}"` - Print relative path

## Arithmetic & Conditionals

- Use `$(( expression ))` for arithmetic
- Examples:
- `[[ condition ]]` for string/pattern tests
- `(( arithmetic_test ))` for numeric comparisons
- Consistent use of `&&` and `||` for chaining
- Example: `[[ -d "$SHADOWDIR" ]] && { ... } || { ... }`

## Safety Practices

- Use `print0` with `read -r -d ''` for safe whitespace handling:
- Always use `--` before filenames to end option parsing:
- Use `"${array[@]}"` to expand all elements safely
- Use `${#array}` for length checks before iteration

<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

## System Overview

```text

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

- **Declarative metadata**: All file operations tracked via shadow files (`.txt` pointer files)
- **Multi-pass processing**: Stage 1 creates metadata, Stage 2 performs operations using metadata
- **Safe rename**: Temporary staging directories prevent collision during bulk operations
- **Hash/size-based matching**: Abstract away filename dependencies; match by content signature

## Layers

- Purpose: Parse arguments, validate inputs, establish configuration
- Location: Top 50-100 lines of each script
- Contains: Argument parsing (zparseopts), usage help, environment setup
- Depends on: zsh builtins, zsh/zutil module
- Used by: All downstream operations
- Purpose: Scan filesystem, verify dependencies, collect files
- Location: Middle sections of scripts (line 50-150 typically)
- Contains: `find` commands, `command -v` checks for external tools (identify, jq, rclone), glob patterns
- Depends on: External commands (identify for ImageMagick, rclone, jq)
- Used by: Processing layer
- Purpose: Calculate metadata, match files, build lookup tables
- Location: Core algorithm sections (line 80-180 typically)
- Contains: Associative arrays (typeset -A), hash/size calculations, while read loops
- Depends on: sha256sum, stat, identify, jq
- Used by: Metadata generation and operation execution
- Purpose: Write shadow files, move files to target locations
- Location: Final sections of scripts (line 100-220 typically)
- Contains: `mkdir -p`, `mv`, file writes with `>` redirection
- Depends on: Filesystem operations
- Used by: External consumers (subsequent pipeline stages)

## Data Flow

### Local Filesystem Indexing (retain-dir-struct-1)

### Shadow File Synchronization (retain-dir-struct-2)

### File Mapping via Shadows (retain-dir-struct-3)

### Remote File Matching (rename-remote-files-1)

### Remote File Reversion (rename-remote-files-2)

## Key Abstractions

- Purpose: Create a parallel directory structure with metadata pointers instead of real files
- Examples: `dev/local-filesys/retain-dir-struct-1.zsh`, `dev/remote/rename-remote-files-1-match-remote.zsh`
- Pattern: For each file in source, create `.txt` file at corresponding path in shadow directory containing file hash or remote metadata
- Implementation: `echo "hash content" > "$TGTDIR/${relpath}.txt"`
- Purpose: Enable O(1) file matching without repeated I/O operations
- Examples: `remote_map[$size]`, `file_map[$hash]`, `shadow_map[$hash]`
- Pattern: Associative arrays (typeset -A) indexed by content signature (hash or size)
- Implementation: `while read -r s p; do remote_map[$s]="$p"; done < <(...)`
- Purpose: Avoid filename collisions during bulk renames
- Examples: `number-pages.zsh` (stage 1: temp files; stage 2: final names)
- Pattern: Stage 1 renames to temporary files (`.numbering_tmp_*`), Stage 2 renames to final names
- Implementation: 
- Purpose: Preserve filesystem structure while reorganizing or staging files
- Examples: `dev/local-filesys/retain-dir-struct-2-sorted.zsh` creates new shadow structure matching reorganized data
- Pattern: Extract relative path from source, apply to target: `target_path="${target_root}/${relpath}"`
- Implementation: `mkdir -p "$(dirname "$target_shadow_path")"` then `cp ... "$target_shadow_path"`

## Entry Points

- Location: `/home/enzief/work/iswi/script/dev/manga/number-pages.zsh`
- Triggers: Manual invocation with directory and chapter arguments
- Responsibilities: Parse image files, detect double-page spreads, calculate sequential page numbers, rename files with smart padding
- Location: `/home/enzief/work/iswi/script/dev/local-filesys/retain-dir-struct-1.zsh`
- Triggers: Manual invocation with source and target directory paths
- Responsibilities: Initial shadow map creation; walk filesystem and hash all files
- Location: `/home/enzief/work/iswi/script/dev/local-filesys/retain-dir-struct-2-sorted.zsh`
- Triggers: Manual invocation after reorganizing data; requires existing shadow from retain-dir-struct-1
- Responsibilities: Sync shadow files to new directory structure; match by hash; preserve metadata
- Location: `/home/enzief/work/iswi/script/dev/local-filesys/retain-dir-struct-3-find-sorted.zsh`
- Triggers: Manual invocation with shadow directory and original data directory
- Responsibilities: Read-only diagnostic; map shadow files back to original files; output mappings for verification
- Location: `/home/enzief/work/iswi/script/dev/remote/rename-remote-files-1-match-remote.zsh`
- Triggers: Manual invocation with local source, shadow output, and sync output directories
- Responsibilities: Fetch remote manifest, match local files by size, create shadow metadata, stage files in sync directory
- Location: `/home/enzief/work/iswi/script/dev/remote/rename-remote-files-2-rename-local.zsh`
- Triggers: Manual invocation after MEGA sync confirms changes; requires shadow from rename-remote-files-1
- Responsibilities: Revert files from sync to original locations; trigger rename events on remote

## Architectural Constraints

- **Language:** Pure zsh; no external scripting languages (Python, Perl, Ruby) used
- **Shell options:** Some scripts enable `setopt extended_glob` for case-insensitive globbing (`**/*.(#i)jpg`)
- **External dependencies:**
- **Hardcoded values:** Remote name "mega" and path "devicesync/2019" hardcoded in `rename-remote-files-1-match-remote.zsh` (lines 5-6)
- **Error handling:** Scripts exit on missing directories, invalid arguments, or failed commands; no recovery/retry logic
- **Parallelization:** No parallel execution; all operations are sequential
- **Temporary files:** `number-pages.zsh` uses `.numbering_tmp_*` prefix for staging; not cleaned up if interrupted
- **File safety:** Uses `-print0` with `while IFS= read -r -d ''` for safe handling of filenames with spaces

## Anti-Patterns

### Hardcoded Remote Configuration

### Size-Based Matching for Remote Files

### No Dependency Validation

```zsh

```

### Unhandled Temporary File Cleanup

### Silent Collisions in Shadow Mapping

## Error Handling

- Argument validation: Exit 1 if `[[ $# -ne N ]]` (e.g., `retain-dir-struct-1.zsh` line 4)
- Directory validation: `[[ ! -d "$DIR" ]] && { echo "Error: ..." >&2; exit 1; }` (e.g., `retain-dir-struct-3-find-sorted.zsh` lines 13-14)
- Dependency checks: `command -v tool &>/dev/null || { echo "Error: ..." >&2; exit 1; }` (e.g., `number-pages.zsh` lines 67-70)
- File operation errors: `mv ... || { echo "Error: ..." >&2; exit 1; }` (e.g., `number-pages.zsh` line 112)
- Numeric validation: `[[ "$var" =~ '^[0-9]+$' ]] || { echo "Error: ..." >&2; exit 1; }` (e.g., `number-pages.zsh` lines 51-54)

## Cross-Cutting Concerns

- Progress: `echo "Processing: $file"`
- Warnings: `echo "Warning: ..." >&2`
- Errors: `echo "Error: ..." >&2`

<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:

- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
