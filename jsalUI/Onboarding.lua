-- The welcome: six steps the first time jsal.ui runs, and any time from
-- Settings or /jsal setup. What jsal.ui is and how to open it; then Plan,
-- Craft and Play, a step each, with a card for each page: what it does,
-- what it read from this character, and its one setting where it has one.
-- Build's card is where a player chooses what to follow. Then what's
-- planned for this character beside the helpers, their class's first, and
-- what jsal.ui puts on the screen, each with its switch, so anything can
-- be turned off before the welcome is done. The last step opens the dashboard, after
-- a reload when a part was switched, since parts start once, at login. It
-- closes as a fight starts, like the dashboard: its Reload button is the
-- game's own secure one.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local Setup = {}
ns.Setup = Setup

local WIDTH, HEIGHT, PAD, BAR, FOOT, TOP = 860, 540, 36, 32, 64, 26
local INNER = WIDTH - PAD * 2
local MEDIA = "Interface\\AddOns\\jsalUI\\Media\\"
local OWN = MEDIA .. "Icons\\"
local STEPS = {
    { key = "welcome", label = "Welcome" },
    { key = "plan", label = "Plan" },
    { key = "craft", label = "Craft" },
    { key = "play", label = "Play" },
    { key = "you", label = "For you" },
    { key = "screen", label = "Look" },
}
Setup.STEPS = STEPS

---------------------------------------------------------------------------
-- The helpers listed on the step that's for this character: a class's own
-- first, another class's never, and one made for an addon only where that
-- addon is installed. The parts with a card of their own on Craft and Play,
-- and the ones on the step for the screen, aren't among them.
---------------------------------------------------------------------------
local CLASS_EXTRAS = { HUNTER = { "rangecheck", "petfeed", "tametip" } }
local ANYONE = { "questtags", "rewardstar", "nextlevel", "guidetags", "foodtile", "lootlog" }
local NEEDS = { guidetags = "RXPGuides" }
local SHOWN = 6

-- The class's helpers, the first of everyone's up to SHOWN rows in all, and
-- how many more there are in Settings.
function Setup.Extras(classFile)
    local own, anyone, more = {}, {}, 0
    local function Offer(key, list)
        local module = ns.modules[key]
        if not module then return end
        if NEEDS[key] and not Compat.AddOnExists(NEEDS[key]) then return end
        if #own + #anyone < SHOWN then list[#list + 1] = module else more = more + 1 end
    end
    for _, key in ipairs(CLASS_EXTRAS[classFile or ""] or {}) do Offer(key, own) end
    for _, key in ipairs(ANYONE) do Offer(key, anyone) end
    return own, anyone, more
end

-- Parts whose switch differs from how the game loaded them: how many.
function Setup.Waiting()
    local count = 0
    for _, module in ipairs(ns.moduleOrder or {}) do
        local was = module.wantedAtStart
        if was ~= nil and ns.ModuleWanted(module) ~= was then count = count + 1 end
    end
    return count
end

-- What jsal.ui reads from this character, a line for each plan: a few
-- words, a line under them, and what it costs where it costs something. A
-- part that's off, or has nothing to read, has no line.
function Setup.Read()
    local read = {}
    local Today = ns.Today or {}
    local function Try(fn) xpcall(fn, ns.Report) end
    Try(function()
        local build = Today.Build and Today.Build()
        if not build then return end
        read.build = { icon = "build", title = build.name or "Your build",
            sub = build.next and ("Next: " .. build.next.name) or ((build.planned or 0) > 0 and "Every planned point is taken"
                or "Plan your points in Build") }
    end)
    Try(function()
        if not Today.Training then return end
        local count, cost = Today.Training()
        if count then
            local ready = count == 1 and "1 spell ready" or (count .. " spells ready")
            read.training = { icon = "training", title = ready .. " to train", short = ready, sub = "Home pins the nearest trainer",
                value = (cost or 0) > 0 and Compat.Money(cost) or nil }
        else
            read.training = { icon = "training", title = "Nothing to train right now", short = "Nothing to train right now",
                sub = "Every visit to 60 is in Training" }
        end
    end)
    Try(function()
        local Gear = ns.Gear
        if not (Gear and Gear.running) then return end
        local tree = Gear.Trees()[Gear.Spec()]
        local named = tree and tree.name and not tree.name:find("^Tree %d") and tree.name
        read.gear = { icon = "gear", title = "An upgrade for every slot", sub = "Ranked for " .. (named or "your spec") }
    end)
    Try(function()
        local P = ns.Professions
        if not (P and P.Mine) then return end
        local mine = P.Mine()[1]
        if mine then
            read.profession = { icon = "professions", title = ("%s %d / %d"):format(mine.name, mine.skill, mine.cap),
                sub = "The cheapest road to its next rank", name = mine.name, skill = mine.skill, cap = mine.cap }
        else
            read.profession = { icon = "professions", title = "No professions yet", sub = "Learn one and its road shows up" }
        end
    end)
    Try(function()
        if not Today.Dungeons then return end
        local fits, coming = Today.Dungeons()
        local here = fits and fits[1]
        if here then
            read.dungeon = { title = here.name, value = ("%d to %d"):format(here.level, here.level + 5) }
        elseif coming then
            read.dungeon = { title = coming.name, value = "opens at " .. coming.level }
        end
    end)
    return read
end

