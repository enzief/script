#!/usr/bin/env zsh
# Backup before Lubuntu -> Kubuntu reinstall (same disk).
# Destination is exFAT: no unix perms/ownership, no real symlinks. Symlinks are SKIPPED
# entirely (no -l, no -L) rather than dereferenced -- work/ alone has ~6500 symlinks
# (mostly node_modules in excluded repos) and -L caused rsync to follow one into a
# runaway copy on 260731. exFAT can't store real symlinks anyway, so skipping is the
# only safe default; anything that specifically needs its symlink target's content is
# handled explicitly by name (see .local/bin/* below), not by blanket dereferencing.
#
# Usage: zsh backup-to-wdhdd.zsh (no arguments; all paths are hardcoded)
#
# set -uo pipefail deliberately omits -e: this run is ~40 independent copy steps plus
# a Tier 2 confirm() flow, and one failed step must not abandon the rest.
#
# confirm() below is duplicated in restore-from-wdhdd.zsh on purpose, not factored out --
# each script must be runnable standalone from the drive when the repo isn't present.
set -uo pipefail

if (( $# > 0 )); then
  print -u2 -r -- "Error: takes no arguments; all paths are hardcoded."
  exit 1
fi

if ! command -v rsync &>/dev/null; then
  print -u2 -r -- "Error: 'rsync' is required"
  exit 1
fi
if ! command -v tar &>/dev/null; then
  print -u2 -r -- "Error: 'tar' is required"
  exit 1
fi
if ! command -v mountpoint &>/dev/null; then
  print -u2 -r -- "Error: 'mountpoint' is required"
  exit 1
fi

if ! mountpoint -q /media/enzief/wdhdd; then
  print -u2 -r -- "Error: /media/enzief/wdhdd is not mounted (is the drive plugged in?)"
  exit 1
fi

DEST="/media/enzief/wdhdd/lubuntu"
RSYNC=(rsync -rt --no-perms --no-owner --no-group -h --info=progress2)
mkdir -p "$DEST"

copy() {
  local src="$1" sub="$2"; shift 2
  if [ ! -e "$HOME/$src" ]; then
    print -u2 -r -- "Warning: source not found, skipping: $src"
    return
  fi
  local out="$DEST/$sub"
  mkdir -p "$(dirname "$out")"
  print -r -- "==> $src"
  "${RSYNC[@]}" "$@" "$HOME/$src" "$out"
}

# copy_file() silently skips a missing source (unlike copy()'s warning above) because it
# targets optional loose files that often legitimately don't exist -- e.g. not every
# machine has firefox_tabs_export.txt. copy() targets dirs that are expected to exist.
copy_file() {
  local src="$1" sub="$2"
  [ -f "$HOME/$src" ] || return 0
  mkdir -p "$DEST/$(dirname "$sub")"
  print -r -- "==> $src"
  "${RSYNC[@]}" "$HOME/$src" "$DEST/$sub"
}

# exFAT forbids : * ? " < > | in filenames -- rsync has no way to sanitize these on the
# fly, so per-file copy fails on anything with those chars (hit this on Downloads/ movie
# and manga chapter titles, 260731). tar sidesteps it entirely: original names (colons
# and all) are preserved INSIDE the archive; only the archive's own filename (which we
# control) ever touches the exFAT directory entry.
tar_copy() {
  local src="$1" archive="$2"
  if [ ! -e "$HOME/$src" ]; then
    print -u2 -r -- "Warning: source not found, skipping: $src"
    return
  fi
  local out="$DEST/$archive"
  mkdir -p "$(dirname "$out")"
  print -r -- "==> tar: $src -> $archive"
  if ! tar -cf "$out" -C "$HOME/$src" .; then
    print -u2 -r -- "Error: tar failed for $archive"
  fi
}

# ============================================================
# TIER 1 — surely important/irreplaceable, or small enough not to matter.
# Runs automatically, no prompts.
# ============================================================
print -r -- "### Tier 1: auto backup ###"

for f in .ssh .gnupg .aws; do copy "$f/" "dotfiles/$f/"; done

for f in .gitconfig .gitignore .zshrc .bashrc .profile \
         .Xresources .Xdefaults .xinputrc \
         .zsh_history .bash_history .psql_history .claude.json \
         firefox_tabs_export.txt exfat_incompatible_names.txt; do
  copy_file "$f" "dotfiles/$f"
done

copy ".claude/" "dotfiles/.claude/"
copy ".claude-byse/" "dotfiles/.claude-byse/" --exclude=cache
copy ".gsd/" "dotfiles/.gsd/"
copy ".codex/" "dotfiles/.codex/"

# .codemoss: keep config + input history, skip redownloadable dependencies/
copy ".codemoss/" "dotfiles/.codemoss/" --exclude=dependencies
# .bmad is pure cache -- intentionally skipped entirely

for f in shabontama go fcitx5 kate vlc transmission calibre thefuck ibus; do
  copy ".config/$f/" "dotfiles/.config/$f/"
done
copy ".config/Signal/" "dotfiles/.config/Signal/" \
  --exclude=Cache --exclude="Code Cache" --exclude=GPUCache \
  --exclude=blob_storage --exclude="Service Worker"

for f in rclone uv uvx coursier env env.fish; do
  copy_file ".local/bin/$f" "dotfiles/.local/bin/$f"
done
for f in kwalletd dolphin gwenview okular kxmlgui5; do
  copy ".local/share/$f/" "dotfiles/.local/share/$f/"
done

# work/ has 60 git repos. Clean ones (no uncommitted changes/stash, HEAD pushed) get
# re-cloned instead via clone-clean-repos.sh — exclude them here so we don't waste space
# copying files git already has upstream. Two whole subtrees declared obsolete (260731)
# and dropped entirely, not backed up in any form: iswi/groowin_tech (23 dirty repos),
# iswi/round (23 repos). iswi/zitadelz (distinct from iswi/round/zitadelz) had 2 stashes;
# user chose to drop them and treat it as clean. After a cleanup pass (260731) only
# round/nubank remains a real backup target (no remote at all).
copy "work/" "work/" \
  --exclude=/iswi/groowin_tech \
  --exclude=/iswi/round \
  --exclude=/Netgear-A6210 \
  --exclude=/dotfiles \
  --exclude=/iswi/byse \
  --exclude=/iswi/purebrew/pb-user-service-typelevel-main \
  --exclude=/iswi/shitagami \
  --exclude=/iswi/zitadelz \
  --exclude=/iswi/afang \
  --exclude=/iswi/mediafire_bulk_downloader \
  --exclude=/iswi/script \
  --exclude=/iswi/shitakaohon \
  --exclude=/iswi/shabontama \
  --exclude=/round/emacs-scala-mode \
  --exclude=/round/scaluzzi \
  --exclude=/round/track \
  --exclude=/round/cashburn

print -r -- "!! NOTE: round/nubank has NO remote at all -- this file copy is its ONLY backup."

copy "Documents/" "Documents/"
copy "Pictures/" "Pictures/"
copy "Apps/" "Apps/" --exclude=node_modules --exclude=chrome-profile --exclude="*.deb" --exclude=Telegram
copy "renikov/" "renikov/"
copy "_recover/" "_recover/"

for f in "j_trading_dupe_2022_07_06_19_23_53.txt" \
         "j_trading_dupe_2022_07_07_23_03_27.txt" \
         "gsd-redux-backup-20260610-053448.tar.gz" \
         "gsd-redux-backup-default-claude-20260610-060323.tar.gz" \
         "Screenshot 2021-12-04 at 01-24-11 Cryptocurrencies Liquidation Feed of BitMex, Binance Futures, FTX, Okex, Bybit and BitFin[...].png" \
         "Screenshot_20250924_223959.png"; do
  copy_file "$f" "loose-files/$f"
done

print -r --
print -r -- "### Tier 1 done. ###"
print -r --

# ============================================================
# TIER 2 — grey area / big. Confirm each before copying.
# ============================================================
confirm() {
  local msg="$1" reply
  read -r "reply?$msg [y/N] "
  [[ "$reply" =~ ^[Yy]$ ]]
}

print -r -- "### Tier 2: confirm each ###"

if confirm "Downloads/ (64G, mostly movie rips) -- back up?"; then
  # 4 manga-chapter dirs under warlord/ have exFAT-forbidden chars (: * ? " < > |) in
  # chapter names -- scanned+confirmed 260731 (see exfat_incompatible_names.txt for the
  # full list of every offending original name). Excluded from the main rsync, tar'd
  # individually instead so their exact original names survive inside the archive.
  # Everything else in Downloads/ is clean and goes through rsync normally.
  copy "Downloads/" "Downloads/" \
    --exclude="/warlord/_hakuneko" \
    --exclude="/warlord/trigun" \
    --exclude="/warlord/trigun_maximum" \
    --exclude="/warlord/Mugen Shinshi - Illusion Arc"
  tar_copy "Downloads/warlord/_hakuneko" "Downloads-warlord-hakuneko.tar"
  tar_copy "Downloads/warlord/trigun" "Downloads-warlord-trigun.tar"
  tar_copy "Downloads/warlord/trigun_maximum" "Downloads-warlord-trigun_maximum.tar"
  tar_copy "Downloads/warlord/Mugen Shinshi - Illusion Arc" "Downloads-warlord-mugen_shinshi.tar"
fi

if confirm "Videos/ (6.8G) -- back up?"; then
  copy "Videos/" "Videos/"
fi

if confirm ".local/share/TelegramDesktop (238M, local chat cache/session) -- back up?"; then
  copy ".local/share/TelegramDesktop/" "dotfiles/.local/share/TelegramDesktop/"
fi

if confirm ".local/share/signal-cli (15M) -- back up?"; then
  copy ".local/share/signal-cli/" "dotfiles/.local/share/signal-cli/"
fi

if confirm ".config/BraveSoftware (2.3G total, ~2.2G is Cache -- will exclude caches) -- back up profile data?"; then
  copy ".config/BraveSoftware/" "dotfiles/.config/BraveSoftware/" \
    --exclude=Cache --exclude="Code Cache" --exclude=GPUCache \
    --exclude="Service Worker" --exclude=blob_storage --exclude="GrShaderCache" \
    --exclude="ShaderCache" --exclude="Crashpad"
fi

if confirm "Firefox profile (958M total, ~662M is per-site storage/cache -- will exclude) -- back up bookmarks/logins/session/extensions?"; then
  copy "snap/firefox/common/.mozilla/firefox/" "dotfiles/snap/firefox/common/.mozilla/firefox/" --exclude=storage
fi

if confirm ".config/Code (1.4G total, mostly workspaceStorage/CachedData -- will exclude caches) -- back up settings?"; then
  copy ".config/Code/" "dotfiles/.config/Code/" \
    --exclude=Cache --exclude="Code Cache" --exclude=GPUCache \
    --exclude=CachedData --exclude=CachedExtensionVSIXs \
    --exclude=workspaceStorage --exclude=logs --exclude="Service Worker"
fi

if confirm ".config/nvm (1.1G, redownloadable node versions) -- back up? [recommend: No]"; then
  copy ".config/nvm/" "dotfiles/.config/nvm/"
fi

if confirm ".config/hakuneko-desktop (294M, but 293M is Cache -- will exclude cache) -- back up?"; then
  copy ".config/hakuneko-desktop/" "dotfiles/.config/hakuneko-desktop/" \
    --exclude=Cache --exclude="Code Cache" --exclude=GPUCache --exclude=blob_storage
fi

print -r --
print -r -- "### Syncing companion scripts onto the drive ###"
# The repo (dev/system/) is now canonical; this drive copy is derived, not the source.
# work/iswi/script is on the work/ exclude list above, so this companion-sync is the
# ONLY path by which the repo's copies reach the drive -- it must be loud on failure.
REPO_DIR="${0:A:h}"
sync_failed=0
for f in backup-to-wdhdd.zsh restore-from-wdhdd.zsh install-essentials.sh \
         clone-clean-repos.sh REINSTALL_INSTRUCTIONS.txt; do
  if [ -f "$REPO_DIR/$f" ]; then
    if cp "$REPO_DIR/$f" "$DEST/$f"; then
      print -r -- "==> $f"
    else
      print -u2 -r -- "Error: failed to copy $f to $DEST"
      (( sync_failed++ ))
    fi
  else
    print -u2 -r -- "Error: companion file not found: $REPO_DIR/$f"
    (( sync_failed++ ))
  fi
done
if (( sync_failed > 0 )); then
  print -u2 -r -- "Warning: $sync_failed companion file(s) failed to sync onto the drive."
fi

print -r --
print -r -- "### All done. Review: $DEST ###"
du -sh "$DEST"
