#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Default Browser: Toggle Work/Personal
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🔄
# @raycast.packageName Default Browser

# Documentation:
# @raycast.description Flip the default browser between Edge (work) and Comet (personal)
# @raycast.author morihaya

export WORK_BROWSER=edge
export PERSONAL_BROWSER=comet

exec "$HOME/.local/bin/set-default-browser" toggle
