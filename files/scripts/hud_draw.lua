-- That's where the magic happens, where the UI elements get drawn :)

-- Took inspiration from Iota MP mod's HUD: our own GuiCreate() + Window(). Struggled to render anything other than text in UI otherwise
-- I don't know what i'm doing, i've barely ever touched lua in my life, much less Noita modding.
-- DrawList with get_line() widget-id hashing, using only base-game 2x2
-- textures (safe to scale to any size).

local M = hud_plus or {}
hud_plus = M

-- Future display modes / settings switch here. Probably gonna move it to it's own files later, for now, i'm trying to make the basics works.
M.config = {
    mode = "compact", -- compact strip above each player's slot row
    gap = 3,          -- padding between the side-by-side bars
}

local GUI_FILENAME_BAR_BG = "data/ui_gfx/hud/colors_bar_bg.png"
local GUI_FILENAME_HEALTH  = "data/ui_gfx/hud/colors_health_bar.png"
local GUI_FILENAME_FLYING  = "data/ui_gfx/hud/colors_flying_bar.png"
local GUI_FILENAME_MANA    = "data/ui_gfx/hud/colors_mana_bar.png"
local GUI_FILENAME_BOX     = "data/ui_gfx/inventory/quick_inventory_box.png"

-- Widget-id hashes (same trick ImmortalDiamond uses for persistent widgets in Iota).
local bar_bg_hash = get_line(function() end)
local health_hash = get_line(function() end)
local flying_hash = get_line(function() end)
local mana_hash   = get_line(function() end)

local gui = GuiCreate()
local window = Window(gui)

-- Compact strip geometry. Three side-by-side bars whose combined track width
-- (tracks + gaps) matches the item-slot row width.
local NATIVE_SIZE = 2        -- all bar textures are nxn
local STRIP_HEIGHT = 4
local FILL_HEIGHT = 2
local FILL_INSET = 1         -- track area is inset n px inside the background
local BAR_GAP = M.config.gap -- padding between the bars

local debug_printed = false

local function clamp01(v)
    return clamp(v, 0, 1)
end

-- Mana/Flask Bar Logic: wand mana %, or potion/flask fill as fallback. nil = empty.
-- Put apart, bit trickyer to make than the others.
-- Need to make the flasks work
local function get_mana_bar_ratio(player)
    local inventory = EntityGetFirstComponentIncludingDisabled(player, "Inventory2Component")
    local active_item = inventory ~= nil and ComponentGetValue2(inventory, "mActiveItem") or nil
    if active_item == nil then return nil end

    local ability = EntityGetFirstComponentIncludingDisabled(active_item, "AbilityComponent")
    if ability ~= nil then
        local mana = ComponentGetValue2(ability, "mana") or 0
        local mana_max = ComponentGetValue2(ability, "mana_max") or 0
        if mana_max > 0 then return clamp01(mana / mana_max) end
        return nil
    end

    local material_inventory = EntityGetFirstComponentIncludingDisabled(active_item, "MaterialInventoryComponent")
    if material_inventory ~= nil then
        local count = ComponentGetValue2(material_inventory, "count") or 0
        local capacity = ComponentGetValue2(material_inventory, "capacity") or 0
        if capacity > 0 then return clamp01(count / capacity) end
        return nil
    end

    return nil
end

local function draw_fill(draw_list, bar_x, y, bar_w, ratio, filename, hash)
    if ratio <= 0 then return end
    local fill_w = bar_w * ratio
    draw_list:layer()
    draw_list:add(GuiOptionsAddForNextWidget, GUI_OPTION.NonInteractive)
    draw_list:add(GuiImage, bar_x, y, filename, 1, fill_w / NATIVE_SIZE, FILL_HEIGHT / NATIVE_SIZE)
    draw_list:bind(hash)
end

