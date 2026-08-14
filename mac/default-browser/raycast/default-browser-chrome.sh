#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Default Browser: Chrome
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🌈
# @raycast.packageName Default Browser

# Documentation:
# @raycast.description Set Google Chrome as the default browser
# @raycast.author morihaya

exec "$HOME/.local/bin/set-default-browser" chrome
