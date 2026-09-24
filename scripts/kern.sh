#!/usr/bin/env bash
# KERN from source: Rust through Omarchy's dev-env, kern built with cargo.
set -euo pipefail

[[ -x "$HOME/.cargo/bin/rustup" ]] || omarchy-install-dev-env rust

src="$HOME/dev/kern"
[[ -d "$src/.git" ]] || gh repo clone yesitsfebreeze/kern "$src"
[[ -x "$HOME/.cargo/bin/kern" ]] || "$HOME/.cargo/bin/cargo" install --path "$src" --locked