local function draw_strip(draw_list, player, row_top, bars_x, width)
    local y = row_top - STRIP_HEIGHT

    -- Background capsule.
    draw_list:layer()
    draw_list:add(GuiOptionsAddForNextWidget, GUI_OPTION.NonInteractive)
    draw_list:add(GuiImage, bars_x, y, GUI_FILENAME_BAR_BG, 1, width / NATIVE_SIZE, STRIP_HEIGHT / NATIVE_SIZE)
    draw_list:bind(bar_bg_hash)

    -- Side-by-side tracks: 3 equal bars + 2 gaps, total = item row width.
    local inner = width - 2 * FILL_INSET
    local bar_w = (inner - 2 * BAR_GAP) / 3
    local x0 = bars_x + FILL_INSET
    local fill_y = y + (STRIP_HEIGHT - FILL_HEIGHT) * 0.5

    -- Health draw
    local damage_model = EntityGetFirstComponentIncludingDisabled(player, "DamageModelComponent")
    local hp, max_hp = 0, 1
    if damage_model ~= nil then
        hp = ComponentGetValue2(damage_model, "hp") or 0
        max_hp = ComponentGetValue2(damage_model, "max_hp") or 1
        if max_hp <= 0 then max_hp = 1 end
    end
    draw_fill(draw_list, x0, fill_y, bar_w, clamp01(hp / max_hp), GUI_FILENAME_HEALTH, health_hash)

    -- Levitation draw
    local character_data = EntityGetFirstComponentIncludingDisabled(player, "CharacterDataComponent")
    local flying_ratio = 1
    if character_data ~= nil then
        local flying_left = ComponentGetValue2(character_data, "mFlyingTimeLeft") or 0
        local flying_max = ComponentGetValue2(character_data, "fly_time_max") or 0
        if flying_max > 0 then flying_ratio = clamp01(flying_left / flying_max) end
    end
    draw_fill(draw_list, x0 + (bar_w + BAR_GAP), fill_y, bar_w, flying_ratio, GUI_FILENAME_FLYING, flying_hash)

    -- Mana draw
    draw_fill(draw_list, x0 + 2 * (bar_w + BAR_GAP), fill_y, bar_w, get_mana_bar_ratio(player) or 0, GUI_FILENAME_MANA, mana_hash)
end

local function draw_inner()
    if ModSettingGet("iota_multiplayer.gui_disabled") then return end
    if GameIsInventoryOpen() then return end
    if type(get_players) ~= "function" then
        M.no_api = true
        return
    end

    local players = get_players()
    if #players < 2 then return end

    local draw_list = window:begin(1000)

    local bars_x = tonumber(MagicNumbersGetValue("UI_BARS_POS_X")) - 1
    local bars_y = tonumber(MagicNumbersGetValue("UI_BARS_POS_Y"))
    local box_width, box_height = GuiGetImageDimensions(gui, GUI_FILENAME_BOX)
    if not debug_printed then
        debug_printed = true
        GamePrint("[IotaMP HUD+] bars=" .. tostring(bars_x) .. "," .. tostring(bars_y)
            .. " box=" .. tostring(box_width) .. "x" .. tostring(box_height))
    end
    local width = 8 * box_width + 1

    -- Same ordering  ImmortalDiamond uses: gui/focus player first, others by player index.
    local gui_enabled_player = get_player_gui_enabled()
    local ordered = table.filter(players, function(player)
        return player ~= gui_enabled_player
    end)
    table.sort(ordered, function(a, b)
        return Player(a).index < Player(b).index
    end)
    if gui_enabled_player ~= nil then
        table.insert(ordered, 1, gui_enabled_player)
    end

    for i, player in ipairs(ordered) do
        local row_top = bars_y + (i - 1) * (box_height + 4)
        draw_strip(draw_list, player, row_top, bars_x, width)
    end

    draw_list:dispatch()
end

-- Quick ass error reporter for my sanity's sake.
local error_count = 0
function M.draw()
    local ok, err = pcall(draw_inner)
    if ok then return end
    error_count = error_count + 1
    if error_count % 120 == 1 then
        GamePrint("[IotaMP HUD+] draw error: " .. tostring(err))
    end
end

-- Global entry point used by init.lua.
hud_plus_draw = M.draw