-- Every Blizzard call that has moved or been renamed between game versions
-- goes through here, so a patch that moves one is fixed in one place. Each
-- uses the newer name when the client has it and falls back to the older one.
local _, ns = ...

-- The moment jsal.ui starts loading, for /jsal perf.
ns.loadStarted = debugprofilestop()

local Compat = {}
ns.Compat = Compat

local AddOns = C_AddOns

function Compat.AddOnExists(name)
    if AddOns and AddOns.DoesAddOnExist then
        return AddOns.DoesAddOnExist(name) and true or false
    end
    local getInfo = (AddOns and AddOns.GetAddOnInfo) or GetAddOnInfo
    if not getInfo then return false end
    local ok, _, _, _, _, reason = pcall(getInfo, name)
    return ok and reason ~= "MISSING"
end

function Compat.IsAddOnLoaded(name)
    local isLoaded = (AddOns and AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return isLoaded and isLoaded(name) and true or false
end

function Compat.Metadata(name, field)
    local get = (AddOns and AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get(name, field) or nil
end

function Compat.InCombat()
    return InCombatLockdown()
end

-- A unit's ID, or nil when the game hides it. In a dungeon Forever hands
-- addons creature IDs as secret values, which raise an error when read
-- (split, compared, used as a key), so every ID is read through here.
function Compat.GUID(unit)
    local guid = UnitGUID(unit)
    if guid == nil or issecretvalue(guid) then return nil end
    return guid
end

function Compat.ServerTime()
    return GetServerTime()
end

-- A clock to a fraction of a second, for timing things. It keeps counting
-- through a /reload.
function Compat.Now()
    return GetTime()
end

function Compat.SecondsUntilDailyReset()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
        return C_DateAndTime.GetSecondsUntilDailyReset()
    end
    return GetQuestResetTime and GetQuestResetTime() or 0
end

function Compat.After(seconds, fn)
    C_Timer.After(seconds, fn)
end

-- One physical screen pixel in a frame's own units, for crisp 1px lines at
-- any UI scale.
function Compat.OnePixel(frame)
    if PixelUtil and PixelUtil.GetPixelToUIUnitFactor then
        return PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()
    end
    return 1
end

-- Stops the game nudging a thin texture onto the pixel grid, which can
-- double or drop a 1px line.
function Compat.Crisp(texture)
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(false)
        texture:SetTexelSnappingBias(0)
    end
end

function Compat.Money(copper)
    if GetMoneyString then return GetMoneyString(copper, true) end
    return GetCoinTextureString(copper)
end

function Compat.SendChat(text, channel)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(text, channel)
    else
        SendChatMessage(text, channel)
    end
end

-- A player's name the way the guild channel gives it. Forever names have a
-- first name and a surname ("Chicago Illinois"); UnitName returns only the
-- first, so the whole name comes from GetUnitName, then the realm is dropped
-- for players on this realm, as Ambiguate does for message senders.
function Compat.MyName()
    local whole = GetUnitName and GetUnitName("player", true) or UnitName("player")
    return Ambiguate(whole, "none")
end

-- Whether the player is one of the guild's officers.
function Compat.IsOfficer()
    if not IsInGuild() then return false end
    local info = C_GuildInfo
    if info and info.IsGuildOfficer then return info.IsGuildOfficer() and true or false end
    if info and info.CanEditOfficerNote then return info.CanEditOfficerNote() and true or false end
    return CanEditOfficerNote and CanEditOfficerNote() and true or false
end

-- Whether the player leads the guild.
function Compat.IsGuildMaster()
    return IsInGuild() and IsGuildLeader and IsGuildLeader() and true or false
end

-- Whether a guildmate (by name, as messages give it) leads the guild, from
-- the roster: true, false, or nil when the roster hasn't loaded yet.
function Compat.IsGuildMasterName(name)
    local count = GetNumGuildMembers and GetNumGuildMembers() or 0
    if count == 0 then return nil end
    for i = 1, count do
        local full, _, rankIndex = GetGuildRosterInfo(i)
        if full and rankIndex == 0 then
            return Ambiguate(full, "none") == name
        end
    end
    return false
end

function Compat.GuildName()
    return IsInGuild() and GetGuildInfo("player") or nil
end

function Compat.OnTaxi()
    return UnitOnTaxi("player") and true or false
end

-- The flight master's map: each slot's node ID (when the client gives one)
-- and name, which slot is where the player stands, and the map's ID.
function Compat.TaxiNodes()
    local mapID = GetTaxiMapID and GetTaxiMapID() or nil
    local nodes, here = {}, nil
    local currentState = Enum and Enum.FlightPathState and Enum.FlightPathState.Current or 0
    if C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and mapID then
        for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(mapID) or {}) do
            if node.slotIndex then
                nodes[node.slotIndex] = { id = node.nodeID, name = node.name }
                if node.state == currentState then here = node.slotIndex end
            end
        end
    end
    if not next(nodes) then
        for slot = 1, NumTaxiNodes() do
            nodes[slot] = { name = TaxiNodeName(slot) }
            if TaxiNodeGetType(slot) == "CURRENT" then here = slot end
        end
    end
    return nodes, here, mapID
end

-- A flight's hops, as pairs of flight map slots: where each leg starts and ends.
function Compat.TaxiHops(slot)
    local hops = {}
    for hop = 1, (GetNumRoutes(slot) or 0) do
        hops[hop] = { TaxiGetNodeSlot(slot, hop, true), TaxiGetNodeSlot(slot, hop, false) }
    end
    return hops
end

-- Frequent Flier, in the Adventure Legacy talent tree, makes flights 20%
-- faster. 1 when it isn't learned or the tree can't be read.
local ADVENTURE_LEGACY_TREE, FREQUENT_FLIER_NODE, FREQUENT_FLIER = 1188, 110300, 1.2
function Compat.FlightSpeedBonus()
    if not (C_Traits and C_Traits.GetConfigIDByTreeID) then return 1 end
    local config = C_Traits.GetConfigIDByTreeID(ADVENTURE_LEGACY_TREE)
    local node = config and C_Traits.GetNodeInfo(config, FREQUENT_FLIER_NODE)
    return node and (node.activeRank or 0) > 0 and FREQUENT_FLIER or 1
end

-- Spells: a name and an icon file ID, or nil when the client has no such spell.
function Compat.SpellInfo(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info then return info.name, info.iconID end
        return nil
    end
    local name, _, icon = GetSpellInfo(spellID)
    return name, icon
end

-- Bags: slot counts, free space and what's in a slot, as one table.
local Container = C_Container
Compat.LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4

function Compat.BagSize(bag)
    local get = (Container and Container.GetContainerNumSlots) or GetContainerNumSlots
    return get(bag) or 0
end

function Compat.BagFree(bag)
    local get = (Container and Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
    return get(bag)
end

function Compat.BagItem(bag, slot)
    if Container and Container.GetContainerItemInfo then
        return Container.GetContainerItemInfo(bag, slot)
    end
    local icon, count, locked, quality, _, _, link, _, noValue, itemID = GetContainerItemInfo(bag, slot)
    if not icon then return nil end
    return { iconFileID = icon, stackCount = count, isLocked = locked, quality = quality, hyperlink = link, hasNoValue = noValue, itemID = itemID }
end

function Compat.PickupBagItem(bag, slot)
    local pick = (Container and Container.PickupContainerItem) or PickupContainerItem
    pick(bag, slot)
end

function Compat.UseBagItem(bag, slot)
    local use = (Container and Container.UseContainerItem) or UseContainerItem
    use(bag, slot)
end

function Compat.SellPrice(item)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    return select(11, get(item))
end

-- A trainer row's name and kind ("header", "available", "unavailable" or
-- "used"). Older clients give name, rank, kind; Forever gives name, kind,
-- icon, with the rank only on the spell itself.
local TRAINER_KINDS = { header = true, available = true, unavailable = true, used = true }
function Compat.TrainerService(index)
    local name, second, third = GetTrainerServiceInfo(index)
    if TRAINER_KINDS[second] then return name, second end
    return name, third, second ~= "" and second or nil
end

-- What you know, from your own spellbook: each spell's ID, and for each name
-- the highest rank in the book (0 for a spell without ranks). Forever can
-- give a spell you know a different ID from the one its trainer sells, so
-- name and rank are the surer check.
function Compat.PlayerSpellbook()
    local ids, ranks = {}, {}
    local function Add(id, name, sub)
        if id then ids[id] = true end
        if name then
            local rank = tonumber(sub and sub:match("(%d+)")) or 0
            if rank >= (ranks[name] or -1) then ranks[name] = rank end
        end
    end
    local book = C_SpellBook
    local player = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo and player then
        for line = 1, book.GetNumSpellBookSkillLines() or 0 do
            local info = book.GetSpellBookSkillLineInfo(line)
            if info then
                for i = (info.itemIndexOffset or 0) + 1, (info.itemIndexOffset or 0) + (info.numSpellBookItems or 0) do
                    local item = book.GetSpellBookItemInfo(i, player)
                    if item then Add(item.spellID or item.actionID, item.name, item.subName) end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(tab)
            for i = (offset or 0) + 1, (offset or 0) + (count or 0) do
                local name, sub, id = GetSpellBookItemName(i, BOOKTYPE_SPELL or "spell")
                Add(id, name, sub)
            end
        end
    end
    return { ids = ids, ranks = ranks }
end

-- What the pet out now knows, from its spellbook: each spell by ID and by
-- name and rank ("Bite|Rank 3").
function Compat.PetSpellbook()
    local known = {}
    local function Add(id, name, sub)
        if id then known[id] = true end
        if name then known[name .. "|" .. (sub or "")] = true end
    end
    if C_SpellBook and C_SpellBook.HasPetSpells and C_SpellBook.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank then
        for i = 1, C_SpellBook.HasPetSpells() or 0 do
            local info = C_SpellBook.GetSpellBookItemInfo(i, Enum.SpellBookSpellBank.Pet)
            if info then Add(info.spellID or info.actionID, info.name, info.subName) end
        end
    elseif HasPetSpells and GetSpellBookItemName then
        for i = 1, HasPetSpells() or 0 do
            local name, sub, id = GetSpellBookItemName(i, BOOKTYPE_PET or "pet")
            Add(id, name, sub)
        end
    end
    return known
end

-- Whether the game's gamepad interface style is on. It opens the spellbook
-- and trainers from secure code, so nothing may hook them then.
function Compat.GamepadUI()
    return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() and true or false
end

-- Where the player stands: the map and the spot on it, from 0 to 1 across.
function Compat.PlayerPosition()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local map = C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return nil end
    local x, y = pos:GetXY()
    return map, x, y
end

-- Puts the game's own map pin on a spot and tracks it. False when the
-- client has no map pins.
function Compat.SetWaypoint(map, x, y)
    if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and C_Map.CanSetUserWaypointOnMap) then return false end
    if not C_Map.CanSetUserWaypointOnMap(map) then return false end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    return true
end

-- Items by ID: how many you have (in your bags, or bags and bank), name and
-- icon. A name the game hasn't loaded yet comes back nil and is asked for;
-- ITEM_DATA_LOAD_RESULT says when it's in.
function Compat.ItemCount(item, bank)
    local get = (C_Item and C_Item.GetItemCount) or GetItemCount
    return get(item, bank) or 0
end

function Compat.ItemName(item)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(item)
    if not name and GetItemInfo then name = GetItemInfo(item) end
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(item) end
    return name
end

function Compat.ItemIcon(item)
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(item) end
    return GetItemIcon and GetItemIcon(item)
end

-- The profession window open now: its name, your skill and its cap. Nil
-- when it shows someone else's linked profession.
function Compat.OpenProfession()
    local ui = C_TradeSkillUI
    if ui and ui.IsTradeSkillLinked and ui.IsTradeSkillLinked() then return nil end
    if ui and ui.GetChildProfessionInfo then
        local info = ui.GetChildProfessionInfo()
        if info and info.professionName and (info.maxSkillLevel or 0) > 0 then
            return info.parentProfessionName or info.professionName, info.skillLevel, info.maxSkillLevel
        end
    end
    if ui and ui.GetBaseProfessionInfo then
        local info = ui.GetBaseProfessionInfo()
        if info and info.professionName and (info.maxSkillLevel or 0) > 0 then
            return info.professionName, info.skillLevel, info.maxSkillLevel
        end
    end
    if GetTradeSkillLine then
        local name, rank, max = GetTradeSkillLine()
        if name and max and max > 0 then return name, rank, max end
    end
end

-- Whether you know a recipe, by its spell.
function Compat.KnowsRecipe(spell)
    local ui = C_TradeSkillUI
    if ui and ui.GetRecipeInfo then
        local info = ui.GetRecipeInfo(spell)
        if info then return info.learned and true or false end
    end
    return IsPlayerSpell(spell)
end

-- What a vendor sells: how many items, and each one's name and price.
function Compat.MerchantCount()
    return GetMerchantNumItems and GetMerchantNumItems() or 0
end

function Compat.MerchantItem(index)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = C_MerchantFrame.GetItemInfo(index)
        if info then return info.name, info.price end
        return nil
    end
    local name, _, price = GetMerchantItemInfo(index)
    return name, price
end

-- Quest givers that open on the gossip window.
local Gossip = C_GossipInfo

function Compat.GossipAvailable()
    return Gossip and Gossip.GetAvailableQuests() or {}
end

function Compat.GossipActive()
    return Gossip and Gossip.GetActiveQuests() or {}
end

function Compat.GossipTakeAvailable(questID)
    Gossip.SelectAvailableQuest(questID)
end

function Compat.GossipTakeActive(questID)
    Gossip.SelectActiveQuest(questID)
end

-- Talent points not spent yet, from the talent tree's own currency.
function Compat.UnspentTalentPoints()
    if C_ClassTalents and C_Traits then
        local configID = C_ClassTalents.GetActiveConfigID()
        local config = configID and C_Traits.GetConfigInfo(configID)
        local treeID = config and config.treeIDs and config.treeIDs[1]
        if not treeID then return 0 end
        local total = 0
        for _, currency in ipairs(C_Traits.GetTreeCurrencyInfo(configID, treeID, false) or {}) do
            total = total + (currency.quantity or 0)
        end
        return total
    end
    return UnitCharacterPoints and UnitCharacterPoints("player") or 0
end

-- Addon messages: the hidden channel jsal.ui players use to talk.
function Compat.RegisterPrefix(prefix)
    C_ChatInfo.RegisterAddonMessagePrefix(prefix)
end

function Compat.SendAddon(prefix, text, channel, target)
    return C_ChatInfo.SendAddonMessage(prefix, text, channel, target)
end

function Compat.ChatLockdown()
    return C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() or false
end
