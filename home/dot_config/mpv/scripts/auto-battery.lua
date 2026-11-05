-- auto-battery.lua
--
-- Switch to a lighter profile when the laptop is running on battery.
-- Only checks at mpv startup, not continuously.
-- Press B to toggle between battery/quality profiles mid-session.

local options = {
    profile = "battery",
    quality_profile = "quality",
    battery = "BAT0",
}

require("mp.options").read_options(options, "auto-battery")

local current_profile = nil

local file = io.open("/sys/class/power_supply/" .. options.battery .. "/status", "r")

if file then
    local status = file:read()
    file:close()

    if status == "Discharging" then
        mp.commandv("apply-profile", options.profile)
        current_profile = options.profile
        mp.msg.info("Battery discharging — applied profile: " .. options.profile)
    end
end

-- Toggle between battery and quality profiles (bound to B in input.conf).
mp.register_script_message("cycle-profile", function()
    if current_profile == options.profile then
        mp.commandv("apply-profile", options.quality_profile)
        current_profile = options.quality_profile
        mp.osd_message("Profile: " .. options.quality_profile)
    else
        mp.commandv("apply-profile", options.profile)
        current_profile = options.profile
        mp.osd_message("Profile: " .. options.profile)
    end
end)
