# Macifier

**An opt-in, fully reversible Mac-affinity mode for [Omarchy](https://omarchy.org/).**

One switch that makes Omarchy feel familiar to someone arriving from macOS — and one
click that puts everything back exactly as it was.

---

## Why

Omarchy is opinionated by design, and its defaults are good ones. But a Mac switcher's
first hour is spent colliding with small, invisible differences: the trackpad scrolls
the wrong way, the keybinding menu names keys that aren't printed on the keyboard, and
no window says what it is. None of these are bugs. Each is a deliberate choice that
happens to be wrong for one specific audience — people whose muscle memory was trained
somewhere else.

Experienced Linux users fix these in minutes and never think about them again. Newcomers
don't know the settings exist, don't know what to search for, and often conclude the
system is broken. That gap is what Macifier addresses.

**The pitch is "make the first hour familiar," not "turn Omarchy into macOS."** The
opinion stays the default. The switcher gets a ramp.

## What it does

| Change | Status |
|---|---|
| Trackpad scrolls in macOS direction (`natural_scroll`) | ✅ shipped |
| Keybinding menu shows Command / Option / Control | planned |
| Focused window's name visible in the bar | planned |
| Onboarding note: folders bookmark, files star | planned |

## Why it is reversible

Reversibility is the entire claim, so it is enforced structurally rather than promised:

- **Nothing is written into `/usr/share/omarchy/`.** That directory belongs to the
  package and is overwritten on update.
- **Nothing is written into `~/.config/hypr/*.lua`.** Those files belong to the user. A
  mode that edits them cannot be cleanly removed.
- Settings live in a **single file** in Omarchy's own toggle directory,
  `~/.local/state/omarchy/toggles/hypr/macifier.lua`. Omarchy sources that directory
  *last*, after the user's own config, so the fragment wins without touching anything.
  **Deleting the file reverts everything in it.** That is the whole mechanism.

Test for any future addition: `on` → `off` → every touched file byte-identical to before.
If an item can't meet that, it doesn't go in.

## Install

```bash
./install.sh
omarchy plugin enable local.macifier right   # first time only
omarchy restart shell
```

## Use

```bash
omarchy-macifier on|off|toggle|status
```

Or click ` Macifier` in the bar. When on, the widget shows the Apple glyph and names
itself; when off, the glyph dims and the label disappears. The name is deliberate — an
unlabelled glyph is a puzzle, and a visible name answers both "what is changing my
machine?" and "how do I stop it?" without anyone having to go looking.

## Layout

```
bin/omarchy-macifier    → ~/.local/bin/              CLI, single source of truth for state
hypr/macifier.lua       → ~/.local/share/macifier/   template copied into the toggle dir
plugin/                 → ~/.config/omarchy/plugins/macifier/   third-party bar widget
docs/PLAN.md            implementation plan, phases, risks, open questions
docs/FRICTION-LOG.md    the newcomer-friction findings this project came out of
```

The bar widget owns no state. It reads `omarchy toggle enabled macifier` and calls
`omarchy-macifier toggle`, so the CLI and the bar can never disagree.

---

## First success — 2026-09-14

**A working, reversible toggle, built and verified in a day.**

Phase 0 is complete. `omarchy-macifier on` flips trackpad scrolling to macOS direction and
lights up a self-naming control in the bar; `off` removes the fragment and restores stock
behaviour. The round trip was verified at the setting level (`natural_scroll: false → true
→ false`) and visually, by screen capture, in both states.

Three things made it work, each verified rather than assumed:

1. **Omarchy sources its toggle directory last.** `~/.config/hypr/hyprland.lua` requires
   `default.hypr.toggles` *after* the user's own files, so a fragment there overrides
   everything without editing a single file the user owns. This is what makes clean
   reversibility possible at all.
2. **Third-party bar widgets need no git repo.** A plain folder in
   `~/.config/omarchy/plugins/` with a `manifest.json` and a `.qml` is discovered
   automatically, validates, and registers as `third-party` — arriving *disabled*, so
   nothing appears until it is enabled. Authoring is fully local; `plugin add <git-url>`
   is for distribution, not development.
3. **Omarchy already had the mechanism.** `omarchy hyprland toggle` and `omarchy toggle`
   existed before this project. Macifier invents no architecture — it adds a file to a
   folder that was already there. That is the strongest argument for it upstream.

Along the way, one upstream contribution was made: a comment on
[omacom/omarchy#7174](https://github.com/omacom/omarchy/issues/7174) documenting a second
symptom of a known window-handoff bug, found while tracing why the first agent window
floats when every later one tiles.

**Still unproven:** whether any of this is actually *better*. The mechanism works; whether
macOS-direction scrolling still feels right after a week is the only thing that decides
what goes into Phase 2. That question can't be answered by building more.

### Gotchas recorded so far
- Editing a plugin's `.qml` does **not** hot-reload. `shell.json` changes do; QML needs
  `omarchy restart shell`.
- `omarchy-hyprland-toggle` copies its source from `$OMARCHY_PATH`, which is read-only, so
  a locally-developed flag has to manage its own state file. Hence the custom CLI.
