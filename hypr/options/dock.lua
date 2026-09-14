-- Macifier option: dock
--
-- Hyprland warps the pointer to the centre of a window when focus moves to it
-- (cursor:no_warps defaults to false). Clicking a dock icon therefore yanks the
-- pointer off the dock and into the middle of the screen.
--
-- macOS never moves the pointer on its own, so turning warping off is both the
-- fix and the more Mac-like behaviour. It applies to every focus change, not
-- just the dock's — which is the point.
hl.config({ cursor = { no_warps = true } })
