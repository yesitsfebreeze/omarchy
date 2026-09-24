#!/usr/bin/env bash
# Point every supported agent's user-level instructions at agent/system.md.
set -euo pipefail

instruction="$HOME/.local/share/omarchy/agent/system.md"

link() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  if [[ -L "$target" || ! -e "$target" ]]; then
    ln -sfn "$instruction" "$target"
  elif ! grep -qF "$instruction" "$target"; then
    echo "drift: $target exists as a regular file; add a reference to $instruction manually" >&2
  fi
}

# Claude Code: native @import, keeps any other user instructions intact.
claude_md="$HOME/.claude/CLAUDE.md"
mkdir -p "$(dirname "$claude_md")"
grep -qsF "@$instruction" "$claude_md" || printf '@%s\n' "$instruction" >>"$claude_md"

link "$HOME/.codex/AGENTS.md"
link "$HOME/.gemini/GEMINI.md"
link "$HOME/.config/opencode/AGENTS.md"
