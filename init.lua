-- Custom HUD for the Iota Local Multiplayer mod.
-- Shows health / levitation / mana above every player's item-slots,
-- so players who are not the focused/gui player can still read their stats.

-- Iota's utilities to be importable (Iota's files exist even if Iota loads
-- after us; mod.xml also enforces the requirement).

local mod_path = "mods/iota_hud_plus"

local ok_util = pcall(dofile, "mods/iota_multiplayer/files/scripts/lib/utilities.lua")
if not ok_util then
    GamePrint("[IotaMP HUD+] failed to import Iota's utilities.lua (is 'Iota Multiplayer' enabled?)")
    return
end

pcall(dofile_once, mod_path .. "/files/scripts/hud_draw.lua")

OnWorldPostUpdate = function()
    if type(hud_plus_draw) == "function" then
        hud_plus_draw()
    end
end