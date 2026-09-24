#!/bin/bash
# Deploy Macifier from this repo to the live locations.
#
# The repo is the source of truth. Nothing is written into /usr/share/omarchy
# (package-owned) or ~/.config/hypr (user-owned) — see MACIFIER.md.

set -euo pipefail
cd "$(dirname "$0")"

# --- refuse to publish a tree that is behind master --------------------------
#
# Everything below copies this working tree over the live system, and until now
# the script had no notion of direction: being behind origin/master looked
# exactly like being ahead of it. So running it from a stale checkout silently
# reverted whatever someone else had already shipped.
#
# That is not hypothetical. On 2026-09-18 it removed a working feature from the
# live CLI thirty seconds after that feature was installed, and disabled a
# plugin with it. Nothing reported an error, because from this script's point of
# view nothing had gone wrong.
#
# It refuses rather than warns. This runs unattended inside agent sessions, and
# a warning nobody is watching is just a slower silence.

force=no
for arg in "$@"; do
  case "$arg" in
    --force) force=yes ;;
    *) echo "usage: install.sh [--force]" >&2; exit 1 ;;
  esac
done

if [[ $force == no ]] && git rev-parse --git-dir >/dev/null 2>&1; then
  # Best effort. A machine with no network should still be able to install, and
  # even a stale origin/master catches the case this exists for.
  git fetch origin master --quiet 2>/dev/null || true

  if git rev-parse --verify --quiet origin/master >/dev/null; then
    if ! git merge-base --is-ancestor origin/master HEAD 2>/dev/null; then
      {
        echo "install.sh: refusing — this tree is behind origin/master."
        echo
        echo "Installing would revert work already on master:"
        git log --oneline HEAD..origin/master
        echo
        echo "Rebase or reset onto origin/master first, or re-run with --force"
        echo "if you really mean to publish an older build."
      } >&2
      exit 1
    fi
  fi
fi

install -Dm755 bin/omarchy-macifier "$HOME/.local/bin/omarchy-macifier"
install -Dm755 bin/macifier-pods    "$HOME/.local/bin/macifier-pods"
install -Dm755 bin/macifier-keybindings "$HOME/.local/bin/macifier-keybindings"
install -Dm644 plugin/manifest.json "$HOME/.config/omarchy/plugins/macifier/manifest.json"
install -Dm644 plugin/Widget.qml    "$HOME/.config/omarchy/plugins/macifier/Widget.qml"
install -Dm644 plugin-switcher/manifest.json "$HOME/.config/omarchy/plugins/macifier-switcher/manifest.json"
install -Dm644 plugin-switcher/Switcher.qml  "$HOME/.config/omarchy/plugins/macifier-switcher/Switcher.qml"
install -Dm644 plugin-dock/manifest.json     "$HOME/.config/omarchy/plugins/macifier-dock/manifest.json"
install -Dm644 plugin-dock/Dock.qml         "$HOME/.config/omarchy/plugins/macifier-dock/Dock.qml"
install -Dm644 plugin-dock/Magnification.js "$HOME/.config/omarchy/plugins/macifier-dock/Magnification.js"
install -Dm644 plugin-launchpad/manifest.json "$HOME/.config/omarchy/plugins/macifier-launchpad/manifest.json"
install -Dm644 plugin-launchpad/Launchpad.qml "$HOME/.config/omarchy/plugins/macifier-launchpad/Launchpad.qml"
install -Dm644 plugin-settings/manifest.json  "$HOME/.config/omarchy/plugins/macifier-settings/manifest.json"
install -Dm644 plugin-settings/Settings.qml   "$HOME/.config/omarchy/plugins/macifier-settings/Settings.qml"

mkdir -p "$HOME/.local/share/macifier/options"
install -m644 hypr/options/*.lua "$HOME/.local/share/macifier/options/"
install -Dm644 share/dock-placeholders.json  "$HOME/.local/share/macifier/dock-placeholders.json"
install -Dm644 share/settings-inventory.json "$HOME/.local/share/macifier/settings-inventory.json"
# Staged, not enabled. `option airpods on` is what copies this into
# ~/.config/systemd/user and starts it, so installing never begins scanning.
install -Dm644 share/systemd/macifier-pods.service "$HOME/.local/share/macifier/systemd/macifier-pods.service"

echo "installed. next:"
echo "  omarchy plugin enable local.macifier right   # first time only"
echo "  omarchy restart shell                        # QML changes need this"
