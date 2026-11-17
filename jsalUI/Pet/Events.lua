-- The companion while you play: the game's events that earn it supplies
-- and that it reacts to, and the /jsal pet command.
local _, ns = ...
local Compat, Rules, Pet = ns.Compat, ns.PetRules, ns.Pet
local inner = Pet.inner
local ui = inner.ui
local Now, Refresh, ZoneName = inner.Now, inner.Refresh, inner.ZoneName

function Pet:OnEnable()
    Pet.Home()
    Pet.Movable()
    -- Hear your emotes, once: the game keeps a listener for good.
    if not Pet.hears then
        Pet.hears = Compat.OnEmote(ns.Safe(self, function(token) Pet.Emote(token) end)) or false
    end
    -- A hatchling from the moment the part is switched on, so what you earn
    -- before first opening its page isn't lost.
    Pet.State()
    -- The pen left out on its own comes back after a reload or a login.
    if ns.db.petShown and (ns.db.petCompact or ns.db.petOut) then
        Compat.After(1, ns.Safe(self, function()
            if not (ui.window and ui.window:IsShown()) then Pet.Open() end
            Pet.React("hello")
        end))
    end
    -- Where you are now, so that only going somewhere else counts as a trip.
    local zone = ZoneName()
    Pet.where = zone
    local fished = 0
    local events = CreateFrame("Frame")
    events:RegisterEvent("LOOT_READY")
    events:RegisterEvent("CHAT_MSG_SKILL")
    events:RegisterEvent("QUEST_TURNED_IN")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:RegisterEvent("PLAYER_CONTROL_LOST")
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:RegisterEvent("PLAYER_UNGHOST")
    events:RegisterEvent("PLAYER_DEAD")
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterEvent("CHAT_MSG_LOOT")
    events:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
    -- Mail come, and someone whispering you: it perks up (Pet.Notice).
    events:RegisterEvent("UPDATE_PENDING_MAIL")
    events:RegisterEvent("CHAT_MSG_WHISPER")
    events:RegisterEvent("CHAT_MSG_BN_WHISPER")
    local mailed = HasNewMail and HasNewMail() and true or false
    -- Out of a fight.
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- A new spell learned (from a trainer, mostly): the Crystal egg's source.
    -- Not in the first moments after logging in, in case the game says so then.
    events:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
    local learnAfter = Now() + 10
    -- A boss brought down: Onyxia may leave the Aurora egg, Ragnaros the Eclipse egg.
    pcall(events.RegisterEvent, events, "ENCOUNTER_END")
    events:SetScript("OnEvent", ns.Safe(self, function(_, event, text, ...)
        -- A chat line can be hidden in a dungeon: then it's nil.
        text = Compat.Plain(text)
        if event == "PLAYER_REGEN_ENABLED" then
            -- A fight you walked away from: once in a long while there's
            -- something in the wreckage.
            if not Compat.Dead() then Pet.Found("fight") end
        elseif event == "ENCOUNTER_END" then
            -- encounterID, encounterName, difficultyID, groupSize, success
            local boss = Rules.BOSSES[tonumber(text) or 0]
            local won = Compat.Plain(select(4, ...)) == 1
            -- A beta build says what the game called the fight, so the numbers
            -- the boss eggs go by can be checked on a kill ("hidden": the game
            -- kept it back, and no egg can come of it).
            if Pet.Trials(ns.version) then
                ns.Print(("Boss fight %s (%s): %s."):format(tostring(text or "hidden"), tostring(Compat.Plain((...)) or "hidden"), won and "won" or "not won"))
            end
            if boss and won then Pet.Found(boss) end
        elseif event == "LEARNED_SPELL_IN_SKILL_LINE" then
            if Now() >= learnAfter then Pet.Found("learn") end
        elseif event == "LOOT_READY" then
            -- A catch, not a corpse; and the game can say so twice for one catch.
            if Compat.Fished() and Now() - fished >= 2 then
                fished = Now()
                Pet.Extra("fishing")
                Pet.Found("fishing")
            end
        elseif event == "CHAT_MSG_SKILL" then
            -- "Your skill in Cooking has increased to 76."
            if type(text) == "string" then
                if text:find("Cooking", 1, true) then Pet.Extra("cooking")
                elseif text:find("First Aid", 1, true) then Pet.Extra("firstaid") end
            end
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            -- The game also says this as you log in; that isn't a trip.
            local now = ZoneName()
            local moved = now and zone and now ~= zone
            zone = now or zone
            Pet.where = zone
            if ui.window and ui.window:IsShown() then Refresh() end
            if moved then
                Pet.Did("zone")
                Pet.Found("zone")
                Pet.React("zone")
                Pet.Along()
            end
        elseif event == "QUEST_TURNED_IN" then
            Pet.Earn("meal", 1)
            Pet.Did("quest")
            Pet.Found("quest")
            Pet.React("quest")
            Pet.Along()
            Pet.Gift()
        elseif event == "PLAYER_LEVEL_UP" then
            Pet.Earn("treat", 2)
            Pet.Earn("soap", 1)
            Pet.Earn("medicine", 1)
            Pet.Found("level")
            Pet.React("level")
            Pet.Along()
        elseif event == "CHAT_MSG_TEXT_EMOTE" then
            -- An emote of yours, by the line it put in chat.
            local emote = Pet.EmoteOf(text)
            if emote then Pet.Emote(emote) end
        elseif event == "PLAYER_TARGET_CHANGED" then
            -- A rare: it perks up, but not every time you look away and back.
            if Compat.TargetRare() and Now() - (Pet.rareAt or 0) >= 30 and Pet.React("rare") then Pet.rareAt = Now() end
        elseif event == "CHAT_MSG_LOOT" then
            -- Yours, and blue or better (by the colour the game gives its name).
            if type(text) == "string" and text:find("^You ") and (text:find("|cff0070dd", 1, true) or text:find("|cffa335ee", 1, true)
                or text:find("|cffff8000", 1, true) or text:find("|cnIQ[345]:")) then
                Pet.React("loot")
            end
        elseif event == "UPDATE_PENDING_MAIL" then
            -- The game says this for more than new mail: only mail that's new
            -- since it last looked counts, once.
            local new = HasNewMail and HasNewMail() and true or false
            if new and not mailed then Pet.Notice("mail") end
            mailed = new
        elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
            Pet.Notice("whisper")
        elseif event == "PLAYER_DEAD" then
            Pet.React("died")
        elseif event == "PLAYER_UNGHOST" then
            -- Back among the living, sometimes with something from the other side.
            Pet.Found("ghost")
            Pet.React("back")
        elseif event == "PLAYER_CONTROL_LOST" then
            -- The game takes the controls away as a flight starts (and for
            -- other things): a moment later, see whether you're flying.
            Compat.After(1, ns.Safe(self, function()
                if Compat.OnTaxi() then
                    Pet.Earn("toy", 1)
                    Pet.Did("flight")
                    Pet.Found("flight")
                    Pet.React("flight")
                    Pet.Along()
                end
            end))
        end
    end))
end

ns.Command("pet", function() Pet.Open() end)
