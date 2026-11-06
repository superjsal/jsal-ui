-- Chess against guildmates who have jsal.ui: challenges, games and the
-- win-loss record. Each game is saved on the character as its moves; the
-- moves go to the opponent by whisper through the addon channel, and only
-- while they're online. When either player comes back, both sides compare
-- how far they've got and send what the other missed, so a move, a
-- resignation or an accepted challenge made while one was away still lands.
local _, ns = ...
local Compat, Comms, Rules = ns.Compat, ns.Comms, ns.ChessRules

local Chess = ns.NewModule("chess", {
    title = "Chess",
    note = "Play chess with guildmates who have jsal.ui. /jsal chess",
})
ns.Chess = Chess

local MAX_GAMES = 8
local FIRST_VERSION = "0.3.0"   -- the first jsal.ui with chess
local SYNC_GAP = 30             -- seconds between catch-ups with one player

---------------------------------------------------------------------------
-- Saved state: games by ID and the record against each opponent.
---------------------------------------------------------------------------
local function Saved()
    local c = ns.char.chess
    if type(c) ~= "table" then
        c = {}
        ns.char.chess = c
    end
    c.games = type(c.games) == "table" and c.games or {}
    c.record = type(c.record) == "table" and c.record or {}
    return c
end

-- The games on the list, newest first. A closed game stays saved, out of
-- sight, for a month, so an opponent who was away still hears how it ended.
local KEEP_CLOSED = 30 * 86400

