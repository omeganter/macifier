# Macifier

Makes Omarchy feel like a Mac. One switch, fully reversible.

**Beta** — `0.1.x`, no tagged release. Reversibility is the part that is
tested; the set of options is still moving and names can change between
commits. Pin a commit if you build on one.

Unofficial. Not affiliated with Omarchy. Opinions and pull requests welcome,
including "that default is wrong".

> **Tested on one machine.** A MacBook Pro 14-inch (M1 Pro, 2021): `aarch64`,
> Apple Silicon, one display at scale 2, Spanish layout, Apple's own keyboard.
> None of it has run on x86_64, on a non-Apple keyboard, or on two monitors.
> `mediakeys` in particular sets an Apple-only kernel parameter and simply
> refuses elsewhere. If you try it on other hardware, the bug report is the
> contribution.

```bash
./install.sh
omarchy plugin enable local.macifier right
omarchy restart shell
```

Then click ` Macifier` in the bar and pick what you want.

---

## Options

| Option | Does | Minimal | Full |
|---|---|:---:|:---:|
| `scroll` | Trackpad scrolls the macOS way | ● | ● |
| `capslock` | Caps Lock works. Compose moves to right ⌘ | ● | ● |
| `mediakeys` | F1–F12 do brightness and volume. Asks for your password | ● | ● |
| `cmdkeys` | ⌘A ⌘Z ⌘F ⌘S and the rest | | ● |
| `windowtitle` | Focused window's name in the bar | | ● |
| `appswitcher` | ⌘Tab switches apps, not workspaces, with an icon bar | | ● |
| `dock` | Auto-hiding dock of favourite apps along the bottom | | ● |
| `launchpad` | Every installed app in a full-screen grid | | ● |

Options are independent. Presets just set a group, so you can flip any one
afterwards and the rest stay put.

**Minimal** is a ramp. It fixes what you trip over in the first minute and takes
nothing away. Most people use it for a week, keep what they liked, drop the rest.

**Full** is for people who want a Mac in Linux and are not going to retrain their
hands. That is a real want, not a lesser one.

## Keybindings

⌘C ⌘V ⌘X ⌘W already work. Omarchy ships those, terminals included. `cmdkeys`
adds the rest.

Press **Edit** in the panel to switch keys one at a time. Two presets:

- **Minimal** — only keys Omarchy leaves free. Nothing is taken away.
- **Full Mac** — also takes ⌘F ⌘S ⌘T ⌘O ⌘P ⌘G ⌘L ⌘K. The window shortcuts on
  those letters move to ⌃⌥ + the same letter, so ⌃⌥F is full screen.

Every row says what it would displace before you turn it on.

In terminals these do nothing. Ctrl+Z suspends a job, Ctrl+D closes the shell.
Sending those would be worse than doing nothing.

## Reverting

Nothing is written to `/usr/share/omarchy` or `~/.config/hypr`. Each option is
one file in `~/.local/state/omarchy/toggles/hypr/`, which Omarchy loads last.
Deleting the file undoes it.

`mediakeys` is the exception. It sets a kernel parameter, so it installs
`/etc/tmpfiles.d/macifier-fnmode.conf`. Turning it off deletes that file and
puts the old value back.

Test for anything new: `on`, `off`, every touched file byte-identical.

## CLI

```bash
omarchy-macifier status
omarchy-macifier preset minimal|full|off
omarchy-macifier option scroll on|off
omarchy-macifier key F off
omarchy-macifier key preset minimal|full|none
omarchy-macifier dock placeholders on|off
omarchy-macifier panel open|keys|dock
```

## ⌘Tab

Hold ⌘, tap Tab to walk the icon bar, release ⌘ to switch. Grouped by app and
ordered most-recently-used, like a Mac. Escape cancels.

Workspace cycling moves to ⌘⌥Tab. Nothing is removed.

The release is read by the overlay, not by a Hyprland bind: Hyprland's
modifier-release bind is swallowed once another bind fires during the hold, and
Tab always does. The overlay takes exclusive keyboard focus and sees the event.

## Dock

Auto-hides at the bottom. Push the pointer to the bottom edge and it slides up.
Pinned apps first, then anything running, with a dot under what is open. Click
to launch, or to raise it if it is already running.

Icons magnify under the pointer as a wave, the way the Mac dock does — the one
under the cursor grows most, its neighbours less, and the row spreads to make
room rather than letting them collide.

