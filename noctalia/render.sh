#!/usr/bin/env bash
# Render noctalia theme templates for the current (or given) wallpaper.
# Output goes to ~/.cache/noctalia/theme/ — never into the git repo.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

wallpaper="${1:-}"
if [ -z "$wallpaper" ]; then
  wallpaper="$(grep -m1 -oP '(?<=^path = ")[^"]+' "$HOME/.local/state/noctalia/settings.toml" 2>/dev/null || true)"
fi
if [ -z "$wallpaper" ]; then
  echo "usage: $0 [wallpaper-image]" >&2
  exit 1
fi

command -v noctalia >/dev/null || { echo "noctalia not found in PATH" >&2; exit 1; }

mkdir -p "$HOME/.cache/noctalia/theme"
noctalia theme "$wallpaper" -c "$DIR/noctalia.toml"

echo "rendered -> $HOME/.cache/noctalia/theme/"
