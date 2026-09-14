# Macifier — implementation plan

**Goal:** one opt-in, fully reversible switch that makes Omarchy feel familiar to a Mac
switcher, offered once at first run. Not a fork, not a theme, not a rebrand.

**Positioning:** *"make the first hour familiar."* Explicitly NOT "turn Omarchy into macOS."
The difference matters for every conversation about this — the first is a nicety for
newcomers, the second reads as an attack on the project's identity.

---

## 1. What already exists (verified 2026-09-14)

Omarchy has **two** independent toggle mechanisms. A macifier needs both.

### 1a. Hyprland config toggles
```
omarchy hyprland toggle <flag> [on|off|toggle]
```
Copies `$OMARCHY_PATH/default/hypr/toggles/<flag>.lua`
    → `~/.local/state/omarchy/toggles/hypr/<flag>.lua`

That directory is sourced wholesale and hot-reloaded by
`/usr/share/omarchy/default/hypr/toggles.lua` (via `require_all.files(..., reload = true)`).
Shipped examples: `flags.lua`, `single-window-aspect-ratio.lua`, `window-no-gaps.lua`.

> **Constraint that shapes everything:** `on()` copies *from the package directory*. A user
> cannot register a new flag without shipping a file into `/usr/share/omarchy/`. So the real
> feature must land in the repo; a local prototype must write the state file directly.

### 1b. Generic feature flags
```
omarchy toggle <flag> [on|off|toggle]     # touch/rm ~/.local/state/omarchy/toggles/<flag>
omarchy toggle enabled <flag>             # query, exit 0/1
```
A marker file with no content. This is how non-Hyprland code asks "is this mode on?"

### 1c. First-run invitations
`/usr/share/omarchy/install/user/first-run/*.hook` — the pattern for asking once.
`setup-agent.hook` is the model:

```bash
if [[ -z $(omarchy-default-agent) ]] && omarchy-done ensure agent-setup-invitation; then
  omarchy-notification-send -u critical -g 󰚩 "Set your default agent" \
    "Let your favorite agent help with Omarchy." \
    --exec omarchy menu summon setup.default.agent
fi
```

`omarchy-done ensure <name>` guarantees once-only. `--exec` makes the notification clickable
into a menu route. **This is exactly the shape of the launch-time question.**

### 1d. Menu entries
`default/omarchy/omarchy-menu.jsonc`. Dotted ids infer parents; `checked` renders a ✓:

```jsonc
"setup.macifier": {"icon":"","label":"Mac affinity",
  "checked":"omarchy toggle enabled macifier",
  "action":"omarchy-macifier toggle"}
```

---

## 2. Scope for v1

Deliberately small. Each item is already evidenced in `omarchy-tech-debt.md`.

| # | Change | Surface | Mechanism | Evidence |
|---|---|---|---|---|
| 1 | `natural_scroll = true` | Hyprland | 1a fragment | TD-005, verified |
| 2 | Modifier labels → Command / Option / Control | `omarchy-menu-keybindings` | 1b flag read | TD-001 |
| 3 | `omarchy.active-window` on the bar | `shell.json` | imperative + revert state | TD-006 |
| 4 | Onboarding line: folders bookmark, files star | docs | docs only | TD-007 |
| 5 | Toggle control in the bar (top right), self-naming when on | `shell.json` + new plugin | third-party bar-widget | this section |

