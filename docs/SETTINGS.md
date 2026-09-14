# Macifier Settings — plan

**Status:** DESIGNED, not built · 2026-09-14

One window that answers "where do I change this?" for someone who has used a Mac
for ten years and Omarchy for ten minutes.

Today Macifier's panel lists seven of our own options. Omarchy's own settings
live in a different place (`SUPER + SPACE` → the menu), organised by *what the
command does* rather than *what the user wants to change*. A Mac switcher
looking for "make the trackpad scroll the other way" does not know to look under
Setup → Input, and does not know that some of what they want is not Omarchy's
job at all.

Macifier Settings is one surface that lists **everything a Mac has a setting
for**, says for each one whether Omarchy has it, who provides it, and — where
nothing provides it — is honest that it does not exist here.

---

## 1. What the window is

A **macOS System Settings clone**: sidebar of panes on the left, rows on the
right, search at the top. Not a copy of Omarchy's menu with a new skin. The
organisation is the point: a Mac user finds things where a Mac puts them.

### The icon

macOS System Settings is a grey rounded square with gears. Ours is the same
shape in the theme's own colours — a rounded-square tile with a gear glyph,
drawn the way `plugin-dock/Dock.qml` already draws dock tiles, so it looks like
the rest of Macifier and not like a pasted screenshot of Apple's artwork.

- Glyph: `` (`nf-md-cog`), the closest Nerd Font shape to Apple's gears.
- Tile: same corner radius and inner shadow as the dock's app tiles.
- It appears in three places: the dock (pinned by default when `dock` is on),
  the Macifier bar widget (click → open), and the Omarchy menu.

Deliberately **not** a photographic Apple icon. We are not shipping Apple's
artwork, and a tile that matches the user's theme ages better than one that
matches macOS Tahoe.

### How it is built — verified

Omarchy accepts exactly three plugin kinds. From
`/usr/share/omarchy/bin/omarchy-plugin-validate:99-101`:

```
"bar-widget:barWidget"   "menu:menu"   "overlay:overlay"
```

So Settings is a fourth Macifier plugin, `local.macifier-settings`, of kind
`overlay` — the same shape as `plugin-dock` and `plugin-switcher`, and the same
shape Omarchy itself uses for the clipboard, emoji and image pickers
(`shell/plugins/clipboard/manifest.json`).

Three further mechanisms are already there and worth using rather than
reinventing:

| Mechanism | Where | What it buys us |
|---|---|---|
| User menu extension | `~/.config/omarchy/extensions/omarchy-menu.jsonc`, read and hot-watched at `shell/plugins/menu/Menu.qml:51` | Macifier can add its own rows to Omarchy's menu without touching any package file. Reversibility survives. |
| Declarative settings schema | `manifest.barWidget.schema` / `.defaults` / `.settingsForm`, consumed at `shell/shell.qml:1400-1412`; worked example in `shell/plugins/agents/manifest.json` | Typed rows (`integer`, `enum`, `path`, `string`) that Omarchy renders itself. Our rows should use the same vocabulary so they feel native. |
| Shell UI primitives | `/usr/share/omarchy/shell/Ui/` — `Panel`, `PanelSlider`, `ToggleSwitch`, `Dropdown`, `SearchableDropdown`, `MultiSelect`, `NumberField`, `ConfirmDialog`, `PanelSectionHeader` | Every control System Settings needs already exists, themed. We write layout, not widgets. |

**Constraint that shapes the build:** editing a plugin's `.qml` does not
hot-reload; `omarchy restart shell` is required (already recorded in
`docs/PLAN.md`). Budget for it in every iteration.

---

## 2. Status tags

Every row in the window carries exactly one tag. This is the feature the user
asked for and the thing that makes the window honest.

| Tag | Means | Row behaviour |
|---|---|---|
| **Omarchy** | Omarchy already does this | Row acts — flips the toggle, or opens the Omarchy menu at the right route |
| **Macifier** | Macifier provides it | Row acts, same as the panel today |
| **Plugin** | A published third-party plugin does it | Row shows the plugin name and an **Install** button (`omarchy plugin add <url> --enable`) |
| **Planned** | Nothing provides it; we intend to build it | Row is inert, shows the phase it is scheduled in |
| **Not on Linux** | Apple hardware or an Apple service; there is nothing to build | Row is dimmed, non-interactive, with one line saying *why* |

