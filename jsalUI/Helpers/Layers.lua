-- Layers: on a busy realm the game runs several copies of a zone, and
-- which one you're in shows only in the IDs of the creatures around you
-- ("Creature-0-server-instance-zone-npc-spawn"): the zone part differs
-- from copy to copy. This reads it, quietly, from creatures you mouse over,
-- target or see a nameplate for. /jsal layer says what it last read, so
-- players in the same zone can compare.
local _, ns = ...
local Compat = ns.Compat

local Layers = ns.NewModule("layers", {
    title = "Layer reader",
    note = "Notes which copy (layer) of a zone you're in, from the creatures around you. /jsal layer",
})
ns.Layers = Layers

-- The zone part of a creature's ID, or nil for players, pets and the like.
function Layers.FromGUID(guid)
    if type(guid) ~= "string" then return nil end
    local kind, _, server, instance, zone, npc = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    zone = tonumber(zone)
    if not zone or zone == 0 then return nil end
    return zone, tonumber(server), tonumber(instance), tonumber(npc)
end

-- What was last read: the layer's number, the map you were on, when, and
-- from which creature.
local current

-- Other parts (the quick bar's Layer button) hear when the number changes.
local listeners = {}
function Layers.OnChange(fn) listeners[#listeners + 1] = fn end
local function Changed()
    for _, fn in ipairs(listeners) do pcall(fn) end
end

local function Note(unit)
    if not (UnitExists(unit) and not UnitIsPlayer(unit)) then return end
    local zone, server, _, npc = Layers.FromGUID(UnitGUID(unit))
    if not zone then return end
    local map = Compat.PlayerPosition()
    local was = current
    current = { layer = zone, server = server, map = map, at = Compat.Now(), from = UnitName(unit), npc = npc }
    if not was or was.layer ~= zone or was.map ~= map then Changed() end
end

-- The layer last read on the map you're on now, or nil.
function Layers.Current()
    if not current then return nil end
    local map = Compat.PlayerPosition()
    if map and current.map and map ~= current.map then return nil end
    return current
end

-- Layer-Swap, a separate addon many players use to change layers: when it's
-- loaded, the quick bar's Layer button opens its panel. It's found by its
-- title in the AddOns list, and opened through its own /ls command.
function Layers.LayerSwapOpener()
    local count = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
    local info = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
    if not (count and info and SlashCmdList) then return nil end
    local loaded = false
    for i = 1, count() do
        local name, title = info(i)
        local plain = tostring(title or name or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
        if plain:find("layer%-?%s?swap") and Compat.IsAddOnLoaded(name) then
            loaded = true
            break
        end
    end
    if not loaded then return nil end
    for key, fn in pairs(SlashCmdList) do
        for n = 1, 9 do
            local word = _G["SLASH_" .. key .. n]
            if type(word) ~= "string" then break end
            if word:lower() == "/ls" then return function() fn("") end end
        end
    end
end

Layers.NONE ="No layer read on this map yet: mouse over or target any creature, then try again."

-- The name of the map a reading was taken on, or nil.
function Layers.MapName(c)
    return c and c.map and C_Map and C_Map.GetMapInfo and (C_Map.GetMapInfo(c.map) or {}).name or nil
end

-- How long ago a reading was taken, in words.
function Layers.Ago(c)
    local seconds = math.max(0, math.floor(Compat.Now() - c.at))
    if seconds < 120 then return seconds .. (seconds == 1 and " second ago" or " seconds ago") end
    return math.floor(seconds / 60) .. " minutes ago"
end

-- The line a player sends to compare: "I'm on layer 12 in Darkshore."
function Layers.ShareLine(c)
    local mapName = Layers.MapName(c)
    return ("I'm on layer %d%s."):format(c.layer, mapName and (" in " .. mapName) or "")
end

ns.Command("layer", function()
    local c = Layers.Current()
    if not c then
        ns.Print(Layers.NONE)
        return
    end
    local mapName = Layers.MapName(c)
    ns.Print(("Layer %d%s, read %d seconds ago from %s (realm part %s)."):format(
        c.layer, mapName and (" in " .. mapName) or "", math.floor(Compat.Now() - c.at), c.from or "a creature",
        tostring(c.server or "?")))
end)

function Layers:OnEnable()
    local events = CreateFrame("Frame")
    events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:SetScript("OnEvent", ns.Safe(self, function(_, event, unit)
        if event == "ZONE_CHANGED_NEW_AREA" then
            if current then
                current = nil
                Changed()
            end
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            Note("mouseover")
        elseif event == "PLAYER_TARGET_CHANGED" then
            Note("target")
        elseif unit then
            Note(unit)
        end
    end))
    self.events = events
end

function Layers:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
end
