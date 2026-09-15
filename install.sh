#!/bin/bash
# Deploy Macifier from this repo to the live locations.
#
# The repo is the source of truth. Nothing is written into /usr/share/omarchy
# (package-owned) or ~/.config/hypr (user-owned) — see MACIFIER.md.

set -euo pipefail
cd "$(dirname "$0")"

install -Dm755 bin/omarchy-macifier "$HOME/.local/bin/omarchy-macifier"
install -Dm644 plugin/manifest.json "$HOME/.config/omarchy/plugins/macifier/manifest.json"
install -Dm644 plugin/Widget.qml    "$HOME/.config/omarchy/plugins/macifier/Widget.qml"
install -Dm644 plugin-switcher/manifest.json "$HOME/.config/omarchy/plugins/macifier-switcher/manifest.json"
install -Dm644 plugin-switcher/Switcher.qml  "$HOME/.config/omarchy/plugins/macifier-switcher/Switcher.qml"
install -Dm644 plugin-dock/manifest.json "$HOME/.config/omarchy/plugins/macifier-dock/manifest.json"
install -Dm644 plugin-dock/Dock.qml      "$HOME/.config/omarchy/plugins/macifier-dock/Dock.qml"
install -Dm644 plugin-launchpad/manifest.json  "$HOME/.config/omarchy/plugins/macifier-launchpad/manifest.json"
install -Dm644 plugin-launchpad/Launchpad.qml  "$HOME/.config/omarchy/plugins/macifier-launchpad/Launchpad.qml"

mkdir -p "$HOME/.local/share/macifier/options"
install -m644 hypr/options/*.lua "$HOME/.local/share/macifier/options/"
install -Dm644 share/dock-placeholders.json "$HOME/.local/share/macifier/dock-placeholders.json"

echo "installed. next:"
echo "  omarchy plugin enable local.macifier right   # first time only"
echo "  omarchy restart shell                        # QML changes need this"
