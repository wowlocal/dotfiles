#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script only supports macOS." >&2
  exit 1
fi

# Lower values make key repeat faster and shorten the delay before it starts.
defaults write -g KeyRepeat -int 1
defaults write -g InitialKeyRepeat -int 15
defaults write -g ApplePressAndHoldEnabled -bool false

echo "Keyboard repeat configured (KeyRepeat=1, InitialKeyRepeat=15, ApplePressAndHoldEnabled=0)."
echo "Log out and back in to ensure the changes apply everywhere."
