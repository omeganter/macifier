# Macifier

**An opt-in, fully reversible Mac-affinity mode for [Omarchy](https://omarchy.org/).**

One switch that makes Omarchy feel familiar to someone arriving from macOS — and one
click that puts everything back exactly as it was.

> **Unofficial, early, and opinionated — deliberately so.**
> This is not an Omarchy project and is not affiliated with or endorsed by Omarchy or its
> maintainers. It is an independent experiment by a Mac switcher, built in the open while
> the switching is still fresh enough to remember what was confusing.
>
> **Opinions and contributions are very welcome** — especially disagreement. If a default
> here is wrong, if something belongs in Minimal that isn't, or if an option breaks on your
> hardware, open an issue. Arguments about what *should* be in it are as useful as code.

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

### Two goals, one switch

Macifier serves two people, and the mode system is what lets it serve both without
compromising for either:

**Reduce the initial friction.** Most switchers do not want macOS back. They want to stop
tripping over small invisible differences long enough to actually learn the system —
then they keep whatever they have grown to prefer and drop the rest. For them Macifier is
a ramp, used for a week or a month and then partly or wholly switched off. **Minimal** is
built for exactly this: the handful of things you hit in the first minute, nothing that
could break, everything reversible.

**Give the full Mac experience to those who want it.** Others genuinely want to be on a
Mac, in Linux — because their hands will not be retrained, because they move between a
Mac and this machine daily, or simply because they prefer it. That is a legitimate want
and not a lesser one. **Full** is for them. It is a much larger job — window management,
key semantics, system gestures — and it will take a long time and more than one pair of
hands.

Nobody has to pick a camp. Options are independent, so the ramp user can keep the two
things they liked, and the full-experience user can leave out the one thing they hate.

## What it does

Every option is **independent**. Presets are shorthand for a group of them, never a
state you get stuck in — flip any single option afterwards and the rest stay put.

| Option | What it changes | Minimal | Full |
|---|---|:---:|:---:|
| `scroll` | Trackpad scrolls the macOS way | ● | ● |
| `capslock` | Caps Lock works; Compose moves to right ⌘ | ● | ● |
| `windowtitle` | Focused window's name shown in the bar | | ● |

**Minimal** is the safe set: things a switcher notices in the first minute, none of which
can break anything. **Full** is the ambition — "be on a Mac, in Linux" — and will take a
long time. It grows as options prove themselves, and it is the natural place for
contributors to add work.

Planned, not yet built: keybinding menu showing Command / Option / Control instead of
SUPER / ALT / CTRL; onboarding note that folders bookmark and files star. Deliberately
**out** for now: Cmd-based copy/paste — terminals, Chromium and TUI apps each handle
`SUPER+C/V` differently, and breaking copy/paste would discredit the whole idea.

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

Click ` Macifier` in the bar to open the options panel: presets across the top, and a
switch per option with a one-line explanation of what each does. Everything can be turned
on or off individually from there.

When anything is on the widget shows the Apple glyph and names itself; when everything is
off the glyph dims and the label disappears. The name is deliberate — an unlabelled glyph
is a puzzle, and a visible name answers both "what is changing my machine?" and "how do I
stop it?" without anyone having to go looking.

From the terminal:

```bash
omarchy-macifier status                     # what is on
omarchy-macifier preset minimal|full|off    # a named set
omarchy-macifier option scroll on|off       # one option
omarchy-macifier list                       # available options
```

The panel is also reachable over IPC, so it can be bound to a key or a menu entry:

```bash
qs -p /usr/share/omarchy/shell ipc call local.macifier toggle
```

## Layout

```
bin/omarchy-macifier    → ~/.local/bin/              CLI, single source of truth for state
hypr/options/*.lua      → ~/.local/share/macifier/options/   one fragment per option
plugin/                 → ~/.config/omarchy/plugins/macifier/   bar widget + options panel
docs/PLAN.md            implementation plan, phases, risks, open questions
docs/FRICTION-LOG.md    the newcomer-friction findings this project came out of
```

The panel owns no state. It reads `omarchy-macifier status --json` and calls back into the
CLI, so the bar, the panel and the terminal can never disagree about what is on.

Adding an option means: a fragment in `hypr/options/`, one line in the `OPTIONS` table in
the CLI, and a label in `Widget.qml`. Options that are not Hyprland config (like
`windowtitle`, which edits the bar layout) declare a different `kind` and get explicit
apply/revert functions.

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
