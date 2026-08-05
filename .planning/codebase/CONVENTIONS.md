# Coding Conventions

**Analysis Date:** 2026-08-05

## Language & Shell

**Primary Language:**
- ZSH shell script (all files)
- No compiled code, no interpreted languages (Python, JS, etc.)

## Naming Patterns

**Files:**
- Format: `kebab-case.zsh`
- Examples: `number-pages.zsh`, `list-missing-pages.zsh`, `retain-dir-struct-1.zsh`
- Convention: Descriptive action verbs with hyphens separating words

**Functions:**
- Format: `snake_case`
- Example: `get_chap_num` in `list-missing-pages.zsh`
- Convention: Lowercase with underscores, descriptive action names

**Variables:**
- **Global/Configuration:** `UPPERCASE_WITH_UNDERSCORES`
  - Examples: `SRCDIR`, `TGTDIR`, `REMOTE_NAME`, `REMOTE_PATH`, `LOCAL_SRC_ABS`, `SHADOW_DIR_ABS`
  - Used for: Directory paths, configuration constants, remote names
- **Local/Temporary:** `lowercase_with_underscores`
  - Examples: `rel_path`, `current_hash`, `stored_hash`, `shadow_file_path`
  - Used for: Loop variables, temporary computations, local state
- **Array Variables:** `variable_name` (same as local convention)
  - Examples: `image_files`, `temp_files`, `orig_exts`, `all_keys`

**Associative Arrays:**
- Declared with `declare -A` or `typeset -A` (equivalent in ZSH)
- Named descriptively: `shadow_map`, `file_map`, `v1_counts`, `v2_counts`, `is_double`

**Type/Constants:**
- No formal type system; ZSH treats everything as strings or arrays
- Numeric validation done explicitly with regex: `[[ "$var" =~ '^[0-9]+$' ]]`

## Code Style

**Formatting:**
- No linting tool configured (no `.eslintrc`, `.prettierrc`, `shfmt`, etc.)
- Hand-formatted with consistent indentation (2-space indentation observed)
- Line length: No strict limit observed; pragmatic based on readability

**Shell Options:**
- Explicitly set when needed using `setopt extended_glob` or `zmodload zsh/zutil`
- See `list-missing-pages.zsh` line 10 and `number-pages.zsh` line 4

**Exit Codes:**
- `exit 0` for successful execution
- `exit 1` for errors
- Used consistently throughout all scripts

## Import Organization

**Module Loading:**
- Use `zmodload` for ZSH built-in modules
  - Example: `zmodload zsh/zutil` in `number-pages.zsh` (line 3) for `zparseopts`
- No package manager imports (this is shell scripting)

**External Command Dependencies:**
- Explicitly checked before use
- Example in `number-pages.zsh` (lines 67-70):
  ```bash
  if ! command -v identify &>/dev/null; then
      echo "Error: 'identify' (ImageMagick) is required" >&2
      exit 1
  fi
  ```
- Dependencies used across scripts: `identify`, `rclone`, `jq`, `sha256sum`, `find`, `awk`, `grep`

## Error Handling

**Patterns:**
- **Early Validation:** Check arguments and preconditions at script start
  - File 1: `number-pages.zsh` lines 4-70 (help text, option parsing, validation)
  - File 2: `retain-dir-struct-1.zsh` lines 4-6 (argument count check)
- **Error Messages to STDERR:** Always use `>&2` redirection
  - Example: `echo "Error: something" >&2`
- **Exit on Error:** Exit with code 1 immediately after error
  - Prevents cascading failures
- **Soft Errors (Warnings):** Some errors are warnings, processing continues
  - Example in `number-pages.zsh` line 86: "Warning: cannot read dimensions for..." allows script to continue

**Error Handling Strategy:**
- **Fail-fast pattern:** Check preconditions (arguments, file existence, command availability) at start
- **Graceful degradation:** Some operations warn but continue (e.g., missing image dimensions)
- **Command safety:** Use error checks after risky operations (`|| { ... exit 1; }`)
  - Example in `number-pages.zsh` line 112: `mv -- "${image_files[$i]}" "$tmp" || { ... exit 1; }`

## Logging

**Framework:** No logging library; uses `echo` and `print` directly

**Patterns:**
- **Progress messages:** Direct to stdout using `echo` or `print`
  - Example: `echo "Creating Shadow Map in '$TGTDIR'..."` (retain-dir-struct-1.zsh line 15)
  - Example: `print "Hashing: $relpath"` (retain-dir-struct-1.zsh line 32)
- **Verbose progress:** For long operations, print status of each item
  - Example: `echo "Matched & Placed: $rel_path"` (retain-dir-struct-2-sorted.zsh line 50)
- **Section separators:** Use comment-like output to organize output
  - Example: `echo "---"` (retain-dir-struct-1.zsh line 37)
  - Example: `echo "------------------------------------------------------------"` (list-missing-pages.zsh line 46)
- **Error logging:** Always to stderr with `>&2`

