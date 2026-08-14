#!/usr/bin/env bash
# Set up the default-browser switcher on a fresh Mac.
#
#   ./install.sh
#
# Symlinks the script and the Raycast commands back into this repository, so
# edits stay tracked. The Finicky config is copied (not linked) because it is
# machine-local and deliberately untracked.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
RAYCAST_DIR="$HOME/.config/raycast/scripts"
FINICKY_CONFIG="$HOME/.finicky.js"

echo "==> Installing from $REPO_DIR"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required: https://brew.sh" >&2
  exit 1
fi

if [ ! -d /Applications/Finicky.app ]; then
  echo "==> Installing Finicky"
  brew install --cask finicky
else
  echo "==> Finicky already installed"
fi

echo "==> Linking set-default-browser into $BIN_DIR"
mkdir -p "$BIN_DIR"
ln -sfn "$REPO_DIR/bin/set-default-browser" "$BIN_DIR/set-default-browser"

echo "==> Linking Raycast script commands into $RAYCAST_DIR"
mkdir -p "$RAYCAST_DIR"
for f in "$REPO_DIR"/raycast/*.sh; do
  ln -sfn "$f" "$RAYCAST_DIR/$(basename "$f")"
done

if [ -e "$FINICKY_CONFIG" ]; then
  echo "==> $FINICKY_CONFIG already exists, leaving it alone"
else
  echo "==> Creating $FINICKY_CONFIG from template"
  cp "$REPO_DIR/finicky.js.example" "$FINICKY_CONFIG"
fi

open -gj -a Finicky 2>/dev/null || open -a Finicky

cat <<'EOF'

==> Remaining manual steps (they cannot be scripted)

  1. Finicky menu bar icon > Set as default browser, then confirm the macOS
     dialog. This is the only confirmation dialog you will ever see.
  2. Finicky settings > enable "Start at login". Links are not routed while
     Finicky is not running.
  3. Raycast > Settings > Extensions > Script Commands > Add Script Directory
     and select ~/.config/raycast/scripts

Then verify:

  set-default-browser --check
EOF
