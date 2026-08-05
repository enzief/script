# Technology Stack

**Analysis Date:** 2026-08-05

## Languages

**Primary:**
- Shell (Zsh) - All scripts are zsh executables with shebang `#!/bin/zsh`

## Runtime

**Environment:**
- Zsh shell (5.x series) as primary interpreter
- Linux kernel (implied by grep `-c` and stat `-c` flags, find `-print0`)

**Package Manager:**
- None (pure shell, no package manager)
- Lockfile: Not applicable

## Frameworks

**Core:**
- No frameworks; pure shell scripting utilities

**Build/Dev:**
- Git (version control, referenced in `.git` directory)

## Key Dependencies

**Critical System Utilities:**
- `find` (3.4+) - Recursive file enumeration (`find -type f -print0`)
- `sha256sum` (GNU coreutils) - Cryptographic hashing for file verification
- `stat` (GNU coreutils) - File size retrieval and metadata

**External Tools:**
- `rclone` (remote file sync) - Cloud storage abstraction layer for MEGA integration (`rclone lsjson`, `rclone` remote named "mega")
- `jq` (JSON processor) - JSON parsing for `rclone lsjson` output
- `ImageMagick` (identify command) - Image dimension detection in `dev/manga/number-pages.zsh`
- `convert` (ImageMagick) - Image rotation utility in `dev/local-filesys/rotate`

**Standard POSIX Utilities:**
- `grep` (pattern matching, with Perl regex via `-oP` flag)
- `awk` (text field extraction)
- `date` (timestamp generation)
- `realpath` (absolute path resolution)
- `mkdir`, `mv`, `cp`, `awk` (standard file operations)

## Configuration

**Environment:**
- rclone remote "mega" with path "devicesync/2019" configured in rclone config (referenced in `dev/remote/rename-remote-files-1-match-remote.zsh`)
- No `.env` files or environment variable configuration detected
- MEGA sync folder path passed as runtime argument to scripts

**Build:**
- No build configuration files detected (package.json, Makefile, cargo.toml, etc.)

## Platform Requirements

**Development:**
- Linux system with GNU coreutils (find, sha256sum, stat, grep, awk, date)
- Zsh interpreter installed and available in PATH
- rclone installed and configured with MEGA remote
- ImageMagick installed (identify, convert commands)
- jq JSON processor installed
- MegaSync desktop application running (for file synchronization at OS level)

**Runtime:**
- Linux filesystem (uses `-c` flag with stat, `-print0` with find — GNU extensions)
- Synchronized MEGA folder (requires MegaSync client running)
- Image files: JPG, JPEG, PNG, WebP, GIF, BMP, TIFF, AVIF

---

*Stack analysis: 2026-08-05*
