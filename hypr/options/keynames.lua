-- Macifier option: keynames
--
-- Omarchy's keybindings screen (⌘K) spells shortcuts the way Hyprland stores
-- them — "SUPER SHIFT + RETURN" — and a Mac user reads ⇧⌘↩. This points the
-- Keybindings key at macifier-keybindings, which shows the same list, runs the
-- same bindings, and only changes the wording.
--
-- Which key that is depends on `cmdkeys`. If it has taken ⌘K for Insert link,
-- Keybindings already lives on ⌃⌥K, and rebinding SUPER+K here would quietly
-- undo that choice. So read the key set the same way the CLI does, and follow
-- Keybindings to wherever it currently is. Toggle files load in sorted order,
-- so macifier-cmdkeys has already run by the time this does.
local function cmdkeys_took_k()
  local file = io.open(os.getenv("HOME") .. "/.local/state/macifier/keyset", "r")
  if not file then return false end
  for line in file:lines() do
    if line == "K" then file:close() return true end
  end
  file:close()
  return false
end

local key = cmdkeys_took_k() and "CTRL + ALT + K" or "SUPER + K"
hl.unbind(key)
o.bind(key, "Keybindings", "macifier-keybindings")