The last tag is the one most projects skip. Showing "AirDrop — Not on Linux:
Apple-only protocol, no compatible implementation" is more useful than silently
omitting AirDrop, because the user's actual question is "did I miss it, or is it
gone?" Omitting it answers neither.

**Rule:** a **Not on Linux** row must always name the reason in one line, and
must name the nearest Linux equivalent when one exists. "AirDrop — Not on Linux.
Closest: `omarchy menu` → Trigger → Share, over Tailscale."

---

## 3. The inventory

Organised by macOS System Settings pane, in sidebar order. Every row is a thing
a Mac user can change. The middle column is what Omarchy calls it.

### Wi-Fi · Bluetooth · Network

| macOS | Omarchy | Tag |
|---|---|---|
| Wi-Fi networks, join, forget | `omarchy.network` bar widget | Omarchy |
| Wi-Fi password / QR | `setup.network.qr`, `omarchy-network-password` | Omarchy |
| Bluetooth devices, pair | `omarchy.bluetooth` bar widget | Omarchy |
| DNS servers | `setup.network.dns` (DHCP/Cloudflare/Google/Custom) | Omarchy |
| VPN | — | Plugin (33 in the registry; pick one, do not build) |
| Firewall | — | Planned (P4) |
| Personal Hotspot | — | Plugin (`Omarchy Hotspot`, marketplace #6417) |
| AirDrop | — | **Not on Linux** — Apple-only protocol. Closest: Trigger → Share (Tailscale) |

### Battery

| macOS | Omarchy | Tag |
|---|---|---|
| Battery percentage in bar | `omarchy.power` widget | Omarchy |
| Low Power Mode / Energy Mode | `omarchy-powerprofiles-set` | Omarchy |
| Turn display off after… | `shell.json` → `idle.screensaver` / `idle.lock` | Omarchy |
| Battery health | — | Plugin (`Battery Insights` #6390, `Battery Guardian` #6889) |
| Optimised charging / charge limit | — | Planned (P4, Apple Silicon only, needs `omarchy-hw-apple-silicon`) |

### General

| macOS | Omarchy | Tag |
|---|---|---|
| About This Mac | `about` → `omarchy-launch-about` | Omarchy |
| Software Update | `update.omarchy`, `update.channel` | Omarchy |
| Storage | `omarchy-drive-info`, `omarchy-disk-speedtest` | Omarchy |
| Login Items | `install/user/first-run/*.hook`, autostart | Planned (P3 — no UI today) |
| Language & Region | `update.timezone`, `/etc/vconsole.conf` layout | Omarchy (partial) |
| Date & Time | `update.time`, `update.timezone` | Omarchy |
| Sharing (screen, file, remote login) | `setup.security.sshd` | Omarchy (partial) |
| Time Machine | — | Plugin (`jankeesvw/omarchy-time-machine`, 105★ — restic + bar browser) |
| Transfer or Reset | `setup.reset` → `omarchy-system-factory-reset` | Omarchy |
| Startup Disk | limine / `omarchy-refresh-limine`; dual-boot macOS via `sid.boot-macos` | Omarchy + Plugin |
| AutoFill & Passwords | 1Password / Bitwarden install entries | Omarchy (install only) |
| Handoff & Continuity | — | **Not on Linux** — Apple service. Closest: KDE Connect (`ekollof.omaconnect`) |
| Device Management (MDM) | — | **Not on Linux** — no equivalent, and nothing to miss |

### Appearance

| macOS | Omarchy | Tag |
|---|---|---|
| Light / Dark / Auto | `style.theme` — Omarchy themes are whole-system, not a light/dark axis | Omarchy (different model — say so in the row) |
| Accent colour | Theme-defined (`omarchy-theme-color`) | Omarchy |
| Sidebar icon size | — | **Not on Linux** — no shared sidebar idiom |
| Allow wallpaper tinting | — | Planned (P4 — Cupertino-style vibrancy; see `Mudales/omarchy-cupertino`) |
| Show scroll bars | Per-toolkit (GTK/Qt), not system-wide | **Not on Linux** — no single setting exists |
| macOS-flavoured chrome (rounded, frosted) | — | Plugin (`Mudales/omarchy-cupertino`, `macarchy/apple-glass-light`) |

### Desktop & Dock — *the densest pane, and the heart of Macifier*

| macOS | Omarchy | Tag |
|---|---|---|
| Dock — show/hide | `dock` | **Macifier** (shipped) |
| Dock — pinned apps | `omarchy-macifier dock <id> add\|remove` | **Macifier** (shipped) |
| Dock — position on screen | — | Planned (P1 — bottom only today) |
| Dock — size | — | Planned (P1) |
| Dock — magnification | — | Plugin (`wisangdg/omarchy-magnify-dock`, `ifubaraboye/omarchy-dock`) or P2 build |
| Dock — automatically hide | Always auto-hides today | Planned (P1 — make it a choice) |
| Dock — indicators for open apps | Dot under running apps | **Macifier** (shipped) |
| Dock — minimise effect (genie/scale) | Hyprland has no minimise-to-dock | Planned (P3 — hard; see §6) |
| Dock — recent apps | — | Planned (P1) |
| Mission Control | — | Plugin (`AndyWeiBoan/omarchy-mission-control`, `zzwong/omarchy-stage`, `rmacy/…`) |
| App Exposé | — | Plugin (`kristofferR/omarchy-expose`, 24★, the healthiest of the bunch) |
| Stage Manager | — | Plugin (`debba/omarchy-stage-manager`, `zzwong.stage`, `community.workspace-stage`) |
| Spaces (multiple desktops) | Hyprland workspaces | Omarchy |
| Displays have separate Spaces | Hyprland: per-monitor workspaces | Omarchy |
| Hot Corners | — | Plugin (`OmarGonD/omacorners`, `sahzudin`, `abdul`, `abhinav` — four of them) |
| Tiled windows (drag to edge) | Hyprland tiles by default | Omarchy (inverted default — explain, don't "fix") |
| Window margins / gaps | `omarchy toggle window-gaps`, `window-no-gaps.lua` | Omarchy |
| Close windows when quitting an app | — | **Not on Linux** — no app/window distinction in Hyprland |
| Prefer tabs when opening documents | Per-app | **Not on Linux** |
| Default web browser | `setup.default.browser` | Omarchy |
| Widgets on desktop | — | Plugin (many bar widgets; no desktop layer) |

### Displays

| macOS | Omarchy | Tag |
|---|---|---|
| Resolution / scaling | `setup.monitors`, `omarchy-hyprland-monitor-scaling` | Omarchy |
| Arrangement | `setup.monitors` | Omarchy |
| Brightness | `omarchy-brightness-display` (+ `-apple`, `-ddc`) | Omarchy |
| True Tone | — | **Not on Linux** — needs Apple's ambient sensor pipeline |
| Night Shift | `omarchy toggle nightlight`, hyprsunset | Omarchy |
| Refresh rate | `setup.monitors` | Omarchy |
| Auto-brightness | — | Plugin (`hz.auto-brightness` — MacBook ALS) |
| AirPlay to Mac / Sidecar | — | **Not on Linux** — Apple protocol. Closest: Sunshine/Moonlight (`install.service.sunshine`) |

### Keyboard

| macOS | Omarchy | Tag |
|---|---|---|
| Key repeat rate / delay | `default/hypr/input.lua:60-61` → `repeat_rate`, `repeat_delay` | Omarchy (config only — no UI) → Planned (P2 UI) |
| Keyboard brightness | `omarchy-brightness-keyboard` | Omarchy |
| Caps Lock behaviour | `capslock` | **Macifier** (shipped) |
| F1–F12 vs media keys | `mediakeys` | **Macifier** (shipped) |
| Modifier Keys (remap ⌘/⌥/⌃) | — | Planned (P2) + Plugin (`oliverlukschander.mac-option`, `asaharan.omackey`) |
| Keyboard Shortcuts — app shortcuts (⌘S ⌘F …) | `cmdkeys`, per-key editor | **Macifier** (shipped) |
| Keyboard Shortcuts — ⌘Tab | `appswitcher` | **Macifier** (shipped) |
| Keyboard Shortcuts — see all bindings | `setup.keybindings` / `SUPER + K` | Omarchy |
| Input Sources (layouts) | `omarchy.keyboard-layout` widget, `/etc/vconsole.conf` | Omarchy |
| Text Replacements | XCompose (`setup.config.xcompose`) | Omarchy (different model) |
| Dictation | `install.ai.dictation`, voxtype | Omarchy |
| Press 🌐 to… | — | **Not on Linux** — no Globe key outside Apple keyboards |
| Emoji picker | `trigger.emoji` / `omarchy-menu-emoji` | Omarchy |

### Trackpad & Mouse

| macOS | Omarchy | Tag |
|---|---|---|
| Natural scrolling | `scroll` | **Macifier** (shipped) |
| Tracking speed | `input.sensitivity`, `default/hypr/input.lua:58` | Omarchy (config only) → Planned (P2 UI) |
| Tap to click | `tap_to_click` (off for Apple pads — `default/hypr/input.lua:78-79`) | Omarchy (config only) → Planned (P2 UI) |
| Secondary click | `clickfinger_behavior = true` — two-finger right-click, already Mac-like | Omarchy |
| Scroll speed | `touchpad.scroll_factor`, per-terminal overrides | Omarchy |
| Swipe between Spaces (3/4 finger) | `hl.gesture(...)` — **present but commented out**, `config/hypr/input.lua:56-62` | Planned (P1 — one-line win) |
| Swipe up for Mission Control | Depends on a Mission Control plugin | Plugin + Planned (P2 wiring) |
| Force click / haptics | `omarchy-hw-dell-xps-haptic-touchpad` exists; nothing for Apple | **Not on Linux** (Apple Silicon: no force-touch driver) |
| Magic Mouse / Magic Trackpad feel | — | Plugin (`maikunari/omarchy-magic-mouse`, `lxp-git/omarchy-trackpad`) |

### Notifications · Focus · Sound

| macOS | Omarchy | Tag |
|---|---|---|
| Do Not Disturb | `trigger.toggle.notifications`, `Dnd` indicator | Omarchy |
| Focus modes (Work, Sleep, custom) | — | Planned (P4) |
| Notification Center (history) | — | Plugin (`Shavanced/omarchy-notification-center-plugin`) |
| Per-app notification settings | — | Planned (P4) |
| Output / input device | `omarchy.audio` widget, `omarchy-audio-output-switch` | Omarchy |
| Alert sound / UI sound effects | Omarchy is silent by design | **Not on Linux** (as shipped) — say so plainly |
| Volume in bar | `omarchy.audio` | Omarchy |

### Lock Screen · Touch ID · Users & Groups · Privacy

| macOS | Omarchy | Tag |
|---|---|---|
| Start screen saver when inactive | `shell.json` → `idle.screensaver` | Omarchy |
| Require password after… | `shell.json` → `idle.lock` | Omarchy |
| Screen saver style | `style.screensaver` (text / image / default) | Omarchy |
| Wallpaper | `style.background`, `omarchy-theme-bg-*` | Omarchy |
| Touch ID | `setup.security.fingerprint` | Omarchy |
| Login password | `update.password.user` | Omarchy |
| FileVault (disk encryption) | `update.password.drive` (LUKS) | Omarchy |
| Hardware key | `setup.security.fido2` | Omarchy |
| Screen Time | — | Plugin (`ax1g/quickshell-screentime-plugin`) |
| Per-app camera/mic/location permissions | Portals exist; no UI, no per-app policy | **Not on Linux** — Wayland/portals have no macOS-equivalent permission ledger |
| Gatekeeper / "apps downloaded from" | pacman + AUR trust model | **Not on Linux** — different model entirely |
| Lockdown Mode | — | **Not on Linux** |

### Spotlight · Finder · Quick Look · Menu Bar

| macOS | Omarchy | Tag |
|---|---|---|
| Spotlight (⌘Space) | `SUPER + SPACE` opens the Omarchy menu — same key, different thing | Omarchy + Plugin (`maajix/omarchy-spotlight`, Raycast-style) |
| Spotlight search categories / privacy | — | Planned (P4, only if we ship our own launcher) |
| Launchpad | — | **Planned (P2)** — no published plugin exists; two open marketplace submissions (#6677, #6701) |
| Quick Look (Space to preview) | — | Plugin (`ccdwyer/omarchy-quicklook`, `andreconde.quick-look`) |
| Finder preferences | Nautilus (`omarchy-launch-nautilus`) | Omarchy (partial) + Plugin (`shafayet.finder`) |
| Look Up (⌃⌘D dictionary) | — | Plugin (marketplace #6385, Webster's 1913) |
| Menu bar — position | `style.bar.position` (top/bottom/left/right) | Omarchy |
| Menu bar — transparency | `style.bar.transparency` | Omarchy |
| Menu bar — which items show | `shell.json` → `bar.layout.{left,center,right}` | Omarchy |
| Menu bar — auto-hide | — | Planned (P3) |
| Menu bar — collapse extras (Bartender) | — | Plugin (`kevclarkco/omarchy-menubar-manager`) |
| Window title in the bar | `windowtitle` | **Macifier** (shipped) |
| Per-app menus in the menu bar (File/Edit/View) | — | **Not on Linux** — Wayland has no protocol associating menus with surfaces ([hyprwm/Hyprland#1358](https://github.com/hyprwm/Hyprland/discussions/1358)). This is the single biggest irreducible difference, and the row should say so. |
| Notch handling | `omarchy-mac` ships it (`install/hardware/apple/enable-notch.sh`) | Omarchy (on `omarchy-mac`) + Plugin (`omarchy-notch`, `macnook`, `gustavo.notchbar`) |

### Apple services — the whole "Not on Linux" block

Shown as one collapsed section, every row dimmed, each with its reason. Users
scroll it once, understand the shape of what is gone, and never look again.

Apple Account · iCloud · iCloud Drive · Family Sharing · Apple Intelligence ·
Siri · Wallet & Apple Pay · Game Center · Apple Pay · Screen Mirroring to Apple
TV · Sidecar · Universal Control · Continuity Camera · Handoff · Universal
Clipboard · Find My · Photos library · Messages · FaceTime · Music/TV/Podcasts
integration · Safari settings · Mail/Calendar/Contacts accounts (partial: see
`Internet Accounts` plugins).

Three of these have real Linux substitutes worth naming inline:
- **Universal Clipboard** → KDE Connect (`ekollof.omaconnect`), `omaclip`
- **iCloud Drive** → marketplace #4242, or Dropbox/Syncthing
- **Apple Music** → six separate plugins in the registry; pick one

---

## 4. What the numbers say about prior art

The Omarchy plugin marketplace (`omacom/omarchy-plugin-marketplace/registry.json`)
lists **3,107 published plugin sources** as of today. Filtering for Mac-shaped
features gives ~84 candidates. The distribution is lopsided and worth reading
before we write a line of code:

| Feature | Published plugins | Read as |
|---|---|---|
| Dock | 15+ | Solved many times over. **Our dock's value is integration, not existence.** |
| Mission Control / Exposé / overview | 12+ | Solved. Adopt. |
| Hot corners | 4 | Solved. Adopt. |
| Mac keybindings / modifier remap | 4 | Overlaps `cmdkeys`. Compare before extending. |
| Quick Look | 2 | Adopt. |
| Spotlight-style launcher | 1 | Adopt (`maajix`). |
| Stage Manager | 3 | Adopt. |
| Launchpad | **0 published** | **Gap.** Two submissions pending review. |
| Accessibility | **0** | **Gap**, and a real one. |
| Printers | **0** | Gap; low priority (CUPS web UI exists). |
| AirDrop / Handoff / Night Shift standalone | 0 | Correctly absent — native or impossible |

But every one of those repos is **young and thinly starred**: the healthiest
Mac-feature plugin we found is `omarchy-expose` at 24★; most sit at 0–10. All
MIT, all pushed within the last three weeks. So:

**Recommendation — do not vendor, do not fork, do not rebuild.** Macifier's
Settings window should *offer to install* these plugins by their real ids and
record which ones it enabled, so `off` can disable exactly those and nothing
else. If a plugin dies, the row degrades to **Planned** and we have lost
nothing. If we had forked it, we would own it.

The one project that looks like competition is
[`mjmanzini/omarchy-macos`](https://github.com/mjmanzini/omarchy-macos) — a
full macOS look-and-feel in one command. It is 0★ and takes the opposite bet:
`hyprpm` plugins (`hyprbars`, `hyprexpo`), AUR themes (`whitesur-gtk-theme`),
Apple fonts and cursors, and it edits `looknfeel.lua`. That is a *skin*, and it
is not cleanly reversible. Macifier's claim is reversibility. Different product;
worth linking to from the Appearance pane as "if you want the whole look".

Note also [`omacom/omarchy-mac`](https://github.com/omacom/omarchy-mac) (1,733★,
pushed today): Omarchy on Apple Silicon. It is a *hardware* layer — notch,
keyboard backlight, Asahi audio — and ships **no** Mac-affinity UX. Its users are
exactly Macifier's audience, and it is where a Phase-4 proposal should go first.

---

## 5. Development plan

Sized in the same unit as everything else in this repo: a phase is what one
person can finish and live on for a week.

### P0 — the window, with nothing new behind it *(the whole point of starting here)*

Build `plugin-settings/` as an `overlay` plugin. Sidebar + rows + search + the
five status tags. Wire **only** what already exists: the seven Macifier options
and deep links into Omarchy's menu routes.

Ship the full inventory from §3 as data, with `Planned` and `Not on Linux` rows
visible and inert from day one. The window is useful the moment it can answer
"does this exist here?" — which is before it can change anything new.

- `bin/omarchy-macifier settings` opens it; `IpcHandler` entry point like the panel's.
- Inventory lives in one JSON file, not in QML, so rows can be added without a shell restart... except QML changes still need one. Keep the data file separate anyway; it is the thing that will change weekly.
- Deep links use `omarchy menu summon <route>` (e.g. `setup.monitors`).
- **Acceptance:** every row in §3 is present with the right tag; every `Omarchy` row goes somewhere; `off` still reverts cleanly.

### P1 — the cheap wins the inventory exposed

Four things that are nearly free and each remove a daily annoyance:

1. **Trackpad gestures** — `hl.gesture({fingers=3, direction="horizontal", action="workspace"})`. The code is already in `config/hypr/input.lua:56-62`, commented out. New Macifier option `gestures`, one Lua fragment, same pattern as `scroll`. *Half a day.*
2. **Dock position / size / auto-hide** — three settings against a dock we already own. *One day.*
3. **Keyboard repeat rate + trackpad tracking speed** — sliders writing a Lua fragment. First Macifier options that are *values*, not booleans; the state format needs to grow to hold them. Do this deliberately, it is the foundation for P2. *One day.*
4. **Plugin install rows** — the `Plugin` tag becomes actionable: `omarchy plugin add <url> --enable`, recorded in `~/.local/state/macifier/plugins` so `off` disables exactly what we enabled. *One day.*

### P2 — Launchpad, and modifier keys

**Launchpad is the one genuine gap with no published plugin.** It is also the
easiest big Mac feature to build well, because we already have every piece: the
dock resolves `.desktop` icons, the switcher already takes exclusive keyboard
focus, and `omarchy-plugin-catalog`'s app enumeration is a solved problem.

- Full-screen blurred overlay, grid of app icons, type to filter, pages, ⎋ to close.
- Bound to F4 and to a dock tile.
- Ship it as its own repo *and* submit it to the marketplace — it fills a hole the ecosystem has, and it is the strongest argument that Macifier is a contributor rather than a re-skinner.

Alongside it: **Modifier Keys** remapping (⌘/⌥/⌃/Caps swap), which two existing
plugins do partially and `cmdkeys` already half-owns. Compare
`oliverlukschander.mac-option` and `asaharan.omackey` first; extending `cmdkeys`
is probably right, but verify.

### P3 — the hard ones

- **Menu bar auto-hide.** Needs `shell.json` mutation plus revert state — the same category as `windowtitle`, so reuse that pattern.
- **Login Items.** No Omarchy UI exists; first-run hooks are the nearest thing.
- **Minimise to dock.** Hyprland has no minimise; the honest implementations use a scratchpad special workspace. Genie effect is out of reach. Consider shipping the *behaviour* and skipping the *animation*, and say so in the row.

### P4 — long tail, only if P0–P2 prove used

Focus modes, per-app notifications, firewall, wallpaper tinting, charge limit,
Spotlight privacy. Each is a small plugin or a small fragment. None is urgent.
Revisit after the window has been lived in.

### Ordering rationale

P0 before everything because the inventory *is* the deliverable — it is the
thing no existing project provides, and it is valuable even if we never build
another option. Fifteen dock plugins exist; zero honest maps of what a Mac
switcher loses exist.

---

## 6. Risks

1. **The window becomes a second Omarchy menu.** If every row just forwards to
   `omarchy menu summon`, we have added indirection and no value. Mitigation:
   the tags. A row that says **Not on Linux** with a reason is doing work the
   menu cannot do. Measure the window by how many rows are *not* forwards.

2. **Plugin churn.** Recommending 0★ repos that vanish. Mitigation: never
   vendor; record what we enabled; degrade a dead row to **Planned**. Re-check
   `registry.json` on a schedule — it is one `gh api` call.

3. **Scope.** This document lists roughly 120 rows. Most are already **Omarchy**
   or **Not on Linux** and cost nothing. The real build is P1's four items plus
   Launchpad. Do not let the size of the table imply the size of the work.

4. **Reversibility, again.** Settings that hold *values* (slider positions)
   are harder to revert than booleans — "off" must restore the previous value,
   not a default. P1 item 3 is where that gets designed; get it right there or
   it will be wrong in twenty places.

5. **Apple's design language.** A System Settings clone invites pixel-copying.
   Use Omarchy's own `Ui/` primitives and the active theme. The *organisation*
   is what a Mac user recognises, not the greys.

6. **Every tag in §3 was decided on one machine.** An M1 Pro MacBook at scale 2
   — see `docs/PLAN.md` risk 6. **Omarchy** rows were confirmed here and nowhere
   else, and a few are hardware-shaped: brightness resolves through
   `-apple`/`-ddc` variants, auto-brightness needs a MacBook sensor, keyboard
   backlight needs Apple's. On x86_64 some **Omarchy** rows are really
   **Not on Linux**, and some **Not on Linux** rows may exist after all.
   Re-check the tags on the first non-Apple machine we get hold of.

---

## 7. Open questions

- [ ] Does `overlay` give us a movable, resizable window, or only a fixed layer?
      `Clipboard.qml` and our `Switcher.qml` are both fixed. A System Settings
      window that cannot be moved will feel wrong. **Prototype this first — it
      could change P0 entirely.**
- [ ] Can a third-party plugin declare `kinds: ["menu"]` usefully, or is the
      user menu extension file the only way to add Omarchy menu rows?
- [ ] Should the inventory JSON live in this repo or be fetched? Fetched stays
      current; bundled works offline and is auditable. Probably bundled, with a
      `settings refresh` command.
- [ ] Marketplace submissions #6677 / #6701 are both Launchpad. If either lands
      before P2, adopt instead of build — and say so without regret.

---

## 8. Sources

Prior art surveyed 2026-09-14. All MIT.

- [omacom/omarchy-mac](https://github.com/omacom/omarchy-mac) — Omarchy on Apple Silicon (1,733★)
- [omacom/omarchy-plugin-marketplace](https://github.com/omacom/omarchy-plugin-marketplace) — 3,107 published plugin sources
- [kristofferR/omarchy-expose](https://github.com/kristofferR/omarchy-expose) — Exposé (24★)
- [AndyWeiBoan/omarchy-mission-control](https://github.com/AndyWeiBoan/omarchy-mission-control) · [zzwong/omarchy-stage](https://github.com/zzwong/omarchy-stage) · [rmacy/omarchy-mission-control](https://github.com/rmacy/omarchy-mission-control) — Mission Control
- [debba/omarchy-stage-manager](https://github.com/debba/omarchy-stage-manager) — Stage Manager
- [OmarGonD/omacorners](https://github.com/OmarGonD/omacorners) — hot corners
- [maajix/omarchy-spotlight](https://github.com/maajix/omarchy-spotlight) — Raycast-style launcher
- [ccdwyer/omarchy-quicklook](https://github.com/ccdwyer/omarchy-quicklook) — Quick Look
- [ifubaraboye/omarchy-dock](https://github.com/ifubaraboye/omarchy-dock) · [wisangdg/omarchy-magnify-dock](https://github.com/wisangdg/omarchy-magnify-dock) — docks with magnification
- [Mudales/omarchy-cupertino](https://github.com/Mudales/omarchy-cupertino) · [macarchy/apple-glass-light](https://github.com/macarchy/apple-glass-light) — macOS-flavoured shell chrome
- [maikunari/omarchy-magic-mouse](https://github.com/maikunari/omarchy-magic-mouse) · [lxp-git/omarchy-trackpad](https://github.com/lxp-git/omarchy-trackpad) — Apple pointing devices
- [aedyle/hypr-trackpad-gestures](https://github.com/aedyle/hypr-trackpad-gestures) — gestures
- [jankeesvw/omarchy-time-machine](https://github.com/jankeesvw/omarchy-time-machine) — restic backups (105★)
- [kevclarkco/omarchy-menubar-manager](https://github.com/kevclarkco/omarchy-menubar-manager) — Bartender-style bar collapse
- [mjmanzini/omarchy-macos](https://github.com/mjmanzini/omarchy-macos) — full macOS skin (the opposite bet)
- [aorumbayev/awesome-omarchy](https://github.com/aorumbayev/awesome-omarchy) — ecosystem index
- [hyprwm/Hyprland#1358](https://github.com/hyprwm/Hyprland/discussions/1358) — why there is no global menu bar
