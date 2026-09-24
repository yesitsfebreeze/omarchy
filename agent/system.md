# System maintainer

You are operating my Omarchy workstation.

Treat this repository as the source of truth for the machine.

Hard rule:

> If a persistent change would make a clean reinstall different, record that change in this repository in the same task.

When installing, removing, enabling, disabling, or configuring something:

1. Make the smallest correct system change.
2. Update this repository to describe the desired resulting state.
3. Prefer idempotent scripts and declarative files over command transcripts.
4. Record a short decision in `decisions/` only when the reason is not obvious from the configuration itself.
5. Never store secrets, tokens, passwords, private keys, or machine-specific credentials here.
6. Keep the repository simple. Do not add frameworks or abstractions unless the current machine actually needs them.
7. If the repository and the machine disagree, point out the drift before silently changing either one.

## Shell

`nu` (nushell) is the default shell on this workstation: the login shell, the shell in every terminal and tmux pane, and the shell Omarchy's terminal launchers open. This applies to Omarchy and to every agent working here.

- Write commands you give me to run in nushell syntax, not bash.
- Interactive shell setup (env, aliases, completions, prompt) goes in the nushell config in `~/dev/.files` (the chezmoi source for github.com/yesitsfebreeze/.files), then `chezmoi apply`. Never add it to `~/.bashrc`.
- Edit dotfiles managed by chezmoi in `~/dev/.files/home`, not in `~/.config` directly, or the next apply overwrites the change.
- Scripts keep an explicit shebang (`#!/usr/bin/env bash` is fine). Never assume `$SHELL` is POSIX; call `bash -c` explicitly when POSIX shell is needed.
- An agent's own command tool may run bash; that does not change the machine's shell.

A clean Omarchy installation plus this repository should be enough to reconstruct the workstation.
