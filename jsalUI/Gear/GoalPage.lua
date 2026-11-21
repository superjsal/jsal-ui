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
local LEFT_W, COL_GAP, HEAD_H = 600, 28, 26
local SLOT_X, ICON_X, NAME_X = 0, 78, 112
local RUN_HEAD, PIECE_H, CARD_GAP = 40, 32, 10
local FOOT = 24                         -- room for the link to the small print
local PLACES = 17                       -- the most slots there are: fifteen, with two rings and two trinkets
local FULL_BAR = 100                    -- the chance that fills a piece's bar: a bar reads as the share it is
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
local function Tip(hot)
    local self = hot.row
    if not (self.item or self.equip) then return end
    GameTooltip:SetOwner(hot, "ANCHOR_RIGHT")
    if self.equip then GameTooltip:SetInventoryItem("player", self.equip) else GameTooltip:SetItemByID(self.item) end
    if self.adds and self.adds ~= "" then GameTooltip:AddLine("Adds " .. self.adds, Style.Color("green")) end
    for _, line in ipairs(self.lines or {}) do GameTooltip:AddLine(line, 0.6, 0.59, 0.53, true) end
    GameTooltip:Show()
end
-- The tooltip belongs to a row's picture and name, as wide as the name is written (`from`
-- is where the name starts): over the rest of the row it covered the rows under the pointer
-- on its way down the list (Style.HotArea, which passes a click to the row, so a line is picked
-- by a click anywhere on it). `Fit` sets its width once the name is written.
local function Tipped(row, from)
    local hot = Style.HotArea(row, Tip)
    hot.row = row
    hot:SetPoint("LEFT")
    hot:SetSize(from, row:GetHeight())
    row.hot = hot
    function row:Fit()
        local room = self.name:GetWidth() or 0
        local wide = self.name:GetStringWidth() or 0
        self.hot:SetWidth(from + math.max(0, room > 0 and math.min(wide, room) or wide))
    end
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
-- Your sets, in a menu under their pill: each set, then a new one, and for
-- the one you're on Copy, Rename and Delete. `act(what, key, words)` does
-- them; Delete asks once ("Sure?") for three seconds; Rename edits the name in
-- place.
---------------------------------------------------------------------------
local MENU_W, MENU_ROW = 220, 24
local function SetsMenu(parent, act)
    local menu = CreateFrame("Frame", nil, parent)
    menu:SetWidth(MENU_W)
    menu:SetFrameStrata("DIALOG")
    menu:EnableMouse(true)
    Style.Box(menu, 6, "titleBar", "lineStrong")
    menu:Hide()
    local lines = {}
    local function Line(i)
        if lines[i] then return lines[i] end
        local b = CreateFrame("Button", nil, menu)
        b:SetSize(MENU_W - 16, MENU_ROW)
        b.text = Style.Text(b, 13, "secondary")
        b.text:SetPoint("LEFT", 6, 0)
        b:SetScript("OnEnter", function(self) if self.what then self.text:SetTextColor(Style.Color("text")) end end)
        b:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color(self.tone or "secondary")) end)
        b:SetScript("OnClick", function(self)
            if not self.what then return end
            if self.what == "delete" and not self.sure then
                self.sure = true
                self.text:SetText("Sure?")
                Compat.After(3, function() if self.sure then self.sure = nil; self.text:SetText(self.words) end end)
                return
            end
            self.sure = nil
            if self.what == "rename" then return menu:Rename(self.key) end
            menu:Hide()
            act(self.what, self.key)
        end)
        lines[i] = b
        return b
    end
    local field = Style.Field(menu, MENU_W - 28)
    field.well:Hide()
    field:SetScript("OnEnterPressed", function(self)
        act("rename", menu.renaming, self:GetText())
        menu:Hide()
    end)
    field:SetScript("OnEscapePressed", function() menu:Hide() end)
    function menu:Rename(key)
        self.renaming = key
        for _, b in ipairs(lines) do b:Hide() end
        field.well:ClearAllPoints()
        field.well:SetPoint("TOPLEFT", 14, -10)
        field.well:Show()
        local set = Goal.OwnSet(key)
        field:SetText(set and set.name or "")
        field:SetFocus()
        field:HighlightText()
        self:SetHeight(48)
    end
    -- `current` is the set you're on when it's one of yours.
    -- `base` names WoWSims' build that is your default set, nil where there's none.
    function menu:Open(anchor, current, from, base)
        if self:IsShown() then return self:Hide() end
        field.well:Hide()
        local list = { { words = "YOUR SETS", tone = "muted" } }
        if base then
            list[#list + 1] = { words = "Default: WoWSims' " .. base, what = "default", tone = not current and "gold" or nil }
        end
        for _, set in ipairs(Goal.OwnSets()) do
            list[#list + 1] = { words = set.name, what = "choose", key = set.key, tone = set.key == current and "gold" or nil }
        end
        list[#list + 1] = { words = "+ New empty set", what = "empty" }
        list[#list + 1] = { words = "+ New set from \226\128\156" .. (from or "your goal") .. "\226\128\157", what = "new" }
        local mine = current and Goal.OwnSet(current)
        if mine then
            list[#list + 1] = { words = "Rename \226\128\156" .. mine.name .. "\226\128\157", what = "rename", key = current }
            list[#list + 1] = { words = "Delete \226\128\156" .. mine.name .. "\226\128\157", what = "delete", key = current, tone = "red" }
        end
        for i, item in ipairs(list) do
            local b = Line(i)
            b.what, b.key, b.words, b.tone, b.sure = item.what, item.key, item.words, item.tone, nil
            b.text:SetText(item.words)
            b.text:SetFontObject(b.text:GetFontObject())
            b.text:SetTextColor(Style.Color(item.tone or "secondary"))
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 8, -(6 + (i - 1) * MENU_ROW))
            b:Show()
        end
        for i = #list + 1, #lines do lines[i]:Hide() end
        self:SetHeight(12 + #list * MENU_ROW)
        self:ClearAllPoints()
        self:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
        self:Show()
    end
    return menu
end

---------------------------------------------------------------------------
-- The card at the top: how many slots are at your goal, and the stage.
---------------------------------------------------------------------------
local function Hero(view, width, onStage, onSet, onSets, onDraft)
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
    -- A change to the set waiting to be kept, under the stages: what changed, then Save (over a set
    -- of yours), Save as new set and Undo. On WoWSims' set there's nothing of yours to save over,
    -- so Save as new set stands first, gold.
    local function Act(words, kind, w, what)
        local b = Style.Button(card, words, kind, w)
        b:SetHeight(24)
        b:SetScript("OnClick", function() onDraft(what) end)
        b:Hide()
        return b
    end
    card.undo = Act("Undo", "plain", 64, "undo")
    card.undo:SetPoint("TOPRIGHT", card.stages, "BOTTOMRIGHT", 0, -6)
    card.saveNew = Act("Save as new set", "plain", 124, "new")
    card.saveNew:SetPoint("RIGHT", card.undo, "LEFT", -6, 0)
    card.saveFirst = Act("Save as new set", "primary", 124, "new")
    card.saveFirst:SetPoint("RIGHT", card.undo, "LEFT", -6, 0)
    card.save = Act("Save", "primary", 64, "save")
    card.save:SetPoint("RIGHT", card.saveNew, "LEFT", -6, 0)
    -- WoWSims' set, where your class has one: its builds, and the full set or the cheap one,
    -- left of the stages. Made the first time a set is shown: the builds are your class's.
    -- Your sets' pill, before raids: named for the one of yours you're on, "Default set" on
    -- WoWSims' (your default set), "My sets" where WoWSims has none for the spec.
    -- Its words leave room at the end for a gold "v" drawn from two strokes, as the dungeon guide's
    -- picker has: the font has no arrow of its own.
    card.mine = Style.Tabs(card, { { "own", "My sets    " } }, function() onSets(card.mine) end)
    card.mine:Hide()
    for _, way in ipairs({ -1, 1 }) do
        local stroke = card.mine.byKey.own:CreateTexture(nil, "OVERLAY")
        stroke:SetSize(6, 2)
        stroke:SetColorTexture(Style.Color("gold"))
        stroke:SetPoint("RIGHT", -12 - (way == -1 and 4 or 0), 0)
        stroke:SetRotation(math.rad(45 * way))
    end
    function card:Choosers(set, before)
        self.mine:SetShown(before)
        if before then
            self.mine:Set("own", (set and (set.own and set.name or "Default set") or "My sets") .. "    ")
            self.mine:Pick(set and set.own and "own" or nil)
        end
        if not (set and before) then
            if self.builds then self.builds:Hide() self.costs:Hide() end
        elseif not self.builds and #set.builds > 0 then
            local items = {}
            for _, b in ipairs(set.builds) do items[#items + 1] = { b.key, b.name } end
            self.builds = Style.Tabs(self, items, function(key) onSet(key, nil) end)
            self.costs = Style.Tabs(self, { { "full", "Full" }, { "cheap", "Cheap" } }, function(key) onSet(nil, key == "cheap") end)
        end
        -- From the right: the stages, Full or Cheap (a WoWSims set's), your sets, WoWSims' builds.
        local right = self.stages
        if self.builds and set and before then
            self.costs:SetShown(set.hasCheap and not set.own)
            self.costs:Pick(set.cheap and "cheap" or "full")
            if set.hasCheap and not set.own then
                self.costs:ClearAllPoints()
                self.costs:SetPoint("RIGHT", right, "LEFT", -8, 0)
                right = self.costs
            end
        end
        if before then
            self.mine:ClearAllPoints()
            self.mine:SetPoint("RIGHT", right, "LEFT", -8, 0)
            right = self.mine
        end
        if self.builds and set and before then
            -- Hidden on a set of yours: they'd take you off it, and the menu's Default line does that.
            self.builds:SetShown(#set.builds > 1 and not set.own)
            self.builds:Pick(not set.own and set.key or nil)
            self.builds:ClearAllPoints()
            self.builds:SetPoint("RIGHT", right, "LEFT", -8, 0)
        end
    end
    function card:Paint(read, stage)
        local s = read[stage]
        local set = stage == Goal.BEFORE and read.set
        self.count:SetText(("|cffe3b04b%d|r of %d"):format(s.done, s.slots))
        self.label:SetText(set and "slots at your pre-BiS" or ("slots at your goal for " .. Goal.LEVEL))
        self:Choosers(set or nil, stage == Goal.BEFORE)
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
        elseif set and set.own then
            self.note:SetText("Your set \226\128\156" .. set.name .. "\226\128\157" .. (set.from and (", started from WoWSims' " .. set.from) or ""))
        elseif set then
            self.note:SetText("WoWSims Forever's pre-raid set for " .. set.name .. (set.cheap and ", the cheap one" or "") .. ", from its sims")
        elseif stage == Goal.BEFORE then
            self.note:SetText("An estimate by your weights: WoWSims has no pre-raid set for this spec yet.")
        else
            self.note:SetText("The best of the raids in the dungeon guide, over what comes before them.")
        end
        local changed = stage == Goal.BEFORE and set and set.changed
        local own = changed and set.own and true or false
        self.undo:SetShown(changed and true or false)
        self.save:SetShown(own)
        self.saveNew:SetShown(own)
        self.saveFirst:SetShown(changed and not own and true or false)
        self.note:ClearAllPoints()
        if changed then
            local said = {}
            for i = 1, math.min(#changed, 3) do said[i] = changed[i] end
            local more = #changed > 3 and (" +" .. (#changed - 3)) or ""
            self.note:SetPoint("RIGHT", own and self.save or self.saveFirst, "LEFT", -10, 0)
            self.note:SetText((own and "Changed: " or ("Changed from WoWSims' " .. set.name .. ": ")) .. table.concat(said, ", ") .. more)
        else
            self.note:SetPoint("TOPRIGHT", self.stages, "BOTTOMRIGHT", 0, -8)
        end
    end
    return card
end

---------------------------------------------------------------------------
-- Your goal, slot by slot: a line each.
---------------------------------------------------------------------------
-- The groups the lines are in, by slot, in the order they're shown.
local GROUPS = {
    { "ARMOR", { head = 1, shoulder = 2, back = 3, chest = 4, wrist = 5, hands = 6, waist = 7, legs = 8, feet = 9 } },
    { "JEWELRY", { neck = 1, finger = 2, trinket = 3 } },
    { "WEAPONS", { main = 1, off = 2, ranged = 3 } },
}
local GAIN_W, PICKS_W = 48, 70
-- A slot's picks by the weights, after the set's piece and WoWSims' own.
local PICKS = 5
-- Raids, until there's raid loot in the game: over the lines and runs, which show greyed under
-- it, a box that says so; nothing under it takes a click.
local function Waiting(view, width, height)
    local cover = CreateFrame("Frame", nil, view)
    cover:SetPoint("TOPLEFT", 0, -(HERO_H + HERO_GAP))
    cover:SetSize(width, height)
    cover:SetFrameLevel((view:GetFrameLevel() or 0) + 30)
    cover:EnableMouse(true)
    local box = CreateFrame("Frame", nil, cover)
    box:SetSize(400, 104)
    box:SetPoint("CENTER")
    Style.Box(box, 8, "well", "cardLine")
    Style.Edge(box, 8)
    local title = Style.Text(box, 17, "gold", nil, true)
    title:SetPoint("TOPLEFT", 22, -28)
    title:SetText("Waiting for raid loot")
    local line = Style.Text(box, 13, "muted")
    line:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    line:SetText("Raids opens once there's raid loot in the game.")
    cover:Hide()
    return cover
end

local function SlotList(view, rowH, onPick)
    local list = CreateFrame("Frame", nil, view)
    list:SetSize(LEFT_W, #GROUPS * HEAD_H + PLACES * rowH)
    list:SetPoint("TOPLEFT", 0, -(HERO_H + HERO_GAP))
    list.heads = {}
    for g in ipairs(GROUPS) do
        list.heads[g] = Style.Section(list, LEFT_W)
        list.heads[g].title:SetText(GROUPS[g][1])
    end
    list.rows = {}
    for i = 1, PLACES do
        local r = CreateFrame("Frame", nil, list)
        r:SetSize(LEFT_W, rowH)
        Style.Rule(r, "BOTTOM", "line")
        r.slot = Style.Text(r, 11, "muted", nil, true)
        r.slot:SetPoint("LEFT", SLOT_X, 0)
        r.box = IconBox(r, 24)
        r.box:SetPoint("LEFT", ICON_X, 0)
        r.name = Style.Text(r, 14, "text")
        r.name:SetPoint("LEFT", NAME_X, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.gain = Style.Text(r, 12, "green", nil, true)
        r.gain:SetPoint("LEFT", r.name, "RIGHT", 10, 0)
        r.where = Style.Text(r, 12, "muted")
        r.where:SetPoint("LEFT", r.gain, "RIGHT", 10, 0)
        r.where:SetJustifyH("LEFT")
        r.where:SetWordWrap(false)
        r.picks = Style.Text(r, 12, "secondary", nil, true)
        r.picks:SetPoint("RIGHT", -6, 0)
        r.picks:SetJustifyH("RIGHT")
        Tipped(r, NAME_X)
        -- A slot with other choices is a click to them, lit while they show: filled, a gold bar
        -- in the gutter at its left (clear of the slot's name), and its slot and picks in gold.
        r.lit = r:CreateTexture(nil, "BACKGROUND")
        r.lit:SetAllPoints()
        r.lit:SetColorTexture(Style.Color("wellHover"))
        r.lit:Hide()
        r.bar = r:CreateTexture(nil, "BORDER")
        r.bar:SetPoint("TOPLEFT", -8, 0)
        r.bar:SetPoint("BOTTOMLEFT", -8, 0)
        r.bar:SetWidth(2)
        r.bar:SetColorTexture(Style.Color("gold"))
        r.bar:Hide()
        r:SetScript("OnMouseUp", function(self) if self.pickable then onPick(self.index) end end)
        r.index = i
        list.rows[i] = r
    end
    -- Where each row stands: its group's place, then its own in the group (rings and trinkets
    -- in their pairs' order).
    local function Place(rows)
        local order = {}
        for i, row in ipairs(rows) do
            for g, group in ipairs(GROUPS) do
                local at = group[2][row.slot.key]
                if at then order[#order + 1] = { i = i, g = g, at = at, n = row.equip } end
            end
        end
        table.sort(order, function(a, b)
            if a.g ~= b.g then return a.g < b.g end
            if a.at ~= b.at then return a.at < b.at end
            return a.n < b.n
        end)
        return order
    end
    function list:Paint(rows, stage, chosen, read)
        local y, group, counts = 0, nil, {}
        for _, row in ipairs(rows) do
            for g, gr in ipairs(GROUPS) do
                if gr[2][row.slot.key] and not (row.taken or row.none) then
                    counts[g] = counts[g] or { 0, 0 }
                    counts[g][2] = counts[g][2] + 1
                    if row.done then counts[g][1] = counts[g][1] + 1 end
                end
            end
        end
        for _, h in ipairs(self.heads) do h:Hide() end
        for _, at in ipairs(Place(rows)) do
            if at.g ~= group then
                group = at.g
                local h = self.heads[group]
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", 0, -y)
                local c = counts[group] or { 0, 0 }
                h.note:SetText(("%d of %d at your goal"):format(c[1], c[2]))
                h:Show()
                y = y + HEAD_H
            end
            local r, row = self.rows[at.i], rows[at.i]
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            y = y + rowH
        end
        for i, r in ipairs(self.rows) do
            local row = rows[i]
            r:SetShown(row ~= nil)
            local others = row and stage == Goal.BEFORE and (row.pick or row.goal or row.open) and Goal.Others(read, row, PICKS) or {}
            r.pickable = #others > 0
            r:EnableMouse(r.pickable)
            local on = r.pickable and chosen == i
            r.lit:SetShown(on)
            r.bar:SetShown(on)
            r.slot:SetTextColor(Style.Color(on and "gold" or "muted"))
            r.picks:SetTextColor(Style.Color(on and "gold" or "secondary"))
            local count = #others + ((row and (row.pick or row.goal)) and 1 or 0)
            r.picks:SetText(r.pickable and (count .. (count == 1 and " pick " or " picks ") .. "\226\128\186") or "")
            r.gain:SetText("")
            if row then
                r.slot:SetText(row.label:upper())
                r.item, r.equip, r.adds, r.lines = nil, nil, nil, nil
                local _, emptyTexture = GetInventorySlotInfo and GetInventorySlotInfo(row.slot.empty)
                if row.taken then
                    r.box.icon:SetTexture(emptyTexture)
                    r.name:SetText(MUTED .. "Taken by your two-hander|r")
                    r.where:SetText("")
                elseif row.open then
                    r.box.icon:SetTexture(emptyTexture)
                    r.name:SetText(MUTED .. "Empty: choose a piece|r")
                    r.where:SetText("")
                elseif row.goal then
                    local name, quality, texture = ItemInfo(row.goal.id)
                    local from = Goal.From(row.goal.e)
                    r.box.icon:SetTexture(texture)
                    r.name:SetText(Colored(name, quality or row.goal.e.quality))
                    r.gain:SetText(row.share and row.share > 0 and ("+%d%%"):format(math.max(1, math.floor(row.share * 100 + 0.5))) or "")
                    r.where:SetText(Gear.GoalSources(from, stage)[1] or "")
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
                -- The name as wide as it's written, up to the room the line leaves it; the
                -- source has what's left before the picks.
                r.name:SetWidth(0)
                local room = LEFT_W - NAME_X - GAIN_W - PICKS_W - 120
                r.name:SetWidth(math.min(Style.Wide(r.name, 200), room))
                r.where:SetWidth(math.max(40, LEFT_W - NAME_X - r.name:GetWidth() - Style.Wide(r.gain, 40) - PICKS_W - 30))
                r:Fit()
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
    Tipped(r, 46)
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
        self:Room(act and (Style.Wide(self.act.text, 130) + 24) or (chance and 110 or (chance == false and 100 or 14)))
    end
    -- The line under the name stops `right` short of the row's right edge, clear of what's there.
    function r:Room(right)
        self.sub:SetWidth(math.max(40, width - 46 - Style.Wide(self.name, 150) - 10 - right))
        self:Fit()
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
        self.count:SetText(("%d piece%s"):format(#run.pieces, #run.pieces == 1 and "" or "s"))
        -- The heading's line gives way whole, from the least needed: the zone, then the share
        -- of runs in its short form, then the share.
        local pct = run.any and math.max(1, math.floor(run.any * 100 + 0.5))
        local left = 14 + Style.Wide(self.name, 150) + (first and (10 + (self.tag:GetWidth() or 90)) or 0) + 10
        local right = 14 + (guide and (Style.Wide(self.open.text, 70) + 18) or 0) + Style.Wide(self.count, 60) + 8
        local room = width - left - right
        local long, short = pct and ("one in %d%% of runs"):format(pct) or "", pct and ("%d%% of runs"):format(pct) or ""
        self.share:SetText(long)
        if Style.Wide(self.share, 120) > room then self.share:SetText(short) end
        if Style.Wide(self.share, 80) > room then self.share:SetText("") end
        room = room - Style.Wide(self.share, 0) - 10
        self.zone:SetWidth(math.max(1, room))
        self.zone:SetWordWrap(false)
        self.zone:SetShown(room >= Style.Wide(self.zone, 80))
        self:SetHeight(RUN_HEAD + #run.pieces * PIECE_H + 4)
    end
    return card
end

-- The column: a heading, then a list that scrolls when a class has many places to go.
local function Runs(view, width, height, onUse, onAdd, onBack)
    local col = CreateFrame("Frame", nil, view)
    col:SetSize(width, height)
    col:SetPoint("TOPLEFT", LEFT_W + COL_GAP, -(HERO_H + HERO_GAP))
    local head = Style.Section(col, width)
    head:SetPoint("TOPLEFT")
    head.title:SetText("RUN NEXT")
    head.note:SetText("ranked by the pieces left for you")
    -- With a slot's picks showing, the way back to what to run, at the heading's right.
    local back = Words(col, "\226\128\185 Run next", onBack)
    back:SetPoint("RIGHT", head, "RIGHT", 0, 0)
    back:Hide()
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
    -- A chosen slot's other choices, at the column's top: the set's piece, then the weights'
    -- best, each with how it stands against it.
    local choiceHead = Style.Section(child, inner)
    local choiceCard = CreateFrame("Frame", nil, child)
    choiceCard:SetWidth(inner)
    Style.Box(choiceCard, 6, "well", "cardLine")
    -- Under the picks of WoWSims' set: their % are the weights', the set is the sims'.
    local weighed = Style.Text(child, 12, "muted")
    weighed:SetWidth(inner)
    weighed:SetJustifyH("LEFT")
    weighed:SetText("The % come from your stat weights, a rough guide. WoWSims' set comes from full sims: where they disagree, go by the set.")
    local runsHead = Style.Section(child, inner)
    runsHead.title:SetText("RUN NEXT")
    runsHead.note:SetText("ranked by the pieces left for you")
    local choices = {}
    local function Choice(i)
        if choices[i] then return choices[i] end
        local r = PieceRow(choiceCard, inner)
        -- The piece into the set (a change that waits to be saved): "Switch" for the piece in
        -- the place, "Choose" where the place is empty.
        r.use = Words(r, "Switch", function(self) onUse(self.id) end)
        r.use:SetPoint("RIGHT", -14, 0)
        r.against = Style.Text(r, 13, "muted")
        choices[i] = r
        return r
    end
    -- Any item for the slot: its ID, a link or a Wowhead address, as on Near your level.
    local addBox = Style.Field(choiceCard, inner - 28 - 70 - 8)
    addBox.hint = Style.Text(addBox.well, 12, "muted")
    addBox.hint:SetPoint("LEFT", 8, 0)
    addBox.hint:SetText("Add an item: its ID, a link or a Wowhead URL")
    addBox:SetScript("OnTextChanged", function(self) addBox.hint:SetShown(self:GetText() == "" and not self:HasFocus()) end)
    addBox:SetScript("OnEditFocusGained", function() addBox.hint:Hide() end)
    addBox:SetScript("OnEditFocusLost", function(self) addBox.hint:SetShown(self:GetText() == "") end)
    local addSaid = Style.Text(choiceCard, 12, "gold")
    local function Add()
        local said = onAdd(addBox:GetText())
        addSaid:SetText(said or "")
        if not said then addBox:SetText("") addBox:ClearFocus() end
    end
    local addButton = Style.Button(choiceCard, "Add", "plain", 70)
    addButton:SetHeight(26)
    addButton:SetPoint("LEFT", addBox.well, "RIGHT", 8, 0)
    addButton:SetScript("OnClick", Add)
    addBox:SetScript("OnEnterPressed", Add)
    -- Shift-clicking an item while the box has the cursor puts its link there.
    Style.TakesLinks(addBox, Gear)
    col.addBox = addBox
    local function Choices(choice)
        local shown = choice ~= nil
        choiceHead:SetShown(shown)
        choiceCard:SetShown(shown)
        weighed:SetShown(shown and choice.set ~= nil and not choice.own)
        runsHead:SetShown(shown)
        local pick = shown and (choice.row.pick or choice.row.goal)
        local n = shown and (#choice.others + (pick and 1 or 0)) or 0
        head.title:SetText(shown and (choice.row.label:upper() .. " · " .. n .. (n == 1 and " PICK" or " PICKS")) or "RUN NEXT")
        head.note:SetText(shown and "" or "ranked by the pieces left for you")
        back:SetShown(shown)
        if not shown then
            for _, r in ipairs(choices) do r:Hide() end
            return 0
        end
        local list = pick and { { pick = true, piece = pick } } or {}
        for _, o in ipairs(choice.others) do list[#list + 1] = o end
        for k, o in ipairs(list) do
            local r = Choice(k)
            local from = Goal.From(o.piece.e)
            local where = Gear.GoalSources(from, Goal.BEFORE)[1] or ""
            r:Set({ goal = o.piece, gains = nil }, Goal.BEFORE, (o.pick and ((choice.own or choice.draft) and "your pick · " or choice.set and "the pre-BiS pick · " or "your goal · ") or o.base and "WoWSims' pick · " or "") .. where, nil)
            r.against:SetText(o.pick and "|cffe3b04bpick|r" or (o.against and ("%+d%%"):format(math.floor(o.against * 100 + 0.5)) or ""))
            r.use.id = o.piece.id
            r.use.text:SetText(pick and "Switch" or "Choose")
            r.use:SetWidth(Style.Wide(r.use.text, 48))
            r.use:SetShown(not o.pick)
            r.against:ClearAllPoints()
            r.against:SetPoint("RIGHT", o.pick and r or r.use, o.pick and "RIGHT" or "LEFT", o.pick and -14 or -12, 0)
            -- Its source stops short of how it stands and Use this.
            r:Room(14 + (o.pick and 0 or (Style.Wide(r.use.text, 60) + 12)) + (r.against:GetText() ~= "" and (Style.Wide(r.against, 40) + 10) or 0))
            r.rule:SetShown(k > 1)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -((k - 1) * PIECE_H))
            r:Show()
        end
        for k = #list + 1, #choices do choices[k]:Hide() end
        local foot = #list * PIECE_H
        addBox.well:ClearAllPoints()
        addBox.well:SetPoint("TOPLEFT", choiceCard, "TOPLEFT", 14, -(foot + 8))
        addSaid:ClearAllPoints()
        addSaid:SetPoint("TOPLEFT", addBox.well, "BOTTOMLEFT", 0, -4)
        foot = foot + 44 + (addSaid:GetText() ~= "" and 16 or 0)
        choiceCard:ClearAllPoints()
        choiceCard:SetPoint("TOPLEFT", 0, 0)
        choiceCard:SetHeight(foot)
        if weighed:IsShown() then
            weighed:ClearAllPoints()
            weighed:SetPoint("TOPLEFT", choiceCard, "BOTTOMLEFT", 0, -8)
            foot = foot + 8 + math.max(weighed:GetStringHeight() or 0, 30)
        end
        runsHead:ClearAllPoints()
        runsHead:SetPoint("TOPLEFT", 0, -(foot + CARD_GAP + 6))
        return foot + CARD_GAP + 6 + HEAD_H + 2
    end
    function col:Paint(s, stage, choice)
        local y, used = Choices(choice), 0
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
        empty:SetShown(y == 0 and not choice)
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
    local showing, stage, retrying, chosen = false, Goal.BEFORE, false, nil
    -- `shownFor`: the spec the page was last drawn for, which a change is made on.
    local last, menu, draft, shownFor
    local function Keep()
        ns.char.prebis = type(ns.char.prebis) == "table" and ns.char.prebis or {}
        return ns.char.prebis
    end
    local function Refresh() if page.Refresh then page.Refresh() end end
    -- The goal's items as they stand before raids, for a new set: the set's, the weights', what you wear.
    local function Current()
        local ids = {}
        for i, row in ipairs(last and last[Goal.BEFORE].rows or {}) do
            ids[i] = (row.pick and row.pick.id) or (row.goal and row.goal.id) or (row.done and row.worn and row.worn.id) or 0
        end
        return ids
    end
    -- An item for the chosen slot. Into a set (WoWSims' or yours) it's a change that waits to be
    -- saved over your set, saved as a new one, or undone; with no set, a new set of yours.
    local function Use(id)
        local set = last and last.set
        if not (chosen and id) then return end
        if not set then
            local key = Goal.NewSet(Current(), nil)
            Keep().build = key
            Goal.SetSlot(key, chosen, id)
            return Refresh()
        end
        draft = draft or { ids = Current(), labels = {}, spec = shownFor, build = Keep().build or "", cheap = Keep().cheap or false }
        draft.ids[chosen] = id
        local row = last[Goal.BEFORE].rows[chosen]
        local label, said = row and row.label, false
        for _, l in ipairs(draft.labels) do
            if l == label then said = true end
        end
        if label and not said then draft.labels[#draft.labels + 1] = label end
        Refresh()
    end
    -- What the top card's buttons do with a change.
    local function Draft(what)
        local set = last and last.set
        if draft and set and what == "save" and set.own then
            Goal.SaveSet(set.key, draft.ids)
        elseif draft and set and what == "new" then
            local mine = set.own and Goal.OwnSet(set.key)
            Keep().build = Goal.NewSet(draft.ids, mine and mine.from or (not set.own and set.key) or nil)
        end
        draft = nil
        Refresh()
    end
    local function AddItem(text)
        local id = Gear.ParseItem and Gear.ParseItem(text)
        if not id then return "Paste an item ID or a Wowhead item link, or shift-click an item." end
        local fits = Goal.Fits(id, chosen)
        if fits == nil then
            if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
            return "Looking that item up... press Add again in a moment."
        end
        if not fits then return "That doesn't go in this slot." end
        Use(id)
    end
    local function Sets(what, key, words)
        if what == "choose" then
            Keep().build = key
        elseif what == "default" then
            Keep().build = Keep().base
        elseif what == "empty" then
            Keep().build = Goal.NewSet(nil, nil)
        elseif what == "new" then
            local set = last and last.set
            Keep().build = Goal.NewSet(Current(), set and (set.own and set.from or (not set.own and set.key)) or nil)
        elseif what == "rename" then
            Goal.RenameSet(key, words)
        elseif what == "delete" then
            Goal.DeleteSet(key)
            Keep().build = nil
        end
        if what ~= "rename" then draft = nil end
        Refresh()
    end
    local hero, list, runs, none, waiting
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
        end, function(build, cheap)
            -- Which of WoWSims' sets is your goal, kept for the character.
            -- A WoWSims build chosen is your default set from then on.
            if build then Keep().build, Keep().base = build, build end
            if cheap ~= nil then Keep().cheap = cheap end
            Refresh()
        end, function(bar)
            menu = menu or SetsMenu(view, Sets)
            local set = last and last.set
            local base
            for _, b in ipairs(set and set.builds or {}) do
                if b.key == (Keep().base or (not (set and set.own) and set.key)) then base = b.name end
            end
            base = base or (set and not set.own and set.name) or nil
            menu:Open(bar, set and set.own and set.key or nil, set and set.name or nil, base)
        end, Draft)
        list = SlotList(view, math.max(24, math.min(32, math.floor((body - #GROUPS * HEAD_H) / PLACES))), function(i)
            chosen = chosen ~= i and i or nil
            if page.Refresh then page.Refresh() end
        end)
        runs = Runs(view, width - LEFT_W - COL_GAP, body, Use, AddItem, function()
            chosen = nil
            Refresh()
        end)
        waiting = Waiting(view, width, body)
        none = Style.Text(view, 14, "muted")
        none:SetPoint("TOPLEFT", 0, -(HERO_H + HERO_GAP))
        none:SetWidth(width)
        none:SetJustifyH("LEFT")
        none:SetText("This spec has no stat weights yet, so there's no goal to work out. Add some under Weights.")
        local about = Style.About(view, "Before raids, where WoWSims Forever has a pre-raid set for your spec, your goal is that set, from its sims, which weigh the hit cap and a weapon and a bow as a pair; click a slot for its other choices, by the Gear plan's weights. Elsewhere your goal is the best piece for each slot at level 60 by those weights. It can be opened at any level.\n"
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
        local kept = type(ns.char.prebis) == "table" and ns.char.prebis or {}
        shownFor = spec
        -- A change waits only on the set, spec and cheap or full it was made on.
        if draft and (draft.spec ~= spec or draft.build ~= (kept.build or "") or draft.cheap ~= (kept.cheap or false)) then draft = nil end
        local read = Goal.Read(spec, kept.build, kept.cheap, draft and draft.ids)
        if read.set then read.set.draft, read.set.changed = draft and true or nil, draft and draft.labels or nil end
        last = read
        ns.Timed("Gear goal, working out", started)
        local has = not read.noWeights
        hero:SetShown(has)
        list:SetShown(has)
        runs:SetShown(has)
        none:SetShown(not has)
        local raids = has and stage == Goal.RAIDS
        waiting:SetShown(raids)
        list:SetAlpha(raids and 0.3 or 1)
        runs:SetAlpha(raids and 0.3 or 1)
        if has then
            hero:Paint(read, stage)
            local row = stage == Goal.BEFORE and chosen and read[stage].rows[chosen]
            -- A slot with picks stays chosen: a piece's, or an empty place of a set of yours.
            if not (row and (row.pick or row.goal or row.open)) then chosen, row = nil, nil end
            list:Paint(read[stage].rows, stage, chosen, read)
            runs:Paint(read[stage], stage, row and { row = row, others = Goal.Others(read, row, PICKS), own = read.set and read.set.own, set = read.set ~= nil, draft = read.set and read.set.draft } or nil)
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
