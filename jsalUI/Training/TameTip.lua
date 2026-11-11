-- Pet abilities on beasts: for a hunter, a gold line on a beast's tooltip
-- when taming it teaches a pet ability rank that isn't in your Beast
-- Training yet ("Tame to learn: Bite (Rank 3)"), and a grey one when the
-- beast is still above your level. A beast with nothing new gets no line.
-- Which beasts carry which ability comes from Wowhead Forever (TameData.lua).
-- It lists several ranks for most beasts, since a beast's level varies; the
-- rank named is the highest of them a pet of the beast's level can know.
-- Wowhead has abilities for about half the tameable beasts, so no line
-- doesn't always mean nothing to learn.
-- what you have comes from your Beast Training list, saved each time you
-- open it, and from the spells the game says you know. Inside a dungeon the
-- game hides which creature you're pointing at, so there's no line there.
local _, ns = ...
local Compat, Style = ns.Compat, ns.Style

local TameTip = ns.NewModule("tametip", {
    title = "Pet abilities on beasts",
    -- A new line on tooltips, so it starts off.
    defaultOn = false,
    note = "Hunters: a line on a beast's tooltip when taming it teaches a pet ability rank you don't have yet.",
})
ns.TameTip = TameTip

local HUNTER = 3

-- Every family ability by the pet's own spell: the Beast Training spell that
-- teaches it, the pet level it needs and its rank. The abilities every family shares come from pet
-- trainers, not from taming, so they're left out.
local index
local function Index()
    if index then return index end
    index = {}
    local source = ns.SpellData and ns.SpellData[HUNTER]
    for family, list in pairs(source and source.families or {}) do
        if family ~= "*" then
            for _, entry in ipairs(list) do
                index[entry[1]] = { pet = entry[1], beast = entry[2], level = entry[3], rank = entry[4] }
            end
        end
    end
    return index
end

-- An ability's name by its spell, asked of the game once.
local names = {}
local function Name(spell)
    local name = names[spell]
    if not name then
        name = Compat.SpellInfo(spell)
        names[spell] = name
    end
    return name
end

local function RankText(rank)
    return rank > 0 and ("Rank " .. rank) or ""
end

-- Whether this rank is yours already: the game says you know its Beast
-- Training spell, or it's in the list saved from your Beast Training.
local function Have(name, entry, listed)
    return (IsPlayerSpell and IsPlayerSpell(entry.beast)) or listed[name .. "|" .. RankText(entry.rank)] ~= nil
end

-- What taming this creature at this level would teach you: a list of
-- { name, rank }, and whether your Beast Training has been seen (before
-- that, only the spells the game says you know count as yours). Nil for a
-- creature that isn't a beast you can tame, or whose level isn't known. Of
-- the ranks a beast is listed with, it has the highest its level allows;
-- a rank below one you have isn't new.
function TameTip.New(npc, level)
    local carries = ns.TameData and ns.TameData[npc]
    if not (carries and level and level > 0) then return nil end
    local saved = type(ns.char.beastTraining) == "table" and ns.char.beastTraining or nil
    local listed = saved and type(saved.rows) == "table" and saved.rows or {}
    local all = Index()
    local best = {}
    for _, spell in ipairs(carries) do
        local entry = all[spell]
        local name = entry and Name(spell)
        if name and entry.level <= level and (not best[name] or entry.rank > best[name].rank) then best[name] = entry end
    end
    local new = {}
    for name, entry in pairs(best) do
        local mine = false
        for other, o in pairs(all) do
            if o.rank >= entry.rank and (o == entry or Name(other) == name) and Have(name, o, listed) then
                mine = true
                break
            end
        end
        if not mine then new[#new + 1] = { name = name, rank = entry.rank } end
    end
    table.sort(new, function(a, b) return a.name < b.name end)
    return new, saved ~= nil
end

-- The creature's number from its ID, or nil for players, pets and the like.
local function Creature(guid)
    if type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, npc = strsplit("-", guid)
    if kind ~= "Creature" then return nil end
    return tonumber(npc)
end

-- The lines for the creature a tooltip is about. `guid` is the tooltip's
-- own, when the game gives one; else it's the creature under the mouse.
function TameTip.Lines(tooltip, guid)
    if not (TameTip.hunter and tooltip and tooltip.AddLine) then return end
    local unit = "mouseover"
    local over = UnitExists(unit) and Compat.GUID(unit) or nil
    if not guid then guid = over end
    -- The level is read from the creature under the mouse, so a tooltip
    -- about any other creature gets no line.
    local level = guid == over and Compat.Plain(UnitLevel(unit)) or nil
    local new, checked = TameTip.New(Creature(guid), level)
    if not (new and #new > 0) then return end
    local parts = {}
    for i, a in ipairs(new) do
        parts[i] = a.name .. (a.rank > 0 and (" (" .. RankText(a.rank) .. ")") or "")
    end
    local r, g, b = Style.Color("gold")
    tooltip:AddLine("Tame to learn: " .. table.concat(parts, ", "), r, g, b, true)
    local mr, mg, mb = Style.Color("muted")
    -- You can tame a beast of your level or below.
    local mine = UnitLevel("player")
    if mine and level > mine then
        tooltip:AddLine("Tameable at level " .. level, mr, mg, mb)
    end
    if not checked then
        tooltip:AddLine("Open Beast Training once so jsal.ui knows what you have.", mr, mg, mb, true)
    end
    if tooltip.Show then tooltip:Show() end
end

local hooked = false
local function Hook()
    if hooked then return end
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType) then return end
    hooked = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, ns.Safe(TameTip, function(tooltip, data)
        if not TameTip.running or tooltip ~= GameTooltip then return end
        TameTip.Lines(tooltip, Compat.Plain(type(data) == "table" and data.guid or nil))
    end))
end

function TameTip:OnEnable()
    local _, class = UnitClass("player")
    self.hunter = class == "HUNTER"
    if self.hunter then Hook() end
end

function TameTip:OnDisable()
    self.hunter = false
end
