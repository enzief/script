#!/usr/bin/env bash
# Deliberately bash, not zsh: this runs FIRST on a stock install where zsh doesn't
# exist yet (it's what installs zsh) -- bash is guaranteed present.
# Assumes the OS was installed from the Ubuntu SERVER iso (fits a 4GB USB, unlike the
# 4.7GB Kubuntu desktop iso) -- no desktop environment exists yet, this installs one.
# Run BEFORE restore-from-wdhdd.zsh (which needs zsh, installed here).
# Sets up the base system + apps; restore-from-wdhdd.zsh then overlays your real
# dotfiles/configs on top (e.g. it replaces the default .zshrc oh-my-zsh creates here).
#
# Usage: bash install-essentials.sh (no arguments; nothing here is configurable)
#
# set -uo pipefail deliberately omits -e: this is a long apt/install sequence and one
# failed step must not abandon the rest.
set -uo pipefail

if (( $# > 0 )); then
  echo "Error: takes no arguments." >&2
  exit 1
fi

sudo apt update

# ---------------------------------------------------------------
# KDE Plasma desktop (the server iso has no GUI at all yet)
# ---------------------------------------------------------------
sudo apt install -y kubuntu-desktop

# ---------------------------------------------------------------
# CLI essentials
# ---------------------------------------------------------------
sudo apt install -y git zsh curl wget htop tig tree parallel thefuck unrar jpegoptim testdisk

# oh-my-zsh (unattended: installs without dropping into a new shell or prompting)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
# custom plugins your old .zshrc referenced (not part of the dotfile backup itself)
for repo in zsh-autosuggestions zsh-completions zsh-syntax-highlighting; do
  dest="$HOME/.oh-my-zsh/custom/plugins/$repo"
  [ -d "$dest" ] || git clone "https://github.com/zsh-users/$repo" "$dest"
done
zsh_path="$(command -v zsh)"
if [ -n "$zsh_path" ]; then
  sudo chsh -s "$zsh_path" "$USER"
else
  echo "Warning: zsh not found; login shell left unchanged." >&2
fi

# ---------------------------------------------------------------
# Node.js (nvm) + npm
# ---------------------------------------------------------------
if [ ! -d "$HOME/.nvm" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
if command -v nvm &>/dev/null; then
  nvm install --lts
else
  echo "Warning: nvm not available; skipping 'nvm install --lts'." >&2
fi

# ---------------------------------------------------------------
# uv (Python) + Claude Code CLI
# ---------------------------------------------------------------
curl -LsSf https://astral.sh/uv/install.sh | sh
npm install -g @anthropic-ai/claude-code

# ---------------------------------------------------------------
# Brave browser (official repo)
# ---------------------------------------------------------------
curl -fsS https://dl.brave.com/install.sh | sh

# Firefox (deb, as you had before — Kubuntu also ships it via snap by default)
sudo apt install -y firefox

# ---------------------------------------------------------------
# MEGAsync (official MEGA repo for this Ubuntu base release)
# ---------------------------------------------------------------
UBUNTU_REL="$(lsb_release -rs)"
MEGA_DEB="megasync-xUbuntu_${UBUNTU_REL}_amd64.deb"
if wget -q "https://mega.nz/linux/repo/xUbuntu_${UBUNTU_REL}/amd64/${MEGA_DEB}" -O "/tmp/${MEGA_DEB}"; then
  sudo apt install -y "/tmp/${MEGA_DEB}"
else
  echo "Warning: MEGAsync: no repo found for xUbuntu_${UBUNTU_REL} yet — grab the deb manually from https://mega.io/linux" >&2
fi

# ---------------------------------------------------------------
# Signal (official repo)
# ---------------------------------------------------------------
wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > /tmp/signal-desktop-keyring.gpg
sudo mkdir -p /usr/share/keyrings
sudo mv /tmp/signal-desktop-keyring.gpg /usr/share/keyrings/signal-desktop-keyring.gpg
echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' \
  | sudo tee /etc/apt/sources.list.d/signal-xenial.list
sudo apt update
sudo apt install -y signal-desktop telegram-desktop

# ---------------------------------------------------------------
# Media / misc
# ---------------------------------------------------------------
sudo apt install -y vlc transmission calibre

# ---------------------------------------------------------------
# Vietnamese input
# ---------------------------------------------------------------
sudo apt install -y fcitx5 fcitx5-unikey
echo "!! fcitx5: set it as Input Method in System Settings > Virtual Keyboard, then log out/in"

# ---------------------------------------------------------------
# Steam (needs i386 multiarch)
# ---------------------------------------------------------------
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install -y steam

# ---------------------------------------------------------------
# Manual step reminder
# ---------------------------------------------------------------
echo
echo "!! 4K Video Downloader: no stable direct-download URL to automate (versioned filenames)."
echo "   Grab the current .deb yourself from https://www.4kdownload.com/products/product-videodownloader"
echo
echo "### Essentials install done. Reboot now to land in SDDM/Plasma, then run"
echo "### restore-from-wdhdd.zsh to overlay your real dotfiles/data. ###"