That wave is not ours. It is [macOS Magnify
Dock](https://github.com/wisangdg/omarchy-magnify-dock) by Wisang Drillian Geni
(wdg), MIT licensed, and we use two functions from it unchanged; the rest of
his dock we left alone, because ours already had tiles, a menu, barred
placeholders and a trash. Full notice in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). If you want the whole thing
rather than our take on it, install his — it is on the marketplace as
`wdg.dock` and it is very good.

Both the dock and ⌘Tab also turn off Hyprland's pointer warping
(`cursor:no_warps`), which otherwise flings the cursor to the centre of
whatever window you focus. macOS never moves the pointer on its own.

Press **Edit** beside Dock in the panel to choose what is pinned, or:

```bash
omarchy-macifier dock list
omarchy-macifier dock chromium add|remove
omarchy-macifier dock reset
```

### Two-finger click

Right-click — two fingers on a trackpad — opens a menu, as on macOS.

On an **app**: its open windows by name, click one to focus it. Keep in Dock.
Quit, which closes every window it has. On the **dock itself**: hiding,
magnification, position, and Dock Settings…

Options we have not built are listed anyway, greyed, each saying why and which
phase it is in. A menu that silently omits what it cannot do leaves you
wondering whether you looked in the wrong place.

### The barred tiles

After a separator sit the Mac dock staples Macifier does not have yet —
Mission Control, System Settings, Stage Manager — drawn grey
with a bar struck through. They are reminders, not buttons; clicking one says
what it will be and which phase it belongs to.

```bash
omarchy-macifier dock placeholders off     # hide them
omarchy-macifier dock placeholders on
```

They come from `~/.local/share/macifier/dock-placeholders.json`, re-read on
every poll, so editing that file needs no shell restart. Delete a row the moment
the real thing ships.

### Trash

Last in the dock, behind its own rule, where a Mac keeps it. The icon shows full
or empty. Click opens it; two-finger click gives **Open** and **Empty Trash…**,
the same two items the Mac dock offers, and emptying asks first because it
cannot be undone. Dragging files onto it deletes them.

This is **the trash Linux already has**, not one of ours. Omarchy has no trash of
its own — nothing in `/usr/share/omarchy` mentions one — so the tile is a view
onto the freedesktop.org trash your file manager already uses: the file moves to
`~/.local/share/Trash/files` with a `.trashinfo` record beside it holding the
original path, and every other mount gets its own `.Trash-$UID`. Nothing about
how Omarchy or Nautilus behaves is changed.

Because trashing is a *rename*, it cannot cross filesystems — that is why other
mounts keep their own. Counting goes through `gio`, so items trashed on a USB
stick are counted too. `rm` still bypasses all of this; it always did.

```bash
omarchy-macifier dock trash          # {"shown":true,"available":true,"count":0}
omarchy-macifier dock trash open
omarchy-macifier dock trash empty
omarchy-macifier dock trash off      # hide the tile
```

Needs `gio` (ships with glib2). Without it the tile simply does not appear.

## Launchpad

Every installed application, in a grid, full screen. `SUPER+ALT+A`, or the
Launchpad tile at the front of the dock — where a Mac keeps it, second only to
Finder, which we do not have. The tile appears only while `launchpad` is on, so
the dock never offers a button for a plugin that is disabled.

Type to filter. Arrow keys walk the grid and carry on across pages, so the
selection never gets stuck at an edge. Enter launches, click launches, Escape
clears what you typed and a second Escape closes.

The Mac key for this is F4, and we cannot use it: `mediakeys` makes the top row
send its media function first, which is the entire point of that option, so
literal F4 would mean pressing Fn+F4. `SUPER+A` is left alone too — `cmdkeys`
gives that to Select All, and a Mac user's hands want ⌘A to select.

This is the one Mac staple with nothing to adopt. Omarchy has fifteen docks and
a dozen Mission Controls; Launchpad had no published plugin at all, so it is
built rather than recommended. It deliberately does not fuzzy-match or rank:
Omarchy's menu and Spotlight are both search-first already, and Launchpad's
point is that you look instead of typing.

Applications marked `NoDisplay` are left out. They are the entries a desktop is
explicitly asked not to show — MIME handlers and per-app helpers — and including
them is what makes most Linux app menus unusable.

## Next

[docs/SETTINGS.md](docs/SETTINGS.md) plans a System Settings window: every Mac
option, tagged by who provides it. The barred dock tiles are its phases made
visible.

[docs/PLAN.md](docs/PLAN.md) has the original design notes.

[docs/FRICTION-LOG.md](docs/FRICTION-LOG.md) lists the Omarchy newcomer
problems this came out of.

## Licence

MIT — see [LICENSE](LICENSE). The same licence Omarchy itself uses, and what
nearly every plugin in the marketplace uses, so code can move between them
without a licence conversation first.
