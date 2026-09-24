# Omarchy — Newcomer Friction & Technical Debt

Focus: **everyday users**, not programmers. Programmers route around these; newcomers
conclude the system is broken or inconsistent and have no vocabulary to ask why.

| Field | Value |
|---|---|
| Machine | Apple MacBook Pro 14-inch, M1 Pro, 2021 |
| Build | `omarchy-dev` 4.0.3.r6962.ga67d7f7 (fork: `maralcbr/omarchy-mx-mac`) |
| Channel | `edge` |
| Upstream | `omacom/omarchy` (was `basecamp/omarchy` — repo moved) |
| Layout | `es` (Spanish) |

**Status legend:** `NEW` logged · `DUP?` upstream check pending · `DUP` already reported ·
`CONFIRMED` novel · `FIXED` resolved upstream

---

## TD-001 — Keybinding UI uses PC modifier names on Apple hardware

**Status:** CONFIRMED (novel as framed) · **Severity:** High (newcomer-facing) · **Affects:** every Mac install

### Current
The keybindings menu (`SUPER + K`) renders modifiers as `SUPER`, `ALT`, `CTRL`.
None of those words appear on an Apple keyboard. The user sees `SUPER + ALT + SPACE`
and must already know that `SUPER` is the key stamped `⌘` and `ALT` is the key
stamped `⌥`. A Mac switcher has no way to derive this.

Actual physical mapping on this machine (`hid_apple`, `swap_opt_cmd=0`):

| Hyprland name | Apple keycap |
|---|---|
| `SUPER` | `⌘` Command |
| `ALT` | `⌥` Option |
| `CTRL` | `⌃` Control |
| `SHIFT` | `⇧` Shift |

### Expected
Modifier names should reflect the hardware. Requested rendering: keep the Hyprland
name but annotate with the Apple name in parentheses — `SUPER (Command)` — so the
user can bridge the two vocabularies rather than memorize a mapping.

*Open design question:* annotating every modifier in every row is verbose
(`SUPER (Command) + ALT (Option) + SPACE`). Candidate resolutions: annotate on first
occurrence only, show a legend at the top of the menu, or substitute names outright
on Apple hardware. Needs a decision before proposing.

### Evidence
`/usr/share/omarchy/bin/omarchy-menu-keybindings:237-257` — `modmask_to_text()` is a
hardcoded lookup table with no hardware awareness:

```bash
modmask_to_text() {
  case "$1" in
    8)  printf 'ALT' ;;
    64) printf 'SUPER' ;;
    72) printf 'SUPER ALT' ;;
    ...
}
```

### Proposed fix
Detection already exists and is already used elsewhere — `apple.lua` gates the cursor
workaround on `omarchy-hw-apple-silicon` (exits 0 on this machine). Gate
`modmask_to_text()` on the same helper. Contained to one function, no new dependency,
no behavior change on non-Apple hardware.

---

## TD-002 — First agent launch floats; every later launch tiles

**Status:** DUP (mechanism) / novel symptom · **Severity:** Medium · **Affects:** first run only (worst possible timing)

### Current
| Path | app-id | Window |
|---|---|---|
| First run — `omarchy-default-agent --install claude` | `org.omarchy.terminal` | **Floats** 875×600 centered |
| Later — `omarchy agent` | `org.omarchy.agent` | **Tiles** |

The installer path borrows the generic `org.omarchy.terminal` id, which is Omarchy's
bucket for transient setup windows (`install.package`, `install.aur`, `remove.package`
all reuse it). Floating those is correct. But the agent session persists after the
installer's job is done, so it inherits overlay treatment it shouldn't keep.

### Expected
Window behavior consistent between first run and steady state.

### Evidence
- `/usr/share/omarchy/default/hypr/apps/system.lua:2-4,7` — `floating-window` tag → float + center + 875×600
- `/usr/share/omarchy/bin/omarchy-agent:137` — `exec omarchy-launch-tui --app-id=org.omarchy.agent`
- `org.omarchy.agent` matches no float rule (grepped the full default tree)