function Chess.Games()
    local list, now = {}, Compat.ServerTime()
    for id, game in pairs(Saved().games) do
        if game.hidden then
            if (game.updated or 0) + KEEP_CLOSED < now then Saved().games[id] = nil end
        else
            list[#list + 1] = game
        end
    end
    table.sort(list, function(a, b) return (a.updated or 0) > (b.updated or 0) end)
    return list
end

function Chess.Game(id) return Saved().games[id] end

function Chess.Record(name)
    local r = Saved().record[name]
    return r and r.w or 0, r and r.l or 0, r and r.d or 0
end

function Chess.Totals()
    local w, l, d = 0, 0, 0
    for _, r in pairs(Saved().record) do
        w, l, d = w + (r.w or 0), l + (r.l or 0), d + (r.d or 0)
    end
    return w, l, d
end

-- A game's position, moves as written and state. Each game is played
-- through once, then grows by its new moves only.
local cache = {}
function Chess.Position(game)
    local run = cache[game.id]
    if not run or run.list ~= game.moves or run.count > #game.moves then
        run = Rules.Start()
        run.list = game.moves
        cache[game.id] = run
    end
    if run.count < #game.moves or not run.status then
        while run.count < #game.moves do
            if not Rules.Advance(run, game.moves[run.count + 1]) then break end
        end
        run.status = Rules.Judge(run)
    end
    return run.state, run.sans, run.status
end

function Chess.MyTurn(game)
    return game.status == "play" and (#game.moves % 2 == 0) == (game.color == "w")
end

---------------------------------------------------------------------------
-- Who can play: guildmates online now whose jsal.ui has chess.
---------------------------------------------------------------------------
local function Older(a, b)
    local pa, pb = { strsplit(".", a or "") }, { strsplit(".", b or "") }
    for i = 1, math.max(#pa, #pb) do
        local x, y = tonumber(pa[i]) or 0, tonumber(pb[i]) or 0
        if x ~= y then return x < y end
    end
    return false
end

-- The guild by name: true for those online now, false for the rest.
local function Roster()
    local roster = {}
    for i = 1, (GetNumGuildMembers and GetNumGuildMembers() or 0) do
        local full, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if full then roster[Ambiguate(full, "none")] = isOnline and true or false end
    end
    return roster
end

local function OnlineNow()
    local online = {}
    for name, on in pairs(Roster()) do
        if on then online[name] = true end
    end
    return online
end

function Chess.Online(name)
    return OnlineNow()[name] == true
end

-- Online guildmates with chess, sorted by name: { name, target }.
function Chess.Players()
    local list, me, online = {}, Compat.MyName(), OnlineNow()
    local members = ns.Guild and ns.Guild.Members and ns.Guild.Members() or {}
    for name, m in pairs(members) do
        if name ~= me and online[name] and (m.version == ns.version or not Older(m.version, FIRST_VERSION)) then
            list[#list + 1] = { name = name, target = m.target or name }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function TargetOf(name)
    local m = ns.Guild and ns.Guild.Members and ns.Guild.Members()[name]
    return m and m.target or name
end

---------------------------------------------------------------------------
-- Sending: only to an opponent who's online; anything missed is caught up
-- when they're back.
---------------------------------------------------------------------------
local function Send(game, kind, payload)
    if not Chess.Online(game.opp) then return end
    Comms.Send(kind, game.id .. ";" .. (payload or ""), "WHISPER", game.target or TargetOf(game.opp))
end

local listeners = {}
function Chess.OnChange(fn) listeners[#listeners + 1] = fn end
local function Changed()
    for _, fn in ipairs(listeners) do xpcall(fn, ns.Report) end
end

local function Touch(game)
    game.updated = Compat.ServerTime()
end

-- The end of a game: the result, why, and the record, counted once.
local HOW = {
    checkmate = "checkmate", stalemate = "stalemate", material = "too few pieces to mate",
    fifty = "fifty moves without a capture", repetition = "the same position three times",
    resigned = "resignation", agreed = "agreement",
}

local function Finish(game, result, how)
    if game.status == "over" then return end
    game.status, game.result, game.how, game.drawOffer = "over", result, how, nil
    Touch(game)
    local r = Saved().record[game.opp] or { w = 0, l = 0, d = 0 }
    if result == "win" then r.w = r.w + 1 elseif result == "loss" then r.l = r.l + 1 else r.d = r.d + 1 end
    Saved().record[game.opp] = r
    local words = result == "win" and "You beat %s" or result == "loss" and "%s beat you" or "Your game with %s was drawn"
    ns.Print((words .. " by %s."):format(game.opp, HOW[how] or how))
end

-- After a move: has the board ended the game?
local function CheckEnd(game)
    local state, _, status = Chess.Position(game)
    if status == "checkmate" then
        -- The side to move is the one mated.
        Finish(game, state.turn == game.color and "loss" or "win", "checkmate")
    elseif status ~= "play" then
        Finish(game, "draw", status)
    end
end

---------------------------------------------------------------------------
-- What the player does.
---------------------------------------------------------------------------
local function NewID()
    return ("%d%03d"):format(Compat.ServerTime(), math.random(0, 999))
end

function Chess.Busy()
    local open = 0
    for _, game in pairs(Saved().games) do
        if game.status ~= "over" then open = open + 1 end
    end
    return open >= MAX_GAMES
end

-- Challenges a guildmate; who plays white is a coin toss.
function Chess.Challenge(name, target)
    if Chess.Busy() then return nil, ("You have %d games going; finish one first."):format(MAX_GAMES) end
    local color = math.random(2) == 1 and "w" or "b"
    local game = { id = NewID(), opp = name, target = target, color = color, moves = {}, status = "invited" }
    Touch(game)
    Saved().games[game.id] = game
    Send(game, "CI", color)
    Changed()
    return game
end

function Chess.Accept(game)
    if game.status ~= "asked" then return end
    game.status = "play"
    Touch(game)
    Send(game, "CA")
    Changed()
end

-- Turns down a challenge, or takes back one not answered yet.
function Chess.Decline(game)
    if game.status ~= "asked" and game.status ~= "invited" then return end
    Send(game, "CD")
    Saved().games[game.id] = nil
    Changed()
end

function Chess.Move(game, uci)
    if not Chess.MyTurn(game) then return false end
    local state = Chess.Position(game)
    if not Rules.FindMove(state, uci) then return false end
    game.moves[#game.moves + 1] = uci
    game.drawOffer = nil
    Touch(game)
    Send(game, "CM", #game.moves .. ";" .. uci)
    CheckEnd(game)
    Changed()
    return true
end

function Chess.Resign(game)
    if game.status ~= "play" then return end
    game.resigned = "me"
    Send(game, "CR")
    Finish(game, "loss", "resigned")
    Changed()
end

-- Offers a draw, or takes up the opponent's offer.
function Chess.Draw(game)
    if game.status ~= "play" then return end
    if game.drawOffer == "them" then
        game.agreed = true
        Send(game, "CX")
        Finish(game, "draw", "agreed")
    else
        game.drawOffer = "me"
        Touch(game)
        Send(game, "CO")
    end
    Changed()
end

-- Takes a finished game off the list; the record keeps it.
function Chess.Close(game)
    if game.status == "over" then
        game.hidden = true
        cache[game.id] = nil
        Changed()
    end
end

---------------------------------------------------------------------------
-- What the opponent sends. Every message names the game; one from anyone
-- but that game's opponent is ignored.
---------------------------------------------------------------------------
local function Their(id, name)
    local game = Saved().games[id or ""]
    if game and game.opp == name then return game end
end

local function Notify(text)
    if not (ns.Window.IsOpen and ns.Window.IsOpen("chess")) then ns.Print(text) end
end

local handlers = {}

handlers.CI = function(id, name, sender, color)
    if Saved().games[id] or (color ~= "w" and color ~= "b") then return end
    if Roster()[name] == nil or Chess.Busy() then return end
    local game = { id = id, opp = name, target = sender, color = color == "w" and "b" or "w", moves = {}, status = "asked" }
    Touch(game)
    Saved().games[id] = game
    Notify(("%s challenged you to chess. /jsal chess to answer."):format(name))
end

handlers.CA = function(id, name)
    local game = Their(id, name)
    if game and game.status == "invited" then
        game.status = "play"
        Touch(game)
        Notify(("%s took your chess challenge.%s"):format(name, Chess.MyTurn(game) and " Your move: /jsal chess" or ""))
    end
end

handlers.CD = function(id, name)
    local game = Their(id, name)
    if game and (game.status == "invited" or game.status == "asked") then
        Saved().games[id] = nil
        if game.status == "invited" then Notify(("%s turned down your chess challenge."):format(name)) end
    end
end

handlers.CM = function(id, name, _, ply, uci)
    local game = Their(id, name)
    if not game then return end
    -- A move to a game we'd invited them to means they took it up.
    if game.status == "invited" then game.status = "play" end
    if game.status ~= "play" then return end
    ply = tonumber(ply)
    if not ply or ply <= #game.moves then return end
    if ply > #game.moves + 1 then
        -- One went missing: ask for what's after what we have.
        Send(game, "CQ", #game.moves)
        return
    end
    if Chess.MyTurn(game) then return end
    local state, sans = Chess.Position(game)
    local m = Rules.FindMove(state, uci or "")
    if not m then return end
    local san = Rules.SAN(state, m)
    game.moves[#game.moves + 1] = uci
    if game.drawOffer == "me" then game.drawOffer = nil end
    Touch(game)
    CheckEnd(game)
    if game.status == "play" then Notify(("%s played %s. Your move: /jsal chess"):format(name, san)) end
end

handlers.CR = function(id, name)
    local game = Their(id, name)
    if game and game.status == "play" then
        game.resigned = "them"
        Finish(game, "win", "resigned")
    end
end

handlers.CO = function(id, name)
    local game = Their(id, name)
    if game and game.status == "play" then
        game.drawOffer = "them"
        Touch(game)
        Notify(("%s offers a draw. /jsal chess to answer."):format(name))
    end
end

handlers.CX = function(id, name)
    local game = Their(id, name)
    if game and game.status == "play" and game.drawOffer == "me" then
        game.agreed = true
        Finish(game, "draw", "agreed")
    end
end

-- A catch-up: how many moves they have and how the game stands for them.
-- Whoever is behind gets the moves they lack; a resignation or agreed draw
-- they missed is told again.
handlers.CQ = function(id, name, _, count, flag)
    local game = Their(id, name)
    if not game then return end
    count = tonumber(count) or 0
    if game.status == "invited" then game.status = "play"; Touch(game) end
    -- Behind: ask for the moves first; the ending, if any, follows them.
    if count > #game.moves then return Send(game, "CQ", #game.moves) end
    for ply = count + 1, #game.moves do Send(game, "CM", ply .. ";" .. game.moves[ply]) end
    if flag == "R" then handlers.CR(id, name) end
    if flag == "X" and game.status == "play" then game.agreed = true; Finish(game, "draw", "agreed") end
    if game.resigned == "me" then Send(game, "CR") end
    if game.agreed then Send(game, "CX") end
end

local lastSync = {}
local function CatchUp(name)
    if (lastSync[name] or 0) + SYNC_GAP > GetTime() then return end
    lastSync[name] = GetTime()
    for _, game in pairs(Saved().games) do
        if game.opp == name and (game.status == "play" or (game.status == "over" and (game.resigned == "me" or game.agreed))) then
            local flag = game.resigned == "me" and "R" or game.agreed and "X" or ""
            Send(game, "CQ", #game.moves .. ";" .. flag)
        elseif game.opp == name and game.status == "invited" then
            Send(game, "CI", game.color)
        end
    end
end

-- The Guild tab heard from a guildmate (a hello or an answer to one).
function Chess.Heard(name)
    if Chess.running then CatchUp(name) end
end

ns.Command("chess", function() ns.Window.Open("chess") end)

function Chess:OnEnable()
    for kind, fn in pairs(handlers) do
        Comms.On(kind, function(payload, name, _, sender)
            local id, a, b = strsplit(";", payload or "")
            fn(id, name, sender, a, b)
            Changed()
        end)
    end
    -- Catch up with every opponent online now, once the guild list is in.
    Compat.After(15, function()
        local online = OnlineNow()
        for _, game in pairs(Saved().games) do
            if online[game.opp] then CatchUp(game.opp) end
        end
    end)
end

function Chess:OnDisable()
    for kind in pairs(handlers) do Comms.On(kind, nil) end
end
