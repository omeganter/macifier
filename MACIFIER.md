# Macifier

Makes Omarchy feel like a Mac. One switch, fully reversible.

Unofficial. Not affiliated with Omarchy. Opinions and pull requests welcome,
including "that default is wrong".

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
```

## ⌘Tab

Hold ⌘, tap Tab to walk the icon bar, release ⌘ to switch. Grouped by app and
ordered most-recently-used, like a Mac. Escape cancels.

Workspace cycling moves to ⌘⌥Tab. Nothing is removed.

The release is read by the overlay, not by a Hyprland bind: Hyprland's
modifier-release bind is swallowed once another bind fires during the hold, and
Tab always does. The overlay takes exclusive keyboard focus and sees the event.

## Next

Nothing planned. [docs/PLAN.md](docs/PLAN.md) has the design notes.

[docs/FRICTION-LOG.md](docs/FRICTION-LOG.md) lists the Omarchy newcomer
problems this came out of.
