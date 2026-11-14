-- The dashboard's first page, Today: what's ready for you right now (a
-- trainer visit, a talent point, today's games), where each of your plans
-- stands, and what's new in this version in one line at the bottom.
-- ns.Today works out what's waiting; the side menu's badges ask it too.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

-- What's new in this version, in two or three short lines, written with
-- each release. The line shows once per version, until it's put away.
local NEWS = {
    "Beta: quest tags. Beside each quest in your tracker, its place in a chain and about how many minutes it will take",
    "Quest tags are off to start: turn them on under Leveling in /jsal settings",
    "Beta: easier to read, in dungeon quests, training and professions",
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
    -- A new block on the first page, so it starts off.
    defaultOn = false,
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
        if rank.next and rank.level == info.level and mine.skill >= rank.at then
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
-- have it, say). It was three right-aligned lines of text (John, 13 Nov
-- 2026: "maybe a whole card instead since it looks like we have space").
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
    end
    return n and n > 0 and n or nil
end

-- The Ready now list, most pressing first. Each: its icon, a title, a line
-- under it, an amount (or nil), and a button with what it does.
local function Ready()
    local rows = {}
    local function Add(row) rows[#rows + 1] = row end
    local function Try(fn) xpcall(fn, ns.Report) end

    Try(function()
        local points, node, rank = Today.Talents()
        if not points then return end
        Add({
            icon = "build", title = Plural(points, "talent point") .. " to spend",
            sub = node and ("Next in your plan: %s, rank %d of %d"):format(node.name, rank, node.max)
                or "Your plan has no next talent yet",
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
            icon = "training", title = "Trainer visit: " .. Plural(count, "spell"),
            sub = nearest and ("Nearest trainer: %s%s"):format(nearest.name, place and (", " .. place) or "")
                or "No class trainer found nearby",
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
        Add({ icon = "chess", title = waiting, sub = "Moves wait for whoever's turn it is",
            button = "Open chess", click = function() Window.Open("chess") end })
    end)

    Try(function()
        for _, entry in ipairs(Today.Games()) do
            Add({ icon = entry.icon, title = ("%s #%d"):format(entry.label, ns.Games.Today()),
                sub = entry.game.Status(), button = "Play", click = function() entry.game.Open() end })
        end
    end)

    Try(function()
        local state = ns.Installer.State()
        if state ~= "ready" and state ~= "update" then return end
        Add({
            icon = "install",
            title = state == "update" and "A newer jsal.ui look is ready" or "The jsal.ui look is ready to install",
            sub = "One click and a reload",
            button = "Open Install", click = function() Window.Open("install") end,
        })
    end)
    return rows
end

---------------------------------------------------------------------------
-- The page.
---------------------------------------------------------------------------
local ROW_H, CARD_H, GAP, PAD = 56, 132, 12, 14
local BUTTON_W, VALUE_W = 124, 90

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

Window.Page("home", function(page)
    local width = Window.contentWidth
    local half = math.floor((width - GAP) / 2)

    local title = Style.Text(page, 21, "text", nil, true)
    title:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    title:SetText("Today")
    local who = Style.Text(page, 13, "muted")
    who:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    -- The date, beside the title (John, 13 Nov 2026: "i also think we
    -- should have the date here").
    local today = Style.Text(page, 13, "muted")
    today:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 12, 2)

    -- Your pal, when it wants something: its picture, what it wants and
    -- what you have for it, under your name; a click opens its pen. It was
    -- a row of Ready now (John, 13 Nov 2026: "how about if we add jsal
    -- pal's any immediate needs as well?"); it's said once, here.
    local pal = CreateFrame("Button", nil, page)
    pal:SetSize(half - GAP, 40)
    pal:SetPoint("TOPLEFT", who, "BOTTOMLEFT", -4, -8)
    pal.icon = pal:CreateTexture(nil, "ARTWORK")
    pal.icon:SetSize(38, 38)
    pal.icon:SetPoint("LEFT")
    pal.title = Style.Text(pal, 13, "gold", nil, true)
    pal.title:SetPoint("TOPLEFT", pal.icon, "TOPRIGHT", 8, -3)
    pal.sub = Style.Text(pal, 12, "muted")
    pal.sub:SetPoint("TOPLEFT", pal.title, "BOTTOMLEFT", 0, -3)
    pal:SetScript("OnClick", function() Window.Open("pet") end)
    Style.Hover(pal, 4)
    pal:Hide()

    -- What the next level brings, as a card at the right of the title: the
    -- level, how far through this one you are, and a row for each thing.
    -- Hidden when there's nothing to say or the part is off.
    local cardW = math.min(380, half)
    local rowW = cardW - PAD * 2 - 2
    local nextCard = CreateFrame("Frame", nil, page)
    nextCard:SetWidth(cardW)
    nextCard:SetPoint("TOPRIGHT", title, "TOPLEFT", width, 4)
    Style.Fill(nextCard, "well")
    nextCard.edge = nextCard:CreateTexture(nil, "ARTWORK")
    nextCard.edge:SetColorTexture(Style.Color("gold"))
    nextCard.edge:SetPoint("TOPLEFT")
    nextCard.edge:SetPoint("BOTTOMLEFT")
    nextCard.edge:SetWidth(3)
    nextCard.head = Caps(nextCard, "")
    nextCard.head:SetPoint("TOPLEFT", PAD + 2, -11)
    nextCard.xp = Style.Text(nextCard, 11, "muted")
    nextCard.xp:SetPoint("TOPRIGHT", -PAD, -11)
    nextCard.xp:SetJustifyH("RIGHT")
    nextCard.track = CreateFrame("Frame", nil, nextCard)
    nextCard.track:SetPoint("TOPLEFT", PAD + 2, -30)
    nextCard.track:SetSize(rowW, 3)
    Style.Fill(nextCard.track, "line")
    nextCard.fill = nextCard.track:CreateTexture(nil, "ARTWORK")
    nextCard.fill:SetPoint("TOPLEFT")
    nextCard.fill:SetPoint("BOTTOMLEFT")
    nextCard.fill:SetColorTexture(Style.Color("gold"))
    nextCard.rows = {}
    local function NextRow(i)
        if nextCard.rows[i] then return nextCard.rows[i] end
        local r = CreateFrame("Frame", nil, nextCard)
        r:SetSize(rowW, 26)
        r:SetPoint("TOPLEFT", PAD + 2, -(42 + (i - 1) * 28))
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(20, 20)
        r.icon:SetPoint("LEFT")
        r.detail = Style.Text(r, 12, "muted")
        r.detail:SetPoint("RIGHT")
        r.detail:SetJustifyH("RIGHT")
        r.label = Style.Text(r, 13, "text")
        r.label:SetPoint("LEFT", r.icon, "RIGHT", 10, 0)
        r.label:SetPoint("RIGHT", r.detail, "LEFT", -8, 0)
        r.label:SetJustifyH("LEFT")
        r.label:SetWordWrap(false)
        nextCard.rows[i] = r
        return r
    end

    -- Ready now: one box, a row for each thing waiting.
    local readyHead = Caps(page, "READY NOW")
    readyHead:SetPoint("TOPLEFT", who, "BOTTOMLEFT", 0, -24)
    local headerTall = 46      -- the title and your name; more with the pal or the card
    local readyCount = Style.Text(page, 11, "muted")
    readyCount:SetPoint("LEFT", readyHead, "RIGHT", 8, 0)
    local list = CreateFrame("Frame", nil, page)
    list:SetPoint("TOPLEFT", readyHead, "BOTTOMLEFT", 0, -10)
    list:SetWidth(width)
    Style.Fill(list, "well")
    Style.Border(list, "cardLine")
    local nothing = Style.Text(list, 13, "muted")
    nothing:SetPoint("LEFT", PAD, 0)
    nothing:SetText("Nothing is waiting on you right now.")

    local rows = {}
    local function Row(i)
        if rows[i] then return rows[i] end
        local r = CreateFrame("Frame", nil, list)
        r:SetSize(width, ROW_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        if i > 1 then Style.Rule(r, "TOP", "line") end
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(34, 34)
        r.icon:SetPoint("LEFT", PAD, 0)
        r.button = Style.Button(r, "", "plain", BUTTON_W)
        r.button:SetHeight(30)
        r.button:SetPoint("RIGHT", -PAD, 0)
        r.value = Style.Text(r, 15, "gold", nil, true)
        r.value:SetPoint("RIGHT", r.button, "LEFT", -14, 0)
        r.value:SetJustifyH("RIGHT")
        r.title = Style.Text(r, 14, "text", nil, true)
        r.title:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 14, 0)
        r.sub = Style.Text(r, 12, "muted")
        r.sub:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -3)
        for _, t in ipairs({ r.title, r.sub }) do
            t:SetWidth(width - PAD * 2 - 34 - 14 - BUTTON_W - 14 - VALUE_W)
            t:SetWordWrap(false)
        end
        rows[i] = r
        return r
    end

    -- Your plans: four cards, each a way into its page.
    local plansHead = Caps(page, "YOUR PLANS")
    local cards = {}
    local function Card(key, label, column, line)
        local c = CreateFrame("Button", nil, page)
        c:SetSize(half, CARD_H)
        c:SetPoint("TOPLEFT", plansHead, "BOTTOMLEFT", (column - 1) * (half + GAP), -10 - (line - 1) * (CARD_H + GAP))
        Style.Fill(c, "well")
        c.edges = Style.Border(c, "cardLine")
        c.label = Caps(c, label, "muted")
        c.label:SetPoint("TOPLEFT", PAD, -PAD)
        c.open = Style.Text(c, 12, "gold")
        c.open:SetPoint("TOPRIGHT", -PAD, -PAD)
        c.open:SetText("Open")
        c.title = Style.Text(c, 15, "text", nil, true)
        c.title:SetPoint("TOPLEFT", c.label, "BOTTOMLEFT", 0, -8)
        c.sub = Style.Text(c, 12, "muted")
        c.sub:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -4)
        c.foot = Style.Text(c, 12, "text")
        c.foot:SetPoint("BOTTOMLEFT", PAD, PAD)
        for _, t in ipairs({ c.title, c.sub, c.foot }) do
            t:SetWidth(half - PAD * 2)
            t:SetWordWrap(false)
        end
        c:SetScript("OnClick", function() Window.Open(key) end)
        c:SetScript("OnEnter", function(self) Style.SetBorder(self.edges, "gold") end)
        c:SetScript("OnLeave", function(self) Style.SetBorder(self.edges, "cardLine") end)
        Style.Hover(c)
        -- What a card says while its part is switched off or has nothing.
        function c:Say(titleText, subText, footText)
            self.title:SetText(titleText or "")
            self.sub:SetText(subText or "")
            self.foot:SetText(footText or "")
        end
        cards[key] = c
        return c
    end
    local build = Card("build", "BUILD", 1, 1)
    build.meter = Meter(build)
    build.meter:SetPoint("BOTTOMLEFT", PAD, PAD + 5)
    build.meter:SetWidth(half - PAD * 2 - 110)
    build.count = Style.Text(build, 12, "text")
    build.count:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    build.count:SetJustifyH("RIGHT")
    local gear = Card("gear", "GEAR", 2, 1)
    local profs = Card("professions", "PROFESSIONS", 1, 2)
    profs.lines = {}
    for i = 1, 3 do
        local l = { name = Style.Text(profs, 13, "text", nil, true), meter = Meter(profs), count = Style.Text(profs, 12, "text") }
        local y = -(PAD + 24 + (i - 1) * 24)
        l.name:SetPoint("TOPLEFT", PAD, y)
        l.name:SetWidth(120)
        l.name:SetWordWrap(false)
        l.count:SetPoint("TOPRIGHT", -PAD, y)
        l.count:SetJustifyH("RIGHT")
        l.meter:SetPoint("TOPLEFT", PAD + 128, y - 5)
        l.meter:SetWidth(half - PAD * 2 - 128 - 76)
        profs.lines[i] = l
    end
    local dungeons = Card("dungeons", "DUNGEONS", 2, 2)

    -- What's new: one line at the bottom, the rest on hover, until it's
    -- put away.
    local news = CreateFrame("Frame", nil, page)
    news:SetPoint("BOTTOMLEFT")
    news:SetSize(width, 40)
    Style.Border(news, "cardLine")
    news:EnableMouse(true)
    local newsHead = Caps(news, "NEW IN " .. ns.version)
    newsHead:SetPoint("LEFT", PAD, 0)
    local more = Style.Text(news, 12, "muted")
    more:SetPoint("RIGHT", -36, 0)
    more:SetText(#NEWS > 1 and ("+%d more"):format(#NEWS - 1) or "")
    local first = Style.Text(news, 13, "text")
    first:SetPoint("LEFT", newsHead, "RIGHT", 12, 0)
    first:SetPoint("RIGHT", more, "LEFT", -12, 0)
    first:SetWordWrap(false)
    first:SetText(NEWS[1] or "")
    news:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("New in " .. ns.version)
        for _, text in ipairs(NEWS) do GameTooltip:AddLine(text, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    news:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Style.CloseButton(news, 32, function()
        ns.db.newsSeen = ns.version
        news:Hide()
    end):SetPoint("RIGHT", -2, 0)

    local function PaintReady()
        local ready = Ready()
        for i, item in ipairs(ready) do
            local r = Row(i)
            -- One of jsal.ui's icons, or a picture of its own (the companion's).
            r.icon:SetTexture(item.texture or (OWN .. item.icon))
            r.title:SetText(item.title)
            r.sub:SetText(item.sub or "")
            r.value:SetText(item.value or "")
            r.button:SetLabel(item.button)
            r.button:SetKind(item.primary and "primary" or "plain")
            r.button:SetScript("OnClick", function()
                xpcall(item.click, ns.Report)
                Window.Refresh()
            end)
            r:Show()
        end
        for i = #ready + 1, #rows do rows[i]:Hide() end
        nothing:SetShown(#ready == 0)
        readyCount:SetText(#ready > 0 and tostring(#ready) or "")
        list:SetHeight(math.max(1, #ready) * ROW_H)
        plansHead:ClearAllPoints()
        plansHead:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -24)
    end

    local function PaintBuild()
        local b = Today.Build()
        build.meter:SetShown(b ~= nil and b.planned > 0)
        build.count:SetText("")
        if not b then return build:Say("No talent trees for this class yet") end
        if b.planned == 0 then
            return build:Say(b.name or "Your build", "No points planned yet", "Plan a build, or copy a ready-made one")
        end
        build:Say(b.name or "Your build",
            b.next and ("Next, at level %d: %s, rank %d"):format(b.level, b.next.name, b.rank) or "Every planned point is taken")
        build.meter:Set(b.taken / b.planned, half - PAD * 2 - 110)
        build.count:SetText(("%d |cff9a9688of %d points|r"):format(b.taken, b.planned))
    end

    local function PaintGear()
        local empty, starred = Today.Gear()
        if not empty then return gear:Say("Turned off", "Switch the Gear plan on in Settings") end
        gear:Say(empty > 0 and (Plural(empty, "slot") .. " with nothing in " .. (empty == 1 and "it" or "them")) or "Every slot is filled",
            "The best upgrade for each slot, for your spec",
            starred > 0 and (Plural(starred, "starred item") .. " to find") or "Star the upgrades you want to chase")
    end

    local function PaintProfessions()
        local mine = ns.Professions and ns.Professions.Mine() or {}
        for i, l in ipairs(profs.lines) do
            local p = mine[i]
            l.name:SetShown(p ~= nil)
            l.meter:SetShown(p ~= nil)
            l.count:SetShown(p ~= nil)
            if p then
                l.name:SetText(p.name)
                l.meter:Set(p.cap > 0 and p.skill / p.cap or 0, half - PAD * 2 - 128 - 76)
                l.count:SetText(("%d |cff9a9688/ %d|r"):format(p.skill, p.cap))
            end
        end
        if #mine == 0 then
            profs:Say("No professions yet", "Learn one and its road to the next rank shows here")
        else
            profs:Say()
        end
    end

    local function PaintDungeons()
        local fits, coming = Today.Dungeons()
        if not fits then return dungeons:Say("Turned off", "Switch the Dungeon guide on in Settings") end
        local d = fits[1]
        if d then
            dungeons:Say(d.name, ("Right for your level · %s"):format(d.zone or "?"),
                #fits > 1 and ("and %d more for your level"):format(#fits - 1) or "")
        elseif coming then
            dungeons:Say(coming.name, ("From level %d · %s"):format(coming.level, coming.zone or "?"), "Nothing for your level right now")
        else
            dungeons:Say("Every dungeon and raid", "Bosses, loot and quests")
        end
    end

    -- The card: returns how tall it is, 0 when it's hidden.
    local function PaintNext()
        local info = Today.NextLevel()
        nextCard:SetShown(info ~= nil)
        if not info then return 0 end
        nextCard.head:SetText(("AT LEVEL %d"):format(info.level))
        local xp, most = UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 0
        local known = (most or 0) > 0
        nextCard.xp:SetShown(known)
        nextCard.track:SetShown(known)
        if known then
            nextCard.xp:SetText(("%s of %s XP"):format(Thousands(xp), Thousands(most)))
            nextCard.fill:SetWidth(math.max(1, rowW * math.min(1, (xp or 0) / most)))
        end
        local lines = Today.NextLevelRows(info)
        for i, line in ipairs(lines) do
            local r = NextRow(i)
            r.icon:SetTexture(line.icon or (OWN .. "build"))
            r.label:SetText(line.label)
            r.detail:SetText(line.detail or "")
            r:Show()
        end
        for i = #lines + 1, #nextCard.rows do nextCard.rows[i]:Hide() end
        local tall = 42 + #lines * 28 + 8
        nextCard:SetHeight(tall)
        return tall
    end

    -- The top of the page: the date, your pal's need, the card; and Ready
    -- now starts under whichever of the two sides is taller.
    local function PaintHeader()
        today:SetText(DateText())
        local wants = Today.Pet()
        pal:SetShown(wants ~= nil)
        if wants then
            pal.icon:SetTexture(wants.texture)
            pal.title:SetText(wants.title)
            pal.sub:SetText(wants.sub)
        end
        local ok, card = pcall(PaintNext)
        if not ok then
            nextCard:Hide()
            ns.Report(card)
            card = 0
        end
        headerTall = math.max(46 + (wants and 50 or 0), card - 4)
        readyHead:ClearAllPoints()
        readyHead:SetPoint("TOPLEFT", title, "TOPLEFT", 0, -(headerTall + 24))
    end

    page.Refresh = function()
        who:SetText(("%s, level %d %s"):format(UnitName("player") or "", UnitLevel("player") or 0, UnitClass("player") or ""))
        news:SetShown(NewsWanted())
        PaintReady()
        for _, paint in ipairs({ PaintHeader, PaintBuild, PaintGear, PaintProfessions, PaintDungeons }) do
            xpcall(paint, ns.Report)
        end
    end
end)
