---
phase: quick-260827-dfl
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - dev/local-filesys/retain-dir-struct-4-revert.zsh
  - dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh
autonomous: true
requirements: [LOCALFS-05]

estimate:
  tokens: 42000
  raw_tokens: 28000
  tasks: 2
  confidence: low

must_haves:
  truths:
    - "A <target_tree> argument that does not exist on disk is created by a real run instead of aborting the invocation"
    - "A dry run prints 'Would create target tree: <path>' for each missing target tree and leaves that path absent from disk when the run finishes"
    - "A dry run with a not-yet-created target tree emits no 'No such file or directory' noise on stderr from the two find traversals"
    - "A dry run in which every target tree is missing reports zero swap candidates and never falls back to scanning the current working directory"
    - "A missing <shadow_tree> still aborts with 'Error: Shadow tree not found:' and exit 1 (unchanged)"
    - "A target tree resolving to the same path as, or nested under/over, the shadow tree still aborts with 'Error: Overlapping tree roots' whether or not that target tree exists yet, and is never created on disk"
    - "All 74 pre-existing assertions in the test suite still pass"
  artifacts:
    - dev/local-filesys/retain-dir-struct-4-revert.zsh
    - dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh
  key_links:
    - "TARGET_TREES_EXISTING filter feeds BOTH find traversals (name-index build and basename-collision rescan)"
    - "Overlap guard runs BEFORE the create block, so a rejected root is never mkdir'd and stdout stays empty on that error path"
    - "realpath -m -- on TARGET_TREES_ABS keeps the overlap comparison valid for roots that do not exist yet"
    - "SHADOW_TREE_ABS stays plain realpath -- because shadow-tree existence remains a hard prerequisite"
---

<objective>
Make `dev/local-filesys/retain-dir-struct-4-revert.zsh` create a missing `<target_tree>` instead of erroring out, without weakening the overlap guard or the dry-run non-destructiveness contract.

Purpose: today any `<target_tree>` that is not already on disk aborts the whole invocation, forcing the user to `mkdir -p` by hand before every first-time swap into a new tree. `retain-dir-struct-1.zsh` already establishes the `mkdir -p "$TGTDIR"` convention for exactly this situation.

Output: the swap script accepts not-yet-existing target trees (created for real, previewed under `--dry-run`), plus new regression assertions in the existing test file covering creation, dry-run non-creation, the shadow-tree hard error, and overlap-guard survival.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.claude/CLAUDE.md
@dev/local-filesys/retain-dir-struct-4-revert.zsh
@dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh
@.planning/phases/04-local-filesys-revert-tool/04-CONTEXT.md
</context>

<facts_verified_at_plan_time>
Empirically confirmed on this machine before writing this plan. Do not re-derive, and do not substitute alternatives.

1. `realpath --version` reports `realpath (uutils coreutils) 0.8.0`.
2. `realpath -- /tmp/nonexistent-xyz/sub/deep` exits 1 with empty stdout. This is why the current `TARGET_TREES_ABS` build would silently store an empty string for a not-yet-created root, weakening the overlap guard.
3. `realpath -m -- /tmp/nonexistent-xyz/sub/deep` exits 0 and echoes the resolved path. On a path that does exist, `-m` returns byte-identical output to plain `realpath --`, so switching to `-m` changes nothing for roots that already exist.
4. `find` invoked with zero path arguments searches the current working directory. Confirmed: a zsh `find "${EMPTY[@]}" -type f -print0` run from a scratch cwd returned `./marker-in-cwd.txt`. This is the hazard the empty-array guard exists to prevent.
5. `mkdir -p -- <path>` is supported on this system, is idempotent on an existing directory, and handles a dash-prefixed final component.
6. Test-suite baseline before any change: `Results: 74 passed, 0 failed`.
7. `grep` on this machine is **ugrep 7.8.4**, not GNU grep. It treats `$` as an anchor even mid-pattern, so a pattern containing a shell variable reference such as `"$t"` or `${#arr[@]}` silently matches nothing under the default regex mode. Every source-inspection gate in this plan therefore uses `grep -F` (fixed strings), which was confirmed to return the expected counts. Character-class patterns such as `^PASS: Case [A-N]:` behave normally and need no `-F`. If a task adds its own source-inspection gate, use `-F`.
</facts_verified_at_plan_time>

