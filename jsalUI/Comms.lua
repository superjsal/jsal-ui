-- Messages between jsal.ui players, through the game's hidden addon channel.
-- They go out one a second at most, and wait out combat and the game's chat
-- lockdown. Each is "KIND|payload"; nothing is stored anywhere online, and
-- nobody sees them in chat.
local _, ns = ...
local Compat = ns.Compat

local Comms = {}
ns.Comms = Comms

local PREFIX = "jsalUI"
local handlers, queue = {}, {}
local pumping = false

function Comms.On(kind, fn)
    handlers[kind] = fn
end

local function Pump()
    if #queue == 0 then
        pumping = false
        return
    end
    if Compat.InCombat() or Compat.ChatLockdown() then
        Compat.After(5, Pump)
        return
    end
    local message = table.remove(queue, 1)
    if message.channel ~= "GUILD" or IsInGuild() then
        if message.channel == "WHISPER" and message.target then Comms.Whispered(message.target) end
        Compat.SendAddon(PREFIX, message.text, message.channel, message.target)
    end
    Compat.After(1, Pump)
end

---------------------------------------------------------------------------
-- A hidden message to someone who logged off a moment before still makes
-- the game print "No player named ... is currently playing." in chat. That
-- line is left out for a few seconds after jsal.ui writes to that name, and
-- only for that name, so a mistyped name in your own whisper still shows.
---------------------------------------------------------------------------
local QUIET = 10
local whispered = {}

-- A name as the line may print it: with its realm after a dash, after a
-- space, or without it. Spaces, dashes and case are left out of the match.
local function Key(name) return (name:gsub("[%s%-]", ""):lower()) end

function Comms.Whispered(target)
    local now = GetTime()
    whispered[Key(target)] = now
    if Ambiguate then whispered[Key(Ambiguate(target, "none"))] = now end
end

local notFound
function Comms.Unanswered(text)
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return false end
    if not notFound then
        local template = ERR_CHAT_PLAYER_NOT_FOUND_S or "No player named '%s' is currently playing."
        notFound = "^" .. template:gsub("[%%%^%$%(%)%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%s", "(.+)") .. "$"
    end
    local name = text:match(notFound)
    if not name then return false end
    local at = whispered[Key(name)] or (Ambiguate and whispered[Key(Ambiguate(name, "none"))])
    return at ~= nil and GetTime() - at <= QUIET
end

local addFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
if addFilter then
    addFilter("CHAT_MSG_SYSTEM", function(_, _, text)
        local ok, hide = pcall(Comms.Unanswered, text)
        return ok and hide or false
    end)
end

function Comms.Send(kind, payload, channel, target)
    queue[#queue + 1] = {
        text = kind .. "|" .. (payload or ""),
        channel = channel or "GUILD",
        target = target,
    }
    if not pumping then
        pumping = true
        Compat.After(0, Pump)
    end
end

---------------------------------------------------------------------------
-- Who is heard. Everything that listens here is between guildmates. A
-- message on the guild's own channel can only come from one; a whisper, or
-- any other channel, can come from anyone who knows the words, so its sender
-- has to be on the guild's roster. The roster's names are read once, and
-- again after the game says it changed. Just after logging in the roster may
-- not be in yet, and that's when the answers to your hello arrive: those are
-- held until it is, then heard or dropped like any other.
---------------------------------------------------------------------------
local HOLD_FOR, HOLD_MOST = 30, 200
local names, stale = nil, true
local waiting, asked = {}, -60

-- Whether a name is on your guild's roster: true or false, or nil while
-- you're in a guild whose roster the game hasn't given yet.
function Comms.Guildmate(name)
    if not (IsInGuild and IsInGuild()) then return false end
    if stale or not names then
        names = nil
        local count = GetNumGuildMembers and GetNumGuildMembers() or 0
        if count > 0 then
            names = {}
            for i = 1, count do
                local full = GetGuildRosterInfo(i)
                if full then names[Ambiguate(full, "none")] = true end
            end
            stale = false
        end
    end
    if not names then return nil end
    return names[name] == true
end

local function Hear(kind, payload, channel, sender)
    local fn = handlers[kind]
    if not fn then return end
    xpcall(function() fn(payload, Ambiguate(sender, "none"), channel, sender) end, ns.Report)
end

-- Asks the game for the roster, at most every ten seconds.
local function AskRoster()
    local now = GetTime()
    if now - asked < 10 then return end
    asked = now
    local ask = C_GuildInfo and C_GuildInfo.GuildRoster
    if ask then pcall(ask) end
end

-- The roster changed: its names are read again at the next ask, and what
-- was held for it is heard now, if it's in and the sender is on it.
local function RosterChanged()
    stale = true
    if #waiting == 0 or Comms.Guildmate("") == nil then return end
    local held, now = waiting, GetTime()
    waiting = {}
    for _, m in ipairs(held) do
        if now - m.at <= HOLD_FOR and Comms.Guildmate(Ambiguate(m.sender, "none")) then
            Hear(m.kind, m.payload, m.channel, m.sender)
        end
    end
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:RegisterEvent("GUILD_ROSTER_UPDATE")
listener:SetScript("OnEvent", function(_, event, prefix, text, channel, sender)
    prefix, text, channel, sender = Compat.Plains(prefix, text, channel, sender)
    if event == "GUILD_ROSTER_UPDATE" then
        xpcall(RosterChanged, ns.Report)
        return
    end
    if prefix ~= PREFIX or type(text) ~= "string" or not sender then return end
    local kind, payload = text:match("^(%u+)|(.*)$")
    if not (kind and handlers[kind]) then return end
    if channel ~= "GUILD" then
        local known = Comms.Guildmate(Ambiguate(sender, "none"))
        if known == nil then
            if #waiting < HOLD_MOST then
                waiting[#waiting + 1] = { kind = kind, payload = payload, channel = channel, sender = sender, at = GetTime() }
            end
            AskRoster()
            return
        end
        if not known then return end
    end
    Hear(kind, payload, channel, sender)
end)

ns.OnLoad(function()
    Compat.RegisterPrefix(PREFIX)
end)
