#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
font="DepartureMono Nerd Font"

list() { grep -vE '^[[:space:]]*(#|$)' "$repo_dir/packages/$1" || true; }

mapfile -t packages < <(list pacman.txt)
if ((${#packages[@]})); then
  sudo pacman -S --needed --noconfirm "${packages[@]}"
fi

mapfile -t aur_packages < <(list aur.txt)
if ((${#aur_packages[@]})); then
  omarchy pkg aur add "${aur_packages[@]}"
fi

[[ "$(omarchy font current)" == "$font" ]] || omarchy font set "$font"

# Dotfiles: github.com/yesitsfebreeze/.files is the chezmoi source for nushell,
# tmux, nvim, wezterm, television and git. On the first apply, Omarchy's stock
# nvim/tmux configs are moved aside so chezmoi does not merge into them.
dotfiles="$HOME/dev/.files"
[[ -d "$dotfiles/.git" ]] || git clone https://github.com/yesitsfebreeze/.files "$dotfiles"
if [[ ! -f "$HOME/.config/chezmoi/chezmoi.toml" ]]; then
  for dir in nvim tmux; do
    [[ -e "$HOME/.config/$dir" ]] && mv "$HOME/.config/$dir" "$HOME/.config/$dir.omarchy.bak.$(date +%s)"
  done
  chezmoi init --source "$dotfiles" \
    --promptString "Full name (for git)=$(git config --global user.name)" \
    --promptString "Email (for git)=$(git config --global user.email)"
fi
bash "$dotfiles/install.sh"

# nu is the login shell (see agent/system.md, "Shell").
[[ "$(getent passwd "$USER" | cut -d: -f7)" == /usr/bin/nu ]] || sudo usermod -s /usr/bin/nu "$USER"

# Config files owned by this repository, linked into ~/.config.
for path in xdg-terminals.list; do
  target="$HOME/.config/$path"
  if [[ -e "$target" && ! -L "$target" ]]; then
    mv "$target" "$target.bak.$(date +%s)"
  fi
  ln -sfn "$repo_dir/config/$path" "$target"
done

bash "$repo_dir/scripts/agents.sh"
bash "$repo_dir/scripts/kern.sh"
bash "$repo_dir/voice/scripts/install.sh"

echo "Omarchy machine state applied."
