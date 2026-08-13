---
status: testing
phase: 03-remote
source: [03-VERIFICATION.md]
started: 2026-08-13T12:48:51Z
updated: 2026-08-13T12:48:51Z
---

## Current Test

number: 1
name: Real-remote match/reversion round trip
expected: |
  Real `rclone lsjson` output's `Size`/`Path` fields behave as the size-index code assumes;
  matches are found; reversion triggers MEGA rename events, not re-uploads.
awaiting: user response

## Tests

### 1. Real-remote match/reversion round trip
expected: On a scratch copy only: export the real `REMOTE_NAME`/`REMOTE_PATH`, run `rename-remote-files-1-match-remote.zsh` against a small throwaway directory whose files are known to exist on the real MEGA remote, confirm match lines name the expected remote filenames, then run `rename-remote-files-2-rename-local.zsh` and confirm MegaSync reports rename operations rather than uploads.
result: [pending]

### 2. Truncated shadow file against a real shadow tree
expected: On a scratch copy only: take a real shadow tree produced by script 1, truncate one shadow file to zero bytes, run `rename-remote-files-2-rename-local.zsh`, confirm the truncated file is named on stderr and skipped, every other file is reverted, and MegaSync reports rename operations for the reverted files.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
