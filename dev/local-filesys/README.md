# local-filesys

Scripts for reorganizing real files on disk while retaining a record of their
original directory structure, and for putting that structure back later.

## The shadow tree

A shadow tree mirrors a source tree, but every real file `<relpath>` is
represented by a text file `<relpath>.txt` containing that real file's
`sha256sum` output (hash plus filename). The stored hash is the only link
back to the real file — no location metadata is recorded — which is why the
later scripts match on file content, not on path.

## Workflow

1. **`retain-dir-struct-1.zsh`** — walks the source tree and writes one hash
   pointer per real file into a new shadow tree.

   ```
   retain-dir-struct-1.zsh <source_directory> <target_shadow_directory>
   ```

2. **Manual step (not a script)** — reorganize the real files however you
   want, outside these tools. File content must stay byte-identical (same
   hash); only location and name may change. Editing a file's content
   breaks its link to its shadow permanently — the hash will no longer
   match anything.

3. **`retain-dir-struct-2-sorted.zsh`** — re-syncs the shadow tree onto the
   new layout: indexes the old shadow tree by stored hash, walks the
   reorganized data, and for each real file whose current hash matches an
   old shadow entry, copies that old shadow `.txt` to the real file's new
   relative path under the new shadow output dir. Real files whose hash is
   not found in the index are reported and skipped. Supports `--dry-run`.

   ```
   retain-dir-struct-2-sorted.zsh [--dry-run] <reorganized_data_dir> <old_shadow_dir> <new_shadow_output_dir>
   ```

4. **`retain-dir-struct-3-find-sorted.zsh`** — read-only diagnostic,
   optional. Has no `--dry-run` flag because it never writes.

   ```
   retain-dir-struct-3-find-sorted.zsh <shadow_dir> <original_data_dir>
   ```

5. **`retain-dir-struct-4-revert.zsh`** — swaps each shadow `.txt` and its
   real file into each other's positions. Supports `--dry-run` and accepts
   more than one target tree.

   ```
   retain-dir-struct-4-revert.zsh [--dry-run] <shadow_tree> <target_tree> [<target_tree>...]
   ```

### retain-dir-struct-4-revert.zsh behavior

This is the only script that moves real files, so its guards matter:

- It selects a shadow only when the `.txt` file's first field is a 64-character
  lowercase hex hash. Other `.txt` files in the tree are counted and left
  strictly untouched.
- It locates the real file by basename across the target trees.
- On a basename collision it hashes only the colliding candidates to
  disambiguate, and errors if zero or more than one candidate matches the
  stored hash.
- It hash-verifies even a unique name match before acting.
- It refuses the swap if either destination path (the real file's new
  location or the shadow's new location) already exists.
- It performs the swap with two `mv` calls and rolls the first one back if
  the second fails, so the file is relocated byte-for-byte and never deleted
  or regenerated.
- It rejects overlapping shadow and target tree roots.
- It exits 1 if any error was counted.

### Script 3 vs script 4 `--dry-run`

The two preview modes look interchangeable. They are not:

- `retain-dir-struct-3-find-sorted.zsh` hash-indexes every real file in the
  data dir up front and matches purely by hash. It is a general read-only
  mapping report, printing a `SHADOW`/`REAL` pair per resolved shadow and a
  `SHADOW`/`RESULT` line when no real file matches. Cost scales with hashing
  the entire data dir.
- `retain-dir-struct-4-revert.zsh --dry-run` indexes real files by basename
  only, with no upfront hashing, hashes just the candidates it actually
  matched, and additionally checks that both swap destinations are vacant.
  It is a preview of the exact swap it is about to perform, not a general
  hash audit.

Use script 3 to answer "where did these files end up". Use script 4
`--dry-run` to answer "will this swap succeed".

### Typical flow

index -> reorganize -> re-sync shadow -> (optional) verify -> dry-run then
real revert.

## Other scripts in this directory

These are unrelated to the shadow workflow:

- `list-missing-pages.zsh` — compares per-chapter image counts between two
  version directories and prints a difference table.
  `list-missing-pages.zsh <version1_dir> <version2_dir>`
- `rotate` — zero-pads its single numeric argument to four digits, appends
  `.jpg`, and rotates that file 90 degrees in place via ImageMagick
  `convert`. It has no usage string.

## Requirements

zsh, GNU coreutils (`sha256sum`, `realpath`), `find`, `awk`; ImageMagick
`convert` for `rotate` only.

## Tests

`dev/local-filesys/tests/` holds the regression tests for these scripts.
