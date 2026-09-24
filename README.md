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

## Layout

```text
agent/system.md       machine-maintainer instruction
packages/pacman.txt   packages required by the machine
decisions/            reasons that are not obvious from configuration
scripts/bootstrap.sh  reconstruct the machine
scripts/verify.sh     verify the repository/setup
```

## Fresh Omarchy install

```bash
git clone https://github.com/yesitsfebreeze/omarchy.git ~/.local/share/omarchy
cd ~/.local/share/omarchy
bash scripts/bootstrap.sh
bash scripts/verify.sh
```

Then configure each LLM/agent you use to always load `~/.local/share/omarchy/agent/system.md` as its machine-level instruction.

The goal is simple: a clean Omarchy installation plus this repository should be enough to reconstruct the workstation.
