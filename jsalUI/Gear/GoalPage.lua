-- The Gear plan's "At 60" view (Gear\Goal.lua works it out): a pair of tabs at the page's top
-- left, "Near your level" and "At 60", while the goal's part is on. Under "At 60": a card with
-- how many slots are at your goal, a pip a slot, and the two stages; your goal for each slot
-- down the left, ticked where you wear it; and at the right where to go next, a card for each
-- dungeon with the pieces left for you there, most first, then what isn't from a run. It's
-- built the first time it's opened, and painted only while it shows.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window
local Gear, Goal = ns.Gear, ns.GearGoal

local TOP = 44                          -- under the tabs
local HERO_H, HERO_GAP = 84, 16
local LEFT_W, COL_GAP, HEAD_H = 452, 40, 26
local SLOT_X, ICON_X, NAME_X = 0, 78, 112
local RUN_HEAD, PIECE_H, CARD_GAP = 40, 32, 10
local FOOT = 24                         -- room for the link to the small print
local PLACES = 17                       -- the most slots there are: fifteen, with two rings and two trinkets
local FULL_BAR = 40                     -- the chance that fills a piece's bar
local TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
local MUTED, DIM = "|cff9a9688", "|cff5d5b55"

local function ItemInfo(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, _, quality, _, _, _, _, _, _, texture = get(id)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return name, quality, texture or Compat.ItemIcon(id)
end

local function Colored(name, quality)
    return ("|cff%s%s|r"):format(Style.Quality(quality), name or "...")
end

local function IconBox(parent, size)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(size, size)
    Style.Lined(box, "lineStrong", "window")
    box.icon = box:CreateTexture(nil, "ARTWORK")
    box.icon:SetPoint("TOPLEFT", 1, -1)
    box.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    box.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return box
end

-- The game's tooltip for a row's piece (what you wear there, or the goal), with what the
-- goal adds and where it's from under it.
local function Tip(self)
    if not (self.item or self.equip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.equip then GameTooltip:SetInventoryItem("player", self.equip) else GameTooltip:SetItemByID(self.item) end
    if self.adds and self.adds ~= "" then GameTooltip:AddLine("Adds " .. self.adds, Style.Color("green")) end
    for _, line in ipairs(self.lines or {}) do GameTooltip:AddLine(line, 0.6, 0.59, 0.53, true) end
    GameTooltip:Show()
end
local function Tipped(frame)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", Tip)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Style.Hover(frame)
end

-- A quiet action: gold words that light up.
local function Words(parent, text, onClick)
    local b = CreateFrame("Button", nil, parent)
    b.text = Style.Text(b, 13, "gold", nil, true)
    b.text:SetPoint("RIGHT")
    b.text:SetText(text)
    b:SetSize(Style.Wide(b.text, #text * 7), 20)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(Style.Color("text")) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color("gold")) end)
    b:SetScript("OnClick", onClick)
    return b
end

---------------------------------------------------------------------------
-- How a goal's source reads.
---------------------------------------------------------------------------
-- The runs of a piece that count in a stage: before raids, a raid isn't one.
local function RunsOf(from, stage)
    local runs = {}
    for _, r in ipairs(from.runs) do
        if stage == Goal.RAIDS or not r.raid then runs[#runs + 1] = r end
    end
    return runs
end

-- In a word or two, for the end of a slot's line: the dungeon, or how it's got.
local SHORT = { crafted = "Crafted", quest = "Quest", vendor = "Vendor", world = "World drop", unknown = "not known yet" }
function Gear.GoalPlace(from, stage)
    if from.kind == "run" then
        local runs = RunsOf(from, stage)
        local first, others = runs[1] and runs[1].name or "", {}
        for _, r in ipairs(runs) do
            if r.name ~= first and not others[r.name] then
                others[r.name] = true
                others[#others + 1] = r.name
            end
        end
        return first .. (#others > 0 and (" +" .. #others) or "")
    end
    if from.kind == "zone" then return from.text:match(" · (.*)$") or from.text end
    return SHORT[from.kind] or ""
end

-- In full, a line a source, for a tooltip.
function Gear.GoalSources(from, stage)
    local lines = {}
    for _, r in ipairs(RunsOf(from, stage)) do
        lines[#lines + 1] = (r.boss and (r.boss .. ", ") or "") .. r.name .. (r.chance and r.chance > 0 and (" · " .. r.chance .. "%") or "")
    end
    if from.kind ~= "run" then lines[1] = from.text ~= "" and from.text or "Wowhead lists no source for it yet" end
    return lines
end

---------------------------------------------------------------------------
-- The card at the top: how many slots are at your goal, and the stage.
---------------------------------------------------------------------------
local function Hero(view, width, onStage)
    local card = CreateFrame("Frame", nil, view)
    card:SetSize(width, HERO_H)
    card:SetPoint("TOPLEFT")
    Style.Box(card, 6, "well", "cardLine")
    Style.Edge(card, 6)
    card.count = Style.Text(card, 26, "text", nil, true)
    card.count:SetPoint("TOPLEFT", 22, -15)
    card.label = Style.Text(card, 15, "secondary")
    card.label:SetPoint("BOTTOMLEFT", card.count, "BOTTOMRIGHT", 10, 3)
    card.pips = {}
    for i = 1, PLACES do
        local t = card:CreateTexture(nil, "ARTWORK")
        t:SetSize(12, 12)
        t:SetPoint("TOPLEFT", 22 + (i - 1) * 16, -54)
        card.pips[i] = t
    end
    card.stages = Style.Tabs(card, { { Goal.BEFORE, "Before raids" }, { Goal.RAIDS, "Raids" } }, onStage)
    card.stages:SetPoint("TOPRIGHT", -20, -15)
    card.note = Style.Text(card, 12, "muted")
    card.note:SetPoint("TOPRIGHT", card.stages, "BOTTOMRIGHT", 0, -8)
    card.note:SetJustifyH("RIGHT")
    function card:Paint(read, stage)
        local s = read[stage]
        self.count:SetText(("|cffe3b04b%d|r of %d"):format(s.done, s.slots))
        self.label:SetText("slots at your goal for " .. Goal.LEVEL)
        for i, t in ipairs(self.pips) do
            t:SetShown(i <= s.slots)
            t:SetColorTexture(Style.Color(i <= s.done and "gold" or "lineStrong"))
        end
        for _, key in ipairs({ Goal.BEFORE, Goal.RAIDS }) do
            self.stages:Set(key, nil, ("%d of %d"):format(read[key].done, read[key].slots))
        end
        self.stages:Pick(stage)
        if read.waiting > 0 then
            self.note:SetText(("Checking %d piece%s the game hasn't sent yet..."):format(read.waiting, read.waiting == 1 and "" or "s"))
        elseif stage == Goal.BEFORE then
            self.note:SetText("Dungeons, quests, vendors and crafting first; raid pieces after.")
        else
            self.note:SetText("The best of the raids in the dungeon guide, over what comes before them.")
        end
    end
    return card
end

---------------------------------------------------------------------------
-- Your goal, slot by slot: a line each.
---------------------------------------------------------------------------
local function SlotList(view, rowH)
    local list = CreateFrame("Frame", nil, view)
    list:SetSize(LEFT_W, HEAD_H + PLACES * rowH)
    list:SetPoint("TOPLEFT", 0, -(HERO_H + HERO_GAP))
    local head = Style.Section(list, LEFT_W)
    head:SetPoint("TOPLEFT")
    head.title:SetText("YOUR GOAL, SLOT BY SLOT")
    list.rows = {}
    for i = 1, PLACES do
        local r = CreateFrame("Frame", nil, list)
        r:SetSize(LEFT_W, rowH)
        r:SetPoint("TOPLEFT", 0, -(HEAD_H + (i - 1) * rowH))
        Style.Rule(r, "BOTTOM", "line")
        r.slot = Style.Text(r, 11, "muted", nil, true)
        r.slot:SetPoint("LEFT", SLOT_X, 0)
        r.box = IconBox(r, 24)
        r.box:SetPoint("LEFT", ICON_X, 0)
        r.name = Style.Text(r, 14, "text")
        r.name:SetPoint("LEFT", NAME_X, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.where = Style.Text(r, 12, "muted")
        r.where:SetPoint("RIGHT")
        r.where:SetJustifyH("RIGHT")
        Tipped(r)
        list.rows[i] = r
    end
    function list:Paint(rows, stage)
        for i, r in ipairs(self.rows) do
            local row = rows[i]
            r:SetShown(row ~= nil)
            if row then
                r.slot:SetText(row.label:upper())
                r.item, r.equip, r.adds, r.lines = nil, nil, nil, nil
                local _, emptyTexture = GetInventorySlotInfo and GetInventorySlotInfo(row.slot.empty)
                if row.taken then
                    r.box.icon:SetTexture(emptyTexture)
                    r.name:SetText(MUTED .. "Taken by your two-hander|r")
                    r.where:SetText("")
                elseif row.goal then
                    local name, quality, texture = ItemInfo(row.goal.id)
                    local from = Goal.From(row.goal.e)
                    r.box.icon:SetTexture(texture)
                    r.name:SetText(Colored(name, quality or row.goal.e.quality))
                    r.where:SetText(Gear.GoalPlace(from, stage))
                    r.item, r.adds, r.lines = row.goal.id, row.gains, Gear.GoalSources(from, stage)
                elseif row.done then
                    local name, quality, texture = ItemInfo(row.worn.id)
                    r.box.icon:SetTexture(texture)
                    r.name:SetText(Colored(name, quality))
                    r.where:SetText(TICK .. " |cff62b35aworn|r")
                    r.equip = row.equip
                else
                    r.box.icon:SetTexture(emptyTexture)
                    r.name:SetText(DIM .. "nothing found for it yet|r")
                    r.where:SetText("")
                end
                -- The name has what the line's end leaves it.
                r.name:SetWidth(LEFT_W - NAME_X - Style.Wide(r.where, 90) - 12)
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Where to go next: a card a dungeon, then what isn't from a run.
---------------------------------------------------------------------------
-- A piece's line in a card: its picture and name, its slot and who drops it (or how it's
-- got), and at the right its chance over a small gold bar, or what to do about it.
local function PieceRow(parent, width)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(width, PIECE_H)
    r:SetFrameLevel(parent:GetFrameLevel() + 3)
    r.rule = Style.Rule(r, "TOP", "line")
    r.box = IconBox(r, 22)
    r.box:SetPoint("LEFT", 14, 0)
    r.name = Style.Text(r, 14, "text")
    r.name:SetPoint("LEFT", 46, 0)
    r.sub = Style.Text(r, 12, "muted")
    r.sub:SetPoint("LEFT", r.name, "RIGHT", 10, 0)
    r.sub:SetJustifyH("LEFT")
    r.sub:SetWordWrap(false)
    r.track = r:CreateTexture(nil, "ARTWORK")
    r.track:SetSize(44, 4)
    r.track:SetPoint("RIGHT", -14, 0)
    r.track:SetColorTexture(Style.Color("window"))
    r.fill = r:CreateTexture(nil, "OVERLAY")
    r.fill:SetHeight(4)
    r.fill:SetPoint("LEFT", r.track, "LEFT")
    r.fill:SetColorTexture(Style.Color("gold"))
    r.chance = Style.Text(r, 13, "text", nil, true)
    r.chance:SetPoint("RIGHT", r.track, "LEFT", -8, 0)
    r.act = Words(r, "Order from your guild", function() Window.Open("guildcrafts") end)
    r.act:SetPoint("RIGHT", -14, 0)
    Tipped(r)
    -- `chance` is a number, false for a boss's piece nobody has counted, nil for a piece
    -- that isn't from a run; `act` shows the action in its place.
    function r:Set(row, stage, sub, chance, act)
        local name, quality, texture = ItemInfo(row.goal.id)
        self.box.icon:SetTexture(texture)
        self.name:SetText(Colored(name, quality or row.goal.e.quality))
        self.sub:SetText(sub)
        self.item, self.adds, self.lines = row.goal.id, row.gains, Gear.GoalSources(Goal.From(row.goal.e), stage)
        self.track:SetShown(chance and true or false)
        self.fill:SetShown(chance and true or false)
        self.act:SetShown(act and true or false)
        if chance then
            self.chance:SetText(("%d%%"):format(math.floor(chance + 0.5)))
            self.fill:SetWidth(math.max(1, 44 * math.min(1, chance / FULL_BAR)))
        else
            self.chance:SetText(chance == false and (MUTED .. "no count yet|r") or "")
        end
        local right = act and (Style.Wide(self.act.text, 130) + 24) or (chance and 110 or (chance == false and 100 or 14))
        self.sub:SetWidth(math.max(40, width - 46 - Style.Wide(self.name, 150) - 10 - right))
    end
    return r
end

-- A dungeon's card: its name, where it is, how many pieces and the share of runs that bring
-- one, and a way to its page in the dungeon guide.
local function RunCard(parent, width)
    local card = CreateFrame("Frame", nil, parent)
    card:SetWidth(width)
    Style.Box(card, 6, "well", "cardLine")
    card.edge = Style.Edge(card, 6)
    card.name = Style.Text(card, 15, "text", nil, true)
    card.name:SetPoint("TOPLEFT", 14, -11)
    card.tag = Style.Tag(card, "best run now", "gold", true)
    card.tag:SetPoint("LEFT", card.name, "RIGHT", 10, 0)
    card.zone = Style.Text(card, 12, "muted")
    card.open = Words(card, "Open guide", function(self)
        if not (ns.Dungeons and self.dungeon) then return end
        ns.Dungeons.want = self.dungeon
        Window.Open("dungeons")
    end)
    card.open:SetPoint("TOPRIGHT", -14, -10)
    card.share = Style.Text(card, 12, "muted")
    card.count = Style.Text(card, 14, "text", nil, true)
    card.count:SetPoint("RIGHT", card.share, "LEFT", -8, 0)
    function card:Set(run, first)
        self.name:SetText(run.name)
        self.edge:SetShown(first)
        self.tag:SetShown(first)
        self.zone:ClearAllPoints()
        self.zone:SetPoint("LEFT", first and self.tag or self.name, "RIGHT", 10, 0)
        self.zone:SetText(run.raid and "Raid" or (run.dungeon and run.dungeon.zone or ""))
        local guide = run.dungeon and ns.Dungeons and ns.Dungeons.running and true or false
        self.open.dungeon = run.dungeon
        self.open:SetShown(guide)
        self.share:ClearAllPoints()
        if guide then self.share:SetPoint("RIGHT", self.open, "LEFT", -18, 0) else self.share:SetPoint("TOPRIGHT", -14, -13) end
        self.share:SetText(run.any and ("one in %d%% of runs"):format(math.max(1, math.floor(run.any * 100 + 0.5))) or "")
        self.count:SetText(("%d piece%s"):format(#run.pieces, #run.pieces == 1 and "" or "s"))
        self:SetHeight(RUN_HEAD + #run.pieces * PIECE_H + 4)
    end
    return card
end

-- The column: a heading, then a list that scrolls when a class has many places to go.
local function Runs(view, width, height)
    local col = CreateFrame("Frame", nil, view)
    col:SetSize(width, height)
    col:SetPoint("TOPLEFT", LEFT_W + COL_GAP, -(HERO_H + HERO_GAP))
    local head = Style.Section(col, width)
    head:SetPoint("TOPLEFT")
    head.title:SetText("WHERE TO GO NEXT")
    head.note:SetText("ranked by the pieces left for you")
    local inner = width - 10
    local scroll, child = Style.Scroller(col, width, height - HEAD_H - 4, inner, 0)
    scroll:SetPoint("TOPLEFT", 0, -(HEAD_H + 4))
    local cards, pieces = {}, {}
    local otherHead = Style.Section(child, inner)
    otherHead.title:SetText("NOT FROM A RUN")
    local otherCard = CreateFrame("Frame", nil, child)
    otherCard:SetWidth(inner)
    Style.Box(otherCard, 6, "well", "cardLine")
    local more = Style.Text(child, 13, "muted")
    local empty = Style.Text(col, 14, "muted")
    empty:SetPoint("TOPLEFT", 0, -(HEAD_H + 16))
    empty:SetWidth(width)
    empty:SetJustifyH("LEFT")
    local function Piece(i)
        if not pieces[i] then pieces[i] = PieceRow(child, inner) end
        return pieces[i]
    end
    function col:Paint(s, stage)
        local y, used = 0, 0
        for i, run in ipairs(s.runs) do
            if not cards[i] then cards[i] = RunCard(child, inner) end
            local card = cards[i]
            card:Set(run, i == 1)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", 0, -y)
            card:Show()
            for k, piece in ipairs(run.pieces) do
                used = used + 1
                local r = Piece(used)
                local who = piece.boss and (piece.boss .. (piece.more > 0 and (" +" .. piece.more) or "")) or nil
                r:Set(piece.row, stage, piece.row.label .. (who and (" · " .. who) or ""), piece.chance or false)
                r.rule:Show()
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -(y + RUN_HEAD + (k - 1) * PIECE_H))
                r:Show()
            end
            y = y + RUN_HEAD + #run.pieces * PIECE_H + 4 + CARD_GAP
        end
        for i = #s.runs + 1, #cards do cards[i]:Hide() end
        local others = #s.other > 0
        otherHead:SetShown(others)
        otherCard:SetShown(others)
        if others then
            y = y + (y > 0 and 6 or 0)
            otherHead:ClearAllPoints()
            otherHead:SetPoint("TOPLEFT", 0, -y)
            y = y + HEAD_H + 2
            otherCard:ClearAllPoints()
            otherCard:SetPoint("TOPLEFT", 0, -y)
            otherCard:SetHeight(#s.other * PIECE_H)
            local orders = ns.Orders and ns.Orders.running
            for k, row in ipairs(s.other) do
                used = used + 1
                local r = Piece(used)
                local from = Goal.From(row.goal.e)
                r:Set(row, stage, row.label .. " · " .. from.text, nil, from.kind == "crafted" and orders)
                r.rule:SetShown(k > 1)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -(y + (k - 1) * PIECE_H))
                r:Show()
            end
            y = y + #s.other * PIECE_H + CARD_GAP
        end
        for i = used + 1, #pieces do pieces[i]:Hide() end
        -- What has no known source is its count: the pieces are in the slots' list.
        more:SetShown(s.unknown > 0)
        if s.unknown > 0 then
            more:ClearAllPoints()
            more:SetPoint("TOPLEFT", 14, -y)
            more:SetText(("+ %d more"):format(s.unknown))
            y = y + 24
        end
        empty:SetShown(y == 0)
        if y == 0 then
            empty:SetText(s.slots > 0 and s.done == s.slots and "Every slot is at your goal."
                or "Nothing to go and get that we know of yet.")
        end
        child:SetHeight(math.max(1, y))
        scroll:UpdateScrollChildRect()
        scroll:Place()
    end
    return col
end

---------------------------------------------------------------------------
-- The view, and the tabs that choose it. The Gear page calls this as it's
-- built; page.Goal(spec) then says how much room the tabs take and whether
-- this view is the one showing, painting it when it is.
---------------------------------------------------------------------------
function Gear.GoalView(page, width, height)
    local showing, stage, retrying = false, Goal.BEFORE, false
    local hero, list, runs, none
    local tabs = Style.Tabs(page, { { "near", "Near your level" }, { "goal", "At " .. Goal.LEVEL } }, function(key)
        showing = key == "goal"
        if page.Refresh then page.Refresh() end
    end)
    tabs:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -6)
    tabs:Hide()
    local view = CreateFrame("Frame", nil, page)
    view:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -TOP)
    view:SetSize(width, height - TOP)
    view:Hide()
    local function Build()
        local body = height - TOP - HERO_H - HERO_GAP - FOOT
        hero = Hero(view, width, function(key)
            stage = key
            if page.Refresh then page.Refresh() end
        end)
        list = SlotList(view, math.max(24, math.min(35, math.floor((body - HEAD_H) / PLACES))))
        runs = Runs(view, width - LEFT_W - COL_GAP, body)
        none = Style.Text(view, 14, "muted")
        none:SetPoint("TOPLEFT", 0, -(HERO_H + HERO_GAP))
        none:SetWidth(width)
        none:SetJustifyH("LEFT")
        none:SetText("This spec has no stat weights yet, so there's no goal to work out. Add some under Weights.")
        local about = Style.About(view, "Your goal is the best piece for each slot at level 60 for your spec, by the Gear plan's own weights. It can be opened at any level.\n"
            .. "Before raids: what a dungeon boss in the guide drops, and crafts, quests and vendors up to the item level dungeons give. Raids: what the guide's raid bosses drop.\n"
            .. "Items, bosses and chances are from Wowhead Forever, and are still filling in at level 60.")
        about:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", 0, 0)
    end
    page.Goal = function(spec)
        if not Goal.running then
            tabs:Hide()
            view:Hide()
            return 0, false
        end
        tabs:Show()
        tabs:Pick(showing and "goal" or "near")
        view:SetShown(showing)
        if not showing then return tabs:GetWidth() + 18, false end
        if not hero then Build() end
        local started = debugprofilestop()
        local read = Goal.Read(spec)
        ns.Timed("Gear goal, working out", started)
        local has = not read.noWeights
        hero:SetShown(has)
        list:SetShown(has)
        runs:SetShown(has)
        none:SetShown(not has)
        if has then
            hero:Paint(read, stage)
            list:Paint(read[stage].rows, stage)
            runs:Paint(read[stage], stage)
            -- Still waiting on items: look again by itself, once at a time.
            if read.waiting > 0 and not retrying then
                retrying = true
                Compat.After(2.5, ns.Safe(Goal, function()
                    retrying = false
                    if view:IsVisible() and page.Refresh then page.Refresh() end
                end))
            end
        end
        return tabs:GetWidth() + 18, true
    end
end
