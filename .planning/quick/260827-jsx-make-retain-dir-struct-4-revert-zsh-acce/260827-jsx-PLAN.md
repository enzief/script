---
phase: quick-260827-jsx
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - dev/local-filesys/retain-dir-struct-4-revert-multi.zsh
  - dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh
  - dev/local-filesys/README.md
  - /media/enzief/wdhdd/mega_wdhdd/devicesync/_deviceshadow/iphone-F2LN2G1MFF9R/revert.zsh
  - /media/enzief/wdhdd/mega_wdhdd/devicesync/_deviceshadow/iphone-F2LN2G1MFF9R/revert-revert.zsh
autonomous: true
requirements: [LOCALFS-05]

estimate:
  tokens: 105000
  raw_tokens: 70000
  tasks: 4
  confidence: low

must_haves:
  truths:
    - "retain-dir-struct-4-revert-multi.zsh accepts one or more repeated --shadow dirs and one or more repeated --target dirs in a single invocation, and swaps every verified shadow/real pair across the full cross-product"
    - "Zero --shadow, zero --target, or any leftover bare positional argument each produce the usage line on stderr with empty stdout and exit 1"
    - "Every --shadow dir that does not exist is a hard 'Error: Shadow tree not found:' before any filesystem mutation, even when other --shadow dirs are valid"
    - "Every --target dir that does not exist is mkdir -p'd on a real run and only announced as 'Would create target tree:' on a dry run"
    - "All three overlap axes (shadow-vs-shadow, target-vs-target, shadow-vs-target) reject with 'Error: Overlapping tree roots' and exit 1 before any mkdir or mv runs"
    - "dev/local-filesys/retain-dir-struct-4-revert.zsh no longer exists and git records the move to the -multi name as a rename, not an add+delete"
    - "The rewritten suite covers every behavior the 101-assertion suite covered, plus multi-shadow and the two new overlap axes, and reports 0 failures"
    - "The sibling suite dev/local-filesys/tests/test-retain-dir-struct.zsh still reports 29 passed, 0 failed"
    - "Both external wrapper scripts invoke the new -multi path with the new flag vector, and revert-revert.zsh does so in exactly one invocation instead of a three-iteration loop"
    - "dev/local-filesys/README.md documents the new script name and flag syntax with no surviving reference to the old name or the old positional usage string"
  artifacts:
    - dev/local-filesys/retain-dir-struct-4-revert-multi.zsh
    - dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh
    - dev/local-filesys/README.md
    - /media/enzief/wdhdd/mega_wdhdd/devicesync/_deviceshadow/iphone-F2LN2G1MFF9R/revert.zsh
    - /media/enzief/wdhdd/mega_wdhdd/devicesync/_deviceshadow/iphone-F2LN2G1MFF9R/revert-revert.zsh
  key_links:
    - "zparseopts '+:=' yields ALTERNATING flag/value pairs; SHADOW_TREES/TARGET_TREES are built by taking every second element (indices 2,4,6...), not by copying the array"
    - "SHADOW_TREES_ABS (strict realpath --) and TARGET_TREES_ABS (lenient realpath -m --) feed the three-axis overlap guard, which runs BEFORE the target create block, which runs BEFORE the TARGET_TREES_EXISTING filter, which gates BOTH find traversal sites"
    - "shadow_files and shadow_roots are parallel arrays appended in lockstep by a per-root find loop; the main loop becomes indexed so shadow_rel strips against the root each shadow actually came from"
    - "The wrappers' target_args/shadow_args flag vectors and the new REPO_SCRIPT absolute path are the only coupling between this repo and the two out-of-repo scripts"
---

<objective>
Generalize `dev/local-filesys/retain-dir-struct-4-revert.zsh` from one shadow tree plus N target trees (positional) to N shadow trees plus N target trees (repeatable `--shadow` / `--target` flags), rename it to `retain-dir-struct-4-revert-multi.zsh`, port its full regression suite to the new interface with added multi-root coverage, and update the README plus the two out-of-repo wrapper scripts that drive it.

Purpose: `revert-revert.zsh` currently has to invoke the swap tool three times in a loop, once per former target tree, because the tool accepts only one shadow root. Accepting repeated `--shadow` flags collapses that into a single invocation and makes the swap tool symmetric in both directions — which is what D-08's "same swap with roles reversed" claim actually requires.

Output: the renamed multi-root swap script, its rewritten test suite, an updated README, and both wrapper scripts rewritten against the new flag interface.
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
@dev/local-filesys/README.md
@.planning/phases/04-local-filesys-revert-tool/04-CONTEXT.md
@.planning/quick/260827-dfl-fix-dev-local-filesys-retain-dir-struct-/260827-dfl-SUMMARY.md
</context>

<facts_verified_at_plan_time>
Empirically confirmed on this machine before writing this plan. Do not re-derive, and do not substitute alternatives.

1. **`zparseopts` `+:=` produces alternating flag/value pairs, not bare values.** Verified with a scratch script using exactly the spec'd form
   `zparseopts -D -E -F -- -shadow+:=opt_shadow -target+:=opt_target -dry-run=opt_dryrun`:
   - `--dry-run --shadow /a --shadow "/b with space" --target /t1 --target /t2` yields
     `opt_shadow` = `(--shadow  /a  --shadow  /b with space)` (length 4) and
     `opt_target` = `(--target  /t1  --target  /t2)` (length 4), with `/b with space` preserved as ONE element.
   - Therefore the values live at indices 2, 4, 6, ... (zsh arrays are 1-indexed). Extraction MUST stride by 2. Copying the array wholesale would treat the literal string `--shadow` as a tree root.
