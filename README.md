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

[`mcp-bridge.txt`](mcp-bridge.txt) is the implementation prompt for the local ChatGPT Voice -> browser bridge -> KERN/MCP control path.

## Layout

```text
agent/system.md       machine-maintainer instruction
mcp-bridge.txt        MCP/browser bridge implementation prompt
packages/pacman.txt   packages required by the machine
decisions/            reasons that are not obvious from configuration
scripts/bootstrap.sh  reconstruct the machine
scripts/agents.sh     link agent/system.md into each agent's global instructions
scripts/verify.sh     verify the repository/setup
```

## Fresh Omarchy install

```bash
git clone https://github.com/yesitsfebreeze/omarchy.git ~/.local/share/omarchy
cd ~/.local/share/omarchy
bash scripts/bootstrap.sh
bash scripts/verify.sh
```

`bootstrap.sh` runs `scripts/agents.sh`, which wires `agent/system.md` into Claude Code, Codex, Gemini CLI and OpenCode. Other agents need an entry there once their global-instruction mechanism is known.

The goal is simple: a clean Omarchy installation plus this repository should be enough to reconstruct the workstation.
