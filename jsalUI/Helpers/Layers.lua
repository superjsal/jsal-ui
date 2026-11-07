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

local function Note(unit)
    if not (UnitExists(unit) and not UnitIsPlayer(unit)) then return end
    local zone, server, _, npc = Layers.FromGUID(UnitGUID(unit))
    if not zone then return end
    local map = Compat.PlayerPosition()
    current = { layer = zone, server = server, map = map, at = Compat.Now(), from = UnitName(unit), npc = npc }
end

-- The layer last read on the map you're on now, or nil.
function Layers.Current()
    if not current then return nil end
    local map = Compat.PlayerPosition()
    if map and current.map and map ~= current.map then return nil end
    return current
end

ns.Command("layer", function()
    local c = Layers.Current()
    if not c then
        ns.Print("No layer read on this map yet: mouse over or target any creature, then try again.")
        return
    end
    local mapName = c.map and C_Map and C_Map.GetMapInfo and (C_Map.GetMapInfo(c.map) or {}).name
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
            current = nil
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
