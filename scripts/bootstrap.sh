#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
packages_file="$repo_dir/packages/pacman.txt"

mapfile -t packages < <(grep -vE '^[[:space:]]*(#|$)' "$packages_file" || true)

if ((${#packages[@]})); then
  sudo pacman -S --needed --noconfirm "${packages[@]}"
fi

bash "$repo_dir/scripts/agents.sh"

echo "Omarchy machine state applied."
