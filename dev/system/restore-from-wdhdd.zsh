#!/usr/bin/env zsh
# Restore onto a freshly installed Kubuntu, from the backup made by backup-to-wdhdd.zsh.
# Source is exFAT: no real perms/ownership were stored -> we set safe defaults after copying.
#
# Usage: zsh restore-from-wdhdd.zsh (no arguments; all paths are hardcoded)
#
# set -uo pipefail deliberately omits -e: this is a multi-step restore (dotfiles,
# several project dirs, optional big dirs, a permission-fix pass) and one failed
# step must not abandon the rest.
#
# confirm() below is duplicated in backup-to-wdhdd.zsh on purpose, not factored out --
# each script must be runnable standalone from the drive when the repo isn't present.
set -uo pipefail

if (( $# > 0 )); then
  print -u2 -r -- "Error: takes no arguments; all paths are hardcoded."
  exit 1
fi

if ! command -v mountpoint &>/dev/null; then
  print -u2 -r -- "Error: 'mountpoint' is required"
  exit 1
fi
if ! command -v rsync &>/dev/null; then
  print -u2 -r -- "Error: 'rsync' is required"
  exit 1
fi

SRC="/media/enzief/wdhdd/lubuntu"
RSYNC=(rsync -rt -h --info=progress2 --no-perms --no-owner --no-group)

if ! mountpoint -q /media/enzief/wdhdd; then
  print -u2 -r -- "Error: /media/enzief/wdhdd is not mounted (is the drive plugged in?)"
  exit 1
fi

restore() {
  local sub="$1"
  [ -e "$SRC/$sub" ] || return 0
  local out="$HOME/$sub"
  mkdir -p "$(dirname "$out")"
  print -r -- "==> $sub"
  "${RSYNC[@]}" "$SRC/$sub" "$(dirname "$out")/"
}

confirm() {
  local msg="$1" reply
  read -r "reply?$msg [y/N] "
  [[ "$reply" =~ ^[Yy]$ ]]
}

print -r -- "### Restoring dotfiles/config/state ###"
if [ -d "$SRC/dotfiles" ]; then
  "${RSYNC[@]}" "$SRC/dotfiles/" "$HOME/"
fi

print -r --
print -r -- "### Restoring project/document dirs ###"
for d in work Documents Pictures Apps renikov _recover; do
  restore "$d"
done

print -r --
print -r -- "### Restoring loose top-level files ###"
if [ -d "$SRC/loose-files" ]; then
  "${RSYNC[@]}" "$SRC/loose-files/" "$HOME/"
fi

print -r --
print -r -- "### Optional big dirs (only present if you chose to back them up) ###"
if [ -d "$SRC/Downloads" ]; then
  if confirm "Restore Downloads/ from backup?"; then
    restore "Downloads"
    # 4 manga-chapter dirs had exFAT-forbidden chars in filenames and were tar'd
    # separately (see exfat_incompatible_names.txt) -- copied as-is, not extracted;
    # extract manually later with: tar -xf <archive> -C <destination>
    mkdir -p "$HOME/Downloads/warlord"
    archives_copied=0
    for archive in Downloads-warlord-hakuneko.tar Downloads-warlord-trigun.tar \
                   Downloads-warlord-trigun_maximum.tar Downloads-warlord-mugen_shinshi.tar; do
      if [ -f "$SRC/$archive" ]; then
        print -r -- "==> $archive"
        if cp "$SRC/$archive" "$HOME/Downloads/warlord/$archive"; then
          (( archives_copied++ ))
        else
          print -u2 -r -- "Error: failed to copy $archive"
        fi
      fi
    done
    if (( archives_copied > 0 )); then
      print -r -- "Reminder: the warlord archives above were copied but not extracted."
      print -r -- "Extract each one manually with: tar -xf <archive> -C <destination>"
    fi
  fi
fi

if [ -d "$SRC/Videos" ]; then
  if confirm "Restore Videos/ from backup?"; then
    restore "Videos"
  fi
fi

print -r --
print -r -- "### Fixing sensitive-dir permissions (exFAT stored none) ###"
if [ -d "$HOME/.ssh" ]; then
  chmod 700 "$HOME/.ssh"
  find "$HOME/.ssh" -type f -name '*.pub' -exec chmod 644 {} +
  find "$HOME/.ssh" -type f ! -name '*.pub' -exec chmod 600 {} +
fi
if [ -d "$HOME/.gnupg" ]; then
  find "$HOME/.gnupg" -type d -exec chmod 700 {} +
  find "$HOME/.gnupg" -type f -exec chmod 600 {} +
fi
if [ -d "$HOME/.aws" ]; then
  find "$HOME/.aws" -type d -exec chmod 700 {} +
  find "$HOME/.aws" -type f -exec chmod 600 {} +
fi

print -r --
print -r -- "### Done. ###"
