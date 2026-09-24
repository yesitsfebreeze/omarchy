# Omarchy

My reproducible Omarchy workstation.

## Rule

> If a persistent change would make a clean reinstall different, that change belongs in this repository.

This repository is the source of truth for the machine: packages, services, configuration, agent/runtime setup, and short decisions when the reason matters.

Do not use it as a shell-history dump. Record desired state.

Secrets, tokens, passwords, private keys, and machine-specific credentials never belong here.

## Agent instruction

The canonical machine-maintainer instruction is [`agent/system.md`](agent/system.md).

Any agent making a persistent system change should update this repository in the same task.

## Current work

- [`voice/prompt.txt`](voice/prompt.txt): local voice agent (wake word -> STT -> agent -> TTS).
- [`mcp-bridge.txt`](mcp-bridge.txt): ChatGPT -> browser -> KERN/MCP bridge. `bridge/omarchy-bridge` and the `kern/` workspace exist; the Chromium extension does not yet.

## Layout

```text
agent/system.md       machine-maintainer instruction
mcp-bridge.txt        MCP/browser bridge implementation prompt
packages/pacman.txt   packages required by the machine
packages/aur.txt      AUR packages required by the machine
config/               files linked into ~/.config (default terminal)
decisions/            reasons that are not obvious from configuration
scripts/bootstrap.sh  reconstruct the machine (packages, monospace font, agents)
scripts/agents.sh     link agent/system.md into each agent's global instructions
scripts/kern.sh       install Rust (Omarchy dev-env) and build KERN from ~/dev/kern
kern/                 KERN workspace for the bridge (svc: read-only unit state)
bridge/omarchy-bridge allowlisted KERN tools over MCP (CLI + native messaging host)
voice/                local voice agent
scripts/verify.sh     verify the repository/setup
```

## Shell and dotfiles

`nu` is the login shell and the shell of every terminal. Its config, and the tmux, nvim, wezterm, television and git configs, come from [`yesitsfebreeze/.files`](https://github.com/yesitsfebreeze/.files), applied with chezmoi from `~/dev/.files`. This repository owns the packages and the login shell; `.files` owns the configs.

## Fresh Omarchy install

```bash
git clone https://github.com/yesitsfebreeze/omarchy.git ~/.local/share/omarchy
cd ~/.local/share/omarchy
bash scripts/bootstrap.sh
bash scripts/verify.sh
```

`bootstrap.sh` runs `scripts/agents.sh`, which wires `agent/system.md` into Claude Code, Codex, Gemini CLI and OpenCode. Other agents need an entry there once their global-instruction mechanism is known.

The goal is simple: a clean Omarchy installation plus this repository should be enough to reconstruct the workstation.
