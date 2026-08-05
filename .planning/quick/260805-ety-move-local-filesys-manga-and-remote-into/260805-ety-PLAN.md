---
phase: quick
plan: 260805-ety
type: execute
wave: 1
depends_on: []
files_modified:
  - dev/local-filesys/list-missing-pages.zsh
  - dev/local-filesys/retain-dir-struct-1.zsh
  - dev/local-filesys/retain-dir-struct-2-sorted.zsh
  - dev/local-filesys/retain-dir-struct-3-find-sorted.zsh
  - dev/local-filesys/rotate
  - dev/manga/number-pages.zsh
  - dev/remote/rename-remote-files-1-match-remote.zsh
  - dev/remote/rename-remote-files-2-rename-local.zsh
  - .claude/CLAUDE.md
  - .planning/codebase/ARCHITECTURE.md
  - .planning/codebase/STRUCTURE.md
  - .planning/codebase/CONCERNS.md
  - .planning/codebase/CONVENTIONS.md
  - .planning/codebase/TESTING.md
  - .planning/codebase/STACK.md
  - .planning/codebase/INTEGRATIONS.md
  - .planning/phases/01-local-filesystem/01-CONTEXT.md
  - .planning/phases/01-local-filesystem/01-PATTERNS.md
  - .planning/phases/01-local-filesystem/01-01-PLAN.md
  - .planning/phases/01-local-filesystem/01-02-PLAN.md
autonomous: true
requirements: [QUICK-260805-ety]

estimate:
  tokens: 48000
  raw_tokens: 24000
  tasks: 4
  confidence: low

must_haves:
  truths:
    - All 8 tracked scripts live under dev/ and git records them as renames, not delete+add
    - local-filesys/, manga/, and remote/ no longer exist at the repository root
    - Every path reference in every tracked doc and plan resolves to a file that exists on disk
    - The two Phase 1 execution plans remain semantically identical - only literal path strings changed
    - The STRUCTURE.md tree and the ARCHITECTURE.md box diagram still render correctly
  artifacts:
    - dev/local-filesys/ (5 files)
    - dev/manga/ (1 file)
    - dev/remote/ (2 files)
  key_links:
    - Every `<verify>` command in 01-01-PLAN.md and 01-02-PLAN.md points at a path that exists
    - The `files_modified` frontmatter of both Phase 1 plans matches the new on-disk layout
---

<objective>
Move `local-filesys/`, `manga/`, and `remote/` into a new top-level `dev/` directory, mirroring sibling project `../byse`'s convention of keeping real source under `dev/` while docs, config, and planning stay at the repo root. Then update every path reference across the repo so nothing dangles.

Purpose: align this repo's layout with the sibling project so the root holds only meta-directories (`.claude/`, `.planning/`, `.git/`) and one source directory.
Output: `dev/{local-filesys,manga,remote}/` with git-preserved history, plus 12 updated reference files.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

This is a pure reorganization. No script logic changes, no behavior changes, no new files
beyond the `dev/` directory itself.

**Audit already performed - do not re-discover it.** A repo-wide grep established:

1. The repo root contains only `.claude/`, `.git/`, `.planning/`, `local-filesys/`, `manga/`,
   `remote/`. No README, no `.gitignore`, no other top-level files.
2. The 8 tracked script files are listed in Task 1.
3. **No script references any other script by path.** Each is a standalone CLI entry point.
   Self-references in help text use the bare filename with no directory prefix
   (e.g. `Usage: number-pages.zsh ...`), so no script file needs editing at all.
4. **No false positives exist.** Every occurrence of `local-filesys/`, `manga/`, or `remote/`
   in the repo is a reference to one of these three repo directories. None is a user data path
   (there is no `/home/user/manga/`-style example anywhere), and none is a non-path string
   (`remote_map[$size]`, `rclone remote "mega"`, and `devicesync/2019` have no matching slash).
   This is what makes the blanket rewrite in Task 2 safe.
5. `ROADMAP.md`, `REQUIREMENTS.md`, and `PROJECT.md` reference scripts by bare filename only
   (`number-pages.zsh`, not `manga/number-pages.zsh`) and therefore need no edits. Leave them
   untouched.
6. `.planning/phases/01-local-filesystem/` does NOT match the rewrite pattern: `local-filesys`
   there is followed by `tem`, not `/`. Phase directory names are unaffected.