<design_decision>
## Ordering: the overlap guard runs before the create block

The task spec identifies two edit regions by their current line numbers (the target-tree validation loop at 37-39, the realpath resolution at 44-49) but does not state which must run first. This plan puts the **overlap guard first** and the **create-or-report block after it**. Rationale:

- **No mutation before validation.** With create-first, a real run given a target tree nested under the shadow tree would `mkdir -p` that directory inside the shadow tree and only then abort with the overlap error, leaving a stray empty directory behind. In a tool whose whole job is physically relocating real files, mutating disk before a fatal validation failure is the wrong order.
- **`realpath -m --` is still required, in both modes.** Under this ordering no target tree exists yet at overlap-check time, so `-m` carries the guard for real runs too, not only dry runs. Per fact 3 this is a strict superset of the spec's requirement with no behavior change for roots that already exist.
- **Keeps the error path stdout-clean.** The test file's `assert_stderr_and_exit` helper passes only when stdout is empty. Create-first would print a creation line to stdout before the overlap error, breaking that assertion style for Case S.

Everything else the spec pins is unchanged: the create logic applies only to `TARGET_TREES`, `TARGET_TREES_EXISTING` is built with `[[ -d ]]` after the create-or-report block, and no `mkdir` is added anywhere else.
</design_decision>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add RED regression assertions for target-tree creation, dry-run non-creation, and guard survival</name>
  <files>dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh</files>
  <read_first>
Read the whole existing test file first. Reuse its established fixture idioms exactly: `make_shadow`, `tree_snapshot`, `assert_path`, `assert_equal`, `assert_contains`, `assert_stderr_and_exit`, `_record`, and the single `mktemp -d` `$FIXROOT` with its `trap cleanup EXIT INT TERM` teardown. Do not introduce a second fixture root, a second cleanup trap, or any new helper unless an existing one genuinely cannot express the assertion.

Note the naming sequence already in use: cases run A through N. New cases continue at O.
  </read_first>
  <behavior>
Append five new cases immediately before the `# --- Summary ---` block. Every target-tree path described below as missing must be a path under `$FIXROOT` that the fixture deliberately does not create.

- **Case O, real run creates a missing target tree.** Home tree holds two shadows. Target tree 1 exists and holds the real file matching the first shadow; target tree 2 is a path that does not exist. Assert: target tree 2 exists on disk after the run; stdout carries `Created target tree: ` naming target tree 2; the first shadow still swapped correctly (real file landed in the home tree, shadow landed in target tree 1); the second shadow reports the no-match skip line; exit code is 0; stderr is empty.
- **Case P, dry run reports but does not create.** Same fixture shape as Case O, run with `--dry-run`. Assert: stdout carries `Would create target tree: ` naming the missing tree; that path is still absent from disk after the run; stdout carries no `Created target tree: `; stdout carries the `Would swap: ` preview for the shadow whose match lives in the existing tree, proving the surviving tree was still traversed; stderr contains no `No such file or directory`; `tree_snapshot` of both the home tree and the existing target tree is byte-identical before and after.
- **Case Q, dry run where every target tree is missing must not fall back to the cwd.** This is the empty-filtered-array guard. Build a bait directory containing a real file whose basename matches the shadow exactly and whose content hashes to the shadow's stored hash. Invoke the script with that bait directory as the process's working directory, using a subshell that `cd`s there so the outer harness cwd is unaffected, and pass a single target tree that does not exist. Assert: stdout carries no `Would swap: `; stdout carries the no-match skip line for that shadow; stdout carries `Would create target tree: `; the missing tree is still absent; the bait file is untouched; stderr contains no `No such file or directory`.
- **Case R, missing shadow tree still hard-errors.** Use `assert_stderr_and_exit` with expected exit 1 and needle `Error: Shadow tree not found: `, against a shadow-tree path that does not exist plus an existing target tree. Repeat once with `--dry-run` prepended, proving the flag does not soften it.
- **Case S, overlap guard survives and rejects before creating.** Two sub-cases. (a) Target tree is a path nested under an existing shadow tree, where that nested path does not itself exist: assert exit 1 with `Error: Overlapping tree roots` on stderr and empty stdout via `assert_stderr_and_exit`, then assert the nested path is still absent from disk. Run sub-case (a) both without and with `--dry-run`. (b) Target tree is an existing directory that is a parent of the shadow tree: assert the same overlap error and exit 1.