2. **`opt_dryrun` is length 1** (`(--dry-run)`) when the flag is present, 0 when absent. The existing `(( ${#opt_dryrun} )) && DRY_RUN=1` line keeps working unchanged.
3. **With no flags at all, all three arrays are empty and `$#` is 0.** So "zero `--shadow`" and "zero `--target`" must both be detected explicitly; zparseopts does not error on them.
4. **`-F` makes an unrecognised flag a hard parse failure.** `--bogus /x` prints `zparseopts:3: bad option: --bogus` to stderr and the `|| exit 1` fires, exit 1. A missing value (`--shadow` with nothing after it) likewise prints `missing argument for option: --shadow` to stderr, exit 1. Both paths leave stdout empty.
5. **zparseopts silently leaves unrecognised BARE words in `$@`.** `--shadow /a leftover1 leftover2` parses fine and leaves `$#` = 2. Nothing warns. This is why the new interface needs an explicit `(( $# > 0 ))` usage guard — without it, a user typing the old positional form would get a silent partial run.
6. **Test-suite baseline before any change: `Results: 101 passed, 0 failed`.** Sibling suite `test-retain-dir-struct.zsh`: `Results: 29 passed, 0 failed`.
7. **`grep` on this machine is ugrep 7.8.4, not GNU grep.** It treats `$` as an anchor even mid-pattern, so a pattern containing a shell variable reference such as `"$t"` or `${#arr[@]}` silently matches nothing in default regex mode. Every source-inspection gate in this plan uses `grep -F` (fixed strings). Character-class patterns such as `^PASS: Case [A-Z]` behave normally and need no `-F`.
8. **The only non-`.planning/` references to the old script name are:** `dev/local-filesys/README.md` lines 47, 52, 55, 84; the script's own header comment line 3; and the test file's header lines 3, 10 plus the `SCRIPT4=` assignment on line 18. Historical `.planning/phases/` and `.planning/quick/` artifacts also mention it — those are completed records and MUST NOT be edited.
9. **The two wrapper scripts' hardcoded roots are pairwise non-overlapping.** `_deviceshadow/iphone-F2LN2G1MFF9R` vs `devicesync/iphone_F2LN2G1MFF9R` vs `history/2019/20191212_...` vs `history/2017/20170828_...` — no pair is equal and no pair is a prefix of another at a `/` boundary. The two NEW overlap axes therefore will not reject the real wrapper invocations.
10. **`realpath -m --` resolves a path that does not exist yet; plain `realpath --` fails and returns empty on one.** (Carried forward from quick task 260827-dfl, which is why the existing code already splits the two.)
</facts_verified_at_plan_time>

<design_decisions>

## D-jsx-1: Task ordering is rename-only, then RED test, then GREEN script, then consumers