### Proposed fix
Have the installer hand off to `org.omarchy.agent` once setup completes, so first run
matches every subsequent run.

### Note
Discovered from a real reaction — "why is your window floating on top of the tiles?"
Nothing was broken; the inconsistency alone produced the confusion.

---

## TD-003 — Caps Lock silently repurposed as Compose

**Status:** DUP (heavily) · **Severity:** Medium · **Affects:** all installs; worse on non-US layouts

### Current
Default `kb_options = "compose:caps,shift:both_capslock_cancel"`. The Caps Lock key
becomes Compose; caps-locking moves to *both Shifts together*. Pressing Caps Lock
appears to do nothing — no indicator, no feedback, no discoverable explanation.
A newcomer reasonably concludes the key or the keyboard is broken.

### Expected
Not necessarily a different default — the tradeoff is defensible — but it must be
**discoverable**. A first-run note, an entry in the keybindings menu, or an OSD on
first Caps Lock press.

### Cost/benefit is layout-dependent
On `es` the Compose key is nearly redundant for its headline use: `´` dead key covers
á é í ó ú, `ñ` has a dedicated key, `¨` gives ü. So a Spanish-layout user pays the
full cost (a dead-looking key) for little of the benefit. Compose still earns its
place for symbols (— ≠ ≤ → € ½ ©), but that is not what the default advertises.

### Evidence
`/usr/share/omarchy/default/hypr/input.lua:37`, comment at lines 34-36.

### Local resolution
Overrode to `compose:rwin` in `~/.config/hypr/input.lua` — Caps Lock restored,
Compose moved to right `⌘`. Right Alt deliberately avoided: it is AltGr on `es` and
types `@ # € [ ] { } \ |`.

---

## TD-004 — GitHub absent from default web apps

**Status:** CHECKED, unreported · **Severity:** Low · **Affects:** anyone trying to file a bug

### Current
Default web apps: Basecamp, Discord, HEY, WhatsApp, X, YouTube, Zoom, Google
Contacts/Maps/Messages/Photos, Docker, Disk Usage. No GitHub.

Mild irony: GitHub is where Omarchy's own issue tracker lives, so the one destination
a user needs in order to report any of the items in this file is the one not shipped.
Curation is a legitimate choice; flagging for consideration, not as a defect.

### Workaround
`omarchy-webapp-install` (menu: Install → Web App).

---

## Duplicate-check results (2026-09-14)

Method: web search scoped to `github.com` + direct page reads. GitHub's search API
still needs auth; these results are good enough to triage but not exhaustive.

### TD-001 — CONFIRMED novel *as framed*
Prior art exists but addresses a **different problem**. Everything found is about
*remapping* keys to Mac muscle memory; nothing addresses *labelling* the keys
correctly in the `SUPER + K` UI:

