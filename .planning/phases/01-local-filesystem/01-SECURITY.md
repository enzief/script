---
phase: 01
slug: local-filesystem
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: 2026-08-05
---

# Phase 01 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| filesystem → script (01-01) | Directory and file names discovered by `find` are untrusted input; flow into `cp`, `mkdir -p`, and output formatting | file/dir paths |
| file content → script (01-01) | Shadow `.txt` contents parsed by `awk`; extracted hash becomes an associative-array key | shadow hash content |
| operator argv → script (01-01) | Three positional directory paths and the `--dry-run` flag | CLI arguments |
| filesystem → script (01-02) | File/directory names from `find`, and absolute paths from `realpath`, flow into output formatting | file/dir paths |
| file content → script (01-02) | Shadow `.txt` contents parsed by `awk`; extracted hash becomes an associative-array key | shadow hash content |
| operator argv → script (01-02) | Two positional directory paths per script | CLI arguments |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-01-01 | Tampering | Test fixture teardown (`tests/test-retain-dir-struct.zsh`, plan 01-01) | high | mitigate | Recursive delete guarded on a non-empty variable naming a directory created by this run's own `mktemp -d`; fixture root never accepted from argv/env. | closed |
| T-01-02 | Tampering | `target_shadow_path` construction (`retain-dir-struct-2-sorted.zsh`) | medium | mitigate | Every path expansion double-quoted, including the `--dry-run` branch; dry-run branch performs no `mkdir`/`cp` at all. | closed |
| T-01-03 | Information disclosure | `print` of discovered filenames (script 2) | low | mitigate | `print -r --` on every output call site. | closed |
| T-01-04 | Denial of service | `shadow_map` in-memory index | low | accept | Single-user local tool; array size bounded by operator's own directory. | closed (accepted) |
| T-01-05 | Elevation of privilege | Symlinks in scanned trees (script 2) | low | accept | `find -type f` without `-L` neither follows nor matches symlinks. Broader symlink policy deferred (LOCALFS-04). | closed (accepted) |
| T-01-06 | Information disclosure | `print` of filenames/`realpath` output (scripts 3 & 1) | medium | mitigate | `print -r --` on every call site that interpolates a value. | closed |
| T-01-07 | Tampering | `retain-dir-struct-3-find-sorted.zsh` scope creep | medium | mitigate | Script remains read-only by contract; no `cp`/`mv`/`rm` invocation exists in the file (confirmed via grep and by code review). | closed |
| T-01-08 | Repudiation | Silent message loss from echo→print conversion | high | mitigate | `print -r --` mandated on every dash-leading/interpolated call site; exact-count separator assertions (52 dashes script 2/3, 3 dashes script 1) in the regression suite. | closed |
| T-01-09 | Tampering | Test fixture teardown (extended in plan 01-02) | high | mitigate | Inherits the single guarded `mktemp -d` root and `EXIT` trap from plan 01-01; no second root/trap added (asserted: exactly one `mktemp -d`, one `trap`). | closed |
| T-01-10 | Elevation of privilege | Symlinks in scanned trees (scripts 3 & 1) | low | accept | `find -type f` without `-L` neither follows nor matches symlinks. Broader symlink policy deferred (LOCALFS-04). | closed (accepted) |
| T-01-SC | Tampering | npm/pip/cargo installs | low | accept | No package-manager installs occurred in this phase; test suite is dependency-free zsh. | closed (accepted) |

*Status: open · closed · open — below {block_on} threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-01 | T-01-04 | Unbounded `shadow_map`/`file_map` in-memory index is acceptable for a single-user local tool scanning the operator's own directories; not internet-facing, no untrusted multi-tenant input. | plan 01-01 threat model | 2026-08-05 |
| AR-02 | T-01-05, T-01-10 | Symlinks are neither followed nor matched by `find -type f` (no `-L`), so they're silently skipped rather than traversed. Full symlink policy explicitly deferred to requirement LOCALFS-04, a future phase. | plan 01-01/01-02 threat models | 2026-08-05 |
| AR-03 | T-01-SC | No package-manager installs occur in this phase's deliverables (test suite is a dependency-free zsh script, `bats` was explicitly rejected). No supply-chain legitimacy checkpoint required. | plan 01-01/01-02 threat models | 2026-08-05 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-05 | 11 | 11 | 0 | Claude (orchestrator, L1 grep-depth per ASVS level 1 short-circuit — register authored at plan time, all mitigations independently confirmed by direct code inspection, the phase's code-review cycle, and goal-backward verification) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-05