-- The lines of the card on the step that's for this character, in order.
function Setup.Plans()
    local read, rows = Setup.Read(), {}
    for _, key in ipairs({ "build", "training", "gear", "profession" }) do
        if read[key] then rows[#rows + 1] = read[key] end
    end
    return rows
end

---------------------------------------------------------------------------
-- What to follow in Build. A player who has planned a build of their own
-- can keep it; a class with a ready-made build can follow that; anyone can
-- build their own, import one from Wowhead, or leave it for later. Building
-- or leaving it follows a build of their own with no points in it, which
-- names no talent until it's planned.
---------------------------------------------------------------------------
-- Which page the dashboard opens on when the welcome is done.
local opens = "home"

local function Trees()
    local Tree = ns.TalentTree
    if not (Tree and Tree.PlayerClass and Tree.Active) then return nil end
    return Tree, Tree.PlayerClass()
end

local function Planned(build)
    return build ~= nil and not build.builtin and #(build.order or {}) > 0
end

-- The choices there are for this character, in order, and the one in force.
function Setup.BuildChoices()
    local Tree, classID = Trees()
    if not Tree then return {}, nil end
    local active = Tree.Active()
    local ready = Tree.Suggested(classID)[1]
    local list = {}
    if Planned(active) then list[#list + 1] = { key = "keep", title = "Keep my build", sub = active.name, build = active } end
    if ready then list[#list + 1] = { key = "ready", title = "Ready-made build", sub = ready.name, build = ready } end
    if not Planned(active) then list[#list + 1] = { key = "own", title = "Build my own", sub = "Opens Build after this" } end
    list[#list + 1] = { key = "import", title = "Import from Wowhead", sub = "Paste a calculator link" }
    list[#list + 1] = { key = "later", title = "Later", sub = "Nothing is followed yet" }
    local now
    if Planned(active) then
        now = "keep"
    elseif active and active.builtin then
        now = "ready"
    else
        now = opens == "build" and "own" or "later"
    end
    return list, now
end

-- A build of the player's own with no points in it: one they have, or a new one.
local function Empty(Tree, classID)
    for _, build in ipairs(Tree.ClassBuilds(classID)) do
        if #(build.order or {}) == 0 then return build end
    end
    return Tree.NewBuild(classID)
end

local function Follow(Tree, classID, build)
    Tree.Select(classID, build)
    Tree.Follow(build)
end

-- Takes a choice. `done` is called when what's followed has changed, at
-- once but for an import, which waits for its window.
function Setup.ChooseBuild(choice, done)
    local Tree, classID = Trees()
    if not Tree then return end
    if choice.key == "import" then
        local Share = ns.TalentShare
        if not (Share and Share.Import) then return end
        Share.Import(function(build)
            if build and build.class == classID then
                Follow(Tree, classID, build)
                opens = "build"
            end
            if done then done() end
        end)
        -- Its window comes up over this one.
        if jsalUIBuildCode and jsalUIBuildCode.Raise then jsalUIBuildCode:Raise() end
        return
    end
    if choice.build then
        Follow(Tree, classID, choice.build)
        opens = "home"
    else
        Follow(Tree, classID, Empty(Tree, classID))
        opens = choice.key == "own" and "build" or "home"
    end
    if done then done() end
end

---------------------------------------------------------------------------
-- Pieces the steps share.
---------------------------------------------------------------------------
local function Picture(parent, path, size, tint)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(path)
    t:SetSize(size, size)
    if tint then t:SetVertexColor(Style.Color(tint)) end
    return t
end

local function Caps(parent, words, colorKey, size)
    local t = Style.Text(parent, size or 11, colorKey or "muted", nil, true)
    t:SetText(words:upper())
    return t
end

local function Box(parent, width, height, radius, fill, line)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, height)
    f.box = Style.Box(f, radius, fill, line)
    return f
end

-- A step's name, large, and one line under it.
local function Heading(page, title, lead)
    local h = Style.Text(page, 21, "text", nil, true)
    h:SetPoint("TOPLEFT")
    h:SetText(title)
    local p = Style.Text(page, 13, "muted")
    p:SetPoint("TOPLEFT", 0, -31)
    p:SetWidth(INNER)
    p:SetWordWrap(false)
    p:SetText(lead or "")
    return h, p
end

-- A round gold sign with a number, as on a road: what a picture's parts
-- are told apart by.
local function Sign(parent, n)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(18, 18)
    Style.Circle(f, "gold", "gold")
    local t = Style.Text(f, 11, "onGold", nil, true)
    t:SetPoint("CENTER")
    t:SetJustifyH("CENTER")
    t:SetText(tostring(n))
    return f
end

-- Words to click that aren't a button: muted, lit under the pointer.
local function Quiet(parent, words, onClick)
    local b = CreateFrame("Button", nil, parent)
    b.label = Style.Text(b, 13, "muted")
    b.label:SetPoint("CENTER")
    b.label:SetText(words)
    b:SetSize(Style.Wide(b.label, #words * 7) + 16, 28)
    b:SetScript("OnEnter", function() b.label:SetTextColor(Style.Color("text")) end)
    b:SetScript("OnLeave", function() b.label:SetTextColor(Style.Color("muted")) end)
    b:SetScript("OnClick", onClick)
    return b
end

-- A tile, a name in bold and a muted line under it, on one row of a card.
local function Line(parent, width, height)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, height)
    row.rule = Style.Rule(row, "TOP", "line")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.title = Style.Text(row, 14, "text", nil, true)
    row.title:SetWordWrap(false)
    row.sub = Style.Text(row, 12, "muted")
    row.sub:SetWordWrap(false)
    row.value = Style.Text(row, 13, "text", nil, true)
    row.value:SetPoint("RIGHT")
    row.value:SetJustifyH("RIGHT")
    -- Where the words start, after a picture `size` across.
    function row:Lay(size, tint)
        self.icon:SetSize(size, size)
        self.icon:SetPoint("LEFT", size < 30 and math.floor((30 - size) / 2) or 0, 0)
        if tint then self.icon:SetVertexColor(Style.Color(tint)) end
        local half = math.floor(height / 2)
        self.title:SetPoint("TOPLEFT", 42, -(half - 17))
        self.sub:SetPoint("TOPLEFT", 42, -(half + 1))
        self.title:SetWidth(width - 42 - 70)
        self.sub:SetWidth(width - 42)
    end
    return row
end

-- A page's card: its tile and name, what it does in a line or two, and a
-- foot that says one thing about this character (Say), with a small bar
-- for a share of something (Share), or holds the page's one setting
-- (Setting). Where a foot's two ends would meet, the right one isn't shown.
local FOOT_H = 44

local function PageCard(parent, width, height, icon, name, words, lines)
    local card = Box(parent, width, height, 6, "well", "cardLine")
    local room = width - 32
    Picture(card, OWN .. icon, 30):SetPoint("TOPLEFT", 16, -14)
    local title = Style.Text(card, 16, "text", nil, true)
    title:SetPoint("LEFT", card, "TOPLEFT", 58, -29)
    title:SetText(name)
    local does = Style.Text(card, 13, "secondary")
    does:SetPoint("TOPLEFT", 16, -54)
    does:SetWidth(room)
    if does.SetMaxLines then does:SetMaxLines(lines or 3) end
    does:SetText(words)

    local foot = CreateFrame("Button", nil, card)
    foot:SetSize(room, FOOT_H)
    foot:SetPoint("BOTTOMLEFT", 16, 0)
    Style.Rule(foot, "TOP", "line")
    foot.left = Style.Text(foot, 13, "text")
    foot.left:SetPoint("LEFT")
    foot.left:SetWordWrap(false)
    foot.right = Style.Text(foot, 13, "muted")
    foot.right:SetPoint("RIGHT")
    foot.right:SetJustifyH("RIGHT")
    card.foot = foot

    function card:Say(left, right, colorKey)
        foot.left:SetText(left or "")
        foot.left:SetTextColor(Style.Color(colorKey or "text"))
        foot.right:SetText(right or "")
        foot.right:SetShown(foot.left:GetStringWidth() + 12 + foot.right:GetStringWidth() <= room)
        if self.track then self.track:Hide() end
    end
    -- A bar between the foot's two ends, `share` of it gold.
    function card:Share(share)
        if not self.track then
            self.track = CreateFrame("Frame", nil, foot)
            self.track:SetHeight(6)
            Style.Fill(self.track, "line")
            self.fill = self.track:CreateTexture(nil, "ARTWORK")
            self.fill:SetPoint("TOPLEFT")
            self.fill:SetPoint("BOTTOMLEFT")
            self.fill:SetColorTexture(Style.Color("gold"))
        end
        local wide = room - foot.left:GetStringWidth() - foot.right:GetStringWidth() - 24
        self.track:SetShown(wide >= 30 and foot.right:IsShown())
        self.track:ClearAllPoints()
        self.track:SetPoint("LEFT", foot.left, "RIGHT", 12, 0)
        self.track:SetWidth(math.max(1, wide))
        self.fill:SetWidth(math.max(1, wide * math.max(0, math.min(1, share))))
    end
    -- The page's one setting: its words and a switch. get() says how it
    -- stands; set(on) changes it. A click anywhere on the foot flips it.
    function card:Setting(words, get, set)
        if not self.switch then
            self.switch = Style.Switch(foot, function(on)
                self.set(on)
                self:Paint()
            end, true)
            self.switch:SetPoint("RIGHT")
            foot:SetScript("OnClick", function() self.switch:Click() end)
        end
        self.get, self.set = get, set
        foot.left:SetText(words)
        foot.right:SetText("")
        self:Paint()
    end
    function card:Paint()
        local on = self.get() and true or false
        self.switch:SetOn(on)
        foot.left:SetTextColor(Style.Color(on and "text" or "secondary"))
    end
    return card
end

-- A setting that is a part's own switch, or one switch over several parts
-- that go together (on while any of them is): `keys` is a part's key or a
-- list of them. Nothing where none of the parts is there.
local function PartSetting(card, keys, words)
    local list = {}
    for _, key in ipairs(type(keys) == "table" and keys or { keys }) do
        if ns.modules[key] then list[#list + 1] = ns.modules[key] end
    end
    if #list == 0 then return card:Say("") end
    card:Setting(words, function()
        for _, module in ipairs(list) do
            if ns.ModuleWanted(module) then return true end
        end
        return false
    end, function(on)
        for _, module in ipairs(list) do ns.db.modules[module.key] = on end
    end)
end

local frame, content, pages, current = nil, nil, {}, 1
local skip, back, nextButton, open, reload, note, stepName
local dots = {}
local BUILD = {}

---------------------------------------------------------------------------
-- Step one: what jsal.ui is, as the dashboard's own menu, and the three
-- ways to open it.
---------------------------------------------------------------------------
-- { tile, name, a few words, the part it belongs to (when it has a switch) }
local MENU = {
    { "Plan", { { "build", "Build", "your talents" }, { "training", "Training", "what to learn" },
                { "gear", "Gear", "upgrades for you", "gear" }, { "dungeons", "Dungeons", "bosses and loot", "dungeons" } } },
    { "Craft", { { "professions", "Professions", "cheapest road" }, { "crafts", "Guild Crafts", "guild orders", "crafters" },
                 { "shop", "Shopping list", "what to buy", "shopping" }, { "profit", "Crafting profit", "what sells", "craftprofit" } } },
    { "Play", { { "journal", "Journal", "your story so far", "journal" }, { "games", "Games", "a puzzle a day" },
                { "guild", "Guild", "who's on today", "guild" }, { "pals", "Jsal's Pals", "a pal of your own", "pet" } } },
}

-- A place's few words, or that its part is off.
local function PlaceWords(row)
    local module = row[4] and ns.modules[row[4]]
    if module and not ns.ModuleWanted(module) then return "switched off" end
    return row[3]
end

BUILD.welcome = function(page)
    Style.Wordmark(page, 34):SetPoint("TOPLEFT")
    local h = Style.Text(page, 21, "text", nil, true)
    h:SetPoint("TOPLEFT", 0, -46)
    h:SetText("Your road to 60, planned.")
    local lead = Style.Text(page, 13, "muted")
    lead:SetPoint("TOPLEFT", 0, -77)
    lead:SetWidth(INNER)
    lead:SetWordWrap(false)
    lead:SetText("Training, talents, gear, dungeons and professions in one window, with a journal and daily games for your guild.")

    local gap, rowH, cardsY = 14, 44, 112
    local cardW = math.floor((INNER - gap * 2) / 3)
    local cardH = 34 + 4 * rowH + 4
    local said = {}
    for c, group in ipairs(MENU) do
        local card = Box(page, cardW, cardH, 6, "well", "cardLine")
        card:SetPoint("TOPLEFT", (c - 1) * (cardW + gap), -cardsY)
        Caps(card, group[1], "gold"):SetPoint("TOPLEFT", 16, -13)
        for i, row in ipairs(group[2]) do
            local line = CreateFrame("Frame", nil, card)
            line:SetSize(cardW - 32, rowH)
            line:SetPoint("TOPLEFT", 16, -(34 + (i - 1) * rowH))
            if i > 1 then Style.Rule(line, "TOP", "line") end
            Picture(line, OWN .. row[1], 26):SetPoint("LEFT")
            local name = Style.Text(line, 14, "text", nil, true)
            name:SetPoint("LEFT", 36, 0)
            name:SetText(row[2])
            local words = Style.Text(line, 12, "muted")
            words:SetPoint("RIGHT")
            words:SetJustifyH("RIGHT")
            said[#said + 1] = { text = words, name = name, row = row, room = cardW - 32 - 36 }
        end
    end

    -- The three ways in, each drawn as it looks.
    local way = Caps(page, "Open it any time")
    way:SetPoint("LEFT", page, "TOPLEFT", 0, -(cardsY + cardH + 22 + 16))
    local function Say(after, words)
        local t = Style.Text(page, 13, "secondary")
        t:SetPoint("LEFT", after, "RIGHT", 8, 0)
        t:SetText(words)
        return t
    end
    local key = Box(page, 52, 24, 5, "titleBar", "lineStrong")
    key:SetPoint("LEFT", way, "RIGHT", 18, 0)
    local slash = Style.Text(key, 13, "text", nil, true)
    slash:SetPoint("CENTER")
    slash:SetText("/jsal")
    local chat = Say(key, "in chat")
    local mini = CreateFrame("Frame", nil, page)
    mini:SetSize(26, 26)
    mini:SetPoint("LEFT", chat, "RIGHT", 26, 0)
    Style.Circle(mini, "titleBar", "gold")
    Picture(mini, MEDIA .. "Logo", 16):SetPoint("CENTER")
    local map = Say(mini, "the minimap button")
    local quick = Box(page, 28, 28, 5, "well", "lineStrong")
    quick:SetPoint("LEFT", map, "RIGHT", 26, 0)
    Picture(quick, MEDIA .. "Logo", 18):SetPoint("CENTER")
    Say(quick, "the j on your quick buttons")

    -- A place's words stand clear of its name, or aren't shown: where a
    -- screen's letters are wide enough that the two would meet, the name
    -- stays, whole.
    page.Refresh = function()
        for _, s in ipairs(said) do
            s.text:SetText(PlaceWords(s.row))
            s.text:SetShown(s.name:GetStringWidth() + 12 + s.text:GetStringWidth() <= s.room)
        end
    end
end

---------------------------------------------------------------------------
-- Step two, Plan: Build across the top with its choices, then Training,
-- Gear and Dungeons.
---------------------------------------------------------------------------
local GRID_Y, GRID_GAP = 66, 14

-- One of Build's choices: its name over a line, lit gold while it's the
-- one in force.
local function ChoiceTile(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(54)
    b.box = Style.Box(b, 5, "window", "lineStrong")
    b.title = Style.Text(b, 13, "text", nil, true)
    b.title:SetPoint("TOPLEFT", 12, -10)
    b.title:SetWordWrap(false)
    b.sub = Style.Text(b, 12, "muted")
    b.sub:SetPoint("TOPLEFT", 12, -28)
    b.sub:SetWordWrap(false)
    function b:Paint()
        local lit = self.on or self.hover
        self.box:Paint(self.on and "needFill" or "window", lit and "gold" or "lineStrong")
        self.title:SetTextColor(Style.Color(self.on and "gold" or "text"))
    end
    b:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
    b:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
    return b
end

BUILD.plan = function(page)
    Heading(page, "Plan", "Your road to 60, a page for each part of it. Build is the one to choose; the rest are read from your character.")

    -- Build, with the gold edge: it's the one that waits on the player.
    local build = Box(page, INNER, 124, 6, "well", "cardLine")
    build:SetPoint("TOPLEFT", 0, -GRID_Y)
    Style.Edge(build, 6)
    Picture(build, OWN .. "build", 30):SetPoint("TOPLEFT", 18, -14)
    local name = Style.Text(build, 16, "text", nil, true)
    name:SetPoint("LEFT", build, "TOPLEFT", 60, -29)
    name:SetText("Build")
    local does = Style.Text(build, 13, "secondary")
    does:SetPoint("LEFT", name, "RIGHT", 14, 0)
    does:SetWordWrap(false)
    does:SetText("Your talents, a point at a time. It names the next one when a point comes in.")
    local none = Style.Text(build, 13, "muted")
    none:SetPoint("TOPLEFT", 18, -72)
    none:SetText("Your talents haven't been read yet. Choose a build in Build once they have.")

    local tiles = {}
    local Paint
    Paint = function()
        local choices, now = Setup.BuildChoices()
        local count = #choices
        local wide = count > 0 and math.floor((INNER - 34 - (count - 1) * 8) / count) or 0
        none:SetShown(count == 0)
        for i, choice in ipairs(choices) do
            tiles[i] = tiles[i] or ChoiceTile(build)
            local tile = tiles[i]
            tile:SetWidth(wide)
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", 18 + (i - 1) * (wide + 8), -56)
            tile.title:SetText(choice.title)
            tile.title:SetWidth(wide - 24)
            tile.sub:SetText(choice.sub)
            tile.sub:SetWidth(wide - 24)
            tile.on = choice.key == now
            tile:Paint()
            tile:SetScript("OnClick", function() Setup.ChooseBuild(choice, Paint) end)
            tile:Show()
        end
        for i = count + 1, #tiles do tiles[i]:Hide() end
    end

    local y = GRID_Y + 124 + GRID_GAP
    local wide = math.floor((INNER - GRID_GAP * 2) / 3)
    local training = PageCard(page, wide, 170, "training", "Training",
        "What to learn at the trainer and what it costs, with every visit to 60 on one road.", 4)
    training:SetPoint("TOPLEFT", 0, -y)
    local gear = PageCard(page, wide, 170, "gear", "Gear",
        "The best upgrade for each slot, ranked for your spec, and where it comes from.", 4)
    gear:SetPoint("TOPLEFT", wide + GRID_GAP, -y)
    local dungeons = PageCard(page, wide, 170, "dungeons", "Dungeons",
        "Every dungeon by level: its bosses, their loot, and the quests to take in.", 4)
    dungeons:SetPoint("TOPLEFT", (wide + GRID_GAP) * 2, -y)

    page.Refresh = function()
        Paint()
        local read = Setup.Read()
        if read.training then training:Say(read.training.short, read.training.value) else training:Say("") end
        gear:Say(read.gear and read.gear.sub or "")
        if read.dungeon then dungeons:Say(read.dungeon.title, read.dungeon.value) else dungeons:Say("") end
    end
end

---------------------------------------------------------------------------
-- Steps three and four, Craft and Play: four cards each, two across.
---------------------------------------------------------------------------
local function Grid(page, cards)
    local wide = math.floor((INNER - GRID_GAP) / 2)
    local made = {}
    for i, c in ipairs(cards) do
        local card = PageCard(page, wide, 158, c[1], c[2], c[3], 3)
        card:SetPoint("TOPLEFT", ((i - 1) % 2) * (wide + GRID_GAP), -(GRID_Y + math.floor((i - 1) / 2) * (158 + GRID_GAP)))
        made[i] = card
    end
    return made
end

BUILD.craft = function(page)
    Heading(page, "Craft", "Your professions, and your guild's. Each is on; switch off any you don't want.")
    local cards = Grid(page, {
        { "professions", "Professions", "The cheapest road to your next rank: what to craft, how many, and where each recipe is learned." },
        { "crafts", "Guild Crafts", "Who in your guild makes what, and orders between guildmates, from asked to received." },
        { "shop", "Shopping list", "What to craft and buy, with prices. One click adds a whole road to it." },
        { "profit", "Crafting profit", "What each recipe you know costs to make and sells for at the auction house." },
    })
    page.Refresh = function()
        local mine = Setup.Read().profession
        if mine and mine.cap then
            cards[1]:Say(mine.name, ("%d |cff9a9688/ %d|r"):format(mine.skill, mine.cap))
            cards[1]:Share(mine.cap > 0 and mine.skill / mine.cap or 0)
        else
            cards[1]:Say("No professions yet", nil, "muted")
        end
        PartSetting(cards[2], { "crafters", "orders" }, "Guildmates see what you can craft")
        PartSetting(cards[3], "shopping", "A list beside your bags")
        PartSetting(cards[4], "craftprofit", Compat.AddOnExists("Auctionator") and "With Auctionator's prices" or "With prices from your own searches")
    end
end

BUILD.play = function(page)
    Heading(page, "Play", "Your story, a puzzle a day, your guild, and a pal of your own. Switch off any you don't want.")
    local cards = Grid(page, {
        { "journal", "Journal", "Your levels, deaths, loot and time on each level, written as you play." },
        { "games", "Games", "Daily Word, Icon Guess and Pal run: one of each a day, the same for everyone, with your guild's results beside yours." },
        { "guild", "Guild", "Who in your guild runs jsal.ui, who's on, how everyone did today, and the Guild Word." },
        { "pals", "Jsal's Pals", "Hatch an egg, name what comes out and look after it. Your questing pays for its keep." },
    })
    page.Refresh = function()
        PartSetting(cards[1], "journal", "Keep a journal")
        PartSetting(cards[2], { "dailyword", "iconguess", "palrun" }, "Today's games, and Pal run")
        local guild = Compat.GuildName and Compat.GuildName()
        PartSetting(cards[3], "guild", guild and ("With " .. guild) or "Waits until you're in a guild")
        PartSetting(cards[4], "pet", "Keep a pal")
    end
end

---------------------------------------------------------------------------
-- Step five: this character's plan, and the helpers to switch.
---------------------------------------------------------------------------
local PLAN_W, PLAN_ROW, EXTRA_ROW, COLUMN_Y = 356, 54, 40, 66

-- A helper: its picture, its name over a line on what it does, and its
-- switch. A click anywhere on the row flips it.
local function ExtraRow(parent, width)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, EXTRA_ROW)
    Style.Rule(row, "BOTTOM", "line")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetAlpha(0.85)
    row.name = Style.Text(row, 14, "text")
    row.name:SetPoint("TOPLEFT", 36, -4)
    row.short = Style.Text(row, 12, "muted")
    row.short:SetPoint("TOPLEFT", 36, -21)
    row.short:SetWidth(width - 36 - 36 - 12)
    row.short:SetWordWrap(false)
    row.switch = Style.Switch(row, function(on)
        ns.db.modules[row.module.key] = on
        row:Set(row.module)
        if row.onChange then row.onChange() end
    end, true)
    row.switch:SetPoint("RIGHT")
    row:SetScript("OnClick", function() row.switch:Click() end)
    Style.Hover(row, 6, 5)
    function row:Set(module, words)
        local on = ns.ModuleWanted(module)
        local icon = ns.Settings and ns.Settings.Icon(module.key)
        self.module = module
        self.name:SetText(module.title)
        self.name:SetTextColor(Style.Color(on and "text" or "secondary"))
        -- Under a heading that names the class, a line needn't name it again.
        local short = words or self.words or (ns.Settings and ns.Settings.Short(module)) or ""
        self.words = words or self.words
        self.short:SetText((short:gsub("^%a+s: (%l)", string.upper)))
        self.icon:SetShown(icon ~= nil)
        if icon then self.icon:SetTexture(icon) end
        self.icon:SetVertexColor(Style.Color(on and "gold" or "muted"))
        self.switch:SetOn(on)
    end
    return row
end

BUILD.you = function(page)
    local title = Heading(page, "", "Nothing to fill in. jsal.ui read your class, level and professions, and your plans are ready.")

    -- The plans, in a card with the gold edge: they're yours.
    local card = Box(page, PLAN_W, 40, 6, "well", "cardLine")
    card:SetPoint("TOPLEFT", 0, -COLUMN_Y)
    Style.Edge(card, 6)
    Caps(card, "Your plan"):SetPoint("TOPLEFT", 18, -15)
    local lines = {}
    for i = 1, 4 do
        local line = Line(card, PLAN_W - 34, PLAN_ROW)
        line:SetPoint("TOPLEFT", 18, -(38 + (i - 1) * PLAN_ROW))
        line:Lay(30)
        lines[i] = line
    end

    -- The helpers, beside it.
    local x = PLAN_W + 32
    local width = INNER - x
    local column = CreateFrame("Frame", nil, page)
    column:SetSize(width, 10)
    column:SetPoint("TOPLEFT", x, -COLUMN_Y)
    Caps(column, "Helpers", "gold"):SetPoint("TOPLEFT", 0, -5)
    local each = Style.Text(column, 12, "muted")
    each:SetPoint("TOPRIGHT", 0, -4)
    each:SetText("each has a switch")
    local heads = { Caps(column, "", "muted", 10), Caps(column, "", "muted", 10) }
    local rows = {}
    local more = Style.Text(column, 13, "muted")

    page.Refresh = function()
        local className, classFile = UnitClass("player")
        title:SetText(("Set for a level %d %s"):format(UnitLevel("player") or 1, className or "adventurer"))

        local plans = Setup.Plans()
        for i, line in ipairs(lines) do
            local plan = plans[i]
            line:SetShown(plan ~= nil)
            if plan then
                line.icon:SetTexture(OWN .. plan.icon)
                line.title:SetText(plan.title)
                line.sub:SetText(plan.sub or "")
                line.value:SetText(plan.value or "")
            end
        end
        card:SetShown(#plans > 0)
        card:SetHeight(38 + #plans * PLAN_ROW + 2)

        local own, anyone, rest = Setup.Extras(classFile)
        local y, used = 24, 0
        local function Group(head, words, list)
            head:SetShown(#list > 0 and words ~= nil)
            if #list == 0 then return end
            if words then
                head:SetText(words:upper())
                head:ClearAllPoints()
                head:SetPoint("TOPLEFT", 0, -(y + 8))
                y = y + 24
            end
            for _, module in ipairs(list) do
                used = used + 1
                rows[used] = rows[used] or ExtraRow(column, width)
                local row = rows[used]
                row:Set(module)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y)
                row:Show()
                y = y + EXTRA_ROW
            end
        end
        -- With none of the class's own, the rest need no heading to tell them apart.
        Group(heads[1], "For " .. (className or "your class"):lower() .. "s", own)
        Group(heads[2], #own > 0 and "For anyone" or nil, anyone)
        for i = used + 1, #rows do rows[i]:Hide() end
        more:ClearAllPoints()
        more:SetPoint("TOPLEFT", 0, -(y + 10))
        more:SetText(used == 0 and "Every helper is in Settings." or (rest > 0 and ("+ %d more in Settings"):format(rest) or ""))
    end
end

---------------------------------------------------------------------------
-- Step six, Look: what jsal.ui puts on the screen, drawn and numbered,
-- with a switch for each piece of it, and where to ask.
---------------------------------------------------------------------------
local BAR_TILES = { "games", "shop", "crafts", "build", "training", "gear", "dungeons" }
local SIDE_W = 318
-- The pieces, and what each is in a few words short enough for the column.
local LOOK = {
    { "launcher", "The bar in the picture" },
    { "minimap", "Opens the dashboard" },
    { "menubar", "The game's menu bar, restyled" },
    { "bagbutton", "One button for all your bags" },
    { "vendor", "Repairs, and sells grey items" },
}

-- The quick buttons as a picture: the grip, the j, a button a place and the
-- layer's number, with a gold dot on the games.
local function BarPicture(parent)
    local size, gap = 32, 4
    local count = #BAR_TILES + 2
    local bar = Box(parent, gap + 12 + gap + count * size + (count - 1) * gap + gap, size + gap * 2, 6, "window", "lineStrong")
    for i = 1, 3 do
        local stroke = bar:CreateTexture(nil, "ARTWORK")
        stroke:SetColorTexture(Style.Color("muted"))
        stroke:SetSize(6, 1.5)
        stroke:SetPoint("LEFT", gap + 3, (i - 2) * 5)
    end
    bar.tiles = {}
    for i = 1, count do
        local tile = Box(bar, size, size, 5, "well", "lineStrong")
        tile:SetPoint("LEFT", gap + 12 + gap + (i - 1) * (size + gap), 0)
        if i == 1 then
            Picture(tile, MEDIA .. "Logo", 22):SetPoint("CENTER")
        elseif i == count then
            local layer = Style.Text(tile, 15, "text", nil, true)
            layer:SetPoint("CENTER")
            layer:SetText("3")
        else
            Picture(tile, OWN .. BAR_TILES[i - 1], 30):SetPoint("CENTER")
        end
        bar.tiles[i] = tile
    end
    local dot = CreateFrame("Frame", nil, bar.tiles[2])
    dot:SetSize(8, 8)
    dot:SetPoint("CENTER", bar.tiles[2], "TOPRIGHT", -1, -1)
    Style.Circle(dot, "gold", "window")
    return bar
end

BUILD.screen = function(page)
    Heading(page, "Look", "What jsal.ui puts on your screen. Switch off any of it; Unlock, in the dashboard's title bar, moves every piece.")

    -- A piece of screen, with the bar and the minimap button on it.
    local leftW = INNER - SIDE_W - 28
    local screen = Box(page, leftW, 176, 6, "titleBar", "line")
    screen:SetPoint("TOPLEFT", 0, -COLUMN_Y)
    local bar = BarPicture(screen)
    bar:SetPoint("BOTTOM", 0, 34)
    Sign(screen, 1):SetPoint("BOTTOM", bar, "TOPLEFT", 10, 6)
    Sign(screen, 2):SetPoint("BOTTOM", bar.tiles[2], "TOP", 0, 10)
    local mini = CreateFrame("Frame", nil, screen)
    mini:SetSize(34, 34)
    mini:SetPoint("TOPRIGHT", -26, -22)
    Style.Circle(mini, "titleBar", "gold")
    Picture(mini, MEDIA .. "Logo", 20):SetPoint("CENTER")
    Sign(screen, 3):SetPoint("RIGHT", mini, "LEFT", -6, 0)

    -- What each number is: its name, and a line on what to do with it.
    for i, legend in ipairs({
        { "The quick buttons", "Drag the bar by its grip. Right-click the grip to choose its buttons." },
        { "A gold dot", "Something's waiting there, like today's puzzle." },
        { "The minimap button", "Opens the dashboard too. Right-click it for every page." },
    }) do
        local y = -(COLUMN_Y + 176 + 16 + (i - 1) * 42)
        Sign(page, i):SetPoint("TOPLEFT", 0, y - 1)
        local name = Style.Text(page, 13, "text", nil, true)
        name:SetPoint("TOPLEFT", 28, y)
        name:SetText(legend[1])
        local words = Style.Text(page, 12, "secondary")
        words:SetPoint("TOPLEFT", 28, y - 17)
        words:SetWidth(leftW - 28)
        words:SetWordWrap(false)
        words:SetText(legend[2])
    end

    -- The pieces, a switch each.
    local x = leftW + 28
    local pieces = Box(page, SIDE_W, 34 + #LOOK * EXTRA_ROW + 6, 6, "well", "cardLine")
    pieces:SetPoint("TOPLEFT", x, -COLUMN_Y)
    Caps(pieces, "On your screen"):SetPoint("TOPLEFT", 16, -13)
    local each = Style.Text(pieces, 12, "muted")
    each:SetPoint("TOPRIGHT", -16, -12)
    each:SetText("each has a switch")
    local rows = {}
    for i, piece in ipairs(LOOK) do
        local row = ExtraRow(pieces, SIDE_W - 32)
        row:SetPoint("TOPLEFT", 16, -(34 + (i - 1) * EXTRA_ROW))
        row.key, row.words = piece[1], piece[2]
        rows[i] = row
    end

    local ask = Box(page, SIDE_W, 60, 6, "well", "cardLine")
    ask:SetPoint("TOPLEFT", pieces, "BOTTOMLEFT", 0, -12)
    local what = Style.Text(ask, 14, "text", nil, true)
    what:SetPoint("TOPLEFT", 16, -13)
    what:SetText("Questions, ideas, bugs")
    local where = Style.Text(ask, 12, "muted")
    where:SetPoint("TOPLEFT", 16, -31)
    where:SetText("jsal.ui has a Discord")
    local link = Style.Button(ask, "Discord link", "plain", 112)
    link:SetPoint("RIGHT", -16, 0)
    -- The game can't open a web page: the invite comes up in a box to copy
    -- it from, raised over this window.
    link:SetScript("OnClick", function()
        if not (ns.Reports and ns.Reports.Discord) then return ns.Print("jsal.ui's Discord: /jsal discord") end
        ns.Reports.Discord()
        if jsalUIDiscord and jsalUIDiscord.Raise then jsalUIDiscord:Raise() end
    end)

    page.Refresh = function()
        for _, row in ipairs(rows) do
            local module = ns.modules[row.key]
            row:SetShown(module ~= nil)
            if module then row:Set(module) end
        end
    end
end

---------------------------------------------------------------------------
-- The window: the step in hand, and a foot with the way back, where you
-- are and the way on.
---------------------------------------------------------------------------
-- Seen: it won't open by itself again. `welcome` is what says so: a setup
-- saved before there was a welcome has none, so its player is shown this
-- once. With `page`, the dashboard opens on that page once after the
-- reload that's about to happen.
local function Seen(page)
    ns.db.setup = { done = ns.codeVersion, welcome = true, open = page or nil }
end

local function Show(i)
    current = math.max(1, math.min(#STEPS, i))
    local step = STEPS[current]
    for n, other in ipairs(STEPS) do
        local page = pages[other.key]
        if n == current and not page then
            page = CreateFrame("Frame", nil, content)
            page:SetAllPoints()
            BUILD[other.key](page)
            pages[other.key] = page
        end
        if page then page:SetShown(n == current) end
        local tone = n == current and "gold" or (n < current and "needFill" or "lineStrong")
        dots[n]:Paint(tone, tone)
    end
    local page = pages[step.key]
    if page.Refresh then xpcall(page.Refresh, ns.Report) end
    stepName:SetText(step.label)

    local last = current == #STEPS
    local waiting = last and Setup.Waiting() or 0
    skip:SetShown(current == 1)
    back:SetShown(current > 1)
    nextButton:SetShown(not last)
    open:SetShown(last and waiting == 0)
    reload:SetShown(last and waiting > 0)
    note:SetText(waiting == 0 and "" or (waiting == 1 and "1 change waits for a reload" or (waiting .. " changes wait for a reload")))
end
Setup.Show = Show

-- A fight closes the welcome (at the foot of this file). That isn't the
-- player closing it, so it doesn't count as seen.
local byFight = false

local function Build()
    frame = Style.Panel("jsalUISetup", WIDTH, HEIGHT, "Welcome")
    -- Closing it early counts as seen, so it doesn't open again by itself.
    frame:HookScript("OnHide", function()
        if byFight or (ns.db.setup and ns.db.setup.welcome) then return end
        ns.db.setup = { done = ns.codeVersion, welcome = true, skipped = true }
    end)
    content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", PAD, -(BAR + TOP))
    content:SetPoint("BOTTOMRIGHT", -PAD, FOOT)

    local foot = CreateFrame("Frame", nil, frame)
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    foot:SetHeight(FOOT)
    Style.Rule(foot, "TOP", "line")

    skip = Quiet(foot, "Skip", function() frame:Hide() end)
    skip:SetPoint("LEFT", 16, 0)
    back = Style.Button(foot, "Back", "plain", 84)
    back:SetPoint("LEFT", 24, 0)
    back:SetScript("OnClick", function() Show(current - 1) end)
    -- That a reload is owed, beside Back, clear of the step's name.
    note = Style.Text(foot, 12, "muted")
    note:SetPoint("LEFT", back, "RIGHT", 14, 0)

    nextButton = Style.Button(foot, "Next", "primary", 110)
    nextButton:SetPoint("RIGHT", -24, 0)
    nextButton:SetScript("OnClick", function() Show(current + 1) end)
    open = Style.Button(foot, "Open the dashboard", "primary", 180)
    open:SetPoint("RIGHT", -24, 0)
    open:SetScript("OnClick", function()
        Seen()
        frame:Hide()
        ns.Window.Open(opens)
    end)
    -- Addons can't reload the game on Forever: the game's own secure button
    -- does, when clicked. It's marked seen before the click's reload runs.
    reload = ns.Window.ReloadButton(foot, "jsalUISetupReload", "Reload and open the dashboard", 236, true)
    reload:SetHeight(28)
    reload:SetPoint("RIGHT", -24, 0)
    reload:SetScript("PreClick", function() Seen(opens) end)

    -- Where you are: a dot a step, and the name of the one in hand.
    for n = 1, #STEPS do
        local dot = CreateFrame("Frame", nil, foot)
        dot:SetSize(8, 8)
        dot:SetPoint("CENTER", foot, "CENTER", -66 + (n - 1) * 15, 0)
        dots[n] = Style.Circle(dot, "lineStrong", "lineStrong")
    end
    stepName = Style.Text(foot, 12, "muted")
    stepName:SetPoint("LEFT", foot, "CENTER", -66 + #STEPS * 15, 0)
end

function Setup.Open()
    if Compat.InCombat() then return ns.Print("The welcome opens once combat ends.") end
    if not frame then Build() end
    opens = "home"
    frame:Show()
    Show(1)
end

ns.Command("setup", Setup.Open)
ns.Command("welcome", Setup.Open)

-- The secure Reload button can't be shown or hidden in combat, so the
-- welcome closes as a fight starts: at once, not faded, since once the
-- fight has begun it can't be hidden. Closed that way it isn't marked as
-- seen, and a line says how to get it back.
local combat = CreateFrame("Frame")
combat:RegisterEvent("PLAYER_REGEN_DISABLED")
combat:SetScript("OnEvent", function()
    if not (frame and frame:IsShown()) then return end
    byFight = true
    local ok = xpcall(frame.HideNow or frame.Hide, ns.Report, frame)
    byFight = false
    if ok then ns.Print("The welcome closed for the fight. /jsal setup opens it again.") end
end)

-- Until the welcome has been seen, it opens a few seconds after login, once
-- out of combat: the first time jsal.ui runs, and once for a player whose
-- saved setup is from before there was a welcome. After the reload its last
-- step asked for, the dashboard opens instead, once, on the page it named.
ns.OnLogin(function()
    local saved = ns.db.setup
    -- What an earlier setup asked and saved is read by nothing now.
    if saved then saved.play, saved.preset = nil, nil end
    if not (saved and saved.welcome) then
        Compat.After(8, function()
            if (ns.db.setup and ns.db.setup.welcome) or Compat.InCombat() then return end
            xpcall(Setup.Open, ns.Report)
        end)
        return
    end
    if saved.open then
        local page = type(saved.open) == "string" and saved.open or "home"
        saved.open = nil
        Compat.After(2, function()
            if Compat.InCombat() then return end
            xpcall(ns.Window.Open, ns.Report, page)
        end)
    end
end)
