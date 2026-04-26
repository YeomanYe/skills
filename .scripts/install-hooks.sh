#!/usr/bin/env bash
# One-shot: tell git to use the tracked hooks in .scripts/git-hooks.
# Run once after cloning this repo.

set -euo pipefail

cd "$(dirname "$0")/.."

git config core.hooksPath .scripts/git-hooks
chmod +x .scripts/git-hooks/*

echo "Hooks installed. core.hooksPath -> .scripts/git-hooks"
echo "Active hooks:"
ls -1 .scripts/git-hooks