Git detects a rename by content similarity. A `git mv` combined with a full rewrite in the same commit will NOT be recorded as a rename — similarity falls far below threshold. The task spec explicitly asks for history preservation, so the rename must land as its own commit with only the three unavoidable path-string touch-ups (the test's `SCRIPT4=` line and two header comment lines). After Task 1 the suite is still 101/0 green.

Tasks 2 (test) and 3 (script) then follow the RED→GREEN order this repo already used in quick task 260827-dfl. The RED state is honest and checkable: every assertion fails with `bad option: --shadow` from zparseopts, because the renamed script still carries the old positional interface.

## D-jsx-2: `shadow_rel` stays root-relative, computed from a parallel `shadow_roots` array

`shadow_rel` is display-only — it appears in the skip line, the three error lines, and the `Swapped:` line, and is never used to build a destination path (`dest_real="${shadow%.txt}"` uses the full path). With N shadow roots there is no single root to strip against, so discovery loops per-root and appends to `shadow_files` and `shadow_roots` in lockstep, and the main loop becomes `for (( i = 1; i <= ${#shadow_files[@]}; i++ ))`.

Rejected: stripping against whichever root happens to be a prefix (extra work for a cosmetic value), and printing absolute shadow paths (would break the existing message format and its assertions). Two shadow files from different roots can produce the same `shadow_rel` string in output; per the task spec that ambiguity is accepted, and the `-> $real_src` half of the `Swapped:` line is absolute so the operation is still traceable.

## D-jsx-3: Overlap checking is a two-line helper plus three explicit loops, not one fused loop

`roots_overlap <abs_a> <abs_b>` returns true when the two are equal or either contains the other, using the same `[[ "$a" == "$b" || "$a/" == "$b/"* || "$b/" == "$a/"* ]]` comparison the current single-axis check already uses. The three axes are then three separate loops (shadow×shadow upper-triangle, target×target upper-triangle, shadow×target full cross-product). Separate loops keep each axis independently greppable and independently testable, which matters because a missed axis is silent data damage, not a crash.

Not in scope: the comparison treats the right-hand operand as a glob, so a root path containing `*`, `?`, or `[` would be interpreted as a pattern. That is pre-existing behavior in the current single-axis check, is unrelated to this task, and is left alone.

## D-jsx-4: Ordering inside the script is fixed and load-bearing

`parse flags` → `usage guards` → `shadow existence hard error` → `abs resolution` → `three-axis overlap guard` → `target create-or-report` → `TARGET_TREES_EXISTING` filter → `find` traversals. Every arrow is a safety dependency: nothing may mutate the filesystem before the overlap guard passes (carried forward from 260827-dfl), and no `find` may run on an unfiltered target array (an empty path list makes `find` scan the invoking shell's cwd).

</design_decisions>

<tasks>

<task type="auto">
  <name>Task 1: Rename script and test to the -multi name in a rename-only commit</name>
  <files>dev/local-filesys/retain-dir-struct-4-revert-multi.zsh, dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh</files>
  <read_first>
    - `dev/local-filesys/retain-dir-struct-4-revert.zsh` line 3 — the only self-reference in the script's header comment
    - `dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh` lines 3, 10, 18 — the two header self-references and the `SCRIPT4=` assignment that resolves the script under test
  </read_first>
  <action>
Perform the rename with git so history is preserved (D-jsx-1). Run exactly:

`git mv dev/local-filesys/retain-dir-struct-4-revert.zsh dev/local-filesys/retain-dir-struct-4-revert-multi.zsh`
`git mv dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh`

Then make ONLY these three minimal path-string edits so the suite still resolves and still runs:

1. In the renamed script, the header comment's leading self-reference on line 3 changes to the new filename. Nothing else in that file changes in this task — the interface stays positional.
2. In the renamed test, the header comment's two self-references (the "Regression test for ..." line naming the script under test, and the "Run directly:" line naming the test's own path) change to the new filenames.
3. In the renamed test, the `SCRIPT4` assignment changes to resolve `retain-dir-struct-4-revert-multi.zsh` under `$LOCALFS_DIR`.

Do not touch any other line in either file. Do not touch `.planning/` artifacts (fact 8 — they are completed historical records). Do not touch `dev/local-filesys/README.md` yet; that is Task 4. Do not touch `retain-dir-struct-1/2/3.zsh` or their test.

Both files must keep mode 0755 (`git mv` preserves it; confirm rather than re-chmod).
  </action>
  <verify>
    <automated>cd /home/enzief/work/iswi/script && git add -A dev/local-filesys && echo "=== rename detection ===" && git diff --cached -M --name-status -- dev/local-filesys && echo "renames=$(git diff --cached -M --name-status -- dev/local-filesys | grep -c '^R')" && echo "=== old paths gone ===" && test ! -e dev/local-filesys/retain-dir-struct-4-revert.zsh && test ! -e dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh && echo "old_paths_absent=yes" && echo "=== modes ===" && stat -c '%a %n' dev/local-filesys/retain-dir-struct-4-revert-multi.zsh dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh && echo "=== suite still green on the unchanged positional interface ===" && ./dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh > /tmp/jsx-t1.txt 2>&1; echo "suite_exit=$?"; tail -2 /tmp/jsx-t1.txt; echo "stale_name_refs=$(grep -cF 'retain-dir-struct-4-revert.zsh' dev/local-filesys/retain-dir-struct-4-revert-multi.zsh dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh | awk -F: '{s+=$NF} END {print s+0}')"</automated>
  </verify>
  <done>
`renames=2` — git recorded both moves as renames, so `--follow` history survives. `old_paths_absent=yes`. Both files are mode 755. `suite_exit=0` and the summary line reads `Results: 101 passed, 0 failed`, proving the rename alone broke nothing. `stale_name_refs=0` — neither renamed file still names the old filename.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Rewrite the test suite against the multi-root flag interface (RED)</name>
  <files>dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh</files>
  <read_first>
    - `dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh` in full — the harness block (lines 14-134: `SCRIPT4`/`SCRIPT1` resolution, `_record`, `assert_contains`, `assert_path`, `assert_equal`, `assert_stderr_and_exit`, the mktemp `FIXROOT` + trap teardown, `make_shadow`, `tree_snapshot`) is kept VERBATIM; only the case bodies below it are rewritten
    - `dev/local-filesys/retain-dir-struct-4-revert-multi.zsh` — the current (still positional) behavior whose messages the assertions match against
  </read_first>
  <behavior>
Every existing case is ported to the flag interface by replacing its invocation form. The old form `"$SCRIPT4" [--dry-run] "$SHADOW" "$T1" "$T2"` becomes `"$SCRIPT4" [--dry-run] --shadow "$SHADOW" --target "$T1" --target "$T2"`. Spell the flags out inline at each call site; do not introduce an invocation helper function — legibility of each assertion's exact argv is the point.

**Ported cases (keep the existing letters, names, and assertion text so the port is auditable):**
- A: clean single-shadow swap — real file lands at the shadow's home path, shadow lands at the real file's vacated path, both originals gone, sha256 of the relocated real file unchanged, relocated shadow byte-identical, `Swapped:` line names the relative path, exit 0, no `Ignored` line.
- B: non-shadow `.txt` left untouched, no file named `notes` created anywhere, `Ignored 1 non-shadow .txt file(s)` reported.
- C: destination already occupied — `Error: destination already exists for `, occupying file unchanged, candidate and shadow both untouched.
- D: same directory passed as both `--shadow` and `--target` — exit 1, stderr-only.
- F: five-shadow batch (`ok`, `mismatch`, `nomatch`, `collide-resolve`, `collide-ambig`) proving a sibling still processes past an errored or skipped one; all existing assertions including `Totals: ` and exit 1.
- G: partial-swap rollback via the `mv` stub that fails on its second call — real file restored, shadow untouched, no shadow left at the target path, `Error: shadow move failed for `.
- H: skip-only run exits 0.
- I: dry-run preview accuracy — both tree snapshots unchanged, `Would swap:` present, no `Swapped: ` line, same mismatch/no-match/ambiguous reports the real run gives, `Dry run complete. No files were moved.`, exit 1 on errors, and the dry run's `Totals: ` line equal to the subsequent real run's over the same fixture.
- K: true round trip with intermediate-state assertions after the first hop, both snapshots and the shadow's bytes identical after the second hop. The second hop's invocation swaps which root carries `--shadow` and which carries `--target`.
- L: multiple target trees — each shadow's own match's tree receives that shadow, and the other tree does not.
- M: identical-content basename collision across two target trees is ambiguous, nothing moves.
- N: spaces in directory and file names survive a full round trip.
- O: real run creates a missing target tree — `Created target tree: `, directory present, the other shadow's swap still completes, stderr empty, exit 0.
- P: dry run reports `Would create target tree: ` and leaves the directory absent, no `Created target tree: ` line, the surviving tree's `Would swap:` still previewed, no `No such file or directory` stderr noise, both snapshots unchanged.
- Q: dry run where every target tree is missing does not fall back to scanning cwd — run from inside a bait directory holding a same-basename same-hash file, assert no `Would swap: ` line, the no-match skip line present, `Would create target tree: `, tree still absent, bait untouched, no stderr noise.
- R: a missing `--shadow` dir hard-errors with `Error: Shadow tree not found: ` in both normal and `--dry-run` mode.
- S: overlap guard rejects before creating — S(a) a not-yet-existing target nested under the shadow tree is rejected in both modes and never created; S(b) a target that is a parent of the shadow tree is rejected.

**Case E is repurposed** (the old "fewer than two arguments" positional case has no meaning here). New E asserts the three usage-error forms, each via `assert_stderr_and_exit` with expected exit 1 and empty stdout:
- E(a): `--shadow <dir>` with no `--target` at all → stderr contains `Usage: `
- E(b): `--target <dir>` with no `--shadow` at all → stderr contains `Usage: `
- E(c): a valid flag pair plus a trailing bare positional word → stderr contains `Usage: ` (fact 5 — zparseopts would otherwise swallow it silently)

**Case J is repurposed**: `--dry-run` with no `--shadow` and no `--target` → exit 1, stderr-only, stderr contains `Usage: `.

**New cases:**
- T — multi-shadow, single target. Two non-overlapping shadow roots S1 and S2, one target T holding both real files in different subdirectories. Assert each real file lands under the shadow root ITS OWN shadow came from (`S1/one.jpg` and `S2/two.jpg`), each shadow lands at its matched real file's vacated target path, and neither real file lands under the other shadow root. Also place one non-shadow `.txt` in each shadow root and assert the closing line reports `Ignored 2 non-shadow .txt file(s)` — proving the tally aggregates across roots rather than resetting per root.
- U — shadow-vs-shadow overlap axis. Three sub-cases, each `assert_stderr_and_exit` exit 1 / stderr contains `Error: Overlapping tree roots` / empty stdout: U(a) the same existing directory passed as `--shadow` twice; U(b) `--shadow parent --shadow parent/child` where both exist; U(c) the same pair in the reverse flag order. For U(b), additionally assert with `assert_path` that a shadow file placed in the parent root is still present afterwards — the run must reject before touching anything.
- V — target-vs-target overlap axis. V(a) the same existing directory passed as `--target` twice → exit 1, `Error: Overlapping tree roots`, stdout empty. V(b) `--target existing --target existing/nested_missing` where the nested path does NOT exist → exit 1 with the same error, AND `assert_path` that `existing/nested_missing` is still absent from disk afterwards, pinning the guard-before-create ordering on this new axis exactly as S(a) pins it on the shadow-vs-target axis.
- W — a missing `--shadow` dir among several. Pass one valid shadow root (holding a shadow whose real file is present in the target) plus one nonexistent shadow root. Assert exit 1, `Error: Shadow tree not found: ` naming the missing one, and — critically — that the valid root's shadow file and the target's real file are both still in their original positions, proving the existence check fires before any traversal or swap.
- X — full multi-shadow ↔ multi-target round trip, the shape the real wrappers use. One home root H and three target roots T1/T2/T3, with three shadows in H whose real files sit one per target tree. Snapshot all four trees. Hop 1: `--shadow H --target T1 --target T2 --target T3`. Assert all three real files are now under H and each shadow sits in the tree its file came from. Hop 2, a SINGLE invocation: `--shadow T1 --shadow T2 --shadow T3 --target H`. Assert all four tree snapshots are byte-identical to their pre-run state. This case is the direct proof that `revert-revert.zsh` can collapse its three-iteration loop.
- Y — flag ordering. Over a fresh copy of a simple fixture, run `--target T --shadow S --dry-run` (interleaved, dry-run last) and assert its `Totals: ` line equals the `Totals: ` line from the canonical `--dry-run --shadow S --target T` order over an identical fixture.
- Z — spaces in flag values. A shadow root and a target root whose directory names both contain spaces, passed through the flags, complete a clean swap — proving values survive the `+:=` array extraction unsplit (fact 1).

The rewritten file is RED at the end of this task: the script still carries the positional interface, so every invocation dies at `zparseopts` with `bad option: --shadow` and every assertion fails. That is the expected and required end state.
  </behavior>
  <action>
Rewrite `dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh` implementing the `<behavior>` above. Do NOT modify `dev/local-filesys/retain-dir-struct-4-revert-multi.zsh` in this task — it must stay byte-identical to its Task 1 state.

Preserve verbatim: the shebang, the `SCRIPT_DIR`/`LOCALFS_DIR`/`SCRIPT1`/`SCRIPT4` resolution block and its `-x` guards, `PASS_COUNT`/`FAIL_COUNT`, `_record`, `assert_contains`, `assert_path`, `assert_equal`, `assert_stderr_and_exit`, the `mktemp -d` `FIXROOT` with its emptiness guard and `trap cleanup EXIT INT TERM`, `make_shadow`, `tree_snapshot`, and the closing summary block. Update only the header comment block to describe the flag interface and the multi-root coverage.

Every fixture root stays under `$FIXROOT`; never accept a fixture path from argv or the environment; never touch anything outside `$FIXROOT`. Keep the existing per-case `# ===` banner comment style and the existing assertion-description phrasing conventions so a reviewer can diff coverage against the old suite.

Match repo style throughout: `print -r --` / `print -u2 -r --`, 4-space indent, `[[ ]]` for string tests and `(( ))` for numeric, `--` before filenames, `-print0` with `while IFS= read -r -d ''`.

Keep the file mode at 0755.
  </action>
  <verify>
    <automated>cd /home/enzief/work/iswi/script && T=dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh && zsh -n "$T" && echo "syntax=ok" && echo "script_untouched=$(git diff --quiet -- dev/local-filesys/retain-dir-struct-4-revert-multi.zsh && echo yes || echo NO)" && echo "case_banners=$(grep -cE '^# Case [A-Z]' "$T")" && B() { grep -v '^[[:space:]]*#' "$T"; } && echo "shadow_flags=$(B | grep -cF -- '--shadow')" && echo "target_flags=$(B | grep -cF -- '--target')" && echo "positional_leftovers=$(B | grep -cF '"$SCRIPT4" "$')" && ./"$T" > /tmp/jsx-t2.txt 2>&1; echo "suite_exit=$?"; tail -2 /tmp/jsx-t2.txt; echo "total_assertions=$(grep -cE '^(PASS|FAIL): ' /tmp/jsx-t2.txt)"; echo "red_reason=$(grep -cF 'bad option: --shadow' /tmp/jsx-t2.txt)"; for c in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z; do printf '%s=%s ' "$c" "$(grep -cE "^(PASS|FAIL): Case $c" /tmp/jsx-t2.txt)"; done; echo</automated>
  </verify>
  <done>
`syntax=ok`. `script_untouched=yes` — the script under test is byte-identical to its Task 1 state, so this really is a RED-only commit. `case_banners` is at least 26 (one banner per case A through Z). `shadow_flags` and `target_flags` are each well above 26, confirming every case invokes through the flags. `positional_leftovers=0` — no surviving `"$SCRIPT4" "$...` positional invocation form.

`suite_exit=1` and the summary reports a large non-zero failure count — this is the required RED state. `red_reason` is greater than 0, proving the failures come from the script not yet implementing `--shadow` (zparseopts `bad option`), not from a malformed fixture. `total_assertions` is at least 130 (the 101 ported behaviors plus the E/J repurposing and the seven new cases T-Z). Every letter A through Z reports a non-zero assertion count in the per-case tally, so no case was silently dropped in the port.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Generalize the script to N shadow roots and N target roots with three-axis overlap guarding (GREEN)</name>
  <files>dev/local-filesys/retain-dir-struct-4-revert-multi.zsh</files>
  <read_first>
    - `dev/local-filesys/retain-dir-struct-4-revert-multi.zsh` in full — every region below is identified by its current content, not by line number
    - `dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh` as Task 2 left it — the specification this task must satisfy
  </read_first>
  <behavior>
    - `--shadow /a --shadow /b --target /t` → both roots scanned, tally and swaps aggregated across them
    - `--target /t1 --target /t2 --shadow /s` → flags accepted in any order (interleaving is legal)
    - no `--shadow`, or no `--target`, or a leftover bare word → usage line on stderr, empty stdout, exit 1
    - `--shadow /nonexistent` (alone or alongside valid roots) → `Error: Shadow tree not found:` and exit 1 before any traversal
    - two `--shadow` roots that are equal or nested → `Error: Overlapping tree roots` and exit 1
    - two `--target` roots that are equal or nested → `Error: Overlapping tree roots` and exit 1, and a nested not-yet-existing target root is not created
    - any `--shadow`/`--target` pair that is equal or nested → `Error: Overlapping tree roots` and exit 1 (unchanged behavior, now pairwise)
  </behavior>
  <action>
Rewrite `dev/local-filesys/retain-dir-struct-4-revert-multi.zsh` to the multi-root flag interface. Do NOT modify the test file in this task. Apply exactly the changes below and nothing else; every region not named here keeps its current logic verbatim.

**1. Header comment.** Update the prose to describe resolving shadows found under one or more shadow roots against real files found under one or more target roots. Keep the existing reference to the 04-CONTEXT.md design (D-01 through D-09) and to the `retain-dir-struct-1.zsh` shadow format.

**2. Flag parsing.** Replace the current `zparseopts` line and the positional-argument block (the `$# -lt 2` usage check, the `SHADOW_TREE=${1%/}` / `shift` pair, and the `TARGET_TREES` build loop over `"$@"`) with:

- `zparseopts -D -E -F -- -shadow+:=opt_shadow -target+:=opt_target -dry-run=opt_dryrun || exit 1`
- the existing `DRY_RUN=0` / `(( ${#opt_dryrun} )) && DRY_RUN=1` pair, unchanged
- a `usage()` function that prints to stderr, on one line, `Usage: $0 [--dry-run] --shadow <dir> [--shadow <dir>...] --target <dir> [--target <dir>...]` and exits 1
- `SHADOW_TREES` and `TARGET_TREES` built by striding the parsed arrays by 2 starting at index 2, applying the existing trailing-slash strip to each value. Per fact 1 these arrays hold ALTERNATING flag/value pairs — index 1 is the literal string `--shadow`. Do not copy the arrays wholesale.
- three usage guards, in this order: empty `SHADOW_TREES`, empty `TARGET_TREES`, then a nonzero leftover `$#` (fact 5)

**3. Shadow existence.** Replace the single `[[ ! -d "$SHADOW_TREE" ]]` check with a loop over `SHADOW_TREES` applying the same check and the same `Error: Shadow tree not found: ` message per root. Shadow roots are read-only sources and are never auto-created.

**4. Absolute resolution.** Replace the scalar `SHADOW_TREE_ABS` with a `SHADOW_TREES_ABS` array built with strict `realpath -- ` (existence is a hard prerequisite, already enforced in step 3). Keep `TARGET_TREES_ABS` built with lenient `realpath -m -- ` (fact 10 — a target root may legitimately not exist yet). Keep the existing explanatory comment about why the two differ, generalized to arrays.

**5. Three-axis overlap guard** (D-jsx-3), replacing the current single shadow-vs-targets loop:

- a `roots_overlap()` helper taking two absolute paths and returning success when they are equal or either contains the other, using the same three-way `[[ ]]` comparison the current check uses
- a `reject_overlap()` helper printing `Error: Overlapping tree roots: $1 and $2` to stderr and exiting 1, preserving the existing message format exactly
- axis 1, shadow vs shadow: upper-triangle double loop over `SHADOW_TREES_ABS` indices
- axis 2, target vs target: upper-triangle double loop over `TARGET_TREES_ABS` indices
- axis 3, shadow vs target: full cross-product, shadow first in the rejection message (matching today's argument order)

Comment each axis with the concrete failure it prevents: nested shadow roots enumerate the same shadow twice; nested target roots double-count basenames and turn unique matches into false ambiguity; a shadow root inside a target root makes the shadow itself a swap candidate.

**6. Target create-or-report and `TARGET_TREES_EXISTING` filter.** Keep both blocks exactly as they are, including the comment explaining that the create block sits after the overlap guard so a rejected root is never mkdir'd, and the comment explaining the empty-path-argument `find` hazard.

**7. Shadow discovery across roots.** Replace the single `find "$SHADOW_TREE" ...` traversal with an outer loop over `SHADOW_TREES` containing the existing `while IFS= read -r -d ''` process-substitution loop over `find "$s" -type f -name "*.txt" -print0`. Keep the 64-char-lowercase-hex first-field discriminator and the `nonshadow_count` tally verbatim; the tally accumulates across roots because it is declared once before the outer loop. Append to a new `shadow_roots` array in lockstep with every `shadow_files` append (D-jsx-2). No empty-array guard is needed here: `SHADOW_TREES` is non-empty by the usage guard and every element exists by step 3, so `find` always receives exactly one real path.

**8. Header line.** Replace the `Reverting shadows from '$SHADOW_TREE' against ...` line with one reporting both counts: the number of shadow trees and the number of target trees. Keep the trailing `...` and the separator line that follows.

**9. Main loop.** Convert `for shadow in "${shadow_files[@]}"` to an indexed `for (( i = 1; i <= ${#shadow_files[@]}; i++ ))`, binding `shadow` from `shadow_files[$i]` and a local shadow root from `shadow_roots[$i]`, and deriving `shadow_rel` by stripping that root. Everything else inside the loop — `stored_hash`, `dest_real`, `base`, the `name_count` lookup, the collision rescan, the mandatory hash verification, the occupied-destination check, the dry-run branch, the two `mv` calls, and the rollback block — stays byte-for-byte as it is. This logic is already indifferent to how many roots the shadow or the real file came from.

**10. Closing summary and exit codes.** Unchanged.

Keep the file mode at 0755. Match repo style: `print -r --` / `print -u2 -r --`, 4-space indent, `[[ ]]` for string tests and `(( ))` for numeric, `--` before filenames, `-print0` with `while IFS= read -r -d ''`, errors to stderr.
  </action>
  <verify>
    <automated>cd /home/enzief/work/iswi/script && S=dev/local-filesys/retain-dir-struct-4-revert-multi.zsh && zsh -n "$S" && echo "syntax=ok" && echo "test_untouched=$(git diff --quiet -- dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh && echo yes || echo NO)" && B() { grep -v '^[[:space:]]*#' "$S"; } && echo "zparseopts_multi=$(B | grep -cF -- '-shadow+:=opt_shadow')" && echo "stride_extraction=$(B | grep -cF 'i += 2')" && echo "usage_guards=$(B | grep -cF 'usage')" && echo "overlap_helper=$(B | grep -cF 'roots_overlap')" && echo "reject_helper=$(B | grep -cF 'reject_overlap')" && echo "shadow_abs_strict=$(B | grep -cF 'realpath -- "$s"')" && echo "target_abs_lenient=$(B | grep -cF 'realpath -m -- "$t"')" && echo "shadow_roots_parallel=$(B | grep -cF 'shadow_roots')" && echo "existing_filter_finds=$(B | grep -cF 'find "${TARGET_TREES_EXISTING[@]}" -type f -print0')" && echo "empty_guards=$(B | grep -cF '${#TARGET_TREES_EXISTING[@]}')" && echo "old_scalar_refs=$(B | grep -cF 'SHADOW_TREE_ABS')" && echo "mkdir_calls=$(B | grep -cF 'mkdir')" && ./dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh > /tmp/jsx-t3.txt 2>&1; echo "suite_exit=$?"; tail -2 /tmp/jsx-t3.txt; echo "fails=$(grep -c '^FAIL: ' /tmp/jsx-t3.txt)"; ./dev/local-filesys/tests/test-retain-dir-struct.zsh > /tmp/jsx-t3-sib.txt 2>&1; echo "sibling_exit=$?"; tail -1 /tmp/jsx-t3-sib.txt</automated>
  </verify>
  <done>
`syntax=ok`. `test_untouched=yes` — the suite written in Task 2 was satisfied, not edited to fit. `zparseopts_multi=1` and `stride_extraction` is 2 (one stride loop per array), confirming values are extracted by index rather than copied wholesale. `usage_guards` is at least 4 (the function plus its three call sites). `overlap_helper` is at least 7 (definition plus six call sites across the three axes) and `reject_helper` is at least 4. `shadow_abs_strict=1` and `target_abs_lenient=1`, confirming the strict/lenient split survived the array conversion. `shadow_roots_parallel` is at least 3 (declaration, append, indexed read). `existing_filter_finds=2` and `empty_guards` is at least 2, confirming both target traversals still route through the filtered array. `old_scalar_refs=0` — no stale single-root variable remains. `mkdir_calls=1`.

`suite_exit=0`, `fails=0`, and the summary line matches the `total_assertions` count from Task 2 with 0 failed — every ported behavior and every new multi-root case is green. `sibling_exit=0` with `Results: 29 passed, 0 failed`, confirming no collateral damage to the scripts 1/2/3 suite.
  </done>
</task>

<task type="auto">
  <name>Task 4: Update the README and both out-of-repo wrapper scripts to the new interface</name>
  <files>dev/local-filesys/README.md, /media/enzief/wdhdd/mega_wdhdd/devicesync/_deviceshadow/iphone-F2LN2G1MFF9R/revert.zsh, /media/enzief/wdhdd/mega_wdhdd/devicesync/_deviceshadow/iphone-F2LN2G1MFF9R/revert-revert.zsh</files>
  <precondition>The external drive is mounted and both wrapper scripts are readable and writable at `/media/enzief/wdhdd/mega_wdhdd/devicesync/_deviceshadow/iphone-F2LN2G1MFF9R/`. If either path is absent, halt and report — do not create it.</precondition>
  <read_first>
    - `/media/enzief/wdhdd/mega_wdhdd/devicesync/_deviceshadow/iphone-F2LN2G1MFF9R/revert.zsh` — currently a single invocation passing `"$@"` then the shadow root then the target array, all positional
    - `/media/enzief/wdhdd/mega_wdhdd/devicesync/_deviceshadow/iphone-F2LN2G1MFF9R/revert-revert.zsh` — currently a three-iteration loop with a `failed` exit-code accumulator, and a header comment explaining that the loop exists because the tool took only one shadow root
    - `dev/local-filesys/README.md` — the workflow section's step 5 entry, its usage fenced block, the behavior subsection heading, and the script-3-vs-script-4 comparison subsection
  </read_first>
  <action>
Three files, no behavior in the repo script changes. The two wrapper scripts are OUTSIDE this git repo (separate external drive, no git tracking there): edit them as plain filesystem writes with the Edit/Write tool, do NOT `git add` or commit them, and do not expect them in this repo's `git status`.

**Do not execute either wrapper script, and do not run the repo script against any path under `/media/enzief/wdhdd/`.** All verification for this task is syntax checking, static inspection, and an argv-capture harness that redirects the wrappers at a throwaway stub in a temp directory.

**A. `revert.zsh`** — keep the existing header comment, the `SHADOW_TREE="${0:A:h}"` line, and the `TARGET_TREES` array verbatim. Point `REPO_SCRIPT` at `/home/enzief/work/iswi/script/dev/local-filesys/retain-dir-struct-4-revert-multi.zsh`. Before the invocation, build a `target_args` array by looping over `TARGET_TREES` and appending the flag and the value as two elements per entry. Invoke once as: the repo script, then `"$@"`, then the shadow flag with `$SHADOW_TREE`, then the expanded `target_args`.

**B. `revert-revert.zsh`** — point `REPO_SCRIPT` at the same new path. Keep `HOME_TREE="${0:A:h}"` and the `FORMER_TARGET_TREES` array verbatim. Build a `shadow_args` array by looping over `FORMER_TARGET_TREES` and appending the flag and the value as two elements per entry. Replace the entire three-iteration loop, its per-tree `=== Reverting against: ... ===` banner, the `failed=0` accumulator, and the trailing `exit $failed` with a SINGLE invocation: the repo script, then `"$@"`, then the expanded `shadow_args`, then the target flag with `$HOME_TREE`. The single invocation's own exit code is the whole result, so no accumulator and no explicit exit line are needed.

Rewrite the header comment to state the new rationale: after `revert.zsh` runs, the shadow `.txt` files are scattered across the three former target trees, and the tool now accepts repeated shadow flags, so all three are handed to one invocation that swaps everything back into this directory in a single pass (D-08: the same swap with roles reversed). Keep the closing "Any args given here (e.g. `--dry-run`) are forwarded as-is." note and keep the file's overall structure and comment style consistent with `revert.zsh`.

**C. `dev/local-filesys/README.md`** — update the four sites that name the old script (workflow step 5's bold heading, its fenced usage block, the behavior subsection heading, and the script-3-vs-script-4 comparison bullet) to the new filename. Replace the fenced usage block with the flag form: the script name, then the optional dry-run flag, then one or more shadow flags with a dir placeholder, then one or more target flags with a dir placeholder. Update step 5's prose so it says the script accepts more than one shadow tree and more than one target tree in a single invocation.

In the behavior bullet list, generalize the two bullets that assume a single shadow root: the bullet about locating the real file by basename now says "across the target trees" (already correct, leave it), and the overlapping-roots bullet must be expanded to name all three axes — shadow-vs-shadow, target-vs-target, and shadow-vs-target — and state that the rejection happens before any directory is created or any file is moved. Add one bullet noting that every shadow tree must already exist while a missing target tree is created (or, under dry run, only announced). Leave every other bullet, the "Typical flow" line, the "Other scripts" section, the "Requirements" section, and the "Tests" section untouched.
  </action>
  <verify>
    <automated>cd /home/enzief/work/iswi/script && W=/media/enzief/wdhdd/mega_wdhdd/devicesync/_deviceshadow/iphone-F2LN2G1MFF9R && R=dev/local-filesys/README.md && zsh -n "$W/revert.zsh" && zsh -n "$W/revert-revert.zsh" && echo "wrapper_syntax=ok" && echo "new_path_refs=$(grep -cF 'retain-dir-struct-4-revert-multi.zsh' "$W/revert.zsh" "$W/revert-revert.zsh" | awk -F: '{s+=$NF} END{print s+0}')" && echo "old_path_refs=$(grep -cF '/retain-dir-struct-4-revert.zsh' "$W/revert.zsh" "$W/revert-revert.zsh" | awk -F: '{s+=$NF} END{print s+0}')" && echo "rr_loop_removed=$(grep -cF 'for st in' "$W/revert-revert.zsh")" && echo "rr_accumulator_removed=$(grep -cF 'failed' "$W/revert-revert.zsh")" && TMP=$(mktemp -d) && printf '#!/bin/zsh\nfor a in "$@"; do print -r -- "$a"; done\n' > "$TMP/stub.zsh" && chmod +x "$TMP/stub.zsh" && for f in revert revert-revert; do sed "s|^REPO_SCRIPT=.*|REPO_SCRIPT=\"$TMP/stub.zsh\"|" "$W/$f.zsh" > "$TMP/$f.zsh"; chmod +x "$TMP/$f.zsh"; done && echo "=== revert.zsh emitted argv ===" && "$TMP/revert.zsh" --dry-run && echo "=== revert-revert.zsh emitted argv ===" && "$TMP/revert-revert.zsh" --dry-run && echo "rev_shadow=$("$TMP/revert.zsh" | grep -cFx -- '--shadow') rev_target=$("$TMP/revert.zsh" | grep -cFx -- '--target')" && echo "rr_shadow=$("$TMP/revert-revert.zsh" | grep -cFx -- '--shadow') rr_target=$("$TMP/revert-revert.zsh" | grep -cFx -- '--target')" && echo "rev_dryrun_forwarded=$("$TMP/revert.zsh" --dry-run | grep -cFx -- '--dry-run') rr_dryrun_forwarded=$("$TMP/revert-revert.zsh" --dry-run | grep -cFx -- '--dry-run')" && rm -rf -- "$TMP" && echo "=== wrapper roots are pairwise non-overlapping (lexical only, nothing executed against them) ===" && zsh -c 'W='"$W"'; ROOTS=("$W"); while IFS= read -r l; do l=${l//\"/}; l=${l//[[:space:]]/}; [[ -n "$l" ]] && ROOTS+=("${l%/}"); done < <(grep -F "\"/media/" "$W/revert.zsh"); print -r -- "root_count=${#ROOTS[@]}"; bad=0; for ((i=1;i<=${#ROOTS[@]};i++)); do for ((j=i+1;j<=${#ROOTS[@]};j++)); do a=${ROOTS[$i]}; b=${ROOTS[$j]}; if [[ "$a" == "$b" || "$a/" == "$b/"* || "$b/" == "$a/"* ]]; then print -r -- "OVERLAP: $a AND $b"; bad=1; fi; done; done; print -r -- "wrapper_root_overlaps=$bad"' && echo "=== README ===" && echo "readme_new_name=$(grep -cF 'retain-dir-struct-4-revert-multi.zsh' "$R")" && echo "readme_old_name=$(grep -cF 'retain-dir-struct-4-revert.zsh' "$R")" && echo "readme_flag_usage=$(grep -cF -- '--shadow' "$R")" && echo "readme_old_usage=$(grep -cF '<shadow_tree> <target_tree>' "$R")" && echo "=== repo scripts untouched by this task ===" && git diff --name-only -- dev/local-filesys/retain-dir-struct-4-revert-multi.zsh dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh && ./dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh 2>&1 | tail -1</automated>
  </verify>
  <done>
`wrapper_syntax=ok`. `new_path_refs=2` (one per wrapper) and `old_path_refs=0`. `rr_loop_removed=0` and `rr_accumulator_removed=0` — the three-iteration loop and its exit-code accumulator are gone from `revert-revert.zsh`.

Argv capture: `rev_shadow=1 rev_target=3` — `revert.zsh` emits exactly one shadow flag and one target flag per entry in its three-entry array. `rr_shadow=3 rr_target=1` — `revert-revert.zsh` emits three shadow flags and one target flag in a SINGLE invocation, which is the whole point of the change. `rev_dryrun_forwarded=1` and `rr_dryrun_forwarded=1` — pass-through args still reach the tool.

`root_count=4` and `wrapper_root_overlaps=0` with no `OVERLAP:` lines — the wrappers' four real roots are pairwise non-overlapping under the exact comparison the new guard uses, so the two new axes will not reject the real invocations. This is a lexical string check; nothing was executed against any path under `/media/`.

README: `readme_new_name` is at least 4, `readme_old_name=0`, `readme_flag_usage` is at least 1, `readme_old_usage=0`.

`git diff --name-only` over the two repo scripts prints nothing — this task changed no repo script — and the suite's summary line still reads 0 failed.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| caller argv → root arrays | Repeatable `--shadow`/`--target` values are unvalidated caller input that become `find` traversal roots, `mkdir -p` targets, and `mv` destinations |
| shadow `.txt` content → swap decision | The stored hash read from a `.txt` file decides whether a real file is moved |
| repo script ↔ out-of-repo wrappers | Two untracked scripts on an external drive invoke the repo script by absolute path; nothing in CI or `git status` catches drift between them |

No package-manager installs (npm/pip/cargo) are introduced by this task, so no package-legitimacy gate applies.

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-jsx-01 | Tampering | shadow-vs-shadow overlap axis (`SHADOW_TREES_ABS`) | critical | mitigate | Nested or equal `--shadow` roots make the per-root `find` loop enumerate the same shadow file twice. The first pass swaps it; the second pass reads a now-vacated source (awk noise, empty `stored_hash`) and finds the destination occupied, so a legitimate swap is reported as an error — and with two equal roots every count in the summary doubles. Task 3 step 5 axis 1 adds an upper-triangle `roots_overlap` guard over `SHADOW_TREES_ABS` before any traversal; Task 2 Case U asserts rejection for the equal, parent-first, and child-first forms and that a shadow in the parent root is untouched. |
| T-jsx-02 | Tampering | target-vs-target overlap axis (`TARGET_TREES_ABS`) | high | mitigate | Nested or equal `--target` roots double-count every basename in `name_count`, pushing otherwise-unique matches down the collision branch where the same physical file appears twice in `candidates` and both hash-match, producing a false `ambiguous match` error that silently refuses correct swaps. Task 3 step 5 axis 2 adds the upper-triangle guard over `TARGET_TREES_ABS`; Task 2 Case V asserts rejection for the equal and nested forms. |
| T-jsx-03 | Tampering | shadow-vs-target overlap axis (cross-product) | critical | mitigate | A shadow root inside a target root (or vice versa) makes shadow files themselves swap candidates and can relocate a shadow onto its own tree. This axis exists today for one shadow root; Task 3 step 5 axis 3 generalizes it to the full cross-product. Task 2 Cases D, S(a), S(b) assert rejection including for a not-yet-existing nested target. |
| T-jsx-04 | Denial of Service | `find` with zero path arguments | high | mitigate | A target array filtered to empty, handed to `find`, silently scans the invoking shell's cwd and offers unrelated files as swap candidates. The existing `TARGET_TREES_EXISTING` filter and its `(( ${#...[@]} ))` guards at both traversal sites are preserved verbatim (Task 3 step 6) and re-asserted by Case Q. |
| T-jsx-05 | Tampering | `mkdir -p` ordering vs. the overlap guard | high | mitigate | Auto-creating a target root before validation would materialize a directory inside or onto a root the guard is about to reject. Task 3 step 5 places all three axes strictly before the create block (D-jsx-4); Cases S(a) and V(b) both assert the rejected not-yet-existing root is still absent from disk after the run. |
| T-jsx-06 | Spoofing | leftover bare positional arguments | medium | mitigate | Fact 5: `zparseopts` silently leaves unrecognised bare words in `$@`. Without a guard, a user typing the old positional form would get a run over a partial root set with no warning and real `mv` calls against it. Task 3 step 2 adds the `(( $# > 0 ))` usage guard; Case E(c) asserts it. |
| T-jsx-07 | Tampering | value extraction from the `+:=` arrays | high | mitigate | Fact 1: the parsed arrays hold alternating flag/value pairs. Copying them wholesale would make the literal string `--shadow` a tree root — `realpath -m --` would resolve it against cwd and it would enter the guard and `find` as a real path. Task 3 step 2 mandates the stride-by-2 extraction; the Task 3 gate greps for two `i += 2` sites; Case Z proves values with spaces survive extraction unsplit. |
| T-jsx-08 | Tampering | out-of-repo wrapper drift | high | mitigate | After the rename the wrappers point at a path that no longer exists; a partially-updated wrapper could instead emit a malformed flag vector that the tool accepts. Task 4 captures each wrapper's exact argv against a throwaway stub and asserts the counts (`1`/`3` and `3`/`1`), plus a lexical pairwise non-overlap check of their four real roots so the two new axes cannot reject them in production. |
| T-jsx-09 | Repudiation | git history across the rename | low | mitigate | A rename fused with a full rewrite falls below git's similarity threshold and is recorded as add+delete, losing `--follow` history on a file that physically moves real data. Task 1 is a rename-only commit touching three path strings; its gate asserts `renames=2` in `git diff --cached -M --name-status`. |
| T-jsx-10 | Information disclosure | ambiguous `shadow_rel` across shadow roots | low | accept | Two shadows from different roots can print the same relative path in the skip/error/swap lines. The task spec explicitly scopes cross-root relative-path collision out; the `Swapped:` line's `-> $real_src` half is absolute, so every completed operation remains traceable. Accepted, recorded in D-jsx-2. |
| T-jsx-11 | Tampering | glob metacharacters in a root path | low | accept | `roots_overlap` uses the right-hand operand as a `[[ ]]` glob pattern, so a root containing `*`, `?`, or `[` is matched as a pattern. This is pre-existing behavior in the current single-axis check, unrelated to this task, and out of scope per the repo's surgical-change rule. Recorded in D-jsx-3. |
| T-jsx-12 | Tampering | live runs against real device-shadow data | critical | mitigate | Any execution of the wrappers or the repo script against `/media/enzief/wdhdd/...` during this task would `mv` real photo archives. Task 4's `<action>` forbids it outright; every Task 4 gate is syntax-only, static-grep, argv-capture against a temp stub, or lexical string comparison. Tasks 1-3 run only against `mktemp -d` fixtures owned by the suite. |
</threat_model>

<verification>
1. `zsh -n` passes on `dev/local-filesys/retain-dir-struct-4-revert-multi.zsh`, its test file, and both wrapper scripts.
2. `./dev/local-filesys/tests/test-retain-dir-struct-4-revert-multi.zsh` exits 0 with 0 failures and at least 130 total assertions, with a non-zero assertion count recorded for every case letter A through Z.
3. `./dev/local-filesys/tests/test-retain-dir-struct.zsh` still reports `Results: 29 passed, 0 failed`.
4. `git log --oneline --follow -- dev/local-filesys/retain-dir-struct-4-revert-multi.zsh` reaches commits predating this task, proving the rename preserved history.
5. `dev/local-filesys/retain-dir-struct-4-revert.zsh` and `dev/local-filesys/tests/test-retain-dir-struct-4-revert.zsh` no longer exist.
6. Neither wrapper script nor the repo script was executed against any path under `/media/enzief/wdhdd/` at any point.
7. No file under `.planning/phases/` or `.planning/quick/` other than this task's own directory was modified.
</verification>

<success_criteria>
- The swap tool accepts repeated `--shadow` and repeated `--target` flags in any order, rejects zero of either and any leftover positional, and swaps correctly across the full root cross-product.
- All three overlap axes reject with the existing `Error: Overlapping tree roots` message and exit 1 before any `mkdir` or `mv`.
- Every shadow root is a hard existence prerequisite; every target root is auto-created on a real run and only announced on a dry run.
- Every behavior the 101-assertion suite covered has an equivalent assertion in the rewritten suite, plus new coverage for multi-shadow discovery, the two new overlap axes, a missing shadow root among several, and the full multi-shadow ↔ multi-target round trip.
- `revert-revert.zsh` performs its work in one invocation instead of three, and both wrappers emit the exact flag vector the argv-capture harness asserts.
- The README describes the new name, the flag syntax, and all three overlap axes, with no stale references.
</success_criteria>

<output>
Create `.planning/quick/260827-jsx-make-retain-dir-struct-4-revert-zsh-acce/260827-jsx-SUMMARY.md` when done.
</output>

<!-- planner-discipline-allow: retain-dir-struct-4-revert.zsh -- the literal is unavoidable in Task 1's `git mv` source path and in Task 4's read_first reference; every negative grep for it is scoped to a specific file (the two renamed files in Task 1, README.md and the two wrappers in Task 4), never to this plan. -->
<!-- planner-discipline-allow: <shadow_tree> <target_tree> -- appears only in Task 4's negative gate, scoped to dev/local-filesys/README.md. -->
