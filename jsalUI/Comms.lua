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

local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:SetScript("OnEvent", function(_, _, prefix, text, channel, sender)
    if prefix ~= PREFIX or type(text) ~= "string" then return end
    local kind, payload = text:match("^(%u+)|(.*)$")
    local fn = kind and handlers[kind]
    if not fn then return end
    xpcall(function() fn(payload, Ambiguate(sender, "none"), channel, sender) end, ns.Report)
end)

ns.OnLoad(function()
    Compat.RegisterPrefix(PREFIX)
end)
