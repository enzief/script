---
phase: 02
slug: manga
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: 2026-08-06
---

# Phase 02 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| local filesystem → script | Image filenames and file contents are read from a user-supplied directory; filenames are attacker-influenceable in the realistic case of unpacking a downloaded archive and running the script on it | filenames, file bytes |
| test fixture → PATH | The new test prepends a fixture-owned directory containing an executable `identify` stub to `PATH` for the duration of each script invocation | PATH environment variable |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-02-01 | Denial of Service | `number-pages.zsh` two-stage rename (empty-dims branch → summary) | high | mitigate | D-01/D-04 keep the branch non-fatal (no `exit`/`return`); prohibition recorded in `must_haves.prohibitions`; Task 2 Scenario D behaviorally asserts exit 0 and zero stranded `.numbering_tmp_*` files after a run containing failures. Re-confirmed by this audit: `dev/manga/number-pages.zsh:86-91` contains no `exit`/`return` in the empty-dims block; `./dev/manga/tests/test-number-pages.zsh` passes 24/24 including the Scenario D assertions. | closed |
| T-02-02 | Elevation of Privilege | `dev/manga/tests/test-number-pages.zsh` PATH prepend | medium | mitigate | Fixture root sourced exclusively from `mktemp -d` (never argv/env/cwd), prepend scoped to the single command invocation (not exported), `trap cleanup EXIT INT TERM` removes the stub. Re-confirmed by this audit: `dev/manga/tests/test-number-pages.zsh:61-68` shows `FIXROOT=$(mktemp -d)` with an emptiness/existence guard and no `$1`/`$@`/env read for the fixture root. | closed |
| T-02-03 | Tampering | filename flowing into the failure message and `mv` | low | accept | Pre-existing surface, unchanged by this phase: `${f:t}` (basename only) and `mv --` (end of option parsing) already mitigate shell-metacharacter and leading-dash filenames. | closed |
| T-02-04 | Information Disclosure | failure message content | low | accept | Message prints `${f:t}` (basename), not the absolute path; single-user local CLI with no second party to disclose to. | closed |
| T-02-05 | Spoofing | — | low | accept | Not applicable — no identity, authentication, session, or credential surface. | closed |
| T-02-06 | Repudiation | — | low | accept | Not applicable — no audit-log or multi-user attribution requirement; this phase's summary failure count is itself a durable record of guessed pages. | closed |
| T-02-SC | Tampering (supply chain) | — | low | accept | Not applicable — no `npm`/`pip`/`cargo` install, no new third-party dependency; pure zsh using tools already in the documented stack. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on (`high`) count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| R-02-01 | T-02-03 | Pre-existing basename/`mv --` handling was in scope for review, not modification, in this phase | planner (02-01-PLAN.md threat_model) | 2026-08-06 |
| R-02-02 | T-02-04 | Single-user local CLI, no second party; basename-only disclosure | planner (02-01-PLAN.md threat_model) | 2026-08-06 |
| R-02-05,06,SC | T-02-05, T-02-06, T-02-SC | ASVS L1 categories with no attachment point in this phase (no identity/session surface, no audit-log requirement, no new dependency) | planner (02-01-PLAN.md threat_model) | 2026-08-06 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-06 | 7 | 7 | 0 | gsd-secure-phase (orchestrator, L1 short-circuit — register authored at plan time, threats_open: 0, asvs_level: 1) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-06
