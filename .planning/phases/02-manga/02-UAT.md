---
status: testing
phase: 02-manga
source: [02-VERIFICATION.md]
started: 2026-08-06T12:41:06Z
updated: 2026-08-06T12:41:06Z
---

## Current Test

number: 1
name: Real ImageMagick against a genuinely corrupt image file
expected: |
  The `Error:` line is noticeable in the output stream, and the summary's
  dimension-detection failure count matches the number of files that
  actually failed to report dimensions.
awaiting: user response

## Tests

### 1. Real ImageMagick against a genuinely corrupt image file
expected: Run `number-pages.zsh` against a scratch copy of a real manga chapter
  that includes one deliberately corrupted image file, using real ImageMagick
  (not the test's stub `identify`). The `Error:` line is noticeable in the
  output stream, and the summary's dimension-detection failure count matches
  the number of files that actually failed to report dimensions. Never run
  this against an original chapter — the script renames in place.
result: [pending]

### 2. Judgment-tier confirmation of the two safety prohibitions
expected: Confirm by design review that (1) the dimension-failure branch never
  becomes a fatal abort that could strand `.numbering_tmp_*` staging files,
  and (2) the test never sources its fixture root from argv/env/cwd. Both
  hold in the current code.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
