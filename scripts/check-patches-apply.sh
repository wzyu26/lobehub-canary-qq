#!/usr/bin/env bash
# Usage: check-patches-apply.sh <lobehub clone> <upstream commit>
# Prepares a throwaway worktree of the commit exactly as the CI build does
# (prepare-claude-code.py, then prepare-ai-comments.py). Exit 0 when both apply.
set -euo pipefail
cfg=$(cd "$(dirname "$0")/.." && pwd)
src=$(cd "$1" && pwd)
sha=$2
dir=$(mktemp -d)/check
git -C "$src" fetch -q origin "$sha"
git -C "$src" worktree add -q --detach "$dir" "$sha"
trap 'git -C "$src" worktree remove --force "$dir" >/dev/null 2>&1 || true' EXIT
python3 "$cfg/scripts/prepare-claude-code.py" "$dir"
python3 "$cfg/scripts/prepare-ai-comments.py" "$dir"
