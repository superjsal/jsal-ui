-- Stars in the gear plan: the items you want. Starring one (or adding one
-- the plan doesn't list, by its ID, its link or its Wowhead address) means
-- "tell me when I can get it": a gold line on its tooltip anywhere, a gold
-- banner when it drops, a chat line on entering a dungeon that has it, and
-- marks in the dungeon guide. A star clears itself once you wear the item,
-- or something at least as good in its place.
local _, ns = ...
local Gear = ns.Gear

-- The game's own star (the raid marker), small enough to sit in text.
Gear.STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t"
local GOLD = "|cffe3b04b"

local function Info(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return nil end
    local name, link, quality, _, req, _, _, _, equipLoc, _, _, classID, subclassID = get(id)
    if not name then
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        return nil
    end
    return { name = name, link = link, quality = quality, req = req or 0, equipLoc = equipLoc,
             classID = classID, subclassID = subclassID }
end
Gear.Info = Info

-- The item an add box holds: a link (shift-clicked), a Wowhead address
-- ("wowhead.com/forever/item=19121/..."), or a plain item ID.
function Gear.ParseItem(text)
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    local id = text:match("|Hitem:(%d+)") or text:match("item[=:/](%d+)") or text:match("^(%d+)$")
    return id and tonumber(id) or nil
end

-- The inventory type an item goes in: what you added it as, GearData's, or
-- the game's.
local function TypeOf(id)
    local added = Gear.Added()[id]
    if added then return added.t end
    local known = Gear.Lookup(id)
    if known then return known.slotType end
    local info = Info(id)
    return info and Gear.INVTYPE[info.equipLoc or ""]
end
Gear.TypeOf = TypeOf

-- What you wear in a slot to compare against: for rings and trinkets the
-- weaker of the two, which an upgrade would replace.
local function Worn(slot, weights)
    local worn
    for _, equip in ipairs(slot.equip) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", equip)
        local stats = link and Gear.Stats(link) or {}
        local score = link and Gear.Score(stats, weights, slot.dps) or 0
        if not worn or score < worn.score then worn = { link = link, stats = stats, score = score or 0 } end
    end
    return worn
end

-- What a starred item adds over what you wear, for its tooltip and its
-- banner: "+14 AP, +6 Sta" and the worn item's name; nil when it adds
-- nothing your spec values or its stats aren't loaded yet.
function Gear.StarGains(id)
    local slot = Gear.SlotOf(TypeOf(id) or 0)
    local weights = Gear.Weights()
    local stats = Gear.Stats(id)
    if not (slot and weights and stats) then return nil end
    local worn = Worn(slot, weights)
    local gains = Gear.Gains(stats, worn.stats, weights, slot.dps)
    if gains == "" then return nil end
    return gains, worn.link and worn.link:match("%[(.-)%]")
end

---------------------------------------------------------------------------
-- Adding an item the plan doesn't list. Returns what to say, and whether it
-- went in; "waiting" when the game hasn't loaded the item yet (try again
-- when it has).
---------------------------------------------------------------------------
function Gear.Add(text)
    local id = Gear.ParseItem(text)
    if not id then return "Paste an item ID or a Wowhead item link, or shift-click an item.", false end
    local info = Info(id)
    if not info then return "waiting", false end
    local invType = Gear.INVTYPE[info.equipLoc or ""]
    local slot = invType and Gear.SlotOf(invType)
    if not slot then return info.name .. " isn't something you wear in a gear slot.", false end
    local _, classFile = UnitClass("player")
    -- Usable now, or once you reach the item's level (mail for a hunter at 40).
    local level = UnitLevel("player") or 1
    local function Usable(at)
        return Gear.ForClass(classFile, at, info.classID, info.subclassID, info.equipLoc) ~= false
            or Gear.CanWear(classFile, at, info.classID, info.subclassID)
    end
    if not (Usable(level) or Usable(math.max(level, info.req or 0))) then
        return "Your class can't use " .. info.name .. ".", false
    end
    Gear.Added()[id] = { t = invType, req = info.req }
    Gear.Starred()[id] = true
    if ns.Window and ns.Window.Refresh then ns.Window.Refresh() end
    return ("%s added under %s, starred."):format(info.name, slot.label), true, slot
end

---------------------------------------------------------------------------
-- A star clears itself once you wear the item, or something at least as
-- good for your spec where it would go.
---------------------------------------------------------------------------
function Gear.Tidy(equipSlot)
    local stars = Gear.Starred()
    if not next(stars) then return end
    local slot
    for _, s in ipairs(Gear.SLOTS) do
        for _, e in ipairs(s.equip) do if e == equipSlot then slot = s end end
    end
    if not slot then return end
    local _, classFile = UnitClass("player")
    local level = UnitLevel("player") or 1
    local weights = Gear.Weights()
    local worn = Worn(slot, weights)
    local wearing = {}
    for _, e in ipairs(slot.equip) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", e)
        local id = link and tonumber(link:match("item:(%d+)"))
        if id then wearing[id] = true end
    end
    for id in pairs(stars) do
        local reason
        if wearing[id] then
            reason = "you wear it now"
        else
            local t = TypeOf(id)
            local stats = t and Gear.Fits(slot, t, classFile, level) and weights and Gear.Stats(id)
            local score = stats and Gear.Score(stats, weights, slot.dps)
            if score and worn.link and worn.score >= score then reason = "what you wear there is as good for your spec" end
        end
        if reason then
            local info = Info(id)
            Gear.Unstar(id)
            ns.Print(("%s is off your gear plan's stars: %s."):format(info and info.link or ("item " .. id), reason))
        end
    end
end

---------------------------------------------------------------------------
-- The gold line on a starred item's tooltip, wherever it shows.
---------------------------------------------------------------------------
function Gear.TooltipLines(tooltip, id)
    if not (id and Gear.Starred()[id] and tooltip and tooltip.AddLine) then return end
    tooltip:AddLine(Gear.STAR .. " Starred in your gear plan", 0.89, 0.69, 0.29)
    local gains, over = Gear.StarGains(id)
    if gains then tooltip:AddLine(gains .. (over and (" over " .. over) or ""), 0.89, 0.69, 0.29, true) end
    if tooltip.Show then tooltip:Show() end
end

local hooked = false
local function HookTooltips()
    if hooked then return end
    hooked = true
    local function Lines(tooltip, id)
        if Gear.running then xpcall(Gear.TooltipLines, ns.Report, tooltip, id) end
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            Lines(tooltip, data and data.id)
        end)
    elseif GameTooltip and GameTooltip.HookScript then
        for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
            if tip then
                tip:HookScript("OnTooltipSetItem", function(tooltip)
                    local _, link = tooltip:GetItem()
                    Lines(tooltip, link and tonumber(link:match("item:(%d+)")))
                end)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Where your stars drop: by dungeon, each starred item with its boss, from
