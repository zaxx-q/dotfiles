-- Automatically enable save-position-on-quit when playing from a playlist.
require("mp")

local function save_playlist()
  local is_playlist = #mp.get_property_native("playlist") > 1

  if is_playlist then
    mp.set_property("save-position-on-quit", "yes")
  end
end

mp.register_event("file-loaded", save_playlist)