Case S(a)'s still-absent assertion is what pins the ordering recorded in `<design_decision>`: it fails if the create block is placed ahead of the overlap guard.
  </behavior>
  <action>
Append the five cases described in `<behavior>` to `dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh`, directly above the `# --- Summary ---` separator, following the file's existing case-banner style: a rule of `=` characters, a short prose explanation of what the case proves and which design decision it traces to, then the fixture and its assertions.

This task lands assertions only. Leave `dev/local-filesys/retain-dir-struct-4-revert.zsh` completely untouched here. The new assertions are expected to fail against the current script, and that is the point: it proves each assertion is load-bearing rather than vacuously true.

Match the file's conventions exactly: 4-space indent, `print -r --` and `print -u2 -r --` for output, `[[ ]]` for string and path tests, `(( ))` for numeric tests, `sha256sum -- "$f" | awk '{print $1}'` for hashing, and every fixture path rooted under `$FIXROOT`. Never hand-write a 64-character hash literal; derive every shadow through `make_shadow`, exactly as the existing cases do.

For the stderr assertions in Cases O, P, and Q, capture stderr separately, either by redirecting it to a file under `$FIXROOT` or with the `2>&1 1>/dev/null` capture form that Cases C, G, and M already use, so a stderr-only check cannot be satisfied by stdout text.
  </action>
  <verify>
    <automated>cd /home/enzief/work/iswi/script && ./dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh > /tmp/dfl-red.txt 2>&1; echo "preexisting_A-N_passes=$(grep -c '^PASS: Case [A-N]:' /tmp/dfl-red.txt)"; echo "new_O-S_fails=$(grep -c '^FAIL: Case [O-S]:' /tmp/dfl-red.txt)"; echo "unexpected_A-N_fails=$(grep -c '^FAIL: Case [A-N]:' /tmp/dfl-red.txt)"</automated>
  </verify>
  <done>
`preexisting_A-N_passes` is 74, `unexpected_A-N_fails` is 0, and `new_O-S_fails` is greater than 0. The RED state is honest: every newly added assertion that fails does so because the script has not been changed yet, not because the fixture is malformed. `dev/local-filesys/retain-dir-struct-4-revert.zsh` is byte-identical to its pre-task state (`git diff --quiet -- dev/local-filesys/retain-dir-struct-4-revert.zsh` exits 0).
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Create missing target trees, resolve them lexically, and filter both find traversals</name>
  <files>dev/local-filesys/retain-dir-struct-4-revert.zsh</files>
  <behavior>
Turns every assertion added in Task 1 green while leaving all 74 pre-existing assertions untouched. Four coordinated edits, all inside the setup region plus the two traversal sites.
  </behavior>
  <action>
Edit `dev/local-filesys/retain-dir-struct-4-revert.zsh` only. Apply exactly these four changes and nothing else.

**(1) Drop the target-tree existence rejection.** Remove the loop that currently rejects a target tree not present on disk and exits 1. The shadow-tree check on the line above it is unrelated and stays exactly as written: a shadow tree that is not on disk remains a hard, fatal error in both modes.

