-- Macifier option: cmdkeys
--
-- Extends Omarchy's Command-key layer to the rest of the Mac editing set.
--
-- Omarchy already ships the hard ones: SUPER+C/V/X are Universal copy/paste/cut
-- and are terminal-aware (default/hypr/bindings/clipboard.lua), and SUPER+W is
-- Close window, matching Cmd+W. What is missing is everything else a Mac user's
-- hands expect — Cmd+A, Cmd+Z, Cmd+N and friends do nothing today.
--
-- This binds only letters Omarchy leaves free, so nothing is taken away.
-- The seven that collide with window-management bindings (F S T P L G K) are
-- deliberately NOT touched here; reclaiming those means moving WM shortcuts,
-- which belongs in its own option that a user can refuse.

-- Same send technique as Omarchy's clipboard bindings: explicit mods to the
-- focused surface, with a down/up split. A virtual keyboard will not do — the
-- physically held SUPER merges into the injected chord at the seat — and the
-- split works around Hyprland leaving synthetic key state stuck.
-- https://github.com/hyprwm/Hyprland/discussions/14099
local function send_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

-- Reuse the terminal tag from default/hypr/apps/terminals.lua so there is one
-- definition of what counts as a terminal. Dynamic tags carry a trailing "*".
local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then return false end
  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then return true end
  end
  return false
end

-- In a terminal these control codes mean something else entirely and sending
-- them would be destructive: Ctrl+Z suspends the foreground job, Ctrl+D closes
-- the shell, Ctrl+A is beginning-of-line. macOS has the same split — Cmd+A is
-- the terminal's select-all, Ctrl+A is readline — but we cannot deliver the
-- Cmd half, so do nothing rather than the wrong thing. The terminal keeps its
-- own Ctrl semantics untouched.
local function forward(key)
  return function()
    if active_window_is_terminal() then return end
    send_once("CTRL", key)()
  end
end

-- Letters Omarchy leaves unbound, so claiming them costs nothing.
local pass_through = {
  A = "Select all",
  B = "Bold",
  D = "Duplicate / bookmark",
  E = "Search / edit",
  I = "Italic",
  N = "New",
  R = "Reload",
  U = "Underline",
  Y = "Redo (Windows-style apps)",
  Z = "Undo",
}

for key, label in pairs(pass_through) do
  o.bind("SUPER + " .. key, "Command+" .. key .. " (" .. label .. ")", forward(key))
end

-- Redo. Most Linux apps take Ctrl+Shift+Z, same chord shape as the Mac.
o.bind("SUPER + SHIFT + Z", "Command+Shift+Z (redo)", function()
  if active_window_is_terminal() then return end
  send_once("CTRL SHIFT", "Z")()
end)

-- Cmd+Q. On a Mac this quits the application; Hyprland has no concept of an
-- application, so the closest honest equivalent is closing the window — which
-- is what SUPER+W already does. Bound because Cmd+Q is deep muscle memory and
-- leaving it dead is its own kind of surprise.
o.bind("SUPER + Q", "Command+Q (close window)", hl.dsp.window.close())
