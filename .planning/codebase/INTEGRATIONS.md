# External Integrations

**Analysis Date:** 2026-08-05

## APIs & External Services

**MEGA Cloud Storage:**
- Service: MEGA (Secure cloud storage platform)
  - What it's used for: Remote file synchronization, file matching, and metadata updates via MegaSync desktop client
  - SDK/Client: rclone (universal cloud storage abstraction layer)
  - Access pattern: 
    - `rclone lsjson --recursive` to fetch remote file manifest with Size and Path metadata
    - `rclone` remote named "mega" with hardcoded path "devicesync/2019"
  - Configuration: Remote must be configured in rclone config file (typically `~/.config/rclone/rclone.conf`)

## Data Storage

**Databases:**
- None (flat filesystem-based approach)

**File Storage:**
- MEGA Cloud Storage (via rclone and MegaSync)
  - Connection: rclone remote config at `[mega]` section in rclone.conf
  - Client: rclone command-line tool
- Local filesystem only (ext4, exFAT, or other Linux-native filesystems)
  - Shadow metadata stored as `.txt` files containing SHA256 hashes and file references

**Caching:**
- Associative array caching in zsh runtime during script execution
  - File maps built for fast lookups: `remote_map[$size]` in `dev/remote/rename-remote-files-1-match-remote.zsh`
  - Shadow file index caching: `shadow_map[$hash]` in `dev/local-filesys/retain-dir-struct-2-sorted.zsh`
  - No persistent cache; rebuild on each run

## Authentication & Identity

**Auth Provider:**
- MEGA (handled externally by rclone)
  - Implementation: rclone remote configuration (stored in `~/.config/rclone/rclone.conf`)
  - Authentication type: Two-factor capable (managed by MEGA account, not by scripts)
  - No credentials embedded in scripts

## Monitoring & Observability

**Error Tracking:**
- None (scripts log to stdout/stderr)

**Logs:**
- Console output only (echo statements to stdout)
- MegaSync transfer list for rename event verification (referenced in `dev/remote/rename-remote-files-2-rename-local.zsh` comments)

## CI/CD & Deployment

**Hosting:**
- No deployment; local utility scripts executed on user's Linux workstation

**CI Pipeline:**
- None

## Environment Configuration

**Required env vars:**
- None detected in scripts (hardcoded or runtime arguments used instead)

**Configuration Files:**
- `~/.config/rclone/rclone.conf` - rclone remote configuration (MEGA credentials managed here)
- `~/.config/MegaSync/` - MegaSync client sync folder path configuration
- rclone remote name: `mega` (hardcoded in `dev/remote/rename-remote-files-1-match-remote.zsh:6`)
- rclone path: `devicesync/2019` (hardcoded in `dev/remote/rename-remote-files-1-match-remote.zsh:7`)

**Secrets location:**
- MEGA authentication credentials stored in rclone config: `~/.config/rclone/rclone.conf`
- Scripts assume rclone is pre-configured; no inline credential management

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- File rename events trigger MegaSync sync updates (implicit; relies on OS filesystem watch)
  - `mv` command in `dev/remote/rename-remote-files-2-rename-local.zsh` triggers MegaSync rename detection
  - MegaSync handles upload of metadata changes back to MEGA servers

## Data Flow

**Primary Integration Path (File Sync Workflow):**

1. `dev/remote/rename-remote-files-1-match-remote.zsh`:
   - Calls `rclone lsjson --recursive mega:devicesync/2019` 
   - Fetches JSON manifest, pipes through jq to extract Size and Path
   - Builds size-based lookup map in memory
   - Matches local files by size against remote files

2. Shadow metadata creation:
   - Writes matching info to `.txt` files preserving local directory structure
   - Stores: `ORIGINAL_LOCAL_PATH`, `MATCHED_REMOTE_PATH`, `FILE_SIZE_BYTES`, `PROCESSED_AT`

3. `dev/remote/rename-remote-files-2-rename-local.zsh`:
   - Sources shadow `.txt` files to read metadata
   - Moves files back to original paths (triggers MegaSync sync)
   - MegaSync detects file rename event and syncs metadata to MEGA servers

---

*Integration audit: 2026-08-05*
