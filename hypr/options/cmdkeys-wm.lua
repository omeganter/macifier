-- Macifier option: cmdkeys-wm
--
-- Hands the last eight Command-key letters to applications, by moving the
-- window-management shortcuts that currently hold them.
--
-- This is the option that *takes something away*, which is why it is separate
-- from `cmdkeys` and off unless you ask for it. If you use SUPER+F for full
-- screen a hundred times a day, you will notice. Requires `cmdkeys`, whose
-- forwarding helpers this builds on conceptually — enable both.
--
--   SUPER + <letter>      now forwards CTRL + <letter> to the app (Mac behaviour)
--   CTRL + ALT + <letter> now does what SUPER + <letter> used to
--
-- CTRL+ALT was chosen because the whole namespace is empty — no Omarchy binding
-- uses CTRL+ALT with a letter — so nothing collides and every displaced
-- shortcut keeps its own letter. SUPER+ALT was rejected: F, G, K and S already
-- hold sibling functions there (Full width, Move out of group, Tmux
-- keybindings, Move to scratchpad), so four of the eight would have had to be
-- renamed, which is worse than moving all eight consistently.
--
-- SUPER+J (Toggle window split) is deliberately left alone: Cmd+J is rare
-- enough that displacing a working shortcut is not worth it.

local function send_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then return false end
  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then return true end
  end
  return false
end

-- Same reasoning as cmdkeys: in a terminal these control codes mean something
-- else and sending them would be wrong, so do nothing instead.
local function forward(key)
  return function()
    if active_window_is_terminal() then return end
    send_once("CTRL", key)()
  end
end

-- letter, what the Mac expects, the Omarchy action being displaced
local reclaim = {
  { "F", "Find",        "Full screen",                  hl.dsp.window.fullscreen({ mode = "fullscreen" }) },
  { "S", "Save",        "Toggle scratchpad",            hl.dsp.workspace.toggle_special("scratchpad") },
  { "T", "New tab",     "Toggle window floating/tiling", hl.dsp.window.float({ action = "toggle" }) },
  { "P", "Print",       "Pseudo window",                hl.dsp.window.pseudo() },
  { "G", "Find next",   "Toggle window grouping",       hl.dsp.group.toggle() },
  { "L", "Location bar", "Toggle workspace layout",     "omarchy-hyprland-workspace-layout-toggle" },
  { "K", "Insert link", "Keybindings",                  "omarchy-menu-keybindings" },
  { "O", "Open",        "Pop window out (float & pin)", "omarchy-hyprland-window-pop" },
}

for _, entry in ipairs(reclaim) do
  local key, mac_label, omarchy_label, action = entry[1], entry[2], entry[3], entry[4]

  -- Release the letter before claiming it, or both bindings fire.
  hl.unbind("SUPER + " .. key)

  o.bind("CTRL + ALT + " .. key, omarchy_label, action)
  o.bind("SUPER + " .. key, "Command+" .. key .. " (" .. mac_label .. ")", forward(key))
end