**Best Practice:**
- Use `print` for formatted output (with printf specifiers)
- Use `echo` for simple messages
- Always prefix errors with "Error:" for consistency

## Comments

**When to Comment:**
- Comment complex algorithms or non-obvious logic
  - Example: "First pass: detect double pages (width > height), calculate total page count" (number-pages.zsh line 79)
- Comment each major section with a marker like `# Stage 1:` or `# 1. Fetch remote manifest`
- Mark helper functions with clear purpose

**Usage Documentation:**
- Comprehensive help text in heredoc at top of script (see `number-pages.zsh` lines 7-44)
- Usage shows: command, options, arguments, output format, examples, dependencies
- Run with `-h` or `--help` flag to display help

**JSDoc/TSDoc:**
- Not applicable to shell scripts
- Function documentation done inline with comments

**Existing Comments in Code:**
- Inline comments explain tricky ZSH features:
  - `# Calculate the relative path of the real file to mirror it in the new shadow dir`
  - `# Extract the hash from the first column of the text file`
  - `# Recreate the subdirectory structure in the target`

## Function Design

**Size:** Functions are kept small and focused
- `get_chap_num` (list-missing-pages.zsh): 1 function, 2 lines
- Most scripts have 0-1 helper function

**Parameters:**
- Functions accept positional parameters
- No named parameters or options within functions (simple approach)
- Example: `get_chap_num() { echo "$1" | grep -oP '(?<![0-9])[0-9]{3}(?![0-9])' | head -1 }`

**Return Values:**
- Functions use `echo` to return strings (piped to calling code or stored in variables)
- Example: `num=$(get_chap_num "${d:t}")`
- Exit codes indicate success/failure at script level

## Module Design

**Exports:** Scripts are standalone; no module exports
- Each `.zsh` file is an executable script
- Invoked from command line with arguments
- No sourcing of shared libraries observed

**Barrel Files:** Not applicable (no module system)

**Script Organization:**
1. Shebang (`#!/bin/zsh`)
2. Module loading (if needed: `zmodload`)
3. Help text (if applicable: heredoc with usage)
4. Argument parsing and validation
5. Variable initialization
6. Main logic
7. Output/summary

**File Locations:**
- `manga/` - Image file operations (`number-pages.zsh`)
- `local-filesys/` - Local filesystem utilities and shadow mapping:
  - `list-missing-pages.zsh` - Compare two directories
  - `retain-dir-struct-*.zsh` - Shadow map operations (3 variants)
  - `rotate` - Simple image rotation utility
- `remote/` - Remote file synchronization:
  - `rename-remote-files-1-match-remote.zsh` - Match local to remote by size
  - `rename-remote-files-2-rename-local.zsh` - Revert files based on shadow metadata

## Variable Expansion & Quoting

**Strict Quoting:**
- Always quote variables: `"$var"` not `$var`
- Protects against word splitting and globbing
- Observed consistently throughout codebase

**Parameter Expansion:**
- Heavy use of ZSH-specific features:
  - `${var%/}` - Remove trailing slash
  - `${var:t}` - Get filename (tail)
  - `${var#prefix}` - Remove prefix
  - `${var:e}` - Get extension
  - `${var:h}` - Get directory (head)
  - `${var##pattern}` - Remove long match
  - `${var%% *}` - Remove trailing whitespace
  - `${#array}` - Array length
  - `${(n)array}` - Sort array numerically
  - `${(k)map}` - Get associative array keys

**Examples from Codebase:**
- `dir="${dir%/}"` - Remove trailing slash from directory
- `chapter="${2:-${dir:t}}"` - Use argument 2 or default to directory name
- `ext="${image_files[$i]:e}"` - Get file extension
- `relpath="${srcfile#$SRCDIR/}"` - Get path relative to root
- `shadowfile="$TGTDIR/${relpath}.txt"` - Build shadow file path
- `print "SHADOW: ${shadow#$SHADOWDIR/}"` - Print relative path

## Arithmetic & Conditionals

**Arithmetic:**
- Use `$(( expression ))` for arithmetic
- Examples:
  - `total_pages=0` then `(( total_pages++ ))` or `(( total_pages += 2 ))`
  - `page=$(( start_page - 1 + total_pages ))`

**Conditionals:**
- `[[ condition ]]` for string/pattern tests
- `(( arithmetic_test ))` for numeric comparisons
- Consistent use of `&&` and `||` for chaining
- Example: `[[ -d "$SHADOWDIR" ]] && { ... } || { ... }`

## Safety Practices

**File Operations:**
- Use `print0` with `read -r -d ''` for safe whitespace handling:
  ```bash
  find ... -print0 | while IFS= read -r -d '' file; do
  ```
- Always use `--` before filenames to end option parsing:
  ```bash
  mv -- "$old_name" "$new_name"
  ```

**Array Handling:**
- Use `"${array[@]}"` to expand all elements safely
- Use `${#array}` for length checks before iteration

---

*Convention analysis: 2026-08-05*
