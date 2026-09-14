#!/bin/bash
# Deploy Macifier from this repo to the live locations.
#
# The repo is the source of truth; these three paths are where Omarchy expects
# each piece to live. Nothing is written into /usr/share/omarchy, and nothing
# into ~/.config/hypr — see MACIFIER.md, "Why it is reversible".

set -euo pipefail
cd "$(dirname "$0")"

install -Dm755 bin/omarchy-macifier  "$HOME/.local/bin/omarchy-macifier"
install -Dm644 hypr/macifier.lua     "$HOME/.local/share/macifier/macifier.lua"
install -Dm644 plugin/manifest.json  "$HOME/.config/omarchy/plugins/macifier/manifest.json"
install -Dm644 plugin/Widget.qml     "$HOME/.config/omarchy/plugins/macifier/Widget.qml"

echo "installed. next:"
echo "  omarchy plugin enable local.macifier right   # first time only"
echo "  omarchy restart shell                        # QML changes need this"
