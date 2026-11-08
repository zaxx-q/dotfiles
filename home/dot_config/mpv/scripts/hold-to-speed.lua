-- hold-to-speed.lua
--
-- Hold space to temporarily speed up playback, release to restore.
-- Tap space = pause/play. Hold space = fast forward.
--
-- Configure in script-opts/hold-to-speed.conf:
--   hold_threshold=0.5
--   speed=2.0

local options = {
    hold_threshold = 0.5,
    speed = 2.0,
}

require("mp.options").read_options(options, "hold-to-speed")

local is_speeding = false
local timer = nil
local pre_hold_speed = 1.0

local function speed_on()
    is_speeding = true
    pre_hold_speed = mp.get_property_number("speed", 1.0)
    mp.set_property_number("speed", options.speed)
    mp.osd_message(string.format("▶▶ %.1fx", options.speed))
end

local function speed_off()
    mp.set_property_number("speed", pre_hold_speed)
    mp.osd_message(string.format("▶ %.1fx", pre_hold_speed), 0.8)
    is_speeding = false
end

local function cancel_timer()
    if timer then
        timer:kill()
        timer = nil
    end
end

local function on_space(event)
    local ev = event.event
    if ev == "down" then
        cancel_timer()
        timer = mp.add_timeout(options.hold_threshold, speed_on)
    elseif ev == "up" then
        cancel_timer()
        if is_speeding then
            speed_off()
        else
            mp.commandv("cycle", "pause")
            mp.commandv("script-binding", "uosc/flash-pause-indicator")
        end
    elseif ev == "press" then
        cancel_timer()
        mp.commandv("cycle", "pause")
        mp.commandv("script-binding", "uosc/flash-pause-indicator")
    end
end

mp.add_forced_key_binding("space", "hold-to-speed", on_space, { complex = true })
