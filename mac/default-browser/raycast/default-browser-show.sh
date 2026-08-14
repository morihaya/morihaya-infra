#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Default Browser: Show
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🔍
# @raycast.packageName Default Browser

# Documentation:
# @raycast.description Show which browser is currently the default
# @raycast.author morihaya

exec "$HOME/.local/bin/set-default-browser" 
