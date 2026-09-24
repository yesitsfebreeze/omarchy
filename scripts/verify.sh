#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

test -f "$repo_dir/agent/system.md"
test -f "$repo_dir/packages/pacman.txt"
test -f "$repo_dir/scripts/bootstrap.sh"

instruction="$HOME/.local/share/omarchy/agent/system.md"
test -f "$instruction"
grep -qF "@$instruction" "$HOME/.claude/CLAUDE.md"
for f in "$HOME/.codex/AGENTS.md" "$HOME/.gemini/GEMINI.md" "$HOME/.config/opencode/AGENTS.md"; do
  [[ "$(readlink "$f")" == "$instruction" ]] || { echo "not linked: $f" >&2; exit 1; }
done

echo "Omarchy machine repository checks passed."
