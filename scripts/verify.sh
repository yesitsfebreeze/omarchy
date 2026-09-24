#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

test -f "$repo_dir/agent/system.md"
test -f "$repo_dir/packages/pacman.txt"
test -f "$repo_dir/packages/aur.txt"
test -f "$repo_dir/scripts/bootstrap.sh"

grep -vhE '^[[:space:]]*(#|$)' "$repo_dir/packages/pacman.txt" "$repo_dir/packages/aur.txt" | xargs -r pacman -Q >/dev/null
[[ "$(omarchy font current)" == "DepartureMono Nerd Font" ]] || { echo "font drift: $(omarchy font current)" >&2; exit 1; }

instruction="$HOME/.local/share/omarchy/agent/system.md"
test -f "$instruction"
grep -qF "@$instruction" "$HOME/.claude/CLAUDE.md"
for f in "$HOME/.codex/AGENTS.md" "$HOME/.gemini/GEMINI.md" "$HOME/.config/opencode/AGENTS.md"; do
  [[ "$(readlink "$f")" == "$instruction" ]] || { echo "not linked: $f" >&2; exit 1; }
done

for path in wezterm xdg-terminals.list; do
  [[ "$(readlink "$HOME/.config/$path")" == "$repo_dir/config/$path" ]] || { echo "not linked: ~/.config/$path" >&2; exit 1; }
done
[[ "$(xdg-terminal-exec --print-id)" == org.wezfurlong.wezterm.desktop* ]] || { echo "default terminal drift" >&2; exit 1; }

echo "Omarchy machine repository checks passed."
