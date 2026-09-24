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

[[ "$(getent passwd "$USER" | cut -d: -f7)" == /usr/bin/nu ]] || { echo "login shell is not nu" >&2; exit 1; }
[[ "$(chezmoi source-path)" == "$HOME/dev/.files/home" ]] || { echo "chezmoi source drift" >&2; exit 1; }

[[ "$(gsettings get org.gnome.desktop.interface font-name)" == "'DepartureMono Nerd Font 11'" ]] || { echo "GTK font drift" >&2; exit 1; }
fc-match sans-serif | grep -q DepartureMono || { echo "sans-serif font drift" >&2; exit 1; }

for path in xdg-terminals.list fontconfig/conf.d/60-system-font.conf omarchy/themed/tinty-scheme.yaml.tpl omarchy/hooks/theme-set.d/tinty hypr/wallpaper-terminal.lua hypr/animations.lua omarchy/extensions/omarchy-menu.jsonc; do
  [[ "$(readlink "$HOME/.config/$path")" == "$repo_dir/config/$path" ]] || { echo "not linked: ~/.config/$path" >&2; exit 1; }
done
[[ "$(xdg-terminal-exec --print-id)" == org.wezfurlong.wezterm.desktop* ]] || { echo "default terminal drift" >&2; exit 1; }

for module in wallpaper-terminal animations; do
  grep -qF "require(\"hypr.$module\")" "$HOME/.config/hypr/hyprland.lua" || { echo "hyprland.lua does not load hypr.$module" >&2; exit 1; }
done
omarchy plugin list --json | jq -e '.[] | select(.id == "omarchy.background") | .enabled' >/dev/null || { echo "omarchy.background is disabled" >&2; exit 1; }

[[ "$(omarchy theme current)" == Vesper ]] || { echo "theme drift: $(omarchy theme current)" >&2; exit 1; }

echo "Omarchy machine repository checks passed."
