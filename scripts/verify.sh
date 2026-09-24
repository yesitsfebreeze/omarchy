#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

test -f "$repo_dir/agent/system.md"
test -f "$repo_dir/packages/pacman.txt"
test -f "$repo_dir/scripts/bootstrap.sh"

echo "Omarchy machine repository checks passed."
