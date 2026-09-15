-- Macifier trial bindings — NOT a Macifier option.
--
-- Binds the third-party plugins we are evaluating so they can be tried on a
-- real desktop instead of judged from screenshots. Nothing here is a decision.
-- See docs/SETTINGS.md for what each candidate is and why it is on the list.
--
--   install:  install -Dm644 hypr/trial/macifier-trial.lua \
--               ~/.local/state/omarchy/toggles/hypr/macifier-trial.lua
--             hyprctl reload
--   remove:   rm ~/.local/state/omarchy/toggles/hypr/macifier-trial.lua
--             hyprctl reload
--
-- The `hyprctl reload` is not optional and is worth recording: that directory
-- is sourced last and is watched, but dropping a *new* file into it does not
-- register its bindings on its own — measured here, the five below appeared
-- only after the reload. Editing a file already loaded is the case that
-- hot-reloads. No shell restart is needed either way.
--
-- Deleting the file undoes every line below, which is the only reason it is
-- safe to bind this much at once. install.sh does not touch this file:
-- options live in hypr/options, and this is not one.
--
-- Nothing is unbound. Every chord below was free on this machine, checked with
-- `hyprctl binds`. The single place where matching the Mac *requires* taking a
-- key Omarchy already owns is Spotlight, and that is left commented out at the
-- bottom to be opted into deliberately rather than arrived at by surprise.

-- ----------------------------------------------------------------- overview
--
-- macOS puts Mission Control on Control+Up and App Exposé on Control+Down.
-- Plain Control has no bindings at all on stock Omarchy — `hyprctl binds`
-- reports no entry with modmask 4 — so both real chords are free.
--
-- The cost, stated plainly: a Hyprland bind is global, so CTRL+UP and
-- CTRL+DOWN stop reaching terminal applications that want them (tmux pane
-- resize, some editors and pagers). macOS has exactly this problem and answers
-- it the same way. If it bites, move these two lines rather than the plugins.

-- Both Mission Control candidates, bound side by side so they can be compared
-- on the same desktop with the same windows open. The faithful one gets the
-- real chord; the alternative goes one modifier along — the same thing
-- appswitcher.lua does to workspace cycling instead of removing it.
o.bind("CTRL + UP", "Mission Control (AndyWeiBoan)",
  "omarchy-shell shell toggle io.github.andyweiboan.missioncontrol '{}'")
o.bind("CTRL + SHIFT + UP", "Mission Control (zzwong Stage)",
  "omarchy-shell shell toggle zzwong.stage")

-- A dedicated exit for the faithful one. Its README recommends this: CTRL+UP
-- toggles, so without a separate close a second press to "get out" is
-- indistinguishable from an accidental re-open.
o.bind("CTRL + ALT + DOWN", "Close Mission Control",
  "omarchy-shell shell hide io.github.andyweiboan.missioncontrol")

-- Exposé. It also opens from the top-left hot corner, which the plugin turns
-- on by default, so this is the second way in rather than the only one — worth
-- knowing before judging whether we still want a separate hot-corners plugin.
o.bind("CTRL + DOWN", "Exposé",
  "omarchy-shell shell toggle expose.window-overview '{}'")

-- ---------------------------------------------------------------- Spotlight
--
-- On a Mac this is Command+Space. On Omarchy that chord opens the Omarchy
-- menu, the most-used binding on the system, so the trial does not take it.
-- ALT+SPACE is free here and is the plugin author's own recommended default,
-- which means Spotlight can be judged on its merits before we argue about
-- whether it is worth displacing anything.
o.bind("ALT + SPACE", "Spotlight",
  "omarchy-shell shell toggle io.github.maajix.spotlight '{}'")

-- The real thing, when you want to feel it. Uncomment the three lines.
--
-- Command+Space becomes Spotlight and the Omarchy menu moves one modifier
-- along, to SUPER+ALT+SHIFT+SPACE. Be honest about this one rather than
-- talking yourself into it: that is a four-key chord for the binding you reach
-- for most, and it is the argument against the swap, not a footnote to it.
-- SUPER+ALT+SPACE would be the natural home, but Omarchy already uses it for
-- the Apps menu, and displacing that too is how a trial turns into a mess.
--
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Spotlight",
--   "omarchy-shell shell toggle io.github.maajix.spotlight '{}'")
-- o.bind("SUPER + ALT + SHIFT + SPACE", "Omarchy menu", "omarchy-menu toggle")

-- --------------------------------------------------------------- no binding
--
-- Quick Look needs none. Nautilus D-Bus-activates
-- org.gnome.NautilusPreviewer when Space is pressed on a selection, and the
-- plugin owns that name. Select a file in Files and press Space. That is the
-- supported hook, and it is the reason to prefer this implementation over the
-- fuzzy-finder one — it puts the feature where the Mac puts it.
--
-- Cupertino needs none. It is a `service` plugin with no surface of its own:
-- it restyles the shell and pushes rounding, shadow and border values into
-- Hyprland at runtime via `hyprctl eval`. It writes nothing to disk. Because
-- it is a service it needs `omarchy restart shell` to start *and* to stop.
--
-- The menubar manager is deliberately not enabled and not bound. Its manifest
-- declares kinds:["bar"] — it replaces the whole Omarchy bar rather than
-- adding a widget beside the others. That is a different and much larger
-- question than the rest of this list, and it deserves its own trial instead
-- of being folded into a seven-plugin one.