**(2) Resolve target roots lexically.** In the block that builds `TARGET_TREES_ABS`, add the `-m` flag to the `realpath` invocation so it becomes `realpath -m -- "$t"`. Per fact 3 in `<facts_verified_at_plan_time>` this is behavior-preserving for roots that already exist and is what keeps the overlap comparison meaningful for a root that does not exist yet. Leave `SHADOW_TREE_ABS` on plain `realpath --`; shadow-tree existence is still a hard prerequisite, so the lenient form would only mask a real error there. Leave the overlap comparison loop itself completely unchanged.

**(3) Add the create-or-report block immediately after the overlap loop.** Placement after the guard is deliberate; see `<design_decision>`. Iterate `TARGET_TREES`, skip any entry that is already a directory, and for the rest branch on `DRY_RUN`: when dry, print a would-create line to stdout naming the path and touch nothing; when not dry, run `mkdir -p -- "$t"` and, if it fails, print an error to stderr and exit 1, otherwise print a created line to stdout naming the path. The two stdout messages must read exactly `Would create target tree: $t` and `Created target tree: $t` because Task 1's assertions grep for those prefixes. Carry a short comment explaining that a brand-new target tree is a legitimate swap destination and that this mirrors the `mkdir -p "$TGTDIR"` convention in `retain-dir-struct-1.zsh`.

**(4) Build `TARGET_TREES_EXISTING` and route both traversals through it.** Directly after the create-or-report block, declare a `typeset -a TARGET_TREES_EXISTING`, initialize it empty, and populate it with every `TARGET_TREES` entry for which `[[ -d "$t" ]]` currently holds. After a real run all entries qualify because step 3 just created them; after a dry run only the roots that already existed do. Then change the array named in both `find ... -type f -print0` process substitutions to `TARGET_TREES_EXISTING`: the name-index build that populates `name_count` and `name_first`, and the basename-collision rescan that populates `candidates` inside the multi-candidate branch. Wrap each of those two traversals in a guard that runs the traversal only when `(( ${#TARGET_TREES_EXISTING[@]} ))` holds, so a run with no surviving roots performs no traversal at all and every shadow simply reports no match. Fact 4 is why the guard is mandatory rather than defensive: a traversal with zero path arguments silently searches the working directory instead. The second guard is unreachable in practice, since a collision rescan can only be triggered by a name the first traversal already indexed, but it is present so neither site can be copied elsewhere without its guard.

Leave everything else alone: argument parsing, the shadow-tree check, the overlap comparison, the shadow-discovery loop and its non-shadow classification, the per-shadow resolution and hash verification, the occupied-destination check, the two-`mv` swap, the rollback path, the counters, and the closing summary. Do not add a `mkdir` anywhere other than the block in step 3; in particular `dest_real` and `dest_shadow` inside the main loop must not gain one, because per D-02 in `04-CONTEXT.md` the trees are structurally symmetric and a discovered shadow's parent directory therefore already exists.

Match the file's existing style: 4-space indent, `print -r --` and `print -u2 -r --`, `[[ ]]` for path and string tests, `(( ))` for numeric tests.
  </action>
  <verify>
    <automated>cd /home/enzief/work/iswi/script && S=dev/local-filesys/retain-dir-struct-4-revert.zsh; zsh -n "$S" && echo "syntax=ok"; B() { grep -v '^[[:space:]]*#' "$S"; }; echo "filtered_find_sites=$(B | grep -cF 'find "${TARGET_TREES_EXISTING[@]}" -type f -print0')"; echo "empty_guards=$(B | grep -cF '${#TARGET_TREES_EXISTING[@]}')"; echo "lenient_realpath=$(B | grep -cF 'realpath -m -- "$t"')"; echo "strict_shadow_realpath=$(B | grep -cF 'realpath -- "$SHADOW_TREE"')"; echo "mkdir_calls=$(B | grep -cF 'mkdir')"; ./dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh > /tmp/dfl-green.txt 2>&1; echo "suite_exit=$?"; tail -2 /tmp/dfl-green.txt; echo "total_fails=$(grep -c '^FAIL: ' /tmp/dfl-green.txt)"; echo "preexisting_A-N_passes=$(grep -c '^PASS: Case [A-N]:' /tmp/dfl-green.txt)"</automated>
    <human-check>Run a live dry run against a scratch tree whose target root does not exist and confirm the terminal shows the would-create line, then confirm with `ls` that the directory is genuinely still absent.</human-check>
  </verify>
  <done>
