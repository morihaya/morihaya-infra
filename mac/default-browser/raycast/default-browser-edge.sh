#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Default Browser: Edge
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🏢
# @raycast.packageName Default Browser

# Documentation:
# @raycast.description Set Microsoft Edge as the default browser (work)
# @raycast.author morihaya

exec "$HOME/.local/bin/set-default-browser" edge
