---
status: testing
phase: 01-local-filesystem
source: [01-VERIFICATION.md]
started: 2026-08-05T19:20:22Z
updated: 2026-08-05T19:20:22Z
---

## Current Test

number: 1
name: Interrupt / idempotency / concurrency behavior of retain-dir-struct-2-sorted.zsh
expected: |
  The interrupted run leaves a partially-populated new shadow tree with no rollback (this is
  accepted, not a bug — the script has no transaction/rollback mechanism). The re-run is
  idempotent: cp overwrites existing shadow files with identical content, so re-running to
  completion produces the same final state as an uninterrupted run. Concurrent runs against the
  same target are not claimed safe (accepted risk for a single-user local tool per
  01-01-PLAN.md's threat register, T-01-04).
awaiting: user response

## Tests

### 1. Interrupt / idempotency / concurrency behavior of retain-dir-struct-2-sorted.zsh
expected: Start a real run of retain-dir-struct-2-sorted.zsh against a fixture tree with enough
  files that it takes a few seconds, interrupt it with Ctrl-C partway through, then re-run the
  identical command over the same inputs. Separately, start two instances of the script
  concurrently against the same new-shadow-root target. Expected: interrupted run leaves a
  partially-populated new shadow tree with no rollback (accepted); re-run is idempotent (cp
  overwrites to identical content); concurrent runs are not claimed safe (accepted risk, single-user
  tool per T-01-04 in 01-01-PLAN.md's threat model).
result: [pending]

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps
