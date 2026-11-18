-- The welcome: three steps the first time jsal.ui runs, and any time from
-- Settings or /jsal setup. What jsal.ui is and how to open it; what it has
-- already planned for this character, beside the parts that start off, the
-- ones for the player's class first; and what it put on the screen. Nothing
-- is asked. The last step opens the dashboard, after a reload when a part
-- was switched, since parts start once, at login. It closes as a fight
-- starts, like the dashboard: its Reload button is the game's own secure one.
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
    { key = "you", label = "For you" },
    { key = "screen", label = "On your screen" },
}
Setup.STEPS = STEPS

---------------------------------------------------------------------------
-- The extras: parts that start switched off. A class's own come first,
-- another class's aren't offered, nor is one made for an addon that isn't
-- installed. A part that starts off and isn't named here still joins the
-- end, so a new one needs no line.
---------------------------------------------------------------------------
local CLASS_EXTRAS = { HUNTER = { "rangecheck", "petfeed", "tametip" } }
local ANYONE = { "pet", "questtags", "rewardstar", "nextlevel", "guidetags", "palrun", "foodtile", "bagbutton",
                 "menubar", "craftprofit", "lootlog" }
local NEEDS = { guidetags = "RXPGuides" }
local SHOWN = 6

-- The class's extras, the first of everyone's up to SHOWN rows in all, and
-- how many more there are in Settings.
function Setup.Extras(classFile)
    local taken, own, anyone, more = {}, {}, {}, 0
    for class, keys in pairs(CLASS_EXTRAS) do
        if class ~= classFile then
            for _, key in ipairs(keys) do taken[key] = true end
        end
    end
    local function Offer(key, list)
        local module = ns.modules[key]
        if taken[key] or not module or module.defaultOn ~= false then return end
        taken[key] = true
        if NEEDS[key] and not Compat.AddOnExists(NEEDS[key]) then return end
        if #own + #anyone < SHOWN then list[#list + 1] = module else more = more + 1 end
    end
    for _, key in ipairs(CLASS_EXTRAS[classFile or ""] or {}) do Offer(key, own) end
    for _, key in ipairs(ANYONE) do Offer(key, anyone) end
    for _, module in ipairs(ns.moduleOrder or {}) do Offer(module.key, anyone) end
    return own, anyone, more
end

-- Parts whose switch differs from how the game loaded them: how many, and
-- the first, to name when it's the only one.
function Setup.Waiting()
    local count, first = 0, nil
    for _, module in ipairs(ns.moduleOrder or {}) do
        local was = module.wantedAtStart
        if was ~= nil and ns.ModuleWanted(module) ~= was then
            count = count + 1
            first = first or module
        end
    end
    return count, first
end

