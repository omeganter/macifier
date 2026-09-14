-- Macifier option: appswitcher
--
-- Cmd+Tab switches applications, not workspaces.
--
-- Omarchy's default sends SUPER+TAB to the next workspace, which is the single
-- most jarring thing for a Mac user: the key their fingers reach for to change
-- app instead teleports them somewhere else. Upstream has the same proposal
-- open at omacom/omarchy#7838, unresolved.
--
-- Workspace cycling is not removed, only moved one modifier along.

hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")

-- Where workspace cycling goes. CTRL+ALT+TAB is taken (next monitor), so the
-- free neighbour is SUPER+ALT.
o.bind("SUPER + ALT + TAB", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
o.bind("SUPER + ALT + SHIFT + TAB", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))

-- The switcher itself. IPC rather than a dispatcher because the overlay owns
-- the selection and, crucially, reads the Cmd release that commits it —
-- Hyprland's own modifier-release bind is swallowed once Tab consumes the
-- chord during the hold.
o.bind("SUPER + TAB", "App switcher", "omarchy-shell local.macifier-switcher next")
o.bind("SUPER + SHIFT + TAB", "App switcher (back)", "omarchy-shell local.macifier-switcher prev")
