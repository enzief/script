#!/usr/bin/env bash
# Re-creates the "clean" repos under work/ via git clone instead of relying on a file
# copy. Generated from a scan on 2026-07-31 (repos with no uncommitted changes/stash and
# HEAD reachable from a remote branch/tag at scan time). iswi/round/* and
# iswi/groowin_tech/* were dropped from the backup entirely (declared obsolete) and are
# NOT in this list, even the ones that were individually clean.
# Run AFTER restore-from-wdhdd.zsh (needs ~/.ssh restored + work/'s non-clean repos in place).
#
# Usage: bash clone-clean-repos.sh (no arguments; the repo list below is fixed)
#
# set -uo pipefail deliberately omits -e: fifteen independent repo clones, and one
# failed clone must not abandon the other fourteen.
#
# Deliberately bash, not zsh (D-01): this runs in the same pre-desktop bootstrap
# window as install-essentials.sh, before zsh is guaranteed to be installed.
set -uo pipefail

if (( $# > 0 )); then
  echo "Error: takes no arguments." >&2
  exit 1
fi

if ! command -v git &>/dev/null; then
  echo "Error: 'git' is required" >&2
  exit 1
fi

TARGET="$HOME/work"
export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new"

failed_repos=()

clone_branch() {
  local relpath="$1" remote="$2" ref="$3"
  local dest="$TARGET/$relpath"
  [ -d "$dest/.git" ] && { echo "skip (exists): $relpath"; return; }
  mkdir -p "$(dirname "$dest")"
  echo "==> $relpath ($ref)"
  if ! git clone -b "$ref" "$remote" "$dest"; then
    failed_repos+=("$relpath")
  fi
}

clone_branch "Netgear-A6210"                                   "https://github.com/kaduke/Netgear-A6210.git"                              master
clone_branch "dotfiles"                                        "git@github.com:enzief/dotfiles.git"                                       master
clone_branch "iswi/byse"                                       "git@github.com:Digital3T/byse.git"                                        main
clone_branch "iswi/purebrew/pb-user-service-typelevel-main"    "git@github.com:Invoker-Software/pb-user-service-typelevel.git"           master
clone_branch "iswi/shitagami"                                  "git@github.com:Invoker-Software/shitagami.git"                            master
clone_branch "iswi/zitadelz"                                   "git@github.com:Invoker-Software/zitadelz.git"                             master
clone_branch "iswi/afang"                                      "git@github.com:Invoker-Software/afang.git"                                master
clone_branch "iswi/mediafire_bulk_downloader"                  "git@github.com:Invoker-Software/mediafire_bulk_downloader.git"           master
clone_branch "iswi/script"                                     "git@github.com:enzief/script.git"                                         master
clone_branch "iswi/shitakaohon"                                "git@github.com:Invoker-Software/shitakaohon.git"                          master
clone_branch "iswi/shabontama"                                 "git@github.com:Invoker-Software/shabontama.git"                          main
clone_branch "round/emacs-scala-mode"                          "git@github.com:enzief/emacs-scala-mode.git"                               my-emacs
clone_branch "round/scaluzzi"                                  "git@github.com:enzief/scaluzzi.git"                                       master
clone_branch "round/track"                                     "git@gitlab.com:genzief/track.git"                                         cv
clone_branch "round/cashburn"                                  "git@gitlab.com:zoftware/cashburn.git"                                     xxx

echo
if (( ${#failed_repos[@]} > 0 )); then
  echo "Error: ${#failed_repos[@]} repo(s) failed to clone:" >&2
  for r in "${failed_repos[@]}"; do
    echo "  - $r" >&2
  done
  exit 1
fi

echo "### Clean repos re-cloned into $TARGET ###"