`syntax=ok`; `filtered_find_sites` is 2; `empty_guards` is at least 2; `lenient_realpath` is 1; `strict_shadow_realpath` is 1, confirming the shadow root still resolves strictly; `mkdir_calls` is 1, confirming the only `mkdir` in non-comment lines of the whole script is the one added in step 3. The suite reports `suite_exit=0`, `total_fails=0`, and `preexisting_A-N_passes=74`, so every Task 1 assertion is now green and no pre-existing behavior regressed. `git diff --stat` shows `dev/local-filesys/retain-dir-struct-4-revert.zsh` as the only file this task changed.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| argv to filesystem | `<shadow_tree>` and every `<target_tree>` are unvalidated caller-supplied paths that this script now both traverses and, for the first time, creates |
| cwd to traversal scope | `find` inherits the invoking shell's working directory whenever its path arguments are absent |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-dfl-01 | Tampering | new `mkdir -p` on a caller-supplied target root | medium | mitigate | Create block is placed after the overlap guard (Task 2 step 3), so a root that resolves onto or into the shadow tree exits 1 before any directory is made. Task 1 Case S(a) asserts the rejected path is still absent from disk. |
| T-dfl-02 | Tampering | `find` traversal with an empty path array | high | mitigate | `TARGET_TREES_EXISTING` guard (Task 2 step 4) skips both traversals when no root survives. Without it, fact 4 shows `find` would silently index the caller's cwd and a bait file there could be matched and physically moved. Task 1 Case Q asserts against exactly this using a same-basename, same-hash bait file. |
| T-dfl-03 | Tampering | weakened overlap comparison via empty `realpath` output | medium | mitigate | `realpath -m --` (Task 2 step 2) removes the fact-2 failure mode in which a non-existent root resolved to the empty string and slipped past the overlap comparison. |
| T-dfl-04 | Denial of Service | dry run mutating disk | low | mitigate | Dry-run branch prints only; Task 1 Case P asserts the path stays absent and that both tree snapshots are byte-identical across the run. |
| T-dfl-SC | Tampering | package-manager installs | low | accept | No package installs of any kind. Pure zsh plus tools already required by the script (`find`, `sha256sum`, `awk`, `realpath`, `mkdir`, `mv`). |
</threat_model>

<verification>
Whole-change gates, run from the repository root after both tasks:

1. `zsh -n dev/local-filesys/retain-dir-struct-4-revert.zsh` exits 0.
2. `./dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh` exits 0 and its summary line reports 0 failures with the 74 pre-existing Case A-N assertions all still passing.
3. `./dev/local-filesys/tests/test-retain-dir-struct.zsh` exits 0, confirming the sibling scripts' suite is unaffected.
4. `git diff --stat` lists exactly two files: the swap script and its test file.
5. A live real run against a scratch fixture whose target root does not exist prints the created line, leaves the directory present afterwards, and writes nothing to stderr.
6. A live dry run over the same fixture shape prints the would-create line, leaves the directory absent afterwards, and writes nothing to stderr.
</verification>

<success_criteria>
- A real run given a target tree that is not on disk creates it and proceeds, rather than exiting 1.
- A dry run given the same input announces the creation and leaves the filesystem byte-for-byte unchanged.
- Neither mode emits stray `find` errors on stderr, and no run traverses the working directory when its target roots are all missing.
- A missing shadow tree still aborts with the original error message and exit 1, in both modes.
- Overlapping tree roots are still rejected with exit 1, whether or not the target root exists yet, and the rejected root is never created.
- Suite total: 74 pre-existing assertions plus the new Case O through Case S assertions, all passing.
</success_criteria>

<output>
Create `.planning/quick/260827-dfl-fix-dev-local-filesys-retain-dir-struct-/260827-dfl-SUMMARY.md` when done.
</output>


