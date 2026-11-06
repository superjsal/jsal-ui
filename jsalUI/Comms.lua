-- Messages between jsal.ui players, through the game's hidden addon channel.
-- They go out one a second at most, and wait out combat and the game's chat
-- lockdown. Each is "KIND|payload"; nothing is stored anywhere online.
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
        Compat.SendAddon(PREFIX, message.text, message.channel, message.target)
    end
    Compat.After(1, Pump)
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
