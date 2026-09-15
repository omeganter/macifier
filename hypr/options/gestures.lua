-- Macifier option: gestures
--
-- The macOS trackpad set. Which shapes Hyprland actually delivers was measured
-- on this machine rather than assumed — a probe bound every candidate to a
-- file touch, and these are the ones that fired:
--
--   3 fingers  left, right, up, down     yes
--   4 fingers  left, right, up, down     yes
--   4 fingers  pinch in, pinch out       yes
--   2 fingers  anything                  NO
--
-- Two fingers can never be a gesture here. libinput classifies two fingers as
-- a scroll axis and only three or more as a swipe, so nothing in Hyprland ever
-- sees it. Its own log is explicit during a two-finger drag:
--
--   [2fg] GESTURE_EVENT_SCROLL_START -> GESTURE_STATE_SCROLL
--
-- That is why Omarchy's own commented examples only ever say `fingers = 3`,
-- and why Launchpad reads page swipes as a wheel instead (plugin-launchpad).
--
-- Nothing here is taken away from anyone: Omarchy ships these lines commented
-- out in config/hypr/input.lua, so this turns on what was already offered.

-- Spaces. Three fingers sideways, the single most-used gesture on a Mac.
-- `horizontal` rather than separate left and right bindings because it gives
-- the continuous, animated follow-your-fingers swipe rather than a discrete
-- jump — that continuity is most of what makes it feel like a Mac.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Mission Control (three up) and App Exposé (three down).
--
-- Both are third-party plugins Macifier recommends rather than ships, so these
-- are best-effort: `omarchy-shell -q` returns success even when the target is
-- not there, so the gesture does nothing at all rather than erroring at someone
-- who never installed them. See docs/SETTINGS.md for what we adopted and why.
hl.gesture({ fingers = 3, direction = "up", action = function()
  hl.exec_cmd("omarchy-shell -q shell toggle io.github.andyweiboan.missioncontrol '{}'")
end })

hl.gesture({ fingers = 3, direction = "down", action = function()
  hl.exec_cmd("omarchy-shell -q shell toggle expose.window-overview '{}'")
end })

-- Launchpad. On a Mac this is a four-finger pinch in, and it turns out we can
-- have exactly that — pinch was the shape most likely to be missing and it is
-- not. So Launchpad gets its real gesture rather than an approximation.
--
-- Pinch out is Show Desktop on a Mac. Hyprland has no equivalent worth faking,
-- so that shape is deliberately left free.
hl.gesture({ fingers = 4, direction = "pinchin", action = function()
  hl.exec_cmd("omarchy-shell -q local.macifier-launchpad toggle")
end })