-- What's already planned for this character, a line each: a tile, a few
-- words, and what it costs where it costs something. A part that's off, or
-- has nothing to read yet, has no line.
function Setup.Plans()
    local rows = {}
    local Today = ns.Today or {}
    local function Try(fn) xpcall(fn, ns.Report) end
    Try(function()
        local build = Today.Build and Today.Build()
        if not build then return end
        rows[#rows + 1] = { icon = "build", title = build.name or "Your build",
            sub = build.next and ("next: " .. build.next.name) or ((build.planned or 0) > 0 and "every planned point is taken"
                or "plan your points in Build") }
    end)
    Try(function()
        if not Today.Training then return end
        local count, cost = Today.Training()
        if count then
            rows[#rows + 1] = { icon = "training", title = count == 1 and "1 spell ready to train" or (count .. " spells ready to train"),
                sub = "Home pins the nearest trainer", value = (cost or 0) > 0 and Compat.Money(cost) or nil }
        else
            rows[#rows + 1] = { icon = "training", title = "Nothing to train right now", sub = "every visit to 60 is in Training" }
        end
    end)
    Try(function()
        local Gear = ns.Gear
        if not (Gear and Gear.running) then return end
        local tree = Gear.Trees()[Gear.Spec()]
        local named = tree and tree.name and not tree.name:find("^Tree %d") and tree.name
        rows[#rows + 1] = { icon = "gear", title = "An upgrade for every slot", sub = "ranked for " .. (named or "your spec") }
    end)
    Try(function()
        local P = ns.Professions
        if not (P and P.Mine) then return end
        local mine = P.Mine()[1]
        if mine then
            rows[#rows + 1] = { icon = "professions", title = ("%s %d / %d"):format(mine.name, mine.skill, mine.cap),
                sub = "the cheapest road to its next rank" }
        else
            rows[#rows + 1] = { icon = "professions", title = "No professions yet", sub = "learn one and its road shows up" }
        end
    end)
    return rows
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
    { "Craft", { { "professions", "Professions", "the cheapest road" }, { "crafts", "Guild Crafts", "who makes what", "crafters" },
                 { "shop", "Shopping list", "what to buy", "shopping" }, { "profit", "Crafting profit", "what sells", "craftprofit" } } },
    { "Play", { { "journal", "Journal", "your story so far", "journal" }, { "games", "Games", "a puzzle a day" },
                { "guild", "Guild", "who's on today", "guild" }, { "pals", "Jsal's Pals", "a pal of your own", "pet" } } },
}

-- A place's few words, or that its part is off.
local function PlaceWords(row)
    local module = row[4] and ns.modules[row[4]]
    if module and not ns.ModuleWanted(module) then
        return module.defaultOn == false and "off to start" or "switched off"
    end
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
            said[#said + 1] = { text = words, row = row }
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

    page.Refresh = function()
        for _, s in ipairs(said) do s.text:SetText(PlaceWords(s.row)) end
    end
end

---------------------------------------------------------------------------
-- Step two: what's already planned, and the extras to switch on.
---------------------------------------------------------------------------
local PLAN_W, PLAN_ROW, EXTRA_ROW, COLUMN_Y = 356, 54, 40, 66

-- An extra: its picture, its name over a line on what it does, and its
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
    end, true)
    row.switch:SetPoint("RIGHT")
    row:SetScript("OnClick", function() row.switch:Click() end)
    Style.Hover(row, 6, 5)
    function row:Set(module)
        local on = ns.ModuleWanted(module)
        local icon = ns.Settings and ns.Settings.Icon(module.key)
        self.module = module
        self.name:SetText(module.title)
        self.name:SetTextColor(Style.Color(on and "text" or "secondary"))
        -- Under a heading that names the class, a line needn't name it again.
        local short = ns.Settings and ns.Settings.Short(module) or ""
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
    Caps(card, "Already planned"):SetPoint("TOPLEFT", 18, -15)
    local lines = {}
    for i = 1, 4 do
        local line = Line(card, PLAN_W - 34, PLAN_ROW)
        line:SetPoint("TOPLEFT", 18, -(38 + (i - 1) * PLAN_ROW))
        line:Lay(30)
        lines[i] = line
    end

    -- The extras, beside it.
    local x = PLAN_W + 32
    local width = INNER - x
    local column = CreateFrame("Frame", nil, page)
    column:SetSize(width, 10)
    column:SetPoint("TOPLEFT", x, -COLUMN_Y)
    Caps(column, "Extras", "gold"):SetPoint("TOPLEFT", 0, -5)
    local off = Style.Text(column, 12, "muted")
    off:SetPoint("TOPRIGHT", 0, -4)
    off:SetText("off until you switch them on")
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
        more:SetText(used == 0 and "Every extra is in Settings." or (rest > 0 and ("+ %d more in Settings"):format(rest) or ""))
    end
end

---------------------------------------------------------------------------
-- Step three: what's on the screen, drawn and numbered; what jsal.ui does
-- by itself; where to ask.
---------------------------------------------------------------------------
local BAR_TILES = { "games", "shop", "crafts", "build", "training", "gear", "dungeons" }
local SIDE_W = 318

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
    Heading(page, "On your screen", "jsal.ui adds two small things to it. Everything else waits in the dashboard.")

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

    -- Good to know: what's on by itself, and where things are changed.
    local x = leftW + 28
    local know = Box(page, SIDE_W, 34 + 3 * 52 + 2, 6, "well", "cardLine")
    know:SetPoint("TOPLEFT", x, -COLUMN_Y)
    Caps(know, "Good to know"):SetPoint("TOPLEFT", 16, -13)
    local vendor
    for i, fact in ipairs({
        { OWN .. "Parts\\vendor", "gold", "Vendor run is on", "Repairs, and sells grey items. Shift skips it." },
        { OWN .. "Parts\\launcher", "gold", "Unlock moves every piece", "In the dashboard's title bar." },
        { OWN .. "settings", nil, "Every part has a switch", "In Settings, a group at a time." },
    }) do
        local line = Line(know, SIDE_W - 32, 52)
        line:SetPoint("TOPLEFT", 16, -(34 + (i - 1) * 52))
        line:Lay(22, fact[2])
        line.icon:SetTexture(fact[1])
        line.title:SetText(fact[3])
        line.sub:SetText(fact[4])
        if i == 1 then vendor = line end
    end

    local ask = Box(page, SIDE_W, 60, 6, "well", "cardLine")
    ask:SetPoint("TOPLEFT", know, "BOTTOMLEFT", 0, -12)
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
        local module = ns.modules.vendor
        local on = module ~= nil and ns.ModuleWanted(module)
        vendor.title:SetText(on and "Vendor run is on" or "Vendor run is off")
        vendor.sub:SetText(on and "Repairs, and sells grey items. Shift skips it." or "It repairs, and sells grey items.")
        vendor.icon:SetVertexColor(Style.Color(on and "gold" or "muted"))
    end
end

---------------------------------------------------------------------------
-- The window: the step in hand, and a foot with the way back, where you
-- are and the way on.
---------------------------------------------------------------------------
-- Seen: it won't open by itself again. With `openNext`, the dashboard opens
-- once after the reload that's about to happen.
local function Seen(openNext)
    ns.db.setup = { done = ns.codeVersion, open = openNext or nil }
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
    local waiting, first = 0, nil
    if last then waiting, first = Setup.Waiting() end
    skip:SetShown(current == 1)
    back:SetShown(current > 1)
    nextButton:SetShown(not last)
    open:SetShown(last and waiting == 0)
    reload:SetShown(last and waiting > 0)
    if waiting == 1 then
        note:SetText(("%s %s after a reload"):format(first.title, ns.ModuleWanted(first) and "starts" or "stops"))
    elseif waiting > 1 then
        note:SetText(waiting .. " changes wait for a reload")
    else
        note:SetText("")
    end
end
Setup.Show = Show

-- A fight closes the welcome (at the foot of this file). That isn't the
-- player closing it, so it doesn't count as seen.
local byFight = false

local function Build()
    frame = Style.Panel("jsalUISetup", WIDTH, HEIGHT, "Welcome")
    -- Closing it early counts as seen, so it doesn't open again by itself.
    frame:HookScript("OnHide", function()
        if byFight then return end
        ns.db.setup = ns.db.setup or { done = ns.codeVersion, skipped = true }
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
    -- What a reload is owed for, beside Back, clear of the step's name.
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
        ns.Window.Open("home")
    end)
    -- Addons can't reload the game on Forever: the game's own secure button
    -- does, when clicked. It's marked seen before the click's reload runs.
    reload = ns.Window.ReloadButton(foot, "jsalUISetupReload", "Reload and open the dashboard", 236, true)
    reload:SetHeight(28)
    reload:SetPoint("RIGHT", -24, 0)
    reload:SetScript("PreClick", function() Seen(true) end)

    -- Where you are: a dot a step, and the name of the one in hand.
    for n = 1, #STEPS do
        local dot = CreateFrame("Frame", nil, foot)
        dot:SetSize(8, 8)
        dot:SetPoint("CENTER", foot, "CENTER", -56 + (n - 1) * 15, 0)
        dots[n] = Style.Circle(dot, "lineStrong", "lineStrong")
    end
    stepName = Style.Text(foot, 12, "muted")
    stepName:SetPoint("LEFT", foot, "CENTER", -8, 0)
end

function Setup.Open()
    if Compat.InCombat() then return ns.Print("The welcome opens once combat ends.") end
    if not frame then Build() end
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

-- The first time jsal.ui runs, the welcome opens a few seconds after login,
-- once out of combat. After the reload its last step asked for, the
-- dashboard opens instead, once.
ns.OnLogin(function()
    local saved = ns.db.setup
    if not saved then
        Compat.After(8, function()
            if ns.db.setup or Compat.InCombat() then return end
            xpcall(Setup.Open, ns.Report)
        end)
        return
    end
    -- What an earlier setup asked and saved is read by nothing now.
    saved.play, saved.preset = nil, nil
    if saved.open then
        saved.open = nil
        Compat.After(2, function()
            if Compat.InCombat() then return end
            xpcall(ns.Window.Open, ns.Report, "home")
        end)
    end
end)
