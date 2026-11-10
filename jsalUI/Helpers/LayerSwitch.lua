-- Changing layers through the guild. Each jsal.ui tells the guild, quietly,
-- which zone and layer it's on whenever that changes, and the quick bar's
-- Layer button lists guildmates in your zone on another layer. Asking to
-- join one sends them a hidden request: their jsal.ui invites you when
-- they're free to, and yours accepts that one invite. On Forever you keep
-- their layer while you're in their group.
local _, ns = ...
local Compat, Comms = ns.Compat, ns.Comms

local Switch = {}
ns.LayerSwitch = Switch

-- A layer is shared only when it changes, so a guildmate's holds until they
-- share another, go offline or log out; an hour is a safety limit.
local STALE = 3600
local SHARE_EVERY = 15   -- at most one share every this many seconds
local WAIT = 60          -- how long a request waits for its invite
local AGAIN = 60         -- never invite the same guildmate twice within this

local others = {}        -- name = { map, layer, at, target }
local invited = {}       -- name = when you last invited them
local asking, joined

local function Running()
    return ns.Layers and ns.Layers.running
end

-- Your zone and layer as "map:layer", or "" before a reading.
function Switch.Code()
    local c = Running() and ns.Layers.Current()
    return c and c.map and (c.map .. ":" .. c.layer) or ""
end

-- A guildmate's zone and layer, from their hello or a share.
function Switch.Heard(name, code, target)
    if not name or name == Compat.MyName() then return end
    local map, layer = tostring(code or ""):match("^(%d+):(%d+)$")
    if not map then
        others[name] = nil
        return
    end
    others[name] = { map = tonumber(map), layer = tonumber(layer), at = GetTime(), target = target or name }
end

local function OnlineNow()
    local online = {}
    for i = 1, (GetNumGuildMembers and GetNumGuildMembers() or 0) do
        local full, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if full and isOnline then online[Ambiguate(full, "none")] = true end
    end
    return online
end