**Out of scope - do not do these:** the `STRUCTURE.md` tree omits
`local-filesys/list-missing-pages.zsh` and `local-filesys/rotate`; it was already stale before
this task. Do not add them. Do not refresh, regenerate, or otherwise improve any codebase doc
beyond the mechanical path change.
</context>

<tasks>

<task type="tracer">
  <name>Task 1: Move all 8 scripts under dev/ with git mv</name>
  <files>dev/local-filesys/*, dev/manga/*, dev/remote/*</files>
  <action>
From the repository root, create the parent directory and move each tracked file with `git mv`
so git records renames and preserves history. Plain `mv` plus `git add`/`git rm` is not
acceptable - it breaks `git log --follow`.

Run `mkdir -p dev`, then `git mv local-filesys manga remote dev/` (moving the three directories
wholesale is fewer operations than 8 individual file moves and produces the same rename records).

The 8 files that must end up relocated:

    local-filesys/list-missing-pages.zsh              -> dev/local-filesys/list-missing-pages.zsh
    local-filesys/retain-dir-struct-1.zsh             -> dev/local-filesys/retain-dir-struct-1.zsh
    local-filesys/retain-dir-struct-2-sorted.zsh      -> dev/local-filesys/retain-dir-struct-2-sorted.zsh
    local-filesys/retain-dir-struct-3-find-sorted.zsh -> dev/local-filesys/retain-dir-struct-3-find-sorted.zsh
    local-filesys/rotate                              -> dev/local-filesys/rotate
    manga/number-pages.zsh                            -> dev/manga/number-pages.zsh
    remote/rename-remote-files-1-match-remote.zsh     -> dev/remote/rename-remote-files-1-match-remote.zsh
    remote/rename-remote-files-2-rename-local.zsh     -> dev/remote/rename-remote-files-2-rename-local.zsh

Do not edit the contents of any moved file. Do not touch file modes - `git mv` preserves the
executable bit, and these scripts must stay executable.
  </action>
  <verify>
    <automated>test "$(git ls-files dev | wc -l)" -eq 8 &amp;&amp; test ! -e local-filesys &amp;&amp; test ! -e manga &amp;&amp; test ! -e remote &amp;&amp; test -x dev/local-filesys/rotate &amp;&amp; test -x dev/manga/number-pages.zsh &amp;&amp; git status --porcelain | grep -c '^R' | grep -qx 8</automated>
  </verify>
  <done>
    - `git ls-files dev` lists exactly the 8 files above
    - `local-filesys`, `manga`, and `remote` no longer exist at the repo root (`test ! -e` succeeds for each)
    - `git status --porcelain` shows 8 lines beginning with `R` (renames), and zero lines beginning with `A` or `D` for these paths
    - Every moved `.zsh` file and `dev/local-filesys/rotate` is still executable
    - `git diff --cached -M --stat` reports 0 insertions and 0 deletions of content
  </done>
</task>

<task type="auto">
  <name>Task 2: Rewrite path references across all 12 reference files</name>
  <files>.claude/CLAUDE.md, .planning/codebase/ARCHITECTURE.md, .planning/codebase/STRUCTURE.md, .planning/codebase/CONCERNS.md, .planning/codebase/CONVENTIONS.md, .planning/codebase/TESTING.md, .planning/codebase/STACK.md, .planning/codebase/INTEGRATIONS.md, .planning/phases/01-local-filesystem/01-CONTEXT.md, .planning/phases/01-local-filesystem/01-PATTERNS.md, .planning/phases/01-local-filesystem/01-01-PLAN.md, .planning/phases/01-local-filesystem/01-02-PLAN.md</files>
  <action>
Apply one idempotent rewrite rule to all 12 files. The rule prefixes each of the three directory
tokens with `dev/`, and tolerates a `dev/` prefix that is already present so a re-run after a
partial failure cannot produce `dev/dev/`:

    sed -i -E 's#(dev/)?(local-filesys|manga|remote)/#dev/\2/#g' \
      .claude/CLAUDE.md \
      .planning/codebase/ARCHITECTURE.md \
      .planning/codebase/STRUCTURE.md \
      .planning/codebase/CONCERNS.md \
      .planning/codebase/CONVENTIONS.md \
      .planning/codebase/TESTING.md \
      .planning/codebase/STACK.md \
      .planning/codebase/INTEGRATIONS.md \
      .planning/phases/01-local-filesystem/01-CONTEXT.md \
      .planning/phases/01-local-filesystem/01-PATTERNS.md \
      .planning/phases/01-local-filesystem/01-01-PLAN.md \
      .planning/phases/01-local-filesystem/01-02-PLAN.md

This rule was dry-tested against every reference shape present in the repo and is correct for
all of them: bare (`manga/number-pages.zsh`), dot-relative (`./manga/x`), absolute
(`/home/enzief/work/iswi/script/remote/y.zsh`), already-prefixed (`dev/local-filesys/z`, left
alone), and paths appearing as the trailing file argument of a grep command
(`grep -cE 'done < <\(find' local-filesys/a.zsh` - the quoted regex has no slash-suffixed token,
so only the file argument changes). It does not touch `01-local-filesystem/`, `remote_map[$size]`,
or `devicesync/2019`.

**The two Phase 1 plan files are already committed and verified. Change nothing in them but
literal path strings.** The sed rule guarantees this - do not hand-edit them. In those files the
rewrite lands on: YAML `files_modified:` entries, `must_haves` `path:`/`from:`/`to:` values,
`<files>` and `<read_first>` paths, `<action>` prose, `<acceptance_criteria>` grep commands,
`<verify><automated>` commands, and the not-yet-created test path
`local-filesys/tests/test-retain-dir-struct.zsh` -> `dev/local-filesys/tests/test-retain-dir-struct.zsh`.
Task structure, wording, and acceptance-criteria semantics stay byte-identical otherwise.

**Expected temporary damage:** this blanket rule also rewrites two ASCII diagrams that must not
be handled this way - the directory tree in `STRUCTURE.md` and the boxed layer diagram row in
`ARCHITECTURE.md`. Leaving them broken here is intentional; Task 3 overwrites both blocks
wholesale, so Task 3 must run after Task 2, never before.
  </action>
  <verify>
    <automated>test "$(grep -rlP '(?&lt;!dev/)\b(local-filesys|manga|remote)/' --exclude-dir=.git --exclude-dir=quick . | wc -l)" -eq 0 &amp;&amp; git diff --stat -- .planning/phases/01-local-filesystem/01-01-PLAN.md .planning/phases/01-local-filesystem/01-02-PLAN.md | grep -qv 'insertion'</automated>
  </verify>
  <done>
    - `grep -rlP '(?&lt;!dev/)\b(local-filesys|manga|remote)/' --exclude-dir=.git --exclude-dir=quick .` returns no files
    - `grep -rc 'dev/dev/' --exclude-dir=.git . | grep -v ':0$'` returns nothing (no double prefix anywhere)
    - `git diff --numstat` for `01-01-PLAN.md` and `01-02-PLAN.md` shows added lines equal to deleted lines (pure in-place substitution, no lines added or removed)
    - `git diff -U0 .planning/phases/01-local-filesystem/` contains no changed line where the only difference is something other than a `dev/` insertion
    - `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, and `.planning/PROJECT.md` are unmodified (`git status --porcelain` does not list them)
  </done>
</task>

<task type="auto">
  <name>Task 3: Repair the two ASCII diagrams mangled by Task 2</name>
  <files>.planning/codebase/STRUCTURE.md, .planning/codebase/ARCHITECTURE.md</files>
  <action>
Task 2's blanket rewrite broke two hand-aligned ASCII blocks. Both are column-sensitive and must
be replaced wholesale rather than patched token by token.

**3a. `STRUCTURE.md` - the directory tree.** It is the first fenced block in the file (opens with
a line containing only three backticks, then `script/`). Task 2 turned its entries into
`├── dev/manga/` etc., which is wrong: a tree expresses the parent through nesting, not through a
repeated prefix. Replace the entire block body - from the `script/` line through the
`└── STRUCTURE.md` line, exclusive of the fence markers - with exactly this, copied verbatim
including all whitespace:

script/
├── dev/                                            # All script source (topic folders live here)
│   ├── manga/                                      # Manga page numbering utilities
│   │   └── number-pages.zsh                        # Rename images to sequential page numbers
│   │
│   ├── local-filesys/                              # Local filesystem operations
│   │   ├── retain-dir-struct-1.zsh                 # Stage 1: Create shadow map (hash-based)
│   │   ├── retain-dir-struct-2-sorted.zsh          # Stage 2: Sync shadow files to new structure
│   │   └── retain-dir-struct-3-find-sorted.zsh     # Stage 3: Map shadow files back to originals
│   │
│   └── remote/                                     # Remote file synchronization (MEGA)
│       ├── rename-remote-files-1-match-remote.zsh        # Stage 1: Match local to remote, create sync
│       └── rename-remote-files-2-rename-local.zsh        # Stage 2: Revert files, trigger renames
│
└── .planning/
    └── codebase/                                   # Architecture documentation
        ├── ARCHITECTURE.md                         # System design and patterns
        └── STRUCTURE.md                            # This file

Note the structural changes beyond indentation: `dev/` is now the first of two top-level entries
so it takes `├──` while `.planning/` keeps `└──`; `remote/` is now the last child of `dev/` so it
takes `└──` and its two children are prefixed with spaces rather than a continuation bar. Comment
text is unchanged from the original for every pre-existing line.

**3b. `ARCHITECTURE.md` - the boxed layer diagram.** In the `## System Overview` fenced block, the
entry-points row lists the three script globs inside a fixed-width box whose right border and
column separators sit at fixed columns. Task 2 added four characters to each of the three cells,
pushing the row 12 characters past the border. Replace that single row with:

│ `dev/manga/*`    │  `dev/local-filesys/*` │  `dev/remote/*`              │

This drops `.zsh` from each glob, which is exactly the four characters that `dev/` adds, so all
three cell widths, both interior separators, and the right border land on their original columns
with no other line in the diagram needing to change. The lost detail (that these are zsh files) is
stated throughout the surrounding document. Do not widen the box, and do not touch any other line
of the diagram.
  </action>
  <verify>
    <automated>awk '/^```/{f++} f==1 &amp;&amp; /├── dev\/$|├── dev\/ /{d=1} END{exit !d}' .planning/codebase/STRUCTURE.md &amp;&amp; test "$(awk '/^│ `dev\/manga/{print length($0)}' .planning/codebase/ARCHITECTURE.md)" = "76" &amp;&amp; ! grep -q 'dev/manga/\*\.zsh' .planning/codebase/ARCHITECTURE.md</automated>
  </verify>
  <done>
    - The `STRUCTURE.md` tree has one `├── dev/` node with `manga/`, `local-filesys/`, and `remote/` nested one level beneath it, and no topic directory remains at the tree's top level
    - No line inside the `STRUCTURE.md` tree contains the string `dev/manga/`, `dev/local-filesys/`, or `dev/remote/` (nesting supplies the parent)
    - The `ARCHITECTURE.md` entry-points row has byte length 76, matching every other border line of that box
    - `awk 'NR>=9 &amp;&amp; NR<=13 {print length($0)}' .planning/codebase/ARCHITECTURE.md` prints the same values it printed before this task (76, 77, 76, 76, 76)
    - No other line of either fenced block was modified
  </done>
</task>

<task type="auto">
  <name>Task 4: Full-repo verification sweep</name>
  <files>(read-only)</files>
  <action>
Prove nothing dangles. Run, from the repository root:

    grep -rnP '(?<!dev/)\b(local-filesys|manga|remote)/' --exclude-dir=.git --exclude-dir=quick .

`--exclude-dir=quick` is required: this plan file itself lives under `.planning/quick/` and
necessarily contains unprefixed source paths in its `git mv` command and in its description of the
before state. Excluding it is not hiding a failure - it is excluding the instructions from their
own audit. `grep -P`'s negative lookbehind is what makes this precise; a plain
`grep 'local-filesys/'` also matches `dev/local-filesys/` and is useless here.

**Expected result: exactly 3 matching lines, all in `.planning/codebase/STRUCTURE.md`**, being the
`│   ├── manga/`, `│   ├── local-filesys/`, and `│   └── remote/` nodes of the directory tree.
Those are correct as written - a tree communicates the `dev/` parent through indentation. Any
match outside those 3 lines is a real miss: fix it and re-run.

Then confirm every referenced script path actually resolves. For each distinct `dev/...zsh` path
mentioned in the 12 updated files, check it exists on disk. The one legitimate exception is
`dev/local-filesys/tests/test-retain-dir-struct.zsh`, which the Phase 1 plans schedule for
creation and which does not exist yet.

Finally, confirm no stray edits: `git status --porcelain` should list exactly the 8 renames from
Task 1 plus the 12 modified files, and nothing else.
  </action>
  <verify>
    <automated>test "$(grep -rnP '(?&lt;!dev/)\b(local-filesys|manga|remote)/' --exclude-dir=.git --exclude-dir=quick . | wc -l)" -eq 3 &amp;&amp; test "$(grep -rlP '(?&lt;!dev/)\b(local-filesys|manga|remote)/' --exclude-dir=.git --exclude-dir=quick .)" = "./.planning/codebase/STRUCTURE.md" &amp;&amp; for f in $(grep -rhoE 'dev/(local-filesys|manga|remote)/[A-Za-z0-9._/-]+\.zsh' --exclude-dir=.git --exclude-dir=quick . | sort -u | grep -v 'tests/test-retain-dir-struct.zsh'); do test -f "$f" || { echo "MISSING $f"; exit 1; }; done</automated>
  </verify>
  <done>
    - The lookbehind grep returns exactly 3 lines, all in `.planning/codebase/STRUCTURE.md`, all inside the directory-tree fenced block
    - Every `dev/{local-filesys,manga,remote}/...` path mentioned anywhere in the repo resolves to an existing file, except `dev/local-filesys/tests/test-retain-dir-struct.zsh` which Phase 1 has not created yet
    - `grep -rn 'dev/dev/' --exclude-dir=.git .` returns nothing
    - `git status --porcelain` lists exactly 20 entries: 8 renames and 12 modifications, with no untracked files
    - `git log --follow --oneline dev/manga/number-pages.zsh` shows history from before the move
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none introduced) | This change moves files within one local git repository. No network, no untrusted input, no new execution surface. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-quick-01 | Tampering | `git mv` of 8 tracked scripts | medium | mitigate | Task 1 gates on `git status --porcelain` reporting 8 `R` rename records and zero content insertions/deletions, so a silent delete+add or a content-altering move fails the task |
| T-quick-02 | Tampering | `sed -i` blanket rewrite across 12 files | medium | mitigate | Rule is anchored to a `/`-suffixed token, dry-tested against all seven reference shapes present in the repo, and idempotent via the optional `(dev/)?` capture; Task 2 gates on added-lines equalling deleted-lines so no line can be dropped or duplicated |
| T-quick-03 | Tampering | Committed, already-verified Phase 1 plans | high | mitigate | Phase 1 plans are edited only by the mechanical sed rule, never by hand; Task 2 requires the diff to be a pure in-place substitution, which prevents semantic drift in acceptance criteria the phase will later be judged against |
| T-quick-04 | Denial of Service | Broken path references left behind | low | mitigate | Task 4's lookbehind grep plus the existence check for every referenced `.zsh` path proves no reference dangles |
| T-quick-05 | Elevation of Privilege | File mode loss on moved scripts | low | mitigate | Task 1 asserts `test -x` on the moved executables |

No package-manager installs occur in this plan, so the package legitimacy gate does not apply.
</threat_model>

<verification>
Run from the repository root after all tasks:

1. `git ls-files dev | wc -l` outputs `8`
2. `test ! -e local-filesys && test ! -e manga && test ! -e remote` succeeds
3. `git status --porcelain | grep -c '^R'` outputs `8`
4. `grep -rnP '(?<!dev/)\b(local-filesys|manga|remote)/' --exclude-dir=.git --exclude-dir=quick .` outputs exactly 3 lines, all in `.planning/codebase/STRUCTURE.md`'s tree block
5. `grep -rn 'dev/dev/' --exclude-dir=.git .` outputs nothing
6. `git log --follow --oneline dev/manga/number-pages.zsh` shows pre-move commits
7. `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md` are absent from `git status --porcelain`
8. The `STRUCTURE.md` tree and the `ARCHITECTURE.md` System Overview box both still render with aligned borders
</verification>

<success_criteria>
- All 8 scripts live under `dev/{local-filesys,manga,remote}/` with git-recorded renames and intact history
- The three topic directories no longer exist at the repository root
- All 12 reference files point at the new paths; no reference dangles
- The two Phase 1 execution plans changed in path strings only - no task, criterion, or wording drift
- Both ASCII diagrams render correctly, with the tree expressing `dev/` through nesting rather than a repeated prefix
- No file outside the declared `files_modified` set was touched
</success_criteria>

<output>
Create `.planning/quick/260805-ety-move-local-filesys-manga-and-remote-into/260805-ety-SUMMARY.md` when done
</output>