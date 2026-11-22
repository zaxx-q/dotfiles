-- hold-to-speed.lua
--
-- Hold space, or click and hold the left mouse button on the video, to
-- temporarily speed up playback. Release to restore.
-- Tap = pause/play. Hold = fast forward.
--
-- Configure in script-opts/hold-to-speed.conf:
--   hold_threshold=0.5
--   speed=2.0
--   release_ramp=0.3      # seconds to glide back to normal speed (0 = instant)
--   mouse=yes             # set to no to disable click-and-hold on the video
--   mouse_tap_pause=yes   # a quick click on the video toggles pause

local options = {
    hold_threshold = 0.5,
    speed = 2.0,
    release_ramp = 0.3,
    mouse = true,
    mouse_tap_pause = true,
}

require("mp.options").read_options(options, "hold-to-speed")

local RAMP_STEP = 0.02 -- seconds between speed updates while gliding back

local pre_hold_speed = 1.0
local ramp = nil -- timer gliding the speed back down after a release
local holders = {} -- inputs ("space", "mouse") currently holding the speed-up

local function any_holder()
    return next(holders) ~= nil
end

local function stop_ramp()
    if ramp then
        ramp:kill()
        ramp = nil
    end
end

-- Snapping straight from 2x back to 1x makes mpv's A/V sync correct itself in
-- one go (it assumes the speed was constant across the audio it has already
-- buffered), which shows up as the picture jumping a frame or two. Stepping
-- the speed down over a few hundred ms spreads that correction out.
local function ramp_speed_to(target)
    stop_ramp()
    local from = mp.get_property_number("speed", target)
    local steps = math.floor(options.release_ramp / RAMP_STEP + 0.5)
    if steps < 2 or from == target then
        mp.set_property_number("speed", target)
        return
    end
    local i = 0
    ramp = mp.add_periodic_timer(RAMP_STEP, function()
        i = i + 1
        if i >= steps then
            stop_ramp()
            mp.set_property_number("speed", target)
        else
            mp.set_property_number("speed", from + (target - from) * i / steps)
        end
    end)
end

-- The speed is only captured and restored by the first / last holder, so
-- holding space and the mouse together can't leave playback stuck at 2x.
local function speed_on(source)
    if not any_holder() then
        if ramp then
            -- Held again while still gliding back: the speed to return to
            -- is the one from before the first hold, not the mid-glide one.
            stop_ramp()
        else
            pre_hold_speed = mp.get_property_number("speed", 1.0)
        end
        mp.set_property_number("speed", options.speed)
        mp.osd_message(string.format("▶▶ %.1fx", options.speed))
    end
    holders[source] = true
end

local function speed_off(source)
    holders[source] = nil
    if not any_holder() then
        ramp_speed_to(pre_hold_speed)
        mp.osd_message(string.format("▶ %.1fx", pre_hold_speed), 0.8)
    end
end

local function toggle_pause()
    mp.commandv("cycle", "pause")
    mp.commandv("script-binding", "uosc/flash-pause-indicator")
end

-- Builds a handler for a complex key binding: a release before the threshold
-- is a tap, staying down past it starts the speed-up until release.
-- tap_on_cancel: whether a "canceled" release counts as a tap. mpv cancels
-- a held mouse button when it starts dragging the window, which shouldn't
-- toggle pause.
local function make_hold_handler(source, on_tap, tap_on_cancel)
    local timer = nil

    local function cancel_timer()
        if timer then
            timer:kill()
            timer = nil
        end
    end

    return function(event)
        local ev = event.event
        if ev == "down" then
            cancel_timer()
            timer = mp.add_timeout(options.hold_threshold, function()
                timer = nil
                speed_on(source)
            end)
        elseif ev == "up" then
            cancel_timer()
            if holders[source] then
                speed_off(source)
            elseif tap_on_cancel or not event.canceled then
                on_tap()
            end
        elseif ev == "press" then
            cancel_timer()
            on_tap()
        end
    end
end

mp.add_forced_key_binding("space", "hold-to-speed",
    make_hold_handler("space", toggle_pause, true), { complex = true })

if options.mouse then
    local function on_mouse_tap()
        if options.mouse_tap_pause then
            toggle_pause()
        end
    end

    -- Deliberately not a forced binding: mpv ranks forced bindings above
    -- regular ones, so uosc's own clicks (timeline, buttons, menus) keep
    -- priority and this only fires on the bare video.
    mp.add_key_binding("MBTN_LEFT", "hold-to-speed-mouse",
        make_hold_handler("mouse", on_mouse_tap, false), { complex = true })
end
