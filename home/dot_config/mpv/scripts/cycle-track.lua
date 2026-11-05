-- cycle-track.lua
--
-- Cycle through audio/subtitle tracks filtered by language with keybinds.
-- Complements trackselect.lua which handles auto-selection on file load.
--
-- Default keybindings:
--   ' (apostrophe) = cycle subtitle tracks (filtered by language)
--   ; (semicolon)  = cycle audio tracks (filtered by language)
--
-- Languages are lua patterns matched against track lang tags.
-- Supports both IETF/BCP 47 (en-US) and ISO 639-2 (eng) codes.

local options = {
    -- Subtitle languages to cycle through (lua pattern, "/" separated).
    sub_langs = "en.?/eng",
    -- Audio languages to cycle through.
    audio_langs = "jpn?/ja/ko/en.?/eng",
    -- Include the currently selected track in the cycle list even if
    -- it doesn't match the language filters.
    include_current = true,
}

require("mp.options").read_options(options, "cycle-track")

local function parse_langs(str)
    local langs = {}
    for lang in string.gmatch(str, "([^/]+)") do
        langs[#langs + 1] = lang
    end
    return langs
end

local function create_cycler(prop_prefix, lang_str)
    local langs = parse_langs(lang_str)
    local idx = 0

    return function()
        local tracklist = mp.get_property_native("track-list")
        local current_id = mp.get_property_native(prop_prefix .. "id")
        local matching_ids = {}

        -- Collect tracks matching our language filters.
        for _, track in ipairs(tracklist) do
            if track.type == (prop_prefix == "s" and "sub" or "audio") then
                local dominated = false
                if track.lang then
                    for _, pattern in ipairs(langs) do
                        if string.match(track.lang:lower(), pattern) then
                            matching_ids[#matching_ids + 1] = track.id
                            dominated = true
                            break
                        end
                    end
                end
                -- Include current track even if it doesn't match filters.
                if not dominated and options.include_current and track.id == current_id then
                    matching_ids[#matching_ids + 1] = track.id
                end
            end
        end

        if #matching_ids == 0 then
            mp.osd_message("No matching tracks to cycle")
            return
        end

        -- Find where we are in the list and advance.
        local current_pos = 0
        for i, id in ipairs(matching_ids) do
            if id == current_id then
                current_pos = i
                break
            end
        end

        local next_pos = (current_pos % #matching_ids) + 1
        local next_id = matching_ids[next_pos]
        mp.set_property(prop_prefix .. "id", next_id)

        -- Show OSD feedback.
        local type_name = prop_prefix == "s" and "sub" or "audio"
        local lang = mp.get_property("current-tracks/" .. type_name .. "/lang") or "?"
        local title = mp.get_property("current-tracks/" .. type_name .. "/title") or ""
        mp.osd_message(string.format("Changed %s to [%s] %s (#%s)", type_name, lang, title, next_id))
    end
end

mp.add_key_binding("'", "cycle-sub", create_cycler("s", options.sub_langs))
mp.add_key_binding(";", "cycle-audio", create_cycler("a", options.audio_langs))
