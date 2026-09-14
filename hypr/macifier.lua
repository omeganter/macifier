-- Macifier — Mac-affinity overrides for Omarchy.
--
-- Loaded from ~/.local/state/omarchy/toggles/hypr/ which `default.hypr.toggles`
-- sources LAST (after the user's own hypr/*.lua), so these win. Deleting this
-- file reverts everything in it — that is the whole point.
--
-- Managed by `omarchy-macifier`. Do not hand-edit the copy in the state dir.

hl.config({
  input = {
    touchpad = {
      -- macOS default since 2011. Omarchy ships PC-style (false).
      natural_scroll = true,
    },
  },
})