### Explicitly out of v1
- **Cmd-based copy/paste (`SUPER + C/V`).** The trap. Terminals, Chromium and TUI apps each
  handle it differently; upstream already has scars ([#7027](https://github.com/omacom/omarchy/issues/7027),
  [#6816](https://github.com/omacom/omarchy/issues/6816)). Breaking copy/paste would
  discredit the whole idea on contact. Revisit only once v1 is accepted and stable.
- **Mission-Control-style overview.** New UI, not a defaults change. Different proposal.
- **Anything contested among switchers** (some retrain to PC scroll direction on purpose).
  If it ships at all, it ships as its own sub-toggle.

---

## 2a. The bar toggle (item #5)

**Terminology:** the top bar is **the bar** (`omarchy.bar`). It has three sections —
`left`, `center`, `right`. "Up right" is the **`right`** section, currently holding
`tray, agents, bluetooth, network, audio, monitor, power`.

### Why this belongs in v1
It makes the reversibility *visible*. A mode you can see and click off is trusted in a way
a mode buried in a menu is not — and reversibility is the entire claim. It also answers
"how do I undo this?" before the user has to go looking, which is the failure mode TD-003
is all about.

### How (verified)
Omarchy's plugin system takes third-party bar widgets:
```
omarchy plugin add [git-url] [--enable]   # install from git
omarchy plugin validate <folder>          # check against the manifest schema
omarchy plugin enable <id> [placement]    # place it on the bar
omarchy plugin list                       # ID / STATE / SOURCE / KINDS
```
`omarchy plugin list` reports a `SOURCE` column (`first-party` today), so non-first-party is
an expected state. User plugins live in `~/.config/omarchy/plugins/` (present, empty).

A macifier widget is therefore a **self-contained plugin folder** — no stock file touched:

```
~/.config/omarchy/plugins/macifier/
├── manifest.json      # kinds: ["bar-widget"], barWidget.defaultSection: "right"
└── Macifier.qml       # icon reflecting state; click → omarchy-macifier toggle
```

Behaviour: read `omarchy toggle enabled macifier` for state, render an on/off icon, toggle on
click, tooltip naming what it changes.

### Rejected alternative
Adding "Macifier" to the stock `omarchy.indicators` widget. Its indicator list is a **fixed
enum** in the manifest (Dictation, ScreenRecording, Reminder, NightLight, Dnd, StayAwake),
so extending it means cloning a first-party plugin — heavier, and it forks stock code we would
then have to keep in sync. A standalone widget is cleaner and independently shippable.

### Consequence for the revert story
This *lightens* the hardest problem. Item #3 (`active-window` on the bar) mutates
`shell.json` and needs recorded revert state. A dedicated widget the user enables once is
theirs — `off` should change the mode, **not** remove the widget, exactly as switching night
light off does not remove its indicator. Keep those two behaviours distinct or `off` will
delete the only control for turning it back `on`.

### RESOLVED 2026-09-14 — no git repo needed
Tested with a throwaway plugin folder. A plain directory in `~/.config/omarchy/plugins/`
containing `manifest.json` + the QML entry point is discovered automatically:

```
$ omarchy plugin validate ~/.config/omarchy/plugins/macifier-test   # exit 0
$ omarchy plugin list
local.macifier-test    disabled   third-party   bar-widget   Macifier (test)
```

It registers as `third-party` and arrives **disabled**, so nothing appears on the bar until
`omarchy plugin enable <id> right`. `plugin add <git-url>` is for *distributing* a plugin,
not for authoring one. Phase 0 is therefore fully local — no repo, no publishing.

Minimum viable manifest (verified to validate):
```json
{
  "schemaVersion": 1,
  "id": "local.macifier", "name": "Macifier", "version": "0.0.1",
  "author": "kolyk", "license": "MIT", "description": "...",
  "kinds": ["bar-widget"],
  "entryPoints": { "barWidget": "Widget.qml" },
  "barWidget": {
    "displayName": "Macifier", "description": "...",
    "category": "Status", "allowMultiple": false, "defaultSection": "right"
  }
}
```

### Built 2026-09-14 — Phase 0 complete
Working prototype, verified by screen capture in both states:

| Piece | Path |
|---|---|
| Fragment template | `~/.local/share/macifier/macifier.lua` |
| Live state | `~/.local/state/omarchy/toggles/hypr/macifier.lua` |
| CLI | `~/.local/bin/omarchy-macifier` (`on\|off\|toggle\|status`) |
| Bar widget | `~/.config/omarchy/plugins/macifier/` (`local.macifier`) |

**On:** Apple glyph at full opacity + the word "Macifier". **Off:** dimmed glyph alone, width
collapses. The widget names itself when active — an unlabelled glyph is a puzzle, and the
visible name doubles as the answer to "what is changing my machine, and how do I stop it?"

**Gotcha worth recording:** editing a plugin's `.qml` does **not** hot-reload. `shell.json`
changes do; QML needs `omarchy restart shell`. Cost ~20 minutes of debugging a widget that
was already correct.

**Contents so far:** natural scroll only (item #1). Items #2 and #3 are Phase 2.

---

## 3. Architecture

`omarchy-macifier <on|off|toggle|status>` — one script, because the changes span three
surfaces and #3 needs revert state.

```
on:
  omarchy toggle macifier on                    # marker, so other code can query
  omarchy hyprland toggle macifier on           # Hyprland fragment (natural scroll)
  record whether omarchy.active-window was already on the bar
  omarchy bar put omarchy.active-window --section left

off:
  omarchy bar remove omarchy.active-window      # ONLY if we added it
  omarchy hyprland toggle macifier off
  omarchy toggle macifier off
  # NOTE: the macifier bar widget itself is NOT removed — it is the control
  # that turns the mode back on.
```

**Reversibility is the whole product claim — it cannot be approximate.**
- Never write into `~/.config/hypr/*.lua`. User files are the user's; a mode that edits them
  is not cleanly removable and the claim collapses.
- #3 mutates `shell.json`, which the user may have customised. Record prior state under
  `~/.local/state/omarchy/macifier/` and restore exactly. If the widget was already there,
  `off` must leave it there.
- Test: `on` → `off` → `git diff`-equivalent on every touched file must be empty.

**#2 is a read, not a write.** `modmask_to_text()` consults `omarchy toggle enabled macifier`
and picks a label table. No state to revert, and no behaviour change for anyone not opted in.

---

## 4. Phases

### Phase 0 — local prototype (no repo, no PR)
Write `~/.local/state/omarchy/toggles/hypr/macifier.lua` by hand; confirm it loads and
hot-reloads. Hand-roll `omarchy-macifier` in `~/.local/bin`. Live on it for a week.
*Purpose: find out whether this is actually nicer, before asking anyone for anything.*

### Phase 1 — the fragment
`default/hypr/toggles/macifier.lua` + the script + a `setup.macifier` menu entry.
Smallest reviewable unit; works standalone.

### Phase 2 — cross-surface
Modifier labels (#2) and the bar widget (#3), each separately reviewable.
#2 should probably be proposed on its own merits too — it is a plain bug for Mac users
whether or not a macifier ever exists.

### Phase 3 — the first-run question
`install/user/first-run/macifier.hook`, gated on `omarchy-hw-apple-silicon` so it only ever
appears on Apple hardware. Wording matters — offer familiarity, don't disparage the default:

> **Coming from a Mac?**
> Match Mac scrolling, key names, and window titles. Reversible anytime.

Never auto-enable. The question is the feature; a silent default would be the same category
of mistake as TD-003.

### Phase 4 — propose
Marcelo first (`maralcbr/omarchy-mx-mac`). His layer, small audience, fast feedback, and
his fork already decided its users are Mac switchers. Upstream only if it proves itself, and
gated on `omarchy-hw-apple-silicon` there regardless.

---

## 5. Risks

1. **Scope-creep objection.** "Now every future default needs a macifier branch."
   *Counter:* one fragment, sets documented options only, adds no new code paths, off by
   default, deletable in one command.
2. **Maintainer identity.** Omarchy is opinionated by design; a "make it like the other OS"
   mode can read as undermining that. *Counter:* it is off by default and asked once — the
   opinion stays the default, the switcher gets a ramp.
3. **The `on()`-copies-from-package constraint (1a).** Nothing ships without a repo change.
   Phase 0 must therefore write state files directly and accept that it is not the real
   mechanism.
4. **Cross-surface revert is where this breaks.** #1 and #2 are trivially reversible; #3 is
   not. If revert state proves fragile, ship v1 with #1 and #2 only and treat #3 as a
   documented suggestion instead.
5. **`stable` vs `edge`.** Verify every claim on `stable` before proposing. This machine runs
   `omarchy-dev` on `edge`.

---

## 6. Open questions

- [ ] Does anything besides `omarchy-menu-keybindings` render modifier names? (OSD, menu,
      cheat sheets) — if so, #2 needs a shared helper rather than a local table.
- [ ] Is there an existing pattern for a script recording revert state, or would
      `~/.local/state/omarchy/macifier/` be novel? Prefer matching an existing convention.
- [ ] Does the fork already patch any of these? Check `maralcbr/omarchy-mx-mac` diffs before
      proposing — it may have solved some of this already.
- [ ] Has a "Mac mode" been proposed upstream before? Not yet searched.

---

## 7. Immediate next step

Phase 0, item 1 only: the Hyprland fragment with `natural_scroll`, written directly to the
state directory, toggled on and off by hand to prove the round trip is clean. One file, one
setting, no repo, no proposal. Everything else waits on that working.

---

# Design: ⌘Tab app switcher with an app bar

**Status:** DESIGNED, not built · 2026-09-14 · Full only

## What it should do
Hold ⌘, tap Tab to walk a horizontal bar of **running applications** — icons, most-recent
first — release ⌘ to switch. ⌘` cycles windows *within* the focused app. This is the single
most-used interaction on a Mac after copy/paste, and the one whose absence is felt hourly.

## What exists today
| Keys | Behaviour | Verdict |
|---|---|---|
| `SUPER+TAB` | Next **workspace** | Wrong target — must move |
| `ALT+TAB` | Focus next **window** | Right idea, no grouping, no overlay |
| `SUPER+SHIFT+TAB` | Previous workspace | Must move |

`ALT+TAB` already cycles windows, so the gap is not switching — it is **grouping by
application** and **showing what you are switching to**.

## Feasibility: confirmed
Hold-to-cycle needs modifier-*release* detection, and Omarchy's bind helper already
supports it — `default/hypr/bindings/voxtype.lua:4` uses `{ release = true }` for
push-to-talk. So the shape is:

```lua
o.bind("SUPER + TAB", "App switcher", advance)            -- open, then advance
o.bind("SUPER_L",     "Commit",       commit, { release = true })  -- release to switch
```

The overlay itself is a Quickshell **overlay-kind plugin**, the same shape Omarchy already
ships for the clipboard, emoji picker and image picker — so there is a working template in
tree rather than a new UI surface to invent.

## Grouping by app
`hyprctl clients -j` gives `class` and `title` per window. Group by `class`, order by
most-recently-focused, resolve an icon from the matching `.desktop` file. A window with no
desktop entry falls back to its class name as text — better than a blank tile.

## Where the displaced workspace shortcuts go
`SUPER+TAB` / `SUPER+SHIFT+TAB` must move, the same problem `cmdkeys-wm` already solved
for letters. `CTRL+ALT+TAB` is **not** free (Focus next monitor). Candidates, in order:
`SUPER+ALT+TAB` (appears free), or fold workspace cycling into the existing
`SUPER+CTRL+←/→` family if one exists. **Check before building.**

## Prior art — check before writing code
- [omacom/omarchy#7838](https://github.com/omacom/omarchy/issues/7838) — **open** — "Proposal:
  macOS-friendly Tab keybindings (SUPER+TAB for windows, not workspaces)". Directly this
  idea, already raised upstream. Read the thread first; if it is moving, contribute there
  rather than duplicating, and Macifier just enables it.
- `hyprswitch` (AUR, v5.0.0, `arch=any`, only 2 votes) — an existing Hyprland app switcher
  with hold-modifier support. Evaluate before building: if it is good, the option becomes
  "install and bind", which is far less to maintain. Low vote count argues for caution.

## Risks
1. **Synthetic key state.** `clipboard.lua` carries a down/up split workaround for Hyprland
   leaving injected key state stuck (hyprwm/Hyprland#14099). A switcher holding a modifier
   is the most likely place to hit that class of bug. Prototype the release-bind alone,
   before any UI.
2. **Reversibility.** An overlay plugin is a separate package from the Lua fragment, so
   `off` must both remove the fragment and disable the plugin. Same two-surface problem as
   `windowtitle`; reuse that pattern.
3. **Scope.** This is the first option needing real UI rather than config. It is plausibly
   a bigger job than everything else in Macifier combined — and a good candidate for the
   first outside contributor.

## Order of work
1. Read #7838; decide contribute-vs-build
2. Evaluate `hyprswitch` on aarch64
3. Prototype the release-bind alone — no UI — to prove hold-to-cycle is reliable
4. Only then build the overlay
