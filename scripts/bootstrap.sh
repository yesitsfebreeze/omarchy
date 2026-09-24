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

# Config files owned by this repository, linked into ~/.config.
for path in wezterm xdg-terminals.list; do
  target="$HOME/.config/$path"
  if [[ -e "$target" && ! -L "$target" ]]; then
    mv "$target" "$target.bak.$(date +%s)"
  fi
  ln -sfn "$repo_dir/config/$path" "$target"
done

bash "$repo_dir/scripts/agents.sh"

echo "Omarchy machine state applied."
