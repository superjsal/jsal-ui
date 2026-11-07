-- Your own stat weights for the gear plan: change any number of WoWSims'
-- for a spec, or paste a whole Pawn scale, kept per character and per spec;
-- Reset goes back to WoWSims. Everything that scores items (the plan, the
-- star tooltips and banners) uses them at once.
local _, ns = ...
local Gear = ns.Gear

-- The stats the editor shows, in order: the game's stat key, its name, and
-- Pawn's name for it. A few stats come in twins the game may use either way
-- (crit on melee items, mana regeneration); changing one changes its twin.
Gear.WEIGHT_STATS = {
    { "ITEM_MOD_AGILITY_SHORT", "Agility", "Agility" },
    { "ITEM_MOD_STRENGTH_SHORT", "Strength", "Strength" },
    { "ITEM_MOD_STAMINA_SHORT", "Stamina", "Stamina" },
    { "ITEM_MOD_INTELLECT_SHORT", "Intellect", "Intellect" },
    { "ITEM_MOD_SPIRIT_SHORT", "Spirit", "Spirit" },
    { "ITEM_MOD_ATTACK_POWER_SHORT", "Attack Power", "Ap" },
    { "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", "Ranged Attack Power", "Rap" },
    { "ITEM_MOD_CRIT_RATING_SHORT", "Crit (1%)", "CritRating" },
    { "ITEM_MOD_HIT_RATING_SHORT", "Hit (1%)", "HitRating" },
    { "ITEM_MOD_SPELL_POWER_SHORT", "Spell Power", "SpellPower" },
    { "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", "Spell Damage", "SpellDamage" },
    { "ITEM_MOD_SPELL_HEALING_DONE_SHORT", "Healing", "Healing" },
    { "ITEM_MOD_CRIT_SPELL_RATING_SHORT", "Spell Crit (1%)", "SpellCritRating" },
    { "ITEM_MOD_HIT_SPELL_RATING_SHORT", "Spell Hit (1%)", "SpellHitRating" },
    { "ITEM_MOD_POWER_REGEN0_SHORT", "Mana every 5 sec", "Mp5" },
    { "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "Defense", "DefenseRating" },
    { "RESISTANCE0_NAME", "Armor", "Armor" },
}
Gear.WEIGHT_DPS = {
    { "mh", "Main-hand weapon DPS", "MainHandDps" },
    { "oh", "Off-hand weapon DPS", "OffHandDps" },
    { "ranged", "Ranged weapon DPS", "RangedDps" },
}
local TWINS = {
    ITEM_MOD_CRIT_RATING_SHORT = "ITEM_MOD_CRIT_MELEE_RATING_SHORT",
    ITEM_MOD_HIT_RATING_SHORT = "ITEM_MOD_HIT_MELEE_RATING_SHORT",
    ITEM_MOD_POWER_REGEN0_SHORT = "ITEM_MOD_MANA_REGENERATION_SHORT",
}

-- Saved: { [spec] = { stats = {...}, dps = {...}, full = true when a whole
-- Pawn scale replaced WoWSims' } }.
local function Saved()
    if not ns.char then return {} end
    ns.char.gearWeights = type(ns.char.gearWeights) == "table" and ns.char.gearWeights or {}
    return ns.char.gearWeights
end

local merged = {}
local function Changed()
    merged = {}
    if ns.Window and ns.Window.Refresh then ns.Window.Refresh() end
end

-- A spec's weights: WoWSims', with your changes on top.
function Gear.Weights(spec)
    spec = spec or Gear.Spec()
    if merged[spec] then return merged[spec] end
    local base = Gear.BaseWeights(spec)
    local mine = Saved()[spec]
    if not mine then return base end
    local out = { stats = {}, dps = {} }
    if base and not mine.full then
        for k, v in pairs(base.stats) do out.stats[k] = v end
        for k, v in pairs(base.dps) do out.dps[k] = v end
    end
    for k, v in pairs(mine.stats or {}) do out.stats[k] = v end
    for k, v in pairs(mine.dps or {}) do out.dps[k] = v end
    merged[spec] = out
    return out
end

function Gear.CustomWeights(spec)
    return Saved()[spec or Gear.Spec()] ~= nil
end

-- One weight changed: a stat's key or a weapon's DPS ("mh", "oh", "ranged").
function Gear.SetWeight(spec, key, value)
    if type(value) ~= "number" or value < 0 then return false end
    local all = Saved()
    local mine = all[spec] or { stats = {}, dps = {} }
    all[spec] = mine
    local isDps = key == "mh" or key == "oh" or key == "ranged"
    local list = isDps and mine.dps or mine.stats
    list[key] = value
    if TWINS[key] then mine.stats[TWINS[key]] = value end
    Changed()
    return true
end

function Gear.ResetWeights(spec)
    Saved()[spec] = nil
    Changed()
end

-- A Pawn scale: ( Pawn: v1: "Name": Agility=1.5, Stamina=0.4, ... ). It
-- replaces the spec's weights whole; a stat it doesn't name counts nothing.
-- Returns how many weights it read, or nil and why not.
function Gear.ParsePawn(text)
    local body = type(text) == "string" and text:match("%(%s*Pawn%s*:%s*v%d+%s*:%s*\"[^\"]*\"%s*:(.*)%)")
    if not body then return nil, "That isn't a Pawn scale: copy one that starts \"( Pawn: v1:\"." end
    local byPawn = {}
    for _, s in ipairs(Gear.WEIGHT_STATS) do byPawn[s[3]:lower()] = { s[1] } end
    local dpsByPawn = { dps = { "mh", "oh", "ranged" }, meleedps = { "mh", "oh" }, rangeddps = { "ranged" },
                        mainhanddps = { "mh" }, offhanddps = { "oh" } }
    local stats, dps, read = {}, {}, 0
    for name, value in body:gmatch("([%a%d]+)%s*=%s*(-?[%d%.]+)") do
        local v = tonumber(value)
        local lower = name:lower()
        if v and byPawn[lower] then
            local key = byPawn[lower][1]
            stats[key] = v
            if TWINS[key] then stats[TWINS[key]] = v end
            read = read + 1
        elseif v and dpsByPawn[lower] then
            for _, k in ipairs(dpsByPawn[lower]) do dps[k] = v end
            read = read + 1
        end
    end
    if read == 0 then return nil, "That Pawn scale has no stats jsal.ui knows." end
    return { stats = stats, dps = dps, full = true }, read
end

function Gear.ImportPawn(spec, text)
    local scale, read = Gear.ParsePawn(text)
    if not scale then return false, read end
    Saved()[spec] = scale
    Changed()
    return true, ("Read %d weights from the Pawn scale."):format(read)
end