-- Guildmates online in your zone on another layer, and your own reading.
function Switch.Choices()
    local c = Running() and ns.Layers.Current()
    if not c then return {}, nil end
    local online, list, now = OnlineNow(), {}, GetTime()
    for name, o in pairs(others) do
        if now - o.at > STALE or not online[name] then
            others[name] = nil
        elseif o.map == c.map and o.layer ~= c.layer then
            list[#list + 1] = { name = name, layer = o.layer, target = o.target }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list, c
end

-- Tells the guild your zone and layer when they change, at most once every
-- 15 seconds; a change in between goes out when the wait is over.
local lastShare, waiting = -SHARE_EVERY, false
local function Share()
    if not (Running() and IsInGuild()) then return end
    local now = GetTime()
    if now - lastShare < SHARE_EVERY then
        if not waiting then
            waiting = true
            Compat.After(SHARE_EVERY - (now - lastShare), function()
                waiting = false
                Share()
            end)
        end
        return
    end
    lastShare = now
    Comms.Send("LY", Switch.Code(), "GUILD")
end
Switch.Share = Share

---------------------------------------------------------------------------
-- Asking, and answering.
---------------------------------------------------------------------------
function Switch.Ask(choice)
    local c = ns.Layers.Current()
    asking = { name = choice.name, target = choice.target, by = GetTime() + WAIT, from = c and c.layer }
    ns.Print(("Asked %s to invite you to layer %d. Their invite is accepted for you when it comes."):format(choice.name, choice.layer))
    Comms.Send("LJ", Switch.Code(), "WHISPER", choice.target)
end

local REASONS = {
    off = "has inviting turned off", combat = "is in combat", instance = "is in a dungeon",
    full = "has a full group", notlead = "is in a group they don't lead", again = "invited you a moment ago",
    zone = "isn't in your zone any more",
}

-- Why you can't invite a guildmate right now, or nil when you can.
function Switch.WhyNot(name, code)
    if not (Running() and ns.OptionOn("layers", "host")) then return "off" end
    if Compat.InCombat() then return "combat" end
    if IsInInstance and IsInInstance() then return "instance" end
    local members = GetNumGroupMembers and GetNumGroupMembers() or 0
    if members >= 5 or (IsInRaid and IsInRaid()) then return "full" end
    if members > 0 and not UnitIsGroupLeader("player") then return "notlead" end
    if (invited[name] or -AGAIN) + AGAIN > GetTime() then return "again" end
    local c = ns.Layers.Current()
    local map = tonumber(tostring(code or ""):match("^(%d+)"))
    if not c or map ~= c.map then return "zone" end
    return nil
end

Comms.On("LY", function(payload, name, _, sender)
    if Running() then Switch.Heard(name, payload, sender) end
end)

-- A guildmate asks to join your layer: invite them, or say why not.
Comms.On("LJ", function(payload, name, _, sender)
    if not Running() then return end
    local why = Switch.WhyNot(name, payload)
    if why then return Comms.Send("LN", why, "WHISPER", sender) end
    invited[name] = GetTime()
    local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    if invite then invite(sender) end
    ns.Print(("Invited %s to join your layer."):format(name))
end)

-- They couldn't invite you.
Comms.On("LN", function(payload, name)
    if not (asking and asking.name == name) then return end
    asking = nil
    ns.Print(("%s can't invite you right now: they %s."):format(name, REASONS[payload] or "are busy"))
end)

-- Their invite arrives: it's the one you asked for, so it's accepted.
local events = CreateFrame("Frame")
events:RegisterEvent("PARTY_INVITE_REQUEST")
events:RegisterEvent("GROUP_LEFT")
events:SetScript("OnEvent", function(_, event, inviter)
    inviter = ns.Compat.Plain(inviter)
    if event == "GROUP_LEFT" then
        joined = nil
        return
    end
    if not (asking and Running()) then return end
    if GetTime() > asking.by then
        asking = nil
        return
    end
    if Ambiguate(tostring(inviter or ""), "none") ~= asking.name then return end
    joined = { name = asking.name, from = asking.from }
    asking = nil
    if AcceptGroup then AcceptGroup() end
    if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
    ns.Print(("Joined %s's group. You'll move to their layer in a moment, and keep it while you're in their group."):format(joined.name))
end)

-- Once the layer you read changes after joining, say so.
local function Moved()
    local c = joined and ns.Layers.Current()
    if c and joined.from and c.layer ~= joined.from then
        ns.Print(("You're on layer %d now, with %s."):format(c.layer, joined.name))
        joined.from = c.layer
    end
end

function Switch.Leave()
    local leave = (C_PartyInfo and C_PartyInfo.LeaveParty) or LeaveParty
    if leave then leave() end
end

-- Asks in General: a plain request typed in for you to send.
function Switch.AskGeneral()
    local c = ns.Layers.Current()
    local where = c and ns.Layers.MapName(c)
    local line = ("Could someone on another layer invite me, please?%s"):format(where and (" I'm in " .. where .. ".") or "")
    local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
    if open then open("/1 " .. line) else ns.Print(line) end
end

---------------------------------------------------------------------------
-- The menu from the quick bar's Layer button.
---------------------------------------------------------------------------
function Switch.Menu(anchor, tell)
    local list, c = Switch.Choices()
    local items = {}
    local nothing = function() end
    if not c then
        items[#items + 1] = { "No layer read yet", "mouse over a creature", nothing }
    else
        items[#items + 1] = { ("You're on layer %d"):format(c.layer), nil, nothing }
        for _, choice in ipairs(list) do
            local short = choice.name:match("^%S+") or choice.name
            items[#items + 1] = { "Join " .. short, ("layer %d"):format(choice.layer), function() Switch.Ask(choice) end }
        end
        if #list == 0 then items[#items + 1] = { "No guildmates on other layers", nil, nothing } end
        items[#items + 1] = { "Ask in General", nil, Switch.AskGeneral }
        if tell then items[#items + 1] = { "Tell your guild", nil, tell } end
    end
    if IsInGroup and IsInGroup() then items[#items + 1] = { "Leave group", nil, Switch.Leave } end
    ns.Launcher.ShowMenu(anchor, items)
end

if ns.Layers and ns.Layers.OnChange then
    ns.Layers.OnChange(function()
        Share()
        Moved()
    end)
end