- [Discussion #3296](https://github.com/omacom/omarchy/discussions/3296) — give a PC a Cmd key
- [Discussion #175](https://github.com/omacom/omarchy/discussions/175) — macOS→Linux keyboard config guide
- [Discussion #611](https://github.com/omacom/omarchy/discussions/611) — MacBook screenshot/media keys
- [Issue #1257](https://github.com/omacom/omarchy/issues/1257) — desire to use Mac keybindings
- [Issue #1115](https://github.com/omacom/omarchy/issues/1115) — use `$mainMod` instead of `SUPER`

**Adjacent doc gap.** The official manual page
[`manual/03-coming-from-mac-or-windows.md`](https://github.com/omacom/omarchy/blob/quattro/manual/03-coming-from-mac-or-windows.md)
covers Command only:

> "Omarchy doesn't remap anything, and Linux treats the Command key as Super, so Super
> sits right where Cmd always was."

Option→ALT and Control→CTRL are **not** documented. The same page then tells the user
`Super + K` is "the only hotkey you actually have to memorize" — pointing them at the
exact UI that shows the unexplained names. That circularity strengthens the report.

**Angle:** two deliverables, a one-function UI fix and a two-line manual addition.
Neither has been proposed.

### TD-002 — CONFIRMED novel, with precedent worth citing
The specific defect (installer window keeping `org.omarchy.terminal`) is unreported,
but the **root cause family is already accepted by maintainers** — the `org.omarchy.*`
app-id taxonomy leaks:

- [Issue #9008](https://github.com/omacom/omarchy/issues/9008) — **open**, PR #9049 — `org.omarchy.agent`
  misses the terminal `scroll_touchpad` rule because it doesn't match `(Alacritty|kitty|foot)`.
  Reporter's conclusion is directly transferable: *"A correct fix probably has to pick the
  value in `omarchy-agent` ... where the terminal is known, rather than in a class-based
  window rule."*
- [Issue #6379](https://github.com/omacom/omarchy/issues/6379) — `SUPER + C` closes floating TUI
  windows instead of copying; `org.omarchy.*` app-ids miss terminal detection.

TD-002 is the **inverse** case: a window *inherits* a rule it should shed, where those
two *miss* rules they should have. Same taxonomy, opposite direction.

**Angle:** cite #9008 and #6379 as established precedent. Much easier than arguing the
category from scratch.

### TD-003 — DUP. Do not file.
Reported repeatedly across both repo names:

- [#2241](https://github.com/basecamp/omarchy/issues/2241) — Caps Lock prints "·"
- [#2545](https://github.com/omacom/omarchy/issues/2545) — Caps Lock not working on 3.1
- [#3238](https://github.com/basecamp/omarchy/issues/3238) — Caps Lock isn't working
- [#5200](https://github.com/omacom/omarchy/issues/5200) — unable to use Caps Lock
- [#10545](https://github.com/omacom/omarchy/issues/10545) — default `kb_options` breaks Shift in XWayland apps

**But the duplicate count is itself the finding.** Five+ independent reports of the same
non-bug means the default is working as designed and failing as communicated. Nobody has
filed the *discoverability* problem — only the symptom, over and over. A discussion that
reframes it ("this keeps getting reported; the defect is the silence, not the mapping")
is defensible and is *not* a duplicate. Lead with the duplicate list as evidence.

### TD-004 — UNCHECKED
Low priority. Check before spending time on it.

---

## Notes for filing

- Venue: **Discussions**, not Issues, for TD-001 and TD-003 — they are UX arguments, not
  defects, and Issues invites "works as designed" closure.
- TD-002 is a genuine defect → Issue, citing #9008 and #6379.
- Resolve TD-001's rendering question *before* filing. "The names are wrong" invites
  bikeshedding; "here is the rendering, here is the one-function change" invites a merge.
- Verify each against `stable` before filing — this machine runs `omarchy-dev` on `edge`.

---

## TD-005 — Touchpad scrolling inverted vs macOS on Apple hardware

**Status:** NEW, unchecked · resolved locally 2026-09-14 · **Severity:** Medium (first-minute friction) · **Affects:** every Mac install

### Current
`natural_scroll = false` — traditional/PC scroll direction. Two fingers down moves the
content down. macOS ships the opposite (`natural`) and has since 2011, so every switcher
arrives with the inverse reflex trained.

Verified at runtime:

```
$ hyprctl getoption input:touchpad:natural_scroll
bool: false
```

### Expected
On a build whose entire purpose is Apple Silicon hardware, the touchpad should default to
the direction that hardware's native OS uses. A switcher should not have to discover the
setting to undo a deliberate mismatch.

### Notes on scope
The **Mac fork does not override this** — it inherits upstream's PC-oriented default
(`grep -rn natural_scroll /usr/share/omarchy/` finds only the upstream line). That makes
it a fork-level gap rather than an upstream bug: `false` is a defensible default for a
PC distro, and the fork is the layer that knows it is running on a Mac.

This overlaps TD-001: same root pattern, where Apple-hardware-specific defaults are not
applied even though `omarchy-hw-apple-silicon` detection already exists and is already
used in `apple.lua`. Worth considering whether TD-001 and TD-005 are one report —
"Apple hardware detection exists but isn't applied to user-facing defaults" — rather
than two.

### Evidence
- `/usr/share/omarchy/default/hypr/input.lua:65` — `natural_scroll = false`
- `~/.config/hypr/input.lua:30` — commented template shows `natural_scroll = true` as opt-in
- No fork-level override anywhere in `/usr/share/omarchy/`

### Local fix (APPLIED 2026-09-14 — `~/.config/hypr/input.lua`)
```lua
hl.config({ input = { touchpad = { natural_scroll = true } } })
```

### Caveat
Genuinely contested: some switchers deliberately retrain to PC direction to stay
consistent with external mice. Counter-argument is that macOS applies natural scrolling
to trackpad and mouse alike, so consistency does not require this default. Frame as
"match the hardware's native OS by default, keep it one line to change" rather than
"the current default is wrong".

### Duplicate check
- [ ] Not yet searched upstream or in the fork.

---

## TD-006 — No way to tell what a window is

**Status:** NEW, unchecked · partially resolved locally 2026-09-14 · **Severity:** High (day-one disorientation) · **Affects:** all installs; felt hardest by switchers

### Current
Tiled windows carry no title bars, and the default bar shows no window information at
all. A new user looking at a screen of windows has no on-screen way to answer "what is
this?" The only built-in answers are `hyprctl clients` (terminal) or focusing each window
in turn and inferring from content.

### What macOS provides, and Omarchy removes at once
| macOS | Omarchy default |
|---|---|
| App name always in the menu bar | nothing |
| Dock showing every running app | nothing |
| Mission Control — all windows, labelled | nothing |
| Window title bars | none (tiling) |

Three independent ways to identify a window collapse to zero. Experienced tiling users
don't miss them because they placed the windows deliberately and hold the layout in their
head. That assumption does not hold on day one.

### The important part: the fix already ships, disabled
`omarchy.active-window` is a **stock widget** — `shell/plugins/bar/widgets/ActiveWindow.qml`,
manifest id `omarchy.active-window`, described as "Title of the focused window", with
`defaultSection: "left"` and a `maxWidth` setting. It is simply absent from the default
bar layout.

So the ask is not "build a taskbar." It is "consider shipping the widget you already
wrote, on by default" — or surfacing it during onboarding. Far easier to argue.

### Residual gap after that fix
`active-window` labels only the **focused** window. Identifying *all* windows at a glance
still has no answer: no taskbar, no window-list widget (verified against every plugin
manifest under `shell/plugins/`). Workarounds: `ALT + TAB` to cycle, or `SUPER + G` groups,
which do render a tab bar with titles.

### Evidence
- `/usr/share/omarchy/shell/plugins/bar/widgets/ActiveWindow.manifest.json` — stock, `defaultSection: "left"`
- `/usr/share/omarchy/shell/plugins/bar/widgets/ActiveWindow.qml:13` — falls back to `appId` when no title
- `~/.config/omarchy/shell.json` — stock layout omits it
- `/usr/share/omarchy/default/hypr/bindings/tiling.lua:44-47` — `ALT + TAB` cycles windows

### Local resolution (APPLIED 2026-09-14)
```bash
omarchy bar put omarchy.active-window --section left   # undo: omarchy bar remove ...
```

### Layer
**Upstream (`omacom/omarchy`), not fork-level.** Nothing Apple-specific in the mechanism —
it is logged here because the Mac comparison is what makes the severity legible, not
because Marcelo owns it. Keep it out of any fork-scoped bundle.

### Duplicate check
- [ ] Not yet searched. Likely terms: taskbar, window list, active window widget, window title bar.

---

## TD-007 — Can't pin a file to the sidebar (folders only)

**Status:** NEW, unchecked · **Severity:** Low-Medium · **Affects:** switchers with a file-pinning habit
**Layer:** **Third-party (GNOME/Nautilus)** — neither Omarchy nor the fork can fix this in code.

### Current
Nautilus sidebar bookmarks accept **folders only**. macOS Finder lets you drag an individual
*file* into Favourites. There is no sidebar equivalent for files.

The nearest mechanism is **Starred** (right-click → Star → "Starred" in the sidebar), backed
by `localsearch`/`tinysparql`. Both are installed here, so it works — but on a minimal Arch
install without them, starring fails silently, which would be a miserable dead end.

### The actual friction
One macOS habit splits into two different Linux mechanisms, neither discoverable:

| Want | macOS | Omarchy |
|---|---|---|
| Pin a folder | drag to Favourites | drag to sidebar, or `Ctrl + D` |
| Pin a file | drag to Favourites | right-click → **Star** (different place, different name) |

The sidebar offers no affordance hinting that files are handled elsewhere, and "Star" does
not read as "pin this where I can find it."

### Scope
GNOME's design choice — bookmarks are locations, not documents — is defensible and unlikely
to change. The only actionable surface is **documentation/onboarding**: one line saying
"folders bookmark, files star" costs nothing and removes the dead end. Omarchy chose
Nautilus, so Omarchy owns the explanation even though it doesn't own the code.

### Evidence
- `~/.config/gtk-3.0/bookmarks` — folder URIs only, no file entries possible
- `localsearch`, `tinysparql` present (Starred functional)
- Nautilus 50.3.1

### Local resolution (APPLIED 2026-09-14)
`~/Work` added to `~/.config/gtk-3.0/bookmarks`.

### Duplicate check
- [ ] Not applicable upstream. If raised at all, raise as onboarding docs.

---

## TD-008 — Closing the lid does not stop the battery draining

**Status:** NEW · **Severity:** High (blocks daily-driver use) · **Affects:** every Apple Silicon install
**Layer:** **Kernel (linux-asahi)** — not config, and not Omarchy.

### Current
Closing the lid *does* suspend. On 2026-09-19 00:51 logind logged `Lid closed` → `Suspending…`
and the kernel logged `PM: suspend entry (s2idle)`. Nothing follows: no `suspend exit`, no
resume. The next journal entry is a cold boot five days later, where `macsmc-reboot` reports
`PMU logged 1 boot error(s) and 1 panic(s)`. pstore was empty.

### Why config can't fix it
- **s2idle is the only mode Apple Silicon has.** `/sys/power/mem_sleep` is `[s2idle]`, there is
  no `/sys/power/disk`, and there's no swap. Hibernation isn't supported on Asahi, so
  suspend-then-hibernate is off the table.
- **Even working s2idle drains about 2%/h**, so a full battery is dead in 2–4 days
  ([asahi-installer#252](https://github.com/AsahiLinux/asahi-installer/issues/252),
  [linux#262](https://github.com/AsahiLinux/linux/issues/262), still open).
- **No RTC wake alarm.** `rtc0` has no `wakealarm`, so "sleep, then power off after N hours"
  can't be built either: nothing can wake the machine to do it.
- **logind is configured correctly.** `HandleLidSwitch=suspend`, and only delay inhibitors are held.

### Likely upstream bug
[AsahiLinux/linux#510](https://github.com/AsahiLinux/linux/issues/510) (open PR). A secondary
DCP with no display attached can fail the suspend path, keep raising mailbox IRQs that wake
the SoC out of s2idle, and crash on resume. This machine's `dcpext` (`289c00000.dcp`)
reports `connected:0` on every boot, which is exactly that setup.

### What Macifier did about its own share
`macifier-pods` ran a BLE scan in bursts, and a burst still open when the lid closed was left
running inside bluetoothd. Now it holds a logind delay inhibitor, stops the scan on
`PrepareForSleep`, and resumes after.

### Measured (2026-09-24, on battery, lid closed 1 h 30 min)
| | Time | Battery | `energy_now` |
|---|---|---|---|
| Sleep | 18:29:49 | 100% | 57.83 Wh |
| Wake | 19:59:42 | 98% | 55.29 Wh |

The Mac used 2.54 Wh in 1.50 h: **1.7 W, about 2.9% of the battery per hour**. At that rate a
full battery lasts about 1.4 days asleep. That's worse than the ~2%/h upstream measured on
M2 Air. Macs on macOS lose about 1% per *day*.

The resume was clean: `suspend exit`, no `pm_wakeup_irq` recorded, and pods stopped and
restarted its scan as designed. So a normal night's sleep works. A multi-day sleep empties the
battery even without a crash; the Sep 19 panic made it worse but isn't needed to explain it.

**Advice until upstream moves:** shut down rather than close the lid for anything longer than
about a day.

---

# Proposal: "Macifier" — an opt-in, reversible Mac-affinity mode

**Status:** CONCEPT, 2026-09-14

## Idea
One switch that applies the Mac-affinity defaults, and unapplies them cleanly. Not a fork,
not a theme — a toggle. The pitch is *"make the first hour familiar,"* not *"make Omarchy
into macOS."*

## Why this is more feasible than it sounds
**Omarchy already has the mechanism.** `omarchy hyprland toggle <flag> [on|off|toggle]` writes
Lua fragments into a state directory that is sourced wholesale and hot-reloaded:

```
~/.local/state/omarchy/toggles/hypr/
```

Shipped examples: `flags.lua`, `single-window-aspect-ratio.lua`, `window-no-gaps.lua`
(`/usr/share/omarchy/default/hypr/toggles/`, loaded by `default/hypr/toggles.lua`).

So "reversible and switchable" is not something to invent — it is the existing pattern for
persistent optional config. A macifier could plausibly be **one Lua fragment plus a menu entry**,
with `omarchy hyprland toggle macifier off` restoring stock behaviour exactly. That framing
matters when pitching: it is not new architecture, it is a new file in an existing folder.

## Candidate contents (all already evidenced in this document)
| Item | Change | Source |
|---|---|---|
| TD-005 | `natural_scroll = true` | verified, applied locally |
| TD-001 | Modifier labels show Command/Option/Control | `modmask_to_text()` |
| TD-006 | `omarchy.active-window` on by default | stock widget, ships disabled |
| TD-007 | Onboarding line: folders bookmark, files star | docs only |

Possible additions, not yet investigated: MacBook screenshot/media key mapping
(cf. upstream Discussion #611), Mission-Control-style overview.

## What should stay OUT, at least at first
- **Cmd-based copy/paste** (`SUPER + C/V`). Deep rabbit hole: terminals, Chromium and TUI apps
  all handle these differently, and upstream already has scar tissue here
  ([#7027](https://github.com/omacom/omarchy/issues/7027) clipboard shortcut flakiness,
  [#6816](https://github.com/omacom/omarchy/issues/6816)). A macifier that breaks copy/paste
  would discredit the whole idea on contact.
- **Anything contested among switchers** — e.g. some deliberately retrain to PC scroll
  direction for mouse consistency. Contested items belong behind their own sub-toggle or
  outside the bundle entirely.

## Honest risks
1. **Scope creep objection.** Maintainers may read "a mode" as an unbounded support burden —
   every future default now needs a macifier branch. Counter: keep it a single fragment that
   only *sets* documented options, adds no new code paths, and is off by default.
2. **Fork vs upstream.** Most contents are fork-level (Apple hardware). The fork is the
   natural home; upstream would need it gated on `omarchy-hw-apple-silicon` anyway.
3. **Reversibility must be real.** If it writes into `~/.config/hypr/*.lua` it is not cleanly
   reversible. Using the toggles directory is what makes the "switchable" claim true — do not
   compromise on this.
4. **Naming.** "Macifier" is good internally; something like "Mac affinity mode" may land
   better in a pitch, since it signals familiarity rather than imitation.

## Next steps
- [ ] Confirm the toggle mechanism supports non-Hyprland settings too (bar widgets, shell.json)
      — currently verified for Hyprland Lua only; TD-006 needs a bar change, which may live elsewhere
- [ ] Prototype locally as a toggle fragment before proposing anything
- [ ] Raise with Marcelo as a fork feature first — smaller audience, faster feedback, his layer

---

## Authenticated re-check (2026-09-14, `gh` as omeganter)

Full `gh search issues` + GraphQL Discussions search. Supersedes the web-search triage above.

### TD-001 — CONFIRMED NOVEL (holds)
Queries `modifier names`, `Option key label`, `keybindings menu Mac`, `Super K Command`,
`modmask_to_text` → **zero results**. Broad `modifier` returns only unrelated input bugs;
`Command key` returns only *remapping* requests ([#7838](https://github.com/omacom/omarchy/issues/7838)
macOS-friendly Tab keybindings, [#1115](https://github.com/omacom/omarchy/issues/1115),
[#1257](https://github.com/omacom/omarchy/issues/1257) — both closed).
Discussions search: nothing on UI labelling.
**Nobody has raised how modifiers are *displayed*. File it.**

### TD-002 — DOWNGRADED. Mechanism already filed.
[**#7174**](https://github.com/omacom/omarchy/issues/7174) — *"First-agent OAuth browser opens
tiled under the 875×600 setup terminal"* — **open**, documents the identical mechanism:

> "On first-run, choosing a default agent opens a floating `org.omarchy.terminal` installer
> (title "Omarchy"). **After install it `exec`s the agent in that same window.**"
>
> "Shipped rules in `default/hypr/apps/system.lua` tag `org.omarchy.terminal` as
> `floating-window`: float, center, **875×600**."

That is TD-002's root cause, already written up — by a reporter on a ThinkPad, so it is not
Mac-specific. Their *symptom* differs (OAuth browser trapped beneath the float, unreachable);
mine is that the agent session simply keeps a window class meant for transient installers.

Related, same family:
- [#8961](https://github.com/omacom/omarchy/issues/8961) — open — `omarchy-launch-floating-terminal-with-presentation` drops `BROWSER`; first-agent OAuth aborts
- [#8122](https://github.com/omacom/omarchy/issues/8122) — open — `omarchy-install-and-launch` keystroke race
- [#10128](https://github.com/omacom/omarchy/issues/10128) — open — presentation terminal disappears after update
- [#6379](https://github.com/omacom/omarchy/issues/6379) — closed — `org.omarchy.*` app-ids miss terminal detection
- [#9008](https://github.com/omacom/omarchy/issues/9008) — open, PR #9049 — `org.omarchy.agent` misses `scroll_touchpad`

**Action: do NOT file a new issue.** Add the second symptom as a comment on #7174. Five open
issues share this root cause — the stronger contribution is arguing that the *handoff* is the
defect, not each downstream symptom.

### TD-003 — DUP confirmed, more instances found
Additional to the web-search list:
- [#7255](https://github.com/omacom/omarchy/issues/7255) — open — Quattro migration doesn't update `kb_options`, **trapping Caps Lock ON**
- [#9560](https://github.com/omacom/omarchy/issues/9560) — open — "My Capslock is not working on my omarchy"
- [#7440](https://github.com/omacom/omarchy/issues/7440) — open — `shift:both_capslock_cancel` breaks **fcitx5** Shift toggle for Chinese/English

Reframing as a *discoverability* defect remains unclaimed.

### TD-004 — no prior report, but low value
`webapp github` → only [#2568](https://github.com/omacom/omarchy/issues/2568) (unrelated, closed).
Unreported, but it is a curation opinion, not a defect. Lowest priority.

### Revised priority
1. **TD-003 reframed** — strongest. Five+ duplicates are the evidence.
2. **TD-001** — cleanly novel, small fix, detection helper already exists.
3. **TD-002** — comment on #7174; do not open a new issue.
4. **TD-004** — optional.

### Caveat
`gh search issues` does **not** cover Discussions; those need the GraphQL `type: DISCUSSION`
search, run separately above. Anyone repeating this check must do both.
