-- The dashboard's first page, Home: who you are and how far through the
-- level, what's new in this version in a strip under that, what's ready for
-- you right now (a trainer visit, a talent point), where each of your plans
-- stands as a picture, the guild, today's games and the Journal.
-- ns.Today works out what's waiting; the side menu's badges ask it too.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

-- What's new in this version, two or three things, written with each
-- release: a few words on it, what a click on it does, and where that goes
-- (a page's key, or "welcome"). They show once per version, until put away.
local NEWS = {
    { "Cheaper roads", "Open Professions", "professions" },
    { "Tooltips say how much better", "Open Gear plan", "gear" },
    { "Craft from the road's card", "Open Professions", "professions" },
}

local function NewsWanted()
    return #NEWS > 0 and ns.db.newsSeen ~= ns.version
end

local OWN = "Interface\\AddOns\\jsalUI\\Media\\Icons\\"

---------------------------------------------------------------------------
-- What's waiting. Each answer is nil when its part is off or has nothing.
---------------------------------------------------------------------------
local Today = {}
ns.Today = Today

local function Plural(n, word)
    return ("%d %s%s"):format(n, word, n == 1 and "" or "s")
end

-- The next trainer visit, counted as the Training Planner counts it: the
-- spells you can learn at your level and haven't skipped, a hunter's pet
-- abilities ready to teach, and the gold the trainer will ask for.
function Today.Training()
    local data = ns.Training and ns.Training.Read()
    if not data then return nil end
    local level = UnitLevel("player") or 1
    local count, cost = 0, 0
    for _, spell in ipairs(data.spells) do
        if not spell.known and not spell.skipped and spell.level <= level then
            count = count + 1
            if spell.cost and spell.via ~= "quest" and spell.via ~= "book" then cost = cost + spell.cost end
        end
    end
    local pet = ns.Training.Pet()
    for _, row in ipairs(pet and pet.rows or {}) do
        if row.state == "ready" and not row.skipped then count = count + 1 end
    end
    if count == 0 then return nil end
    return count, cost
end

-- Talent points to spend, and the plan's next talent when it has one.
function Today.Talents()
    local points = Compat.UnspentTalentPoints() or 0
    if points <= 0 then return nil end
    local Tree = ns.TalentTree
    local data = Tree and Tree.Read()
    if not data then return points end
    local order = Tree.Replay(data, Tree.Active().order or {})
    local id, rank = Tree.Next(data, order)
    return points, id and data.nodes[id], rank
end

-- Your build: its name, the points taken of the points planned, and the
-- next talent with the level it comes at.
function Today.Build()
    local Tree = ns.TalentTree
    local data = Tree and Tree.Read()
    if not data then return nil end
    local build = Tree.Active()
    local order = Tree.Replay(data, build.order or {})
    local id, rank, index = Tree.Next(data, order)
    return {
        name = build.name, planned = #order, taken = (index or (#order + 1)) - 1,
        next = id and data.nodes[id], rank = rank, level = index and Tree.Level(index),
    }
end

-- A chess game waiting on you: a challenge to answer, or your move.
function Today.Chess()
    local chess = ns.Chess
    if not (chess and chess.running) then return nil end
    for _, game in ipairs(chess.Games()) do
        if game.status == "asked" then return game.opp .. " wants a game of chess" end
        if chess.MyTurn(game) then return "Your move against " .. game.opp end
    end
end

-- Today's daily games not played yet.
function Today.Games()
    local list = {}
    for _, entry in ipairs({
        { game = ns.DailyWord, label = "Daily Word", icon = "word" },
        { game = ns.IconGuess, label = "Icon Guess", icon = "icons" },
        { game = ns.PalRun, label = "Pal run", icon = "run" },
    }) do
        if entry.game and entry.game.running and not entry.game.DailyDone() then list[#list + 1] = entry end
    end
    return list
end

-- Gear slots with nothing in them, and how many items you've starred.
function Today.Gear()
    local G = ns.Gear
    if not (G and G.running) then return nil end
    local empty, starred = 0, 0
    for _, slot in ipairs(G.SLOTS) do
        for _, id in ipairs(slot.equip) do
            if not GetInventoryItemLink("player", id) then empty = empty + 1 end
        end
    end
    for _ in pairs(G.Starred()) do starred = starred + 1 end
    return empty, starred
end

-- The dungeons right for your level (from the level each is tuned to, up to
-- five above), the one nearest your level first; and the next one coming.
function Today.Dungeons()
    if not (ns.Dungeons and ns.Dungeons.running) then return nil end
    local level = UnitLevel("player") or 1
    local faction = UnitFactionGroup("player")
    local fits, coming = {}, nil
    for _, d in ipairs(ns.DungeonData or {}) do
        if not d.raid and (not d.faction or d.faction == faction) then
            if level >= d.level and level <= d.level + 5 then
                fits[#fits + 1] = d
            elseif d.level > level and (not coming or d.level < coming.level) then
                coming = d
            end
        end
    end
    table.sort(fits, function(a, b) return a.level > b.level end)
    return fits, coming
end

---------------------------------------------------------------------------
-- What the next level brings. A part of its own, so it has a switch.
---------------------------------------------------------------------------
local NextLevel = ns.NewModule("nextlevel", {
    title = "Next level on Today",
    note = "Beside Today's title: the talent and trainer visit your next level brings, and whether your gold covers it.",
})
ns.NextLevel = NextLevel

-- Nothing to set up: the page asks Today.NextLevel() each time it opens.
function NextLevel:OnEnable() end

local LAST_LEVEL = 60

-- Spells at an odd level are trained on the next even one, as the Training
-- Planner counts its stops.
local function Stop(level)
    if level <= 1 then return 1 end
    return level + level % 2
end

-- What the next level brings: the talent your plan takes with its point, the
-- trainer visit (or the next one after it, when that level has nothing to
-- buy), a dungeon that becomes right for you, a profession rank you can
-- train, and the gold you have. Nil at the last level, with the part off, or
-- when there's nothing to say.
function Today.NextLevel()
    if not NextLevel.running then return nil end
    local level = UnitLevel("player") or 1
    if level >= LAST_LEVEL then return nil end
    local info = { level = level + 1, money = GetMoney() }

    -- The plan's talent for that level's point: the one after the points
    -- you already have to spend.
    local Tree = ns.TalentTree
    local data = Tree and Tree.Read()
    if data and info.level >= Tree.FIRST_LEVEL then
        local waiting, seen = Compat.UnspentTalentPoints() or 0, {}
        for _, id in ipairs(Tree.Replay(data, Tree.Active().order or {})) do
            seen[id] = (seen[id] or 0) + 1
            local node = data.nodes[id]
            if node and node.learned < seen[id] then
                if waiting == 0 then
                    info.talent, info.rank = node, seen[id]
                    break
                end
                waiting = waiting - 1
            end
        end
    end

    -- Trainer visits ahead of you, by the level you'd make each. A spell no
    -- trainer has shown yet has no price, so the total is "from" that much.
    local training = ns.Training and ns.Training.Read()
    if training then
        local visits = {}
        for _, spell in ipairs(training.spells) do
            if not spell.known and not spell.skipped and spell.level > level then
                local stop = Stop(spell.level)
                local visit = visits[stop] or { level = stop, count = 0, cost = 0, unpriced = 0 }
                visits[stop] = visit
                visit.count = visit.count + 1
                if spell.via ~= "quest" and spell.via ~= "book" then
                    if spell.cost then visit.cost = visit.cost + spell.cost else visit.unpriced = visit.unpriced + 1 end
                end
            end
        end
        info.visit = visits[info.level]
        if not info.visit then
            for stop, visit in pairs(visits) do
                if not info.later or stop < info.later.level then info.later = visit end
            end
        end
    end

    local _, coming = Today.Dungeons()
    if coming and coming.level == info.level then info.dungeon = coming.name end

    local P = ns.Professions
    for _, mine in ipairs(P and P.Mine() or {}) do
        local rank = P.Rank(mine.cap)
        if rank.next and rank.level == info.level and mine.skill >= P.At(mine.line, rank) then
            info.profession = ("%s %s to train"):format(rank.next, mine.name)
            break
        end
    end

    if not (info.talent or info.visit or info.later or info.dungeon or info.profession) then return nil end
    return info
end

local function VisitText(visit)
    local text = Plural(visit.count, "spell")
    if visit.cost > 0 then
        text = text .. (visit.unpriced > 0 and " from " or " for ") .. Compat.Money(visit.cost)
    end
    return text
end

-- What the next level brings, a row for each thing: its picture, what it
-- is, and a word more at the right (what the visit costs and whether you
-- have it, say). It was three right-aligned lines of text.
function Today.NextLevelRows(info)
    local rows = {}
    if info.talent then
        rows[#rows + 1] = { icon = info.talent.icon, detail = "next talent",
            label = info.rank > 1 and ("%s, rank %d"):format(info.talent.name, info.rank) or info.talent.name }
    end
    if info.visit then
        local detail = VisitText(info.visit)
        if info.visit.cost > 0 then
            local short = info.visit.cost - info.money
            detail = detail .. " · " .. (short > 0 and (Style.Tint("red") .. Compat.Money(short) .. " short|r")
                or (Style.Tint("green") .. "you have enough|r"))
        end
        rows[#rows + 1] = { icon = OWN .. "training", label = ("Trainer visit at %d"):format(info.level), detail = detail }
    elseif info.later then
        rows[#rows + 1] = { icon = OWN .. "training", label = ("Trainer visit at %d"):format(info.later.level), detail = VisitText(info.later) }
    end
    if info.dungeon then
        rows[#rows + 1] = { icon = OWN .. "dungeons", label = info.dungeon .. " opens", detail = "a dungeon for your level" }
    end
    if info.profession then
        rows[#rows + 1] = { icon = OWN .. "professions", label = info.profession, detail = "at a trainer" }
    end
    return rows
end

-- A number with its thousands apart: 47,000.
local function Thousands(n)
    local text = tostring(math.floor(n or 0)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (text:gsub("^,", ""))
end

-- Today's date, as "Friday 13 November".
local function DateText()
    if not date then return "" end
    return ("%s %d %s"):format(date("%A"), tonumber(date("%d")) or 0, date("%B"))
end

-- Your companion, when it wants something from you: what to say, and its
-- picture. Nil when it's fine, asleep, or the part is off.
function Today.Pet()
    return ns.Pet and ns.Pet.Wants() or nil
end

-- The number beside a menu entry: things to do there now.
function Today.Badge(key)
    local n
    if key == "pet" then
        n = Today.Pet() and 1 or nil
    elseif key == "training" then
        n = Today.Training()
    elseif key == "build" then
        n = Today.Talents()
    elseif key == "games" then
        n = #Today.Games()
    elseif key == "chess" then
        n = Today.Chess() and 1 or nil
    elseif key == "guildcrafts" then
        -- Orders you accepted, and ones you could accept that you haven't looked at yet.
        n = ns.Orders and ns.Orders.Badge(true) or nil
    end
    return n and n > 0 and n or nil
end

---------------------------------------------------------------------------
-- What the cards show. Each answer is nil when its part is off.
---------------------------------------------------------------------------
-- The plan's next talents, `most` of them at most: each with the rank it
-- becomes and the level its point comes at.
function Today.Queue(most)
    local Tree = ns.TalentTree
    local data = Tree and Tree.Read()
    if not data then return {} end
    local order = Tree.Replay(data, Tree.Active().order or {})
    local _, _, index = Tree.Next(data, order)
    local out, seen = {}, {}
    if not index then return out end
    for i, id in ipairs(order) do
        seen[id] = (seen[id] or 0) + 1
        local node = data.nodes[id]
        if i >= index and #out < most and node then
            out[#out + 1] = { node = node, rank = seen[id], level = Tree.Level(i) }
        end
    end
    return out
end

-- What you wear, slot by slot in the Gear plan's order: its picture and
-- quality, or that it's empty, and whether something you've starred goes there.
function Today.Slots()
    local G = ns.Gear
    if not (G and G.running) then return nil end
    local wanted = {}
    for _, star in pairs(G.Starred()) do
        if type(star) == "table" and star.t then wanted[star.t] = true end
    end
    local out = {}
    for _, slot in ipairs(G.SLOTS) do
        local starred = false
        for _, kind in ipairs(slot.types or {}) do starred = starred or wanted[kind] == true end
        for _, id in ipairs(slot.equip) do
            local worn = GetInventoryItemLink("player", id) ~= nil
            out[#out + 1] = {
                empty = not worn, starred = starred,
                texture = worn and GetInventoryItemTexture and GetInventoryItemTexture("player", id) or nil,
                quality = worn and GetInventoryItemQuality and GetInventoryItemQuality("player", id) or nil,
            }
        end
    end
    return out
end

-- Guildmates online now, yourself aside, each with their class. Nil outside
-- a guild.
function Today.Guildmates()
    if not (IsInGuild and IsInGuild()) then return nil end
    local me, out = UnitName("player"), {}
    for i = 1, (GetNumGuildMembers and GetNumGuildMembers() or 0) do
        local full, _, _, _, _, _, _, _, online, _, class = GetGuildRosterInfo(i)
        local name = full and Ambiguate(full, "none")
        if name and online and name ~= me then out[#out + 1] = { name = name, class = class } end
    end
    return out
end

-- The guild's orders that touch you, counted by where they stand: waiting on
-- you, waiting for a crafter, being made. Nil with none, or the part off.
function Today.Orders()
    local O = ns.Orders
    if not (O and O.running) then return nil end
    local mine, forMe = O.Mine(), O.ForMe()
    local out = { you = #forMe.todo + #mine.sent, waiting = #mine.waiting + #forMe.waiting, making = #mine.making }
    if out.you + out.waiting + out.making == 0 then return nil end
    return out
end

-- Today's daily games that are switched on, each with where it stands in a
-- word or two and the colour for it: gold to play, green done, red missed.
function Today.GameTiles()
    local out = {}
    local word = ns.DailyWord
    if word and word.running then
        local day, score
        if word.Result then day, score = word.Result() end
        out[#out + 1] = { icon = "word", label = "Daily Word", game = word,
            state = not day and "Play" or (score == "X" and "missed" or ("solved in " .. tostring(score))),
            tone = not day and "gold" or (score == "X" and "red" or "green") }
    end
    local icons = ns.IconGuess
    if icons and icons.running then
        local day, score
        if icons.Result then day, score = icons.Result() end
        out[#out + 1] = { icon = "icons", label = "Icon Guess", game = icons,
            state = day and (tostring(score) .. " right") or "Play", tone = day and "green" or "gold" }
    end
    local run = ns.PalRun
    if run and run.running then
        local day, best
        if run.Result then day, best = run.Result() end
        local clock = day and ns.PalRunRules and ns.PalRunRules.Clock and ns.PalRunRules.Clock(best)
        local used = not day and run.DailyDone()
        out[#out + 1] = { icon = "run", label = "Pal run", game = run,
            state = clock or (day and "done") or (used and "no time") or "Play",
            tone = day and "green" or (used and "muted" or "gold") }
    end
    return out
end

-- The time each of your last `most` levels took, oldest first, as the Journal
-- kept it, and whether you died on it. Nil with the Journal off.
function Today.Levels(most)
    local J = ns.Journal
    if not (J and J.running and J.Book) then return nil end
    local levels = J.Book().levels
    if type(levels) ~= "table" then return nil end
    local level, out = UnitLevel("player") or 1, {}
    for l = math.max(1, level - most + 1), level do
        local row = levels[l]
        out[#out + 1] = { level = l, seconds = row and row.seconds or 0, deaths = row and row.deaths or 0 }
    end
    return out
end

-- Your pace, in XP a second, as the Journal's Summary works it out: over the
-- level you're on and the two before it, once that's ten minutes of play.
function Today.Pace()
    local J = ns.Journal
    if not (J and J.running and J.Book) then return nil end
    local levels, level = J.Book().levels, UnitLevel("player") or 1
    if type(levels) ~= "table" then return nil end
    local xp, seconds = 0, 0
    for l = level, level - 2, -1 do
        local row = levels[l]
        if row then xp, seconds = xp + (row.xp or 0), seconds + (row.seconds or 0) end
    end
    return seconds >= 600 and xp > 0 and xp / seconds or nil
end

-- The Ready now cards, most pressing first. Each: its icon, a title, a line
-- under it (with the talent it's about, when it is), an amount, and what a
-- click does in a word or two. The daily games have a card of their own.
local function Ready()
    local rows = {}
    local function Add(row) rows[#rows + 1] = row end
    local function Try(fn) xpcall(fn, ns.Report) end

    Try(function()
        local points, node, rank = Today.Talents()
        if not points then return end
        Add({
            icon = "build", title = Plural(points, "talent point"),
            sub = node and node.name or "Your plan has no next talent yet", node = node, rank = rank,
            tip = node and ("Next in your plan: %s, rank %d of %d"):format(node.name, rank, node.max) or nil,
            button = "Open plan", click = function() Window.Open("build") end,
        })
    end)

    Try(function()
        local count, cost = Today.Training()
        if not count then return end
        local _, _, classID = UnitClass("player")
        local nearest = classID and ns.Trainers and ns.Trainers.Nearest("class" .. classID)
        local place = nearest and ns.Trainers.Zone(nearest)
        Add({
            icon = "training", title = "Trainer visit",
            sub = Plural(count, "spell") .. " · " .. (nearest and (nearest.name .. (place and (", " .. place) or "")) or "no trainer found nearby"),
            value = cost > 0 and Compat.Money(cost) or nil,
            button = nearest and "Show on map" or "Open planner", primary = true,
            click = function()
                if nearest then ns.Trainers.Pin(nearest) else Window.Open("training") end
            end,
        })
    end)

    Try(function()
        local waiting = Today.Chess()
        if not waiting then return end
        Add({ icon = "chess", title = waiting, sub = "Guild chess",
            button = "Open chess", click = function() Window.Open("chess") end })
    end)

    Try(function()
        local state = ns.Installer.State()
        if state ~= "ready" and state ~= "update" then return end
        Add({
            icon = "install",
            title = state == "update" and "A newer look is ready" or "The look is ready to install",
            sub = "One click and a reload",
            button = "Open Install", click = function() Window.Open("install") end,
        })
    end)
    return rows
end

---------------------------------------------------------------------------
-- The page's building blocks.
---------------------------------------------------------------------------
local GAP, PAD = 16, 16
local HERO_H, READY_H, IDLE_H, PLAN_H, LOW_H = 148, 100, 44, 208, 140
local WHO_W, PAL_W = 252, 242
local MEDIA = "Interface\\AddOns\\jsalUI\\Media\\"
local UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark"

local function Caps(parent, text, colorKey)
    local t = Style.Text(parent, 11, colorKey or "gold", nil, true)
    t:SetText(text)
    return t
end

-- A thin bar: how far along something is.
local function Meter(parent)
    local track = CreateFrame("Frame", nil, parent)
    track:SetHeight(6)
    Style.Fill(track, "window")
    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT")
    fill:SetPoint("BOTTOMLEFT")
    fill:SetColorTexture(Style.Color("gold"))
    function track:Set(part, width)
        fill:SetWidth(math.max(1, width * math.max(0, math.min(1, part))))
    end
    return track
end

-- One of the game's own icons in a thin line, its baked-in border trimmed. The line is a square
-- behind the icon (Style.Lined), one picture where it was four: the icon covers the rest, and
-- with `fillKey` (a gear slot, which can be empty) the inside is filled for when it doesn't.
local function GameIcon(parent, size, fillKey)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.edges = Style.Lined(f, "lineStrong", fillKey)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 1, -1)
    f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    function f:Set(texture) self.icon:SetTexture(texture or UNKNOWN) end
    return f
end

-- The small square before a count, in the shape its state has everywhere:
-- full for what waits on you, an outline for what waits on someone else, half
-- for what's under way.
local function Sign(parent, colorKey, shape)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(8, 8)
    if shape ~= "full" then Style.Border(f, colorKey) end
    if shape ~= "outline" then
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(Style.Color(colorKey))
        t:SetPoint("TOPLEFT")
        t:SetPoint("BOTTOMLEFT")
        t:SetWidth(shape == "half" and 4 or 8)
    end
    return f
end

-- Six hex digits as the three parts of a colour.
local function Parts(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

-- The code that starts words in a class's colour.
local function ClassTint(classFile)
    local c = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
    if not c then return Style.Tint("text") end
    local function Part(v) return math.floor((v or 1) * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(Part(c.r), Part(c.g), Part(c.b))
end

-- Seconds as "46m" or "1h 52m".
local function Took(seconds)
    local minutes = math.floor((seconds or 0) / 60 + 0.5)
    if minutes < 60 then return minutes .. "m" end
    return ("%dh %dm"):format(math.floor(minutes / 60), minutes % 60)
end

-- A card that opens a page: the page's tile and name at its top, a word at
-- the right of them, and a line for when it has nothing to show.
local function PageCard(parent, key, label, icon, width, height)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(width, height)
    c.edges = { Style.Box(c, 6, "well", "cardLine").line }
    local tile = c:CreateTexture(nil, "ARTWORK")
    tile:SetTexture(OWN .. icon)
    tile:SetSize(22, 22)
    tile:SetPoint("TOPLEFT", PAD, -14)
    c.label = Caps(c, label, "muted")
    c.label:SetPoint("LEFT", tile, "RIGHT", 8, 0)
    c.note = Style.Text(c, 12, "muted")
    c.note:SetPoint("TOPRIGHT", -PAD, -17)
    c.note:SetJustifyH("RIGHT")
    c.empty = Style.Text(c, 12, "muted")
    c.empty:SetPoint("TOPLEFT", PAD, -52)
    c.empty:SetWidth(width - PAD * 2)
    c:SetScript("OnClick", function() Window.Open(key) end)
    c:SetScript("OnEnter", function(self) Style.SetBorder(self.edges, "gold") end)
    c:SetScript("OnLeave", function(self) Style.SetBorder(self.edges, "cardLine") end)
    Style.Hover(c, 0, 6)
    return c
end

---------------------------------------------------------------------------
-- The top card: who you are, this level and what the next one brings, and
-- your pal in its pen. Returns the function that paints it.
---------------------------------------------------------------------------
local function Hero(page, width)
    local hero = CreateFrame("Frame", nil, page)
    hero:SetSize(width, HERO_H)
    hero:SetPoint("TOPLEFT")
    Style.Box(hero, 6, "well", "cardLine")

    -- Who you are: your portrait in a line of your class's colour, your
    -- name, level and class, your gold, and the day.
    local face = CreateFrame("Frame", nil, hero)
    face:SetSize(66, 66)
    face:SetPoint("TOPLEFT", 20, -20)
    face.edges = Style.Lined(face, "lineStrong", "titleBar")
    face.picture = face:CreateTexture(nil, "ARTWORK")
    face.picture:SetPoint("TOPLEFT", 1, -1)
    face.picture:SetPoint("BOTTOMRIGHT", -1, 1)
    local name = Style.Text(hero, 23, "text", nil, true)
    name:SetPoint("TOPLEFT", face, "TOPRIGHT", 14, 3)
    name:SetWidth(WHO_W - 20 - 66 - 14 - 6)
    name:SetWordWrap(false)
    local who = Style.Text(hero, 13, "secondary")
    who:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    local money = Style.Text(hero, 13, "text", nil, true)
    money:SetPoint("TOPLEFT", who, "BOTTOMLEFT", 0, -7)
    local day = Style.Text(hero, 12, "muted")
    day:SetPoint("BOTTOMLEFT", 20, 16)

    -- Your pal, in the pen of the land you're in: what it wants, or its name
    -- when it's content. A click opens its pen.
    local pal = CreateFrame("Button", nil, hero)
    pal:SetPoint("TOPRIGHT")
    pal:SetPoint("BOTTOMRIGHT")
    pal:SetWidth(PAL_W)
    Style.Rule(pal, "LEFT", "line")
    pal.scene = pal:CreateTexture(nil, "ARTWORK")
    pal.scene:SetSize(220, 100)
    pal.scene:SetPoint("TOPLEFT", 11, -10)
    -- A scene's picture is 256 by 128 with the scene in its top left 220 by 100.
    pal.scene:SetTexCoord(0, 220 / 256, 0, 100 / 128)
    pal.picture = pal:CreateTexture(nil, "OVERLAY")
    pal.picture:SetPoint("BOTTOM", pal.scene, "BOTTOM", 0, 6)
    pal.title = Style.Text(pal, 13, "gold", nil, true)
    pal.title:SetPoint("BOTTOMLEFT", 11, 11)
    pal.title:SetWordWrap(false)
    pal.sub = Style.Text(pal, 12, "muted")
    pal.sub:SetPoint("BOTTOMRIGHT", -11, 11)
    pal.sub:SetJustifyH("RIGHT")
    pal.sub:SetWordWrap(false)
    pal:SetScript("OnClick", function() Window.Open("pet") end)
    Style.Hover(pal)
    -- Both lines whole, for when the second has no room beside the first.
    pal:HookScript("OnEnter", function(self)
        if not self.said then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(self.said)
        if self.more and self.more ~= "" then GameTooltip:AddLine(self.more, 0.6, 0.59, 0.53, true) end
        GameTooltip:Show()
    end)
    pal:HookScript("OnLeave", function() GameTooltip:Hide() end)

    -- This level: how far through it you are, the rested part in blue, and
    -- how long the rest takes at your pace.
    local level = CreateFrame("Frame", nil, hero)
    level:SetPoint("TOPLEFT", WHO_W, 0)
    level:SetPoint("BOTTOMLEFT", WHO_W, 0)
    Style.Rule(level, "LEFT", "line")
    local now = CreateFrame("Frame", nil, level)
    now:SetHeight(62)
    now.head = Caps(now, "")
    now.head:SetPoint("TOPLEFT")
    now.pace = Style.Text(now, 12, "muted")
    now.pace:SetPoint("TOPRIGHT")
    now.pace:SetJustifyH("RIGHT")
    now.track = CreateFrame("Frame", nil, now)
    now.track:SetHeight(12)
    now.track:SetPoint("TOPLEFT", 0, -26)
    now.track:SetPoint("TOPRIGHT", 0, -26)
    Style.Fill(now.track, "line")
    now.fill = now.track:CreateTexture(nil, "ARTWORK")
    now.fill:SetPoint("TOPLEFT")
    now.fill:SetPoint("BOTTOMLEFT")
    now.fill:SetColorTexture(Style.Color("gold"))
    now.rest = now.track:CreateTexture(nil, "ARTWORK")
    now.rest:SetPoint("TOPLEFT", now.fill, "TOPRIGHT")
    now.rest:SetPoint("BOTTOMLEFT", now.fill, "BOTTOMRIGHT")
    now.rest:SetColorTexture(Style.Color("blue"))
    now.xp = Style.Text(now, 12, "text")
    now.xp:SetPoint("TOPLEFT", 0, -45)
    now.rested = Style.Text(now, 12, "muted")
    now.rested:SetPoint("TOPRIGHT", 0, -45)
    now.rested:SetText("rested")
    now.restSign = Sign(now, "blue", "full")
    now.restSign:SetPoint("RIGHT", now.rested, "LEFT", -6, 0)

    -- What the next level brings, under a rule: the talent your plan takes
    -- and its ranks, then the trainer visit and whether your gold covers it.
    -- The whole of it is in its tooltip.
    local soon = CreateFrame("Frame", nil, level)
    soon:SetHeight(42)
    soon:SetPoint("BOTTOMLEFT", 24, 0)
    Style.Rule(soon, "TOP", "line")
    soon.head = Caps(soon, "", "muted")
    soon.head:SetPoint("LEFT", 0, -1)
    soon.icon = GameIcon(soon, 24)
    soon.icon:SetPoint("LEFT", soon.head, "RIGHT", 12, 0)
    soon.name = Style.Text(soon, 13, "text")
    soon.name:SetPoint("LEFT", soon.icon, "RIGHT", 8, 0)
    soon.name:SetWordWrap(false)
    soon.pips = Style.Pips(soon)
    soon.pips:SetPoint("LEFT", soon.name, "RIGHT", 8, 0)
    soon.enough = Style.Text(soon, 12, "green", nil, true)
    soon.enough:SetPoint("RIGHT", 0, -1)
    soon.cost = Style.Text(soon, 13, "text", nil, true)
    soon.cost:SetPoint("RIGHT", soon.enough, "LEFT", -8, 0)
    soon.spells = Style.Text(soon, 13, "text")
    soon.spells:SetPoint("RIGHT", soon.cost, "LEFT", -8, 0)
    soon.tile = soon:CreateTexture(nil, "ARTWORK")
    soon.tile:SetTexture(OWN .. "training")
    soon.tile:SetSize(24, 24)
    soon.tile:SetPoint("RIGHT", soon.spells, "LEFT", -8, 0)
    soon:EnableMouse(true)
    soon:SetScript("OnEnter", function(self)
        if not self.rows then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(self.title or "")
        for _, row in ipairs(self.rows) do
            GameTooltip:AddLine(row.label .. (row.detail and row.detail ~= "" and ("  |cff9a9688" .. row.detail .. "|r") or ""), 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    soon:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- At the last level, with the gear goal on: where your pre-raid set stands in the level bar's
    -- place (how many slots, a pip a slot, which set), and in the next level's, what to run next
    -- for what's left. Made the first time it shows, so a character below the cap never has it.
    local goal
    local function OpenGoal()
        if ns.Gear then ns.Gear.openAt60 = true end
        Window.Open("gear")
    end
    local function GoalParts()
        if goal then return goal end
        goal = CreateFrame("Frame", nil, level)
        goal:SetPoint("TOPLEFT", 24, -17)
        goal:SetHeight(72)
        goal.count = Style.Text(goal, 26, "gold", nil, true)
        goal.count:SetPoint("TOPLEFT")
        goal.label = Style.Text(goal, 15, "secondary")
        goal.tick = goal:CreateTexture(nil, "ARTWORK")
        goal.tick:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        goal.tick:SetSize(16, 16)
        goal.tick:SetPoint("LEFT", goal.label, "RIGHT", 8, 0)
        -- Quiet gold words to the At 60 view, lit under the pointer.
        goal.open = CreateFrame("Button", nil, goal)
        goal.open.text = Style.Text(goal.open, 13, "gold", nil, true)
        goal.open.text:SetPoint("RIGHT")
        goal.open.text:SetText("Open Gear plan")
        goal.open:SetSize(Style.Wide(goal.open.text, 100), 20)
        goal.open:SetPoint("TOPRIGHT", 0, -4)
        goal.open:SetScript("OnEnter", function(self) self.text:SetTextColor(Style.Color("text")) end)
        goal.open:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color("gold")) end)
        goal.open:SetScript("OnClick", OpenGoal)
        goal.pips = {}
        for i = 1, 17 do
            local t = goal:CreateTexture(nil, "ARTWORK")
            t:SetSize(12, 12)
            t:SetPoint("TOPLEFT", (i - 1) * 16, -37)
            goal.pips[i] = t
        end
        goal.set = Style.Text(goal, 12, "muted")
        goal.set:SetPoint("TOPLEFT", 0, -57)
        goal.set:SetWordWrap(false)
        -- What to run next, in the next level's place; a click goes to the At 60 view, and the
        -- whole of it is in its tooltip.
        local nextRow = CreateFrame("Frame", nil, level)
        nextRow:SetHeight(42)
        nextRow:SetPoint("BOTTOMLEFT", 24, 0)
        Style.Rule(nextRow, "TOP", "line")
        nextRow.head = Caps(nextRow, "NEXT", "muted")
        nextRow.head:SetPoint("LEFT", 0, -1)
        nextRow.icons = {}
        for i = 1, 3 do
            local icon = GameIcon(nextRow, 24, "window")
            icon:SetPoint("LEFT", nextRow.head, "RIGHT", 14 + (i - 1) * 28, 0)
            icon:EnableMouse(true)
            icon:SetScript("OnEnter", function(self)
                if not self.item then return end
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:SetItemByID(self.item)
                GameTooltip:Show()
            end)
            icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
            icon:SetScript("OnMouseUp", OpenGoal)
            nextRow.icons[i] = icon
        end
        nextRow.line = Style.Text(nextRow, 13, "text")
        nextRow.line:SetWordWrap(false)
        nextRow:EnableMouse(true)
        nextRow:SetScript("OnEnter", function(self)
            if not self.title then return end
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(self.title)
            for _, line in ipairs(self.lines or {}) do GameTooltip:AddLine(line, 1, 1, 1) end
            GameTooltip:Show()
        end)
        nextRow:SetScript("OnLeave", function() GameTooltip:Hide() end)
        nextRow:SetScript("OnMouseUp", OpenGoal)
        goal.next = nextRow
        return goal
    end

    -- The next row's words: the first that fits whole of `list`, the first part in text colour
    -- and the rest muted.
    local function Fits(text, list, room)
        for _, words in ipairs(list) do
            text:SetText(words[1] .. (words[2] ~= "" and ("|cff9a9688" .. words[2] .. "|r") or ""))
            if Style.Wide(text, #(words[1] .. words[2]) * 6.5) <= room then return end
        end
    end

    -- At the last level: paints the set's place and returns true, or false where there's no set to
    -- show (the gear goal off, a tree WoWSims has no set for), for the level's card as before.
    local function PaintGoal(room)
        local Goal = ns.GearGoal
        local ok, s = pcall(function() return Goal and Goal.running and Goal.Summary and Goal.Summary() end)
        if not ok then ns.Report(s) end
        if not (ok and s) then
            if goal then goal:Hide() goal.next:Hide() end
            return false
        end
        GoalParts()
        goal:Show()
        goal.next:Show()
        goal:SetWidth(room)
        goal.next:SetWidth(room)
        local done = s.of > 0 and s.at >= s.of
        goal.label:ClearAllPoints()
        if s.empty then
            goal.count:SetText("")
            goal.label:SetPoint("TOPLEFT", 0, -4)
            goal.label:SetText("Your set has no pieces yet")
        else
            goal.count:SetText(s.at)
            goal.label:SetPoint("BOTTOMLEFT", goal.count, "BOTTOMRIGHT", 8, 3)
            goal.label:SetText(("of %d slot%s at your pre-BiS"):format(s.of, s.of == 1 and "" or "s"))
        end
        goal.tick:SetShown(done)
        for i, t in ipairs(goal.pips) do
            t:SetShown(i <= s.of)
            t:SetColorTexture(Style.Color(i <= s.at and "gold" or "lineStrong"))
        end
        goal.set:SetWidth(room)
        goal.set:SetText((s.own and s.name or ("WoWSims' " .. (s.name or "") .. " set")) .. ", before raids")
        -- What's next.
        local nextRow = goal.next
        local run, piece = s.runs and s.runs[1], s.other and s.other[1]
        local ids = {}
        if not (s.empty or done) then
            if run then
                for i, p in ipairs(run.pieces) do if i <= 3 then ids[i] = p.row.goal.id end end
            elseif piece then
                ids[1] = piece.goal.id
            end
        end
        for i, icon in ipairs(nextRow.icons) do
            local id = ids[i]
            icon:SetShown(id ~= nil)
            icon.item = id
            if id then
                icon:Set(Compat.ItemIcon(id))
                local e = ns.Gear and ns.Gear.Lookup and ns.Gear.Lookup(id)
                local hex = Style.Quality(e and e.quality or 1)
                icon.edges[1]:SetColorTexture(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255)
            end
        end
        nextRow.line:ClearAllPoints()
        if #ids > 0 then
            nextRow.line:SetPoint("LEFT", nextRow.icons[#ids], "RIGHT", 10, 0)
        else
            nextRow.line:SetPoint("LEFT", nextRow.head, "RIGHT", 14, 0)
        end
        local lineRoom = room - Style.Wide(nextRow.head, 30) - 14 - (#ids > 0 and (#ids * 28 + 6) or 0)
        nextRow.line:SetWidth(0)
        nextRow.title, nextRow.lines = nil, nil
        if s.empty then
            Fits(nextRow.line, { { "", "Choose its pieces in the Gear plan" } }, lineRoom)
        elseif done then
            Fits(nextRow.line, { { "Your set is done", " \194\183 Raids opens once there's raid loot" }, { "Your set is done", "" } }, lineRoom)
        elseif run then
            local n = #run.pieces
            local pieces = (" \194\183 %d piece%s"):format(n, n == 1 and "" or "s")
            local share = run.any and (" \194\183 one in %d%% of runs"):format(math.max(1, math.floor(run.any * 100 + 0.5))) or ""
            Fits(nextRow.line, { { run.name, pieces .. share }, { run.name, pieces }, { run.name, "" } }, lineRoom)
            nextRow.title = run.name .. pieces .. share
            nextRow.lines = {}
            for _, p in ipairs(run.pieces) do
                nextRow.lines[#nextRow.lines + 1] = p.row.label .. (p.boss and (" \194\183 " .. p.boss) or "")
                    .. (p.chance and (" \194\183 %d%%"):format(math.floor(p.chance + 0.5)) or "")
            end
        elseif piece then
            local from = ns.GearGoal.From(piece.goal.e)
            Fits(nextRow.line, { { piece.label, " \194\183 " .. (from.text or "") }, { piece.label, "" } }, lineRoom)
        else
            Fits(nextRow.line, { { "", ("%d piece%s with no known source yet"):format(s.unknown or 0, (s.unknown or 0) == 1 and "" or "s") } }, lineRoom)
        end
        return true
    end

    local function PaintWho()
        local _, classFile = UnitClass("player")
        local colour = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
        if colour then
            for _, edge in ipairs(face.edges) do edge:SetColorTexture(colour.r, colour.g, colour.b) end
        end
        if SetPortraitTexture then SetPortraitTexture(face.picture, "player") end
        name:SetText(UnitName("player") or "")
        who:SetText(("Level %d %s"):format(UnitLevel("player") or 0, UnitClass("player") or ""))
        money:SetText(Compat.Money(GetMoney and GetMoney() or 0))
        day:SetText(DateText())
    end

    -- Returns whether the pal's block shows.
    local function PaintPal()
        local Pet = ns.Pet
        local portrait = Pet and Pet.Portrait and Pet.Portrait() or nil
        local wants = Today.Pet()
        local shown = portrait ~= nil or wants ~= nil
        pal:SetShown(shown)
        if not shown then return false end
        local scene = Pet.Scene and Pet.Scene(Pet.where) or "meadow"
        pal.scene:SetTexture(MEDIA .. "Pet\\" .. scene .. ".png", "CLAMP", "CLAMP", "NEAREST")
        -- Its picture at its own size, so every pixel stays square; the two
        -- largest at half theirs, to stand inside the scene.
        local size = portrait and portrait.size or 64
        if size > 96 then size = size / 2 end
        pal.picture:SetSize(size, size)
        pal.picture:SetTexture(wants and wants.texture or portrait.texture, "CLAMP", "CLAMP", "NEAREST")
        local said, more = wants and wants.title or (portrait.name or "Your pal"), wants and wants.sub or (portrait.form or "")
        pal.said, pal.more = said, more
        pal.title:SetWidth(0)
        pal.title:SetText(said)
        pal.title:SetTextColor(Style.Color(wants and "gold" or "text"))
        local titleW = math.min(Style.Wide(pal.title, #said * 7), PAL_W - 22)
        pal.title:SetWidth(titleW)
        -- The second line only where it fits whole beside the first: a few
        -- letters of it say nothing. It's in the tooltip either way.
        pal.sub:SetText(more)
        pal.sub:SetShown(more ~= "" and Style.Wide(pal.sub, #more * 6) <= PAL_W - 22 - titleW - 10)
        return true
    end

    local function PaintSoon(info, room)
        soon:SetShown(info ~= nil)
        if not info then return end
        soon:SetWidth(room)
        soon.title = ("At level %d"):format(info.level)
        soon.rows = Today.NextLevelRows(info)
        soon.head:SetText(("AT %d"):format(info.level))
        local first = soon.rows[1]
        soon.icon:Set(info.talent and info.talent.icon or nil)
        soon.icon:SetShown(info.talent ~= nil)
        soon.pips:SetShown(info.talent ~= nil)
        soon.name:ClearAllPoints()
        if info.talent then
            soon.name:SetPoint("LEFT", soon.icon, "RIGHT", 8, 0)
            soon.name:SetText(info.talent.name)
            soon.pips:Set(info.rank - 1, info.talent.max or info.rank, 1)
        else
            soon.name:SetPoint("LEFT", soon.head, "RIGHT", 12, 0)
            soon.name:SetText(first and first.label or "")
        end
        -- The visit at the right, when there's a talent to its left to leave
        -- it the room; with no talent the first row's words say it already.
        local visit = info.talent and (info.visit or info.later) or nil
        for _, region in ipairs({ soon.enough, soon.cost, soon.spells, soon.tile }) do region:SetShown(visit ~= nil) end
        -- The name is shown whole, as wide as its words. Where the visit's
        -- words would leave it too little room they're cut to the level it's
        -- at, or left out: the tooltip has them all.
        soon.name:SetWidth(0)
        local need = Style.Wide(soon.name, 40)
        local before = Style.Wide(soon.head, 40) + 12 + (info.talent and (24 + 8 + 8 + soon.pips.wide + 14) or 0)
        local used = 0
        if visit then
            local cost = visit.cost > 0 and Compat.Money(visit.cost) or ""
            local short = visit.cost - info.money
            local sure = info.visit ~= nil and visit.cost > 0
            local enough = not sure and "" or (short > 0 and "short" or "enough")
            soon.cost:SetText(cost)
            soon.enough:SetText(enough)
            soon.enough:SetTextColor(Style.Color(short > 0 and "red" or "green"))
            local function Takes(words)
                soon.spells:SetText(words)
                return 24 + 8 + (words ~= "" and Style.Wide(soon.spells, #words * 7) + 8 or 0)
                    + (cost ~= "" and Style.Wide(soon.cost, 50) + 8 or 0) + (enough ~= "" and Style.Wide(soon.enough, 44) or 0)
            end
            used = Takes(Plural(visit.count, "spell") .. (info.visit and "" or (" at " .. visit.level)))
            if need > room - before - used then used = Takes(info.visit and "" or ("at " .. visit.level)) end
        end
        soon.name:SetWidth(math.max(40, math.min(need, room - before - used)))
    end

    return function()
        PaintWho()
        local hasPal = PaintPal()
        local room = width - WHO_W - (hasPal and PAL_W or 0) - 48
        level:SetWidth(room + 48)
        -- At the last level, where your set stands takes the level's place.
        local atGoal = (UnitLevel("player") or 0) >= LAST_LEVEL and PaintGoal(room)
        now:SetShown(not atGoal)
        if atGoal then
            soon:Hide()
            return
        end
        local ok, info = pcall(Today.NextLevel)
        if not ok then
            ns.Report(info)
            info = nil
        end
        PaintSoon(info, room)
        now:ClearAllPoints()
        now:SetPoint("TOPLEFT", 24, info and -19 or -43)
        now:SetWidth(room)
        local mine = UnitLevel("player") or 0
        now.head:SetText(("LEVEL %d"):format(mine))
        local xp, most = UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 0
        local known = (most or 0) > 0
        for _, region in ipairs({ now.track, now.xp, now.pace }) do region:SetShown(known) end
        local rested = known and GetXPExhaustion and GetXPExhaustion() or 0
        now.rested:SetShown(known and (rested or 0) > 0)
        now.restSign:SetShown(known and (rested or 0) > 0)
        if not known then return end
        local part = math.max(0, math.min(1, (xp or 0) / most))
        now.fill:SetWidth(math.max(1, room * part))
        now.rest:SetWidth(math.max(0.001, room * math.min(1 - part, (rested or 0) / most)))
        now.rest:SetShown((rested or 0) > 0 and part < 1)
        now.xp:SetText(("%s |cff9a9688of %s XP|r"):format(Thousands(xp), Thousands(most)))
        local rate = Today.Pace()
        now.pace:SetText(rate and ("about %s to %d at your pace"):format(Took((most - xp) / rate), mine + 1) or "")
    end
end

---------------------------------------------------------------------------
-- Ready now: a card for each thing waiting, three across (four when there
-- are four). Returns the box the cards are in, for what's under it to hang
-- from, and the function that paints it.
---------------------------------------------------------------------------
local function ReadyCards(page, width)
    local head = Caps(page, "READY NOW")
    local count = Style.Text(page, 11, "muted", nil, true)
    count:SetPoint("LEFT", head, "RIGHT", 8, 0)
    local box = CreateFrame("Frame", nil, page)
    box:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -10)
    box:SetWidth(width)
    local idle = CreateFrame("Frame", nil, box)
    idle:SetAllPoints()
    Style.Box(idle, 6, "well", "cardLine")
    local nothing = Style.Text(idle, 12, "muted")
    nothing:SetPoint("LEFT", PAD, 0)
    nothing:SetText("Nothing is waiting on you right now.")

    local cards = {}
    local function Card(i)
        if cards[i] then return cards[i] end
        local c = CreateFrame("Button", nil, box)
        c.edges = { Style.Box(c, 6, "well", "cardLine").line }
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetSize(40, 40)
        c.icon:SetPoint("TOPLEFT", 14, -14)
        c.title = Style.Text(c, 15, "text", nil, true)
        c.title:SetPoint("TOPLEFT", 66, -13)
        c.title:SetWordWrap(false)
        c.value = Style.Text(c, 15, "gold", nil, true)
        c.value:SetPoint("TOPRIGHT", -PAD, -13)
        c.value:SetJustifyH("RIGHT")
        c.talent = GameIcon(c, 18)
        c.talent:SetPoint("TOPLEFT", 66, -37)
        c.sub = Style.Text(c, 12, "muted")
        c.sub:SetWordWrap(false)
        c.pips = Style.Pips(c)
        c.pips:SetPoint("LEFT", c.sub, "RIGHT", 8, 0)
        -- What a click does: quiet words, or for the page's one main action
        -- the gold button.
        c.action = Style.Text(c, 12, "gold", nil, true)
        c.action:SetPoint("BOTTOMRIGHT", -PAD, 15)
        c.button = Style.Button(c, "", "primary", 110)
        c.button:SetHeight(26)
        c.button:SetPoint("BOTTOMRIGHT", -14, 13)
        local function Click()
            if not c.click then return end
            xpcall(c.click, ns.Report)
            Window.Refresh()
        end
        c:SetScript("OnClick", Click)
        c.button:SetScript("OnClick", Click)
        c:SetScript("OnEnter", function(self)
            Style.SetBorder(self.edges, "gold")
            if self.tip then
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        c:SetScript("OnLeave", function(self)
            Style.SetBorder(self.edges, "cardLine")
            GameTooltip:Hide()
        end)
        Style.Hover(c, 0, 6)
        cards[i] = c
        return c
    end

    local function Paint()
        local ready = Ready()
        local across = math.max(3, math.min(4, #ready))
        local cardW = math.floor((width - GAP * (across - 1)) / across)
        for i = 1, math.min(#ready, across) do
            local item, c = ready[i], Card(i)
            c:SetSize(cardW, READY_H)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", (i - 1) * (cardW + GAP), 0)
            c.click, c.tip = item.click, item.tip
            c.icon:SetTexture(OWN .. item.icon)
            c.value:SetText(item.value or "")
            c.title:SetText(item.title)
            c.title:SetWidth(cardW - 66 - PAD - (item.value and (Style.Wide(c.value, 60) + 10) or 0))
            -- The line under it starts with the talent's picture when it's about one.
            c.talent:SetShown(item.node ~= nil)
            c.pips:SetShown(item.node ~= nil)
            c.sub:ClearAllPoints()
            c.sub:SetText(item.sub or "")
            if item.node then
                c.talent:Set(item.node.icon)
                c.sub:SetPoint("LEFT", c.talent, "RIGHT", 7, 0)
                c.pips:Set(item.rank - 1, item.node.max or item.rank, 1)
                c.sub:SetWidth(math.min(Style.Wide(c.sub, 100), cardW - 66 - 25 - PAD - 60))
            else
                c.sub:SetPoint("TOPLEFT", 66, -38)
                c.sub:SetWidth(cardW - 66 - PAD)
            end
            c.action:SetShown(not item.primary)
            c.button:SetShown(item.primary == true)
            if item.primary then
                c.button:SetLabel(item.button)
                c.button:SetWidth(Style.Wide(c.button.label, 90) + 28)
            else
                c.action:SetText(item.button)
            end
            c:Show()
        end
        for i = math.min(#ready, across) + 1, #cards do cards[i]:Hide() end
        idle:SetShown(#ready == 0)
        count:SetText(#ready > 0 and tostring(#ready) or "")
        box:SetHeight(#ready == 0 and IDLE_H or READY_H)
    end
    return box, Paint, head
end

---------------------------------------------------------------------------
-- Your plans, four across. Each builder returns its card and the function
-- that paints it.
---------------------------------------------------------------------------
local function BuildCard(parent, width)
    local c = PageCard(parent, "build", "BUILD", "build", width, PLAN_H)
    local inner = width - PAD * 2
    c.title = Style.Text(c, 15, "text", nil, true)
    c.title:SetPoint("TOPLEFT", PAD, -46)
    c.title:SetWidth(inner)
    c.title:SetWordWrap(false)
    c.count = Style.Text(c, 12, "text")
    c.count:SetPoint("TOPRIGHT", -PAD, -72)
    c.count:SetJustifyH("RIGHT")
    c.meter = Meter(c)
    c.meter:SetPoint("TOPLEFT", PAD, -77)
    c.say = Style.Text(c, 12, "muted")
    c.say:SetPoint("TOPLEFT", PAD, -98)
    c.say:SetWidth(inner)
    c.nextHead = Caps(c, "NEXT", "muted")
    c.nextHead:SetPoint("TOPLEFT", PAD, -99)
    c.next = Style.Text(c, 13, "text")
    c.next:SetPoint("LEFT", c.nextHead, "RIGHT", 10, 0)
    c.next:SetWordWrap(false)
    c.pips = Style.Pips(c)
    c.pips:SetPoint("RIGHT", c, "TOPRIGHT", -PAD, -106)
    -- The plan's next talents, the level each comes at under it; the first,
    -- the one named above, in a gold line.
    c.queue = {}
    for i = 1, 5 do
        local q = GameIcon(c, 34)
        q:SetPoint("TOPLEFT", PAD + (i - 1) * 44, -126)
        q.level = Style.Text(q, 11, i == 1 and "gold" or "muted", nil, i == 1)
        q.level:SetPoint("TOP", q, "BOTTOM", 0, -3)
        q.level:SetJustifyH("CENTER")
        if i == 1 then Style.SetBorder(q.edges, "gold") end
        c.queue[i] = q
    end

    return c, function()
        local b = Today.Build()
        local queue = b and b.next and Today.Queue(5) or {}
        local planned = b ~= nil and b.planned > 0
        c.empty:SetText(b and "" or "No talent trees for this class yet.")
        -- A build with no points planned is no build yet, whatever it's called: it's said so, greyed.
        c.title:SetText(b and (planned and (b.name or "Your build") or "Build not set") or "")
        c.title:SetTextColor(Style.Color(planned and "text" or "muted"))
        c.meter:SetShown(planned)
        c.count:SetText(planned and ("%d |cff9a9688of %d|r"):format(b.taken, b.planned) or "")
        if planned then
            local meterW = inner - Style.Wide(c.count, 50) - 10
            c.meter:SetWidth(meterW)
            c.meter:Set(b.taken / b.planned, meterW)
        end
        local upcoming = planned and b.next ~= nil
        c.say:SetText(not b and "" or (not planned and "No points planned yet. Plan a build, or copy a ready-made one.")
            or (not b.next and "Every planned point is taken.") or "")
        c.nextHead:SetShown(upcoming)
        c.pips:SetShown(upcoming)
        c.next:SetText(upcoming and b.next.name or "")
        if upcoming then
            c.pips:Set(b.rank - 1, b.next.max or b.rank, 1)
            c.next:SetWidth(inner - Style.Wide(c.nextHead, 34) - 10 - 60)
        end
        for i, q in ipairs(c.queue) do
            local step = queue[i]
            q:SetShown(step ~= nil)
            if step then
                q:Set(step.node.icon)
                q.level:SetText(tostring(step.level or ""))
            end
        end
    end
end

local function GearCard(parent, width)
    local c = PageCard(parent, "gear", "GEAR", "gear", width, PLAN_H)
    c.slots = {}
    local function Slot(i)
        if c.slots[i] then return c.slots[i] end
        local s = GameIcon(c, 30, "titleBar")
        s:SetPoint("TOPLEFT", PAD + ((i - 1) % 6) * 36, -50 - math.floor((i - 1) / 6) * 36)
        -- A gold corner: something you've starred goes in this slot.
        s.star = s:CreateTexture(nil, "OVERLAY")
        s.star:SetSize(7, 7)
        s.star:SetPoint("TOPRIGHT", -2, -2)
        s.star:SetColorTexture(Style.Color("gold"))
        c.slots[i] = s
        return s
    end
    c.emptySign = Sign(c, "red", "outline")
    c.emptySign:SetPoint("BOTTOMLEFT", PAD, 16)
    c.emptyText = Style.Text(c, 12, "red")
    c.emptyText:SetPoint("LEFT", c.emptySign, "RIGHT", 6, 0)
    c.filled = Style.Text(c, 12, "muted")
    c.filled:SetPoint("BOTTOMLEFT", PAD, 13)
    c.filled:SetText("Every slot filled")
    c.starText = Style.Text(c, 12, "gold")
    c.starText:SetPoint("BOTTOMRIGHT", -PAD, 13)
    c.starText:SetJustifyH("RIGHT")
    c.starSign = Sign(c, "gold", "full")
    c.starSign:SetPoint("RIGHT", c.starText, "LEFT", -6, 0)

    return c, function()
        local slots = Today.Slots()
        local empty, starred = Today.Gear()
        c.empty:SetText(slots and "" or "Turned off. Switch the Gear plan on in Settings.")
        for i, slot in ipairs(slots or {}) do
            local s = Slot(i)
            s.icon:SetShown(not slot.empty)
            if not slot.empty then s:Set(slot.texture) end
            s.star:SetShown(slot.starred)
            local r, g, b = Style.Color("red")
            if not slot.empty then r, g, b = Parts(Style.Quality(slot.quality)) end
            for _, edge in ipairs(s.edges) do edge:SetColorTexture(r, g, b, slot.empty and 1 or 0.6) end
            s:Show()
        end
        for i = #(slots or {}) + 1, #c.slots do c.slots[i]:Hide() end
        local some = slots ~= nil and (empty or 0) > 0
        c.emptySign:SetShown(some)
        c.emptyText:SetText(some and (empty .. " empty") or "")
        c.filled:SetShown(slots ~= nil and not some)
        local stars = slots ~= nil and (starred or 0) > 0
        c.starSign:SetShown(stars)
        c.starText:SetText(stars and (starred .. " starred to find") or "")
    end
end

local function ProfessionsCard(parent, width)
    local c = PageCard(parent, "professions", "PROFESSIONS", "professions", width, PLAN_H)
    local barW = width - PAD * 2 - 28 - 10
    c.lines = {}
    for i = 1, 3 do
        local l = { icon = GameIcon(c, 28), name = Style.Text(c, 13, "text", nil, true), count = Style.Text(c, 12, "text"), meter = Meter(c) }
        local y = -51 - (i - 1) * 47
        l.icon:SetPoint("TOPLEFT", PAD, y)
        l.name:SetPoint("TOPLEFT", PAD + 38, y + 2)
        l.name:SetWordWrap(false)
        l.count:SetPoint("TOPRIGHT", -PAD, y + 1)
        l.count:SetJustifyH("RIGHT")
        l.meter:SetPoint("TOPLEFT", PAD + 38, y - 22)
        l.meter:SetWidth(barW)
        -- At the top of its rank with the next one open to you: a gold tag
        -- in place of the count.
        l.train = Style.Tag(c, "train", true)
        l.train:SetPoint("TOPRIGHT", -PAD, y + 4)
        c.lines[i] = l
    end

    return c, function()
        local P = ns.Professions
        local mine = P and P.Mine() or {}
        local level = UnitLevel("player") or 1
        c.empty:SetText(#mine == 0 and "No professions yet. Learn one and its road to the next rank shows here." or "")
        for i, l in ipairs(c.lines) do
            local p = mine[i]
            for _, region in ipairs({ l.icon, l.name, l.count, l.meter, l.train }) do region:SetShown(p ~= nil) end
            if p then
                l.icon:Set(p.icon)
                l.name:SetText(p.name)
                l.meter:Set(p.cap > 0 and p.skill / p.cap or 0, barW)
                local rank = P.Rank and P.Rank(p.cap) or nil
                local open = rank ~= nil and rank.next ~= nil and level >= (rank.level or 0)
                    and p.skill >= (P.At and P.At(p.line, rank) or p.cap)
                l.train:SetShown(open)
                -- The name is written whole and the count gives way to it:
                -- "158 / 225", then "158/225", then the skill alone, whose
                -- share of the cap the bar under it shows.
                l.name:SetWidth(0)
                local room = barW - l.name:GetStringWidth() - 8
                local right, words = open and l.train:GetWidth() or 0, ""
                if not open then
                    for _, form in ipairs({ { "%d / %d", "%d |cff9a9688/ %d|r" }, { "%d/%d", "%d|cff9a9688/%d|r" }, { "%d", "%d" } }) do
                        l.count:SetText(form[1]:format(p.skill, p.cap))
                        right, words = l.count:GetStringWidth(), form[2]:format(p.skill, p.cap)
                        if right <= room then break end
                    end
                end
                l.count:SetText(words)
                l.name:SetWidth(math.max(40, barW - right - 8))
            end
        end
    end
end

local function DungeonsCard(parent, width)
    local c = PageCard(parent, "dungeons", "DUNGEONS", "dungeons", width, PLAN_H)
    local bandW = width - PAD * 2 - 66
    c.rows = {}
    for i = 1, 3 do
        local r = { name = Style.Text(c, 13, "text", nil, true), range = Style.Text(c, 12, "muted"), band = CreateFrame("Frame", nil, c) }
        local y = -44 - (i - 1) * 44
        r.name:SetPoint("TOPLEFT", PAD, y)
        r.name:SetWidth(width - PAD * 2)
        r.name:SetWordWrap(false)
        -- The six levels it's right for, how far into them you are, and a
        -- gold mark where you stand.
        r.band:SetSize(bandW, 6)
        r.band:SetPoint("TOPLEFT", PAD, y - 26)
        Style.Fill(r.band, "window")
        r.past = r.band:CreateTexture(nil, "ARTWORK")
        r.past:SetPoint("TOPLEFT")
        r.past:SetPoint("BOTTOMLEFT")
        r.past:SetColorTexture(Style.Color("lineStrong"))
        r.mark = r.band:CreateTexture(nil, "OVERLAY")
        r.mark:SetSize(3, 12)
        r.mark:SetColorTexture(Style.Color("gold"))
        r.range:SetPoint("RIGHT", c, "TOPRIGHT", -PAD, y - 29)
        r.range:SetJustifyH("RIGHT")
        c.rows[i] = r
    end
    c.foot = Style.Text(c, 12, "muted")
    c.foot:SetPoint("BOTTOMLEFT", PAD, 12)
    c.foot:SetWidth(width - PAD * 2)
    c.foot:SetWordWrap(false)

    return c, function()
        local fits, coming = Today.Dungeons()
        local level = UnitLevel("player") or 1
        c.note:SetText(fits and #fits > 0 and ("for level %d"):format(level) or "")
        c.empty:SetText(not fits and "Turned off. Switch the Dungeon guide on in Settings."
            or (#fits == 0 and "Nothing for your level right now.") or "")
        for i, r in ipairs(c.rows) do
            local d = fits and fits[i]
            for _, region in ipairs({ r.name, r.range, r.band }) do region:SetShown(d ~= nil) end
            if d then
                r.name:SetText(d.name)
                r.range:SetText(("%d to %d"):format(d.level, d.level + 5))
                local part = math.max(0, math.min(1, (level - d.level) / 5))
                r.past:SetWidth(math.max(0.001, bandW * part))
                r.mark:ClearAllPoints()
                r.mark:SetPoint("LEFT", (bandW - 3) * part, 0)
            end
        end
        local more = fits and #fits - #c.rows or 0
        c.foot:SetText(not fits and "" or (more > 0 and ("and %d more for your level"):format(more))
            or (coming and ("then %s at %d"):format(coming.name, coming.level)) or "")
    end
end

---------------------------------------------------------------------------
-- The row under the plans: the guild, today's games, and the Journal.
---------------------------------------------------------------------------
local ORDER_SIGNS = {
    { key = "you", color = "gold", shape = "full", words = "%d for you" },
    { key = "waiting", color = "amber", shape = "outline", words = "%d waiting" },
    { key = "making", color = "sky", shape = "half", words = "%d being made" },
}

local function GuildCard(parent, width)
    local c = PageCard(parent, "games", "GUILD", "guild", width, LOW_H)
    c.names = {}
    local function Name(i)
        if c.names[i] then return c.names[i] end
        local n = { dot = Style.Dot(c, 9), text = Style.Text(c, 13, "text") }
        n.dot:Paint("green")
        n.text:SetPoint("LEFT", n.dot, "RIGHT", 5, 0)
        c.names[i] = n
        return n
    end
    c.more = Style.Text(c, 12, "muted")
    -- The guild's orders that touch you, each count with its state's sign
    -- and colour, under a rule.
    c.orders = CreateFrame("Frame", nil, c)
    c.orders:SetPoint("BOTTOMLEFT", PAD, 0)
    c.orders:SetSize(width - PAD * 2, 38)
    Style.Rule(c.orders, "TOP", "line")
    local tile = c.orders:CreateTexture(nil, "ARTWORK")
    tile:SetTexture(OWN .. "crafts")
    tile:SetSize(18, 18)
    tile:SetPoint("LEFT", 0, 0)
    c.signs = {}
    for i, sign in ipairs(ORDER_SIGNS) do
        local s = { sign = Sign(c.orders, sign.color, sign.shape), text = Style.Text(c.orders, 12, sign.color) }
        s.text:SetPoint("LEFT", s.sign, "RIGHT", 6, 0)
        c.signs[i] = s
    end

    return c, function()
        local mates = Today.Guildmates()
        local orders = Today.Orders()
        c.orders:SetShown(orders ~= nil)
        local x = 28
        for i, sign in ipairs(ORDER_SIGNS) do
            local s, n = c.signs[i], orders and orders[sign.key] or 0
            s.sign:SetShown(n > 0)
            s.text:SetText(n > 0 and sign.words:format(n) or "")
            if n > 0 then
                s.sign:ClearAllPoints()
                s.sign:SetPoint("LEFT", x, 0)
                x = x + 14 + Style.Wide(s.text, 60) + 14
            end
        end
        c.empty:SetText(not mates and "You're not in a guild." or "")
        c.note:SetText(not mates and "" or (#mates == 0 and "nobody else online") or (Style.Tint("green") .. #mates .. " online|r"))
        -- Their names, in their class's colours, on as many lines as there's
        -- room for; then how many more there are.
        local lines = orders and 2 or 3
        local at, line, shown = PAD, 1, 0
        for i, mate in ipairs(mates or {}) do
            local n = Name(i)
            n.text:SetText(ClassTint(mate.class) .. mate.name .. "|r")
            local wide = 14 + Style.Wide(n.text, #mate.name * 7)
            local function Room() return width - PAD - at - ((line == lines and i < #mates) and 84 or 0) end
            if wide > Room() and line < lines then at, line = PAD, line + 1 end
            if wide > Room() then break end
            n.dot:ClearAllPoints()
            n.dot:SetPoint("LEFT", c, "TOPLEFT", at, -(34 + line * 22))
            n.dot:Show()
            n.text:Show()
            at, shown = at + wide + 14, i
        end
        for i = shown + 1, #c.names do
            c.names[i].dot:Hide()
            c.names[i].text:Hide()
        end
        local left = #(mates or {}) - shown
        c.more:SetText(left > 0 and ("and %d more"):format(left) or "")
        c.more:ClearAllPoints()
        c.more:SetPoint("LEFT", c, "TOPLEFT", at, -(34 + line * 22))
    end
end

local function GamesCard(parent, width)
    local c = PageCard(parent, "games", "TODAY'S GAMES", "games", width, LOW_H)
    local tileW = math.floor((width - PAD * 2 - 20) / 3)
    c.tiles = {}
    for i = 1, 3 do
        local t = CreateFrame("Button", nil, c)
        t:SetSize(tileW, 78)
        t:SetPoint("TOPLEFT", PAD + (i - 1) * (tileW + 10), -48)
        t.edges = { Style.Box(t, 5, "titleBar", "line").line }
        t.icon = t:CreateTexture(nil, "ARTWORK")
        t.icon:SetSize(28, 28)
        t.icon:SetPoint("TOP", 0, -8)
        t.name = Style.Text(t, 12, "text")
        t.name:SetPoint("TOP", 0, -40)
        t.name:SetJustifyH("CENTER")
        t.state = Style.Text(t, 12, "gold", nil, true)
        t.state:SetPoint("TOP", 0, -57)
        t.state:SetJustifyH("CENTER")
        t:SetScript("OnClick", function(self)
            if self.game and self.game.Open then xpcall(self.game.Open, ns.Report) end
        end)
        t:SetScript("OnEnter", function(self) Style.SetBorder(self.edges, "gold") end)
        t:SetScript("OnLeave", function(self) Style.SetBorder(self.edges, "line") end)
        c.tiles[i] = t
    end

    return c, function()
        local games = Today.GameTiles()
        c.empty:SetText(#games == 0 and "Turned off. Switch the daily games on in Settings." or "")
        c.note:SetText(#games > 0 and ns.Games and ns.Games.Until and ("new in " .. ns.Games.Until(true)) or "")
        for i, t in ipairs(c.tiles) do
            local game = games[i]
            t:SetShown(game ~= nil)
            if game then
                t.game = game.game
                t.icon:SetTexture(OWN .. game.icon)
                t.name:SetText(game.label)
                t.state:SetText(game.state)
                t.state:SetTextColor(Style.Color(game.tone))
            end
        end
    end
end

local function JournalCard(parent, width)
    local c = PageCard(parent, "journal", "JOURNAL", "journal", width, LOW_H)
    local MOST, BAR_W, BAR_GAP, CHART_H = 12, 18, 7, 52
    -- A bar for each of your last levels, as tall as the time it took: this
    -- one in gold, a red dot over one you died on.
    c.bars = {}
    for i = 1, MOST do
        local b = { fill = c:CreateTexture(nil, "ARTWORK"), dot = c:CreateTexture(nil, "ARTWORK") }
        b.fill:SetWidth(BAR_W)
        b.fill:SetPoint("BOTTOMLEFT", PAD + (i - 1) * (BAR_W + BAR_GAP), 34)
        b.dot:SetSize(4, 4)
        b.dot:SetColorTexture(Style.Color("red"))
        b.dot:SetPoint("BOTTOM", b.fill, "TOP", 0, 3)
        c.bars[i] = b
    end
    c.span = Style.Text(c, 12, "muted")
    c.span:SetPoint("BOTTOMLEFT", PAD, 11)
    c.deaths = Style.Text(c, 12, "muted")
    c.deaths:SetPoint("BOTTOMRIGHT", -PAD, 11)
    c.deaths:SetJustifyH("RIGHT")
    c.deathSign = Sign(c, "red", "full")
    c.deathSign:SetPoint("RIGHT", c.deaths, "LEFT", -6, 0)

    return c, function()
        local rows = Today.Levels(MOST)
        local top, died = 0, 0
        for _, row in ipairs(rows or {}) do top, died = math.max(top, row.seconds), died + row.deaths end
        local any = rows ~= nil and top > 0
        c.empty:SetText(any and "" or (rows and "Nothing here yet. It fills in as you play." or "Turned off. Switch the Journal on in Settings."))
        for i, b in ipairs(c.bars) do
            local row = any and rows[i] or nil
            b.fill:SetShown(row ~= nil)
            b.dot:SetShown(row ~= nil and row.deaths > 0)
            if row then
                b.fill:SetHeight(math.max(2, CHART_H * row.seconds / top))
                b.fill:SetColorTexture(Style.Color(i == #rows and "gold" or "lineStrong"))
            end
        end
        local last = any and rows[#rows] or nil
        c.note:SetText(last and (Style.Tint("text") .. Took(last.seconds) .. "|r on this level") or "")
        c.span:SetText(any and (#rows > 1 and ("levels %d to %d"):format(rows[1].level, last.level) or ("level %d"):format(last.level)) or "")
        c.deaths:SetText(any and died > 0 and Plural(died, "death") or "")
        c.deathSign:SetShown(any and died > 0)
    end
end

---------------------------------------------------------------------------
-- What's new: a strip under the top card with the gold edge, a segment for
-- each new thing. A segment says the thing and, in gold, what a click on it
-- does; nothing is behind a tooltip. Its cross puts it away for this version.
---------------------------------------------------------------------------
local NEWS_H = 60

-- Where a new thing's click goes: the welcome (the dashboard closes for it),
-- or a page.
local function NewsGo(target)
    if target == "welcome" then
        if not (ns.Setup and ns.Setup.Open) then return end
        Window.Toggle()
        return ns.Setup.Open()
    end
    Window.Open(target)
end

local function News(page, width, onAway)
    local news = CreateFrame("Frame", nil, page)
    news:SetPoint("TOPLEFT", 0, -(HERO_H + GAP))
    news:SetSize(width, NEWS_H)
    Style.Box(news, 6, "well", "cardLine")
    Style.Edge(news, 6)
    local head = Caps(news, "NEW IN " .. ns.version, "gold")
    head:SetPoint("TOPLEFT", 18, -15)
    local count = Style.Text(news, 12, "muted")
    count:SetPoint("TOPLEFT", 18, -33)
    count:SetText(#NEWS == 1 and "1 thing" or (#NEWS .. " things"))
    -- The heading has the room it needs (a beta's version is long); the
    -- segments share the rest, short of the cross.
    local left = math.max(130, 18 + Style.Wide(head, (#ns.version + 7) * 7) + 18)
    local each = math.floor((width - left - 44) / math.max(1, #NEWS))
    for i, item in ipairs(NEWS) do
        local b = CreateFrame("Button", nil, news)
        b:SetSize(each, NEWS_H)
        b:SetPoint("TOPLEFT", left + (i - 1) * each, 0)
        Style.Rule(b, "LEFT", "line")
        b.title = Style.Text(b, 13, "text", nil, true)
        b.title:SetPoint("TOPLEFT", 16, -14)
        b.title:SetWidth(each - 32)
        b.title:SetWordWrap(false)
        b.title:SetText(item[1])
        b.action = Style.Text(b, 12, "gold", nil, true)
        b.action:SetPoint("TOPLEFT", 16, -33)
        b.action:SetWidth(each - 32)
        b.action:SetWordWrap(false)
        b.action:SetText(item[2])
        b.target = item[3]
        b:SetScript("OnClick", function() NewsGo(item[3]) end)
        Style.Hover(b)
    end
    Style.CloseButton(news, 32, function()
        ns.db.newsSeen = ns.version
        onAway()
    end):SetPoint("RIGHT", -6, 0)
    return news
end

---------------------------------------------------------------------------
-- The page: the top card, what's new, Ready now, your plans, the guild,
-- games and Journal. It has the whole width of the dashboard.
---------------------------------------------------------------------------
Window.Page("home", function(page)
    local width = Window.fullWidth
    local paints = {}
    paints[#paints + 1] = Hero(page, width)

    local ready, paintReady, readyHead = ReadyCards(page, width)

    local plansHead = Caps(page, "YOUR PLANS")
    local plans = CreateFrame("Frame", nil, page)
    plans:SetPoint("TOPLEFT", plansHead, "BOTTOMLEFT", 0, -10)
    plans:SetSize(width, PLAN_H)
    local planW = math.floor((width - GAP * 3) / 4)
    for i, make in ipairs({ BuildCard, GearCard, ProfessionsCard, DungeonsCard }) do
        local card, paint = make(plans, planW)
        card:SetPoint("TOPLEFT", (i - 1) * (planW + GAP), 0)
        paints[#paints + 1] = paint
    end

    local lower = CreateFrame("Frame", nil, page)
    lower:SetPoint("TOPLEFT", plans, "BOTTOMLEFT", 0, -GAP)
    lower:SetSize(width, LOW_H)
    local lowW = math.floor((width - GAP * 2) / 3)
    for i, make in ipairs({ GuildCard, GamesCard, JournalCard }) do
        local card, paint = make(lower, lowW)
        card:SetPoint("TOPLEFT", (i - 1) * (lowW + GAP), 0)
        paints[#paints + 1] = paint
    end

    -- With what's new showing, the sections under it sit a little closer, so
    -- the page still ends where it did.
    local news
    local function Lay()
        local showing = NewsWanted()
        local gap = showing and GAP or 24
        news:SetShown(showing)
        readyHead:ClearAllPoints()
        readyHead:SetPoint("TOPLEFT", 0, -(HERO_H + (showing and (GAP + NEWS_H) or 0) + gap))
        plansHead:ClearAllPoints()
        plansHead:SetPoint("TOPLEFT", ready, "BOTTOMLEFT", 0, -gap)
    end
    news = News(page, width, Lay)

    page.Refresh = function()
        Lay()
        paintReady()
        for _, paint in ipairs(paints) do xpcall(paint, ns.Report) end
    end
end, nil, true)
