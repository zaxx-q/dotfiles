-- Take screenshots, copy to Wayland clipboard, and tag with xattr metadata.
require("mp")

local function screenshot(flag)
  return function()
    local result = mp.command_native({ "screenshot", flag })
    if not result or not result.filename then
      mp.osd_message("Screenshot failed")
      return
    end
    local filename = result.filename
    mp.osd_message("Screenshot (" .. flag .. ") taken")

    if mp.get_property("platform") ~= "linux" then return end

    -- Copy to clipboard via wl-copy
    if os.getenv("XDG_SESSION_TYPE") == "wayland" then
      os.execute('wl-copy -t text/uri-list "file://' .. filename .. '"')
    else
      os.execute('echo "file://' .. filename .. '" | xclip -sel c -t text/uri-list')
    end

    -- Tag with xattr metadata
    local title = mp.get_property("media-title")
    if title == mp.get_property("filename") then
      title = mp.get_property("filename/no-ext")
    end
    local pos = mp.get_property_osd("time-pos/full")

    os.execute("setfattr -n user.xdg.tags -v mpv " .. filename)
    os.execute(("setfattr -n user.xdg.comment -v %q %q"):format(title .. " at " .. pos, filename))
  end
end

mp.add_key_binding("s", "subs", screenshot("subtitles"))
mp.add_key_binding("S", "video", screenshot("video"))
mp.add_key_binding("Ctrl+s", "window", screenshot("window"))