-- Wowhead's loot lists and what you've seen drop.
---------------------------------------------------------------------------
function Gear.StarsIn(dungeon)
    local stars = Gear.Starred()
    local out, seen = {}, {}
    if not (dungeon and next(stars)) then return out end
    local D = ns.Dungeons
    local learned = D and D.Loot and D.Loot() or {}
    for _, b in ipairs(dungeon.bosses or {}) do
        local function Add(id)
            if stars[id] and not seen[id] then
                seen[id] = true
                out[#out + 1] = { id = id, boss = b[3] or b[2] }
            end
        end
        for _, drop in ipairs(ns.DungeonLoot and ns.DungeonLoot[b[1]] or {}) do Add(drop[1]) end
        for id in pairs(learned[D.Key(b[2])] or {}) do Add(id) end
    end
    return out
end

---------------------------------------------------------------------------
-- The drop alert: a gold banner when a starred item shows in a loot window
-- or a roll, once a minute at most for the same item.
---------------------------------------------------------------------------
local alerted = {}
function Gear.Dropped(link)
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if not (id and Gear.Starred()[id]) then return false end
    local now = GetTime and GetTime() or 0
    if alerted[id] and now - alerted[id] < 60 then return false end
    alerted[id] = now
    local gains, over = Gear.StarGains(id)
    local line = link .. (gains and ("  " .. "|cff9a9688· " .. gains .. (over and (" over " .. over) or "") .. "|r") or "")
    if ns.Style and ns.Style.Banner then
        ns.Style.Banner(Gear.STAR .. " Starred item dropped", line)
    end
    if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959) end
    return true
end

-- Entering a dungeon: one chat line naming your starred items there and
-- who drops them, once per visit.
local announced
function Gear.Entered()
    if not GetInstanceInfo then return end
    local _, kind, _, _, _, _, _, instanceID = GetInstanceInfo()
    if kind ~= "party" and kind ~= "raid" then
        announced = nil
        return
    end
    if announced == instanceID then return end
    announced = instanceID
    for _, d in ipairs(ns.DungeonData or {}) do
        if d.map == instanceID then
            local list = Gear.StarsIn(d)
            if #list == 0 then return end
            local parts = {}
            for _, s in ipairs(list) do
                local info = Info(s.id)
                parts[#parts + 1] = (info and info.link or ("item " .. s.id)) .. " (" .. s.boss .. ")"
            end
            ns.Print(GOLD .. "Starred here:|r " .. table.concat(parts, ", "))
            return
        end
    end
end

local function OnEvent(_, event, a)
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        Gear.Tidy(a)
    elseif event == "LOOT_OPENED" then
        for slot = 1, (GetNumLootItems and GetNumLootItems() or 0) do
            Gear.Dropped(GetLootSlotLink and GetLootSlotLink(slot))
        end
    elseif event == "START_LOOT_ROLL" then
        Gear.Dropped(GetLootRollItemLink and GetLootRollItemLink(a))
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        -- A moment later, so the items' names have loaded.
        ns.Compat.After(3, function() xpcall(Gear.Entered, ns.Report) end)
    end
end
Gear.OnStarEvent = OnEvent

local events
function Gear.StartStars(module)
    events = events or CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "LOOT_OPENED", "START_LOOT_ROLL",
                             "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", ns.Safe(module, OnEvent))
    HookTooltips()
end

function Gear.StopStars()
    if events then events:UnregisterAllEvents() end
end
