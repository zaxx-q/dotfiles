-- Hold a key to temporarily speed up playback, release to restore.
-- Space: tap = pause/play, hold 0.5s = 2x speed
-- Shift+Space: hold 0.5s = 3x speed

local hold_threshold = 0.5

local function make_speed_handler(fast_speed, default_action)
    local is_speeding = false
    local timer = nil
    local pre_hold_speed = 1.0

    local function speed_on()
        is_speeding = true
        pre_hold_speed = mp.get_property_number("speed", 1.0)
        mp.set_property("speed", fast_speed)
        mp.set_osd_ass(0, 0, string.format("▶▶ %.1fx faster", fast_speed))
    end

    local function speed_off()
        mp.set_property("speed", pre_hold_speed)
        mp.set_osd_ass(0, 0, "")
        mp.osd_message(string.format("▶ %.2fx", pre_hold_speed), 0.8)
        is_speeding = false
    end

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
            timer = mp.add_timeout(hold_threshold, speed_on)
        elseif ev == "up" then
            cancel_timer()
            if is_speeding then
                speed_off()
            elseif default_action then
                default_action()
            end
        elseif ev == "press" then
            cancel_timer()
            if default_action then default_action() end
        end
    end
end

local function toggle_pause()
    mp.command("cycle pause")
end

mp.add_forced_key_binding("space", "speed_space",
    make_speed_handler(2.0, toggle_pause), { complex = true })

mp.add_forced_key_binding("Shift+space", "speed_space_shift",
    make_speed_handler(3.0, nil), { complex = true })
