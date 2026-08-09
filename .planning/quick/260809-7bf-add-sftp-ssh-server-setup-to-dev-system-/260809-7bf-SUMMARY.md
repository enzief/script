---
phase: quick-260809-7bf
plan: 01
subsystem: infra
tags: [openssh, sftp, ssh, bash, systemd, ufw]

requires: []
provides:
  - install-essentials.sh now installs openssh-server, enables+starts the ssh
    service, and guards an optional ufw allow rule on every future fresh install
  - REINSTALL_INSTRUCTIONS.txt's offline Step 3/Step 5 text kept in sync with
    the script
affects: [dev-system]

actuals:
  tokens: 3200
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Non-fatal privileged steps in install-essentials.sh: command -v <tool> guard + || echo Warning >&2, never -e, matching the file's set -uo pipefail contract"

key-files:
  created: []
  modified:
    - dev/system/install-essentials.sh
    - dev/system/REINSTALL_INSTRUCTIONS.txt

key-decisions:
  - "SSH/SFTP section placed between the shell-setup block and the Node.js/nvm banner (D-02), not appended near the manual-step reminders, since a service the machine depends on should not read as an afterthought"
  - "No sshd_config edit, no chroot jail, no separate restricted account (D-01) — Ubuntu's stock OpenSSH config already ships the sftp subsystem, so installing the package is the whole job"
  - "Firewall rule guarded behind command -v ufw with non-fatal warnings on failure (D-04); no firewall tool is installed by this plan"

patterns-established:
  - "Rationale comments live as whole-line comments above the command they explain, never as trailing inline comments, so a config/jail-reference grep over executable lines stays a clean signal"

requirements-completed: [SYS-09]

coverage:
  - id: D1
    description: "install-essentials.sh installs openssh-server and runs systemctl enable --now ssh under its own banner, between the shell-setup and Node.js sections"
    requirement: SYS-09
    verification:
      - kind: other
        ref: "bash -n dev/system/install-essentials.sh; grep checks for openssh-server / systemctl enable --now ssh / command -v ufw / ufw allow OpenSSH / apt-install-line-count==9 / Warning-count>=5 / pre-existing-content-preserved (Task 1 <verify> block)"
        status: pass
    human_judgment: false
  - id: D2
    description: "REINSTALL_INSTRUCTIONS.txt's Step 3 installer summary names the SSH/SFTP server and Step 5 documents the systemctl disable opt-out, with no out-of-scope script touched"
    requirement: SYS-09
    verification:
      - kind: other
        ref: "grep checks for sftp mention / systemctl disable --now ssh / all pre-existing instructions intact / line-count 125-131 / zero SSH mentions in backup-to-wdhdd.zsh, restore-from-wdhdd.zsh, clone-clean-repos.sh (Task 2 <verify> block)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The service is actually installed, enabled, and reachable (sftp prompt) on this machine today (D-03)"
    verification:
      - kind: other
        ref: "User ran the live-apply commands themselves (sudo apt install openssh-server; sudo systemctl enable --now ssh) and confirmed: systemctl is-active ssh -> active; sftp $USER@127.0.0.1 -> reached sftp> prompt successfully"
        status: pass
    human_judgment: true
    rationale: "D-05: no agent in this session could supply a sudo password, so the live apply and its verification were run by the human directly. Confirmed working 2026-08-09."

duration: 12min
completed: 2026-08-09
status: complete
---

# Quick Task 260809-7bf: Add SFTP/SSH server setup to dev/system Summary

**install-essentials.sh gained an openssh-server + systemctl enable --now ssh section (with a guarded, non-fatal ufw rule); REINSTALL_INSTRUCTIONS.txt synced to match. Applied live on this machine and confirmed working (sftp reaches an sftp> prompt).**

## Performance

- **Duration:** 12 min (Tasks 1-2) + human live-apply
- **Tasks:** 3/3 completed
- **Files modified:** 2

## Accomplishments
- `install-essentials.sh` installs `openssh-server`, runs `sudo systemctl enable --now ssh` (with a warning fallback), and conditionally adds a `ufw allow OpenSSH` rule only when `ufw` is present — all under one new banner between the shell-setup block and the Node.js/nvm section, exactly per D-01/D-02/D-04.
- `REINSTALL_INSTRUCTIONS.txt`'s Step 3 installer summary now lists the SSH/SFTP server alongside the other base-system items, and Step 5's loose-ends list carries the `systemctl disable --now ssh` opt-out bullet.
- `backup-to-wdhdd.zsh`, `restore-from-wdhdd.zsh`, and `clone-clean-repos.sh` were confirmed untouched (grep for openssh/sftp returns 0 hits in all three).

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the SSH/SFTP server section to install-essentials.sh (D-01, D-02, D-04)** - `368345c` (feat)
2. **Task 2: Keep REINSTALL_INSTRUCTIONS.txt's installer summary accurate** - `929e38b` (docs)

**Task 3 (checkpoint:human-verify, gate="blocking"): APPROVED.** No agent in this session could supply a sudo password (D-05), so the user ran the live-apply commands themselves and confirmed `systemctl is-active ssh` -> `active` and `sftp $USER@127.0.0.1` -> reached an `sftp>` prompt.

## Files Created/Modified
- `dev/system/install-essentials.sh` - New SSH/SFTP server banner section (install, enable+start, guarded firewall rule, user-facing reminder line)
- `dev/system/REINSTALL_INSTRUCTIONS.txt` - Step 3 installer summary rewrapped to include the SSH/SFTP server; Step 5 gained one opt-out bullet

## Decisions Made
- Section placement fixed at the shell-setup/Node.js boundary (D-02), not near the bottom manual-step reminders — a listening network daemon deserves the same visibility as the other base-system sections, not an afterthought slot.
- Rationale comments kept as whole-line comments above the install command (never trailing), so the verification gate's `grep -v '^[[:space:]]*#'` scan over executable lines cleanly proves no config/jail reference exists in code, while the comment text can still name and reject those alternatives for future readers.
- Firewall tool is checked for, never installed — D-04 draws that line explicitly to avoid a silent network-posture change as a side effect of an SFTP task.

## Deviations from Plan

None - plan executed exactly as written for Tasks 1 and 2. All automated `<verify>` blocks for both tasks passed on first attempt with no fix cycles.

## Issues Encountered
None for Tasks 1-2.

## User Setup Required

None further. The user applied the live-apply commands themselves (`sudo apt install -y openssh-server`, `sudo systemctl enable --now ssh`) and confirmed the service is active and `sftp $USER@127.0.0.1` reaches an `sftp>` prompt. The two open decisions from the checkpoint (password auth left on; firewall left as-is) were not raised as objections, so both stand as documented in PLAN.md Task 3.

## Next Phase Readiness
- All three tasks complete: the script and documentation changes are committed, and the live SSH/SFTP service is confirmed working on this machine.

## Self-Check: PASSED
- FOUND: dev/system/install-essentials.sh
- FOUND: dev/system/REINSTALL_INSTRUCTIONS.txt
- FOUND: .planning/quick/260809-7bf-add-sftp-ssh-server-setup-to-dev-system-/260809-7bf-SUMMARY.md
- FOUND: 368345c (Task 1 commit)
- FOUND: 929e38b (Task 2 commit)
