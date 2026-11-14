-- A small Training panel that opens beside the spellbook, a class, pet or
-- weapon trainer and Beast Training: how many spells you can train now and
-- what they cost, whether your gold covers it, the spells under column
-- headings, what the next level brings, and where you trained last, with a
-- map pin and a way into the Training Planner. Beside a trainer
-- it shows only what that trainer teaches; with its Settings switch on, it
-- stands in for the class, pet or weapon trainer's window, with a Train
-- button on each spell.
local _, ns = ...
local Style, Compat, Training, Window = ns.Style, ns.Compat, ns.Training, ns.Window

local Panel = ns.NewModule("trainingpanel", {
    title = "Training beside the spellbook",
    note = "What you can train now and next, beside the spellbook and at trainers.",
    options = {
        { key = "replace", title = "Use it in place of the game's trainer window", default = false,
          note = "At class, pet and weapon trainers: train each spell from the panel instead." },
    },
})

local WIDTH, PAD, ROW_H, MAX_ROWS = 330, 14, 30, 8
local TALL_H, LATER_H = 40, 26   -- a spell with its Train button; one of the next level's
-- The windows it opens beside. Forever's spellbook is the book inside
-- PlayerSpellsFrame, which loads on demand; older clients' is SpellBookFrame.
-- Class, pet and weapon trainers share the trainer window, and so does
-- Beast Training in Forever.
local TARGETS = {
    function() return PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame end,
    function() return not PlayerSpellsFrame and SpellBookFrame end,
    function() return ClassTrainerFrame end,
    function() return CraftFrame end,
}
local TAG = { quest = "Quest", book = "Book", portal = "Portal" }

local panel, anchor, dismissed, context
local hooked = {}

-- Spells at an odd level are trained on the next even one.
local function Stop(level)
    if level <= 1 then return 1 end
    return level + level % 2
end

-- Quest and book spells cost no gold.
local function Free(spell)
    return spell.via == "quest" or spell.via == "book"
end

-- The class trainer seen last: the most recent saved trainer whose list
-- teaches this class's spells.
local function LastTrainer(classID)
    local source = ns.SpellData[classID]
    if not source then return nil end
    local classSpells = {}
    for _, entry in ipairs(source.spells) do classSpells[entry[1]] = true end
    local best, bestKey
    for key, t in pairs(type(ns.db.trainers) == "table" and ns.db.trainers or {}) do
        if t.class == classID and type(t.rows) == "table" and not key:find("^%? @ ") then
            local teaches = false
            for _, row in ipairs(ns.TrainerPrices.RowsOf(t)) do
                if row.spell and classSpells[row.spell] then teaches = true break end
            end
            if teaches and (not best or (t.seen or 0) > (best.seen or 0)) then best, bestKey = t, key end
        end
    end
    if not best then return nil end
    -- The first visits saved only the "Name @ Zone" label, not the name.
    local npc, zone = best.npc, best.zone
    if not npc then npc, zone = bestKey:match("^(.-) @ ([^(]+)") end
    return best, npc or bestKey, zone and strtrim(zone) or nil
end

local function PriceText(spell)
    if spell.source == "beast" then
        return spell.points and (spell.points .. " TP") or "|cff9a9688? TP|r"
    elseif Free(spell) then
        return "|cff9a9688" .. TAG[spell.via] .. "|r"
    end
    return spell.cost and Compat.Money(spell.cost) or "|cff9a9688?|r"
end

---------------------------------------------------------------------------
-- The frame.
---------------------------------------------------------------------------
local rows, used = {}, 0

-- How wide a line of text is drawn, or a guess where that isn't known.
local function Wide(text, guess)
    local w = text.GetStringWidth and text:GetStringWidth()
    return (type(w) == "number" and w > 0) and w or guess
end

-- The rank number of a spell ("Rank 3" -> 3); none for one-rank spells.
local function RankNumber(rank)
    return rank and tonumber(rank:match("(%d+)")) or nil
end

-- A spell you don't have in any rank yet: tagged "new", where a higher rank
-- says which rank. A weapon master's skills are all new, so none is tagged.
local function New(spell)
    return context ~= "weapons" and (RankNumber(spell.rank) or 1) == 1
end

local function Row()
    used = used + 1
    local r = rows[used]
    if not r then
        r = CreateFrame("Frame", nil, panel)
        r:SetSize(WIDTH - PAD * 2, ROW_H)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetPoint("LEFT")
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = Style.Text(r, 13, "text")
        r.name:SetWordWrap(false)
        r.rank = Style.Text(r, 12, "muted")
        r.new = CreateFrame("Frame", nil, r)
        r.new.fill = Style.Fill(r.new, "gold")
        r.new.text = Style.Text(r.new, 10, "onGold", nil, true)
        r.new.text:SetPoint("CENTER")
        r.new.text:SetText("new")
        r.new:SetSize(Wide(r.new.text, 17) + 12, 15)
        r.price = Style.Text(r, 12, "text", nil, true)
        r.price:SetPoint("RIGHT")
        r.price:SetJustifyH("RIGHT")
        r.line = Style.Rule(r, "BOTTOM", "line")
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(self)
            if not self.spellID then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        Style.Hover(r, 6)
        -- Standing in for the trainer, a spell you can learn has its own
        -- Train button, and "skip" under its name; a skipped one, Unskip.
        r.train = Style.Button(r, "Train", "plain", 52)
        r.train:SetHeight(24)
        r.train:SetPoint("RIGHT")
        r.skip = CreateFrame("Button", nil, r)
        r.skip:SetSize(44, 18)
        r.skip.text = Style.Text(r.skip, 12, "muted")
        r.skip:SetScript("OnEnter", function(self) self.text:SetTextColor(Style.Color("gold")) end)
        r.skip:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color("muted")) end)
        -- A spell's name, and that it's new or its rank. `tall`: on two
        -- lines, the name over the rest, as a row with a Train button is.
        function r:Lay(spell, tall, nameW)
            self:SetHeight(tall and TALL_H or (self.later and LATER_H or ROW_H))
            self.icon:SetSize(tall and 26 or 20, tall and 26 or 20)
            self.icon:SetTexture(spell.icon)
            self.spellID = spell.id
            self.name:SetWidth(0)
            self.name:SetText(spell.name)
            self.name:SetWidth(math.min(Wide(self.name, #spell.name * 7) + 2, nameW))
            local fresh = New(spell)
            self.new:SetShown(fresh)
            self.rank:SetText(not fresh and spell.rank or "")
            self.name:ClearAllPoints()
            self.rank:ClearAllPoints()
            self.new:ClearAllPoints()
            if tall then
                self.name:SetPoint("BOTTOMLEFT", self.icon, "RIGHT", 10, 1)
                self.rank:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -3)
                self.new:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -2)
            else
                self.name:SetPoint("LEFT", self.icon, "RIGHT", 10, 0)
                self.rank:SetPoint("LEFT", self.name, "RIGHT", 8, 0)
                self.new:SetPoint("LEFT", self.name, "RIGHT", 8, 0)
            end
            self.line:SetShown(tall and true or false)
            self.price:SetText(PriceText(spell))
            self.price:ClearAllPoints()
            self.price:SetPoint("RIGHT")
            self.train:Hide()
            self.skip:Hide()
            self:SetAlpha(1)
        end
        rows[used] = r
    end
    r.later = nil
    r:Show()
    return r
end

local function Build()
    panel = CreateFrame("Frame", "jsalUITrainingPanel", UIParent)
    panel:SetWidth(WIDTH)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:Hide()
    Style.Fill(panel, "window")
    Style.Border(panel, "lineStrong")
    Style.Shadow(panel)

    local bar = CreateFrame("Frame", nil, panel)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(36)
    Style.Fill(bar, "titleBar")
    Style.Rule(bar, "BOTTOM", "line")
    local mark = bar:CreateTexture(nil, "ARTWORK")
    mark:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Logo")
    mark:SetSize(18, 18)
    mark:SetPoint("LEFT", 12, 0)
    local divider = bar:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(Style.Color("lineStrong"))
    divider:SetSize(Compat.OnePixel(bar), 16)
    divider:SetPoint("LEFT", mark, "RIGHT", 10, 0)
    local title = Style.Text(bar, 13, "text", nil, true)
    title:SetPoint("LEFT", divider, "RIGHT", 10, 0)
    title:SetText("Training")
    panel.title = title
    -- Standing in for the trainer, closing the panel ends the visit, as the
    -- game's own window would; beside a window, it only hides the panel.
    Style.CloseButton(bar, 36, function()
        if panel.standIn and anchor then return HideUIPanel(anchor) end
        dismissed = anchor
        panel:Hide()
    end):SetPoint("TOPRIGHT")
    panel.sub = Style.Text(panel, 12, "muted")
    panel.sub:SetWidth(WIDTH - PAD * 2)
    panel.sub:SetWordWrap(false)
    -- "+ 2 skipped ... show": the skipped spells, to take back.
    panel.skipped = CreateFrame("Button", nil, panel)
    panel.skipped:SetSize(WIDTH - PAD * 2, 20)
    panel.skipped.sign = Style.Text(panel.skipped, 14, "gold", nil, true)
    panel.skipped.sign:SetPoint("LEFT")
    panel.skipped.text = Style.Text(panel.skipped, 12, "secondary")
    panel.skipped.text:SetPoint("LEFT", 16, 0)
    panel.skipped.act = Style.Text(panel.skipped, 12, "muted")
    panel.skipped.act:SetPoint("RIGHT")
    panel.skipped.act:SetJustifyH("RIGHT")
    Style.Hover(panel.skipped, 6)

    -- The top: how many there are to train and what they cost, in a line you
    -- can read at a glance; under it, whether your gold covers it.
    panel.count = Style.Text(panel, 15, "text", nil, true)
    panel.nowCost = Style.Text(panel, 15, "gold", nil, true)
    panel.nowCost:SetJustifyH("RIGHT")
    panel.gold = Style.Text(panel, 12, "muted")
    panel.gold:SetWidth(WIDTH - PAD * 2)
    panel.gold:SetWordWrap(false)
    -- The column headings over the spells.
    panel.cols = CreateFrame("Frame", nil, panel)
    panel.cols:SetSize(WIDTH - PAD * 2, 18)
    local spellCol = Style.Text(panel.cols, 10, "muted", nil, true)
    spellCol:SetPoint("TOPLEFT")
    spellCol:SetText("SPELL")
    panel.cols.cost = Style.Text(panel.cols, 10, "muted", nil, true)
    panel.cols.cost:SetJustifyH("RIGHT")
    panel.cols.cost:SetText("COST")
    Style.Rule(panel.cols, "BOTTOM", "lineStrong")

    panel.nextHead = Style.Text(panel, 12, "gold", nil, true)
    panel.nextCost = Style.Text(panel, 13, "text", nil, true)
    panel.nextCost:SetJustifyH("RIGHT")
    panel.rule1 = panel:CreateTexture(nil, "BORDER")
    panel.rule1:SetColorTexture(Style.Color("lineStrong"))
    panel.rule1:SetSize(WIDTH - PAD * 2, Compat.OnePixel(panel))
    panel.more = Style.Text(panel, 12, "muted")

    panel.rule2 = panel:CreateTexture(nil, "BORDER")
    panel.rule2:SetColorTexture(Style.Color("line"))
    panel.rule2:SetSize(WIDTH - PAD * 2, Compat.OnePixel(panel))
    panel.where = Style.Text(panel, 12, "muted")
    panel.where:SetWidth(WIDTH - PAD * 2)

    panel.map = Style.Button(panel, "Show on map", "plain", 100)
    panel.map:SetHeight(28)
    panel.open = Style.Button(panel, "Open planner", "primary", 100)
    panel.open:SetHeight(28)
    panel.open:SetScript("OnClick", function() Window.Open("training") end)
    panel.train = Style.Button(panel, "Train all", "primary", 100)
    panel.train:SetHeight(32)
    -- Beside Open planner, at a trainer: what Train all leaves out.
    panel.note = Style.Text(panel, 11, "muted")
    panel.note:SetJustifyH("RIGHT")
    panel.note:SetText("skipped spells are left out")
end

-- Buying needs the rows that can be learned listed; the player's other two
-- filters stay as they are, as rows of any other kind are passed over.
local LEARNABLE = { available = true }

-- Buys everything the trainer offers now that isn't skipped, from the last
-- row up: buying one can renumber the rows after it. Gold is counted down
-- here, as the game's own count only drops once the trainer answers.
local function TrainAll(skippedIDs, skippedNames)
    local budget, bought, spent, short = GetMoney(), 0, 0, 0
    local ok, err = ns.TrainerPrices.WithFilters(LEARNABLE, function()
        for i = GetNumTrainerServices(), 1, -1 do
            local name, kind, rank = Compat.TrainerService(i)
            if name and kind == "available" then
                local info = C_TooltipInfo and C_TooltipInfo.GetTrainerService and C_TooltipInfo.GetTrainerService(i)
                local id = info and info.id
                if not rank and id and C_Spell and C_Spell.GetSpellSubtext then
                    rank = C_Spell.GetSpellSubtext(id)
                    if rank == "" then rank = nil end
                end
                if not ((id and skippedIDs[id]) or skippedNames[name .. "|" .. (rank or "")]) then
                    local cost = GetTrainerServiceCost(i) or 0
                    if cost <= budget then
                        BuyTrainerService(i)
                        budget, spent, bought = budget - cost, spent + cost, bought + 1
                    else
                        short = short + 1
                    end
                end
            end
        end
    end)
    if not ok then return ns.Report(err) end
    if bought == 0 and short == 0 then
        ns.Print("Nothing here to train that you haven't skipped.")
    else
        local line = ("Trained %d for %s."):format(bought, Compat.Money(spent))
        if short > 0 then
            line = line .. (" %d more need more gold than you have."):format(short)
        end
        ns.Print(line)
    end
end

-- The trainer's row for one spell, by its ID or else its name and rank.
local function TrainOne(spell)
    local result
    local ok, err = ns.TrainerPrices.WithFilters(LEARNABLE, function()
        for i = 1, GetNumTrainerServices() do
            local name, kind, rank = Compat.TrainerService(i)
            if name and kind == "available" then
                local info = C_TooltipInfo and C_TooltipInfo.GetTrainerService and C_TooltipInfo.GetTrainerService(i)
                local id = info and info.id
                if not rank and id and C_Spell and C_Spell.GetSpellSubtext then
                    rank = C_Spell.GetSpellSubtext(id)
                    if rank == "" then rank = nil end
                end
                if (id and id == spell.id) or (name == spell.name and (rank or "") == (spell.rank or "")) then
                    if (GetTrainerServiceCost(i) or 0) > GetMoney() then
                        result = "short"
                    else
                        BuyTrainerService(i)
                        result = "bought"
                    end
                    return
                end
            end
        end
    end)
    if not ok then return ns.Report(err) end
    if result == "short" then
        ns.Print(("%s needs more gold than you have."):format(spell.name))
    elseif not result then
        ns.Print(("This trainer doesn't teach %s right now."):format(spell.name))
    end
end

-- Standing in for the trainer: the game's window stays open (closing it
-- would end the visit, and nothing could be bought) but out of sight,
-- faded out, with an invisible cover over it so nothing of it can be
-- clicked. Its size is left alone: UI skins size their borders by it, and
-- a window shrunk away leaves them drawn far too thick. It comes back as
-- it was when the visit ends.
-- The cover and the panel sit a whole strata above the game's window: its
-- list rows and buttons are drawn at frame levels of their own, above any
-- level beside it, so in the window's own strata they still took clicks and
-- showed tooltips through the cover and over the panel's Train all.
local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
local function Above(strata)
    for i, s in ipairs(STRATA) do
        if s == strata then return STRATA[math.min(i + 1, #STRATA - 1)] end
    end
    return "DIALOG"
end
Panel.Above = Above

local concealed, cover
local function Conceal(frame)
    if concealed then return end
    concealed = { frame = frame, alpha = frame:GetAlpha() }
    frame:SetAlpha(0)
    if not cover then
        cover = CreateFrame("Frame", nil, UIParent)
        cover:EnableMouse(true)
        cover:EnableMouseWheel(true)
        cover:SetScript("OnMouseWheel", function() end)
    end
    cover:ClearAllPoints()
    cover:SetAllPoints(frame)
    cover:SetFrameStrata(Above(frame:GetFrameStrata()))
    cover:SetFrameLevel(1)
    cover:Show()
end

local function Reveal()
    if not concealed then return end
    concealed.frame:SetAlpha(concealed.alpha)
    concealed = nil
    if cover then cover:Hide() end
end

-- The panel's width: 330 beside a window, and wider standing in for the
-- trainer, where a spell also has its Train button: wide enough for the
-- longest trainer spell's name (Improved Demoralizing Shout, about 167px)
-- beside a price in gold and silver and the button.
local STAND_W = 390
local NAME_W = 172
local inner = WIDTH - PAD * 2
local function SetWidths(w)
    inner = w - PAD * 2
    panel:SetWidth(w)
    for _, f in ipairs({ panel.cols, panel.gold, panel.where, panel.sub, panel.skipped, panel.rule1, panel.rule2 }) do
        f:SetWidth(inner)
    end
    for _, r in ipairs(rows) do r:SetWidth(inner) end
end

local function StandsIn()
    return anchor == ClassTrainerFrame and ns.OptionOn("trainingpanel", "replace")
        and (context == "class" or context == "pet" or context == "weapons")
end

-- Places a line of the panel y down from its top, at the left margin or x.
local function Place(region, y, x)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", panel, "TOPLEFT", x or PAD, -y)
    region:Show()
end

local function PlaceRight(region, y)
    region:ClearAllPoints()
    region:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -y)
    region:Show()
end

-- The top of the list, from y: how many there are to train and what they
-- cost; whether your gold covers it, said once in a colour, where it was a
-- bar to read against two numbers; and the column headings. Returns the y
-- under it. `words` says what `count` things are; `costX` is how far in from
-- the right the prices are.
local function Head(y, count, words, cost, money, costX)
    panel.count:SetText(count > 0 and words or "Nothing to train right now")
    Place(panel.count, y)
    panel.nowCost:SetText(cost > 0 and Compat.Money(cost) or "")
    PlaceRight(panel.nowCost, y)
    y = y + 24
    if cost > 0 then
        local short = money < cost
        panel.gold:SetText(("You have %s:  %s"):format(Compat.Money(money), short
            and (Style.Tint("red") .. "short by " .. Compat.Money(cost - money) .. "|r")
            or (Style.Tint("green") .. "enough, " .. Compat.Money(money - cost) .. " left after|r")))
        Place(panel.gold, y)
        y = y + 22
    else
        panel.gold:Hide()
    end
    if count > 0 then
        y = y + 6
        panel.cols.cost:ClearAllPoints()
        panel.cols.cost:SetPoint("TOPRIGHT", -(costX or 0), 0)
        Place(panel.cols, y)
        y = y + 20
    else
        panel.cols:Hide()
    end
    return y
end

-- What there is to train, in words.
local function Count(n, pet)
    if context == "weapons" then return ("%d weapon skill%s to learn"):format(n, n == 1 and "" or "s") end
    if context == "beast" then return ("%d abilit%s to teach %s"):format(n, n == 1 and "y" or "ies", pet or "your pet") end
    return ("%d spell%s to train"):format(n, n == 1 and "" or "s")
end

-- What the next level brings: its heading, said once, with its cost, and a
-- greyed line for each spell. Returns the y under it.
local function Later(y, head, cost, list, most)
    panel.nextHead:SetText(head)
    Place(panel.nextHead, y + 1)
    panel.nextCost:SetText(cost > 0 and Compat.Money(cost) or "")
    PlaceRight(panel.nextCost, y)
    y = y + 22
    Place(panel.rule1, y)
    y = y + 4
    for i, spell in ipairs(list) do
        if i > most then break end
        local r = Row()
        r.later = true
        r:SetWidth(inner)
        Place(r, y)
        r:Lay(spell, false, 170)
        r:SetAlpha(0.7)
        y = y + LATER_H
    end
    return y
end

-- Train all, saying how many and for how much, and under it the planner.
local function Foot(y, data, count, cost)
    local skippedIDs, skippedNames = {}, {}
    for _, list in ipairs({ data.spells, data.weapons }) do
        for _, spell in ipairs(list) do
            if spell.skipped then
                skippedIDs[spell.id] = true
                skippedNames[spell.name .. "|" .. (spell.rank or "")] = true
            end
        end
    end
    panel.train:SetLabel(count > 0 and (("Train all %d"):format(count) .. (cost > 0 and ("  ·  " .. Compat.Money(cost)) or "")) or "Train all")
    panel.train:SetEnabled(count > 0)
    panel.train:SetScript("OnClick", function() TrainAll(skippedIDs, skippedNames) end)
    panel.train:SetWidth(inner)
    Place(panel.train, y)
    y = y + 32 + 8
    panel.open:SetWidth(110)
    panel.open:SetKind("plain")
    Place(panel.open, y)
    PlaceRight(panel.note, y + 7)
    return y + 28 + PAD
end

local PaintTrainer

local function Paint()
    local data = Training.Read()
    if not data then panel:Hide() return end
    used = 0
    panel.standIn = StandsIn()
    SetWidths(panel.standIn and STAND_W or WIDTH)
    panel.title:SetText("Training")
    panel.sub:Hide()
    panel.skipped:Hide()
    local level = UnitLevel("player")
    local money = GetMoney()

    -- Which spells belong beside this window: your own spells beside the
    -- spellbook (a pet's or demon's abilities have their own trainers); at a
    -- trainer, only what that trainer teaches.
    local function Belongs(spell)
        if context == "book" then return spell.source == nil end
        if context == "pet" then return spell.source == "pet" end
        if context == "class" then return spell.source == nil and spell.via == nil end
        return false
    end

    -- Ready now, and the spells of the next even level.
    local now, nextLevel, nextList = {}, nil, {}
    local nowCost, nextCost = 0, 0
    local nextHead, petName = "AT LEVEL %d", nil
    for _, spell in ipairs(data.spells) do
        if not spell.known and not spell.skipped and Belongs(spell) then
            if spell.level <= level then
                now[#now + 1] = spell
                if not Free(spell) and spell.cost then nowCost = nowCost + spell.cost end
            else
                local stop = Stop(spell.level)
                if not nextLevel or stop < nextLevel then nextLevel = stop end
            end
        end
    end
    for _, spell in ipairs(data.spells) do
        if not spell.known and not spell.skipped and Belongs(spell) and spell.level > level and Stop(spell.level) == nextLevel then
            nextList[#nextList + 1] = spell
            if not Free(spell) and spell.cost then nextCost = nextCost + spell.cost end
        end
    end
    -- A weapon master: the weapon skills still to learn.
    if context == "weapons" then
        for _, w in ipairs(data.weapons) do
            if not w.known and not w.skipped then
                now[#now + 1] = w
                if w.cost then nowCost = nowCost + w.cost end
            end
        end
    end
    -- At Beast Training: a hunter's pet abilities ready to teach, in
    -- training points, and the ones waiting on the pet's next level.
    if context == "beast" then
        local pet = Training.Pet()
        local function Entry(row)
            return {
                id = row.spell.pet, name = row.name, icon = row.icon,
                rank = row.spell.rank > 0 and ("Rank " .. row.spell.rank) or nil,
                source = "beast", points = row.points,
            }
        end
        for _, row in ipairs(pet and pet.rows or {}) do
            if row.state == "ready" and not row.skipped then now[#now + 1] = Entry(row) end
        end
        if pet and not pet.none then
            petName = pet.name
            nextHead = "AT PET LEVEL %d"
            for _, row in ipairs(pet.rows) do
                if row.state == "level" and not row.skipped and (not nextLevel or row.spell.level < nextLevel) then
                    nextLevel = row.spell.level
                end
            end
            for _, row in ipairs(pet.rows) do
                if row.state == "level" and not row.skipped and row.spell.level == nextLevel then
                    nextList[#nextList + 1] = Entry(row)
                end
            end
        end
    end

    if panel.standIn then
        return PaintTrainer(data, now, nowCost, nextLevel, nextList, nextCost, nextHead, Belongs)
    end

    local y = Head(36 + 12, #now, Count(#now, petName), nowCost, money)
    for i, spell in ipairs(now) do
        if i > MAX_ROWS then break end
        local r = Row()
        r:SetWidth(inner)
        Place(r, y)
        r:Lay(spell, false, 170)
        y = y + ROW_H
    end
    if #now > MAX_ROWS then
        panel.more:SetText(("And %d more in the planner."):format(#now - MAX_ROWS))
        Place(panel.more, y + 2)
        y = y + 20
    else
        panel.more:Hide()
    end

    -- What the next level brings.
    if nextLevel then
        y = Later(y + 14, nextHead:format(nextLevel), nextCost, nextList, MAX_ROWS)
    else
        panel.rule1:Hide()
        panel.nextHead:Hide()
        panel.nextCost:Hide()
    end

    y = y + 10
    -- At a class, pet or weapon trainer: train everything not skipped, and
    -- the planner.
    if context == "class" or context == "pet" or context == "weapons" then
        panel.rule2:Hide()
        panel.where:Hide()
        panel.map:Hide()
        y = Foot(y + 4, data, #now, nowCost)
        for i = used + 1, #rows do rows[i]:Hide() end
        panel:SetHeight(y)
        return
    end
    panel.train:Hide()
    panel.note:Hide()
    Place(panel.rule2, y)
    y = y + 12
    local half = (WIDTH - PAD * 2 - 8) / 2

    -- Elsewhere: your nearest class trainer with a map pin to them, or where
    -- you trained last, and the planner.
    local _, _, classID = UnitClass("player")
    local nearest = ns.Trainers and ns.Trainers.Nearest("class" .. classID)
    local trainer, npc, zone = LastTrainer(classID)
    local pin
    if nearest then
        local place = ns.Trainers.Zone(nearest)
        panel.where:SetText(place and ("Nearest trainer: |cffece6d6%s|r, %s"):format(nearest.name, place)
            or ("Nearest trainer: |cffece6d6%s|r"):format(nearest.name))
        pin = function() ns.Trainers.Pin(nearest) end
    elseif trainer then
        panel.where:SetText(zone and ("Trained last at |cffece6d6%s|r, %s"):format(npc, zone)
            or ("Trained last at |cffece6d6%s|r"):format(npc))
        if trainer.map and trainer.x then
            pin = function()
                ns.Trainers.Pin({ name = npc, map = trainer.map, x = trainer.x, y = trainer.y })
            end
        end
    else
        panel.where:SetText("Prices fill in when you open a class trainer.")
    end
    Place(panel.where, y)
    y = y + 26
    panel.map:SetShown(pin and true or false)
    panel.map:SetKind("primary")
    panel.open:SetKind(pin and "plain" or "primary")
    if pin then
        panel.map:SetWidth(half)
        panel.open:SetWidth(half)
        Place(panel.map, y)
        Place(panel.open, y, PAD + half + 8)
        panel.map:SetScript("OnClick", pin)
    else
        panel.open:SetWidth(WIDTH - PAD * 2)
        Place(panel.open, y)
    end
    y = y + 28 + PAD

    for i = used + 1, #rows do rows[i]:Hide() end
    panel:SetHeight(y)
end

---------------------------------------------------------------------------
-- Standing in for the trainer: who's teaching, each spell you can learn
-- with its Train button and "skip" under its name, the skipped spells to
-- take back, what the next level brings, and Train all.
---------------------------------------------------------------------------
-- The most spells listed with a Train button: Train all covers the rest,
-- and the panel stays on the screen.
local TRAIN_ROWS = 8
local showSkipped = false

PaintTrainer = function(data, now, nowCost, nextLevel, nextList, nextCost, nextHead, Belongs)
    local level, money = UnitLevel("player"), GetMoney()
    local who = context == "weapons" and "Weapon master" or context == "pet" and "Pet trainer"
        or ((UnitClass("player")) .. " trainer")
    panel.title:SetText(who)
    local npc = ns.Compat.Name("npc")
    local zone = GetSubZoneText and GetSubZoneText() ~= "" and GetSubZoneText() or (GetZoneText and GetZoneText()) or nil
    local y = 36 + 10
    panel.sub:SetText(("%s%s"):format(npc or "Trainer", zone and (", " .. zone) or ""))
    Place(panel.sub, y)
    y = y + 24

    -- Ready now: the name over its rank and "skip", its price, and Train.
    y = Head(y, #now, Count(#now), nowCost, money, 60)
    for i, spell in ipairs(now) do
        if i > TRAIN_ROWS then break end
        local r = Row()
        r:SetWidth(inner)
        Place(r, y)
        r:Lay(spell, true, NAME_W)
        r.price:ClearAllPoints()
        r.price:SetPoint("RIGHT", r.train, "LEFT", -8, 0)
        r.train:Show()
        r.train:SetScript("OnClick", function() TrainOne(spell) end)
        -- "skip" goes after the tag or the rank, on the line under the name.
        local fresh = r.new:IsShown()
        r.skip.text:ClearAllPoints()
        r.skip.text:SetPoint("LEFT")
        r.skip.text:SetJustifyH("LEFT")
        r.skip.text:SetText((fresh or not spell.rank) and "skip" or "·  skip")
        r.skip:ClearAllPoints()
        if fresh then
            r.skip:SetPoint("LEFT", r.new, "RIGHT", 8, 0)
        elseif spell.rank then
            r.skip:SetPoint("LEFT", r.rank, "RIGHT", 6, 0)
        else
            r.skip:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -1)
        end
        r.skip:Show()
        r.skip:SetScript("OnClick", function()
            Training.Skip(spell.id, true)
            xpcall(Paint, ns.Report)
        end)
        y = y + TALL_H
    end
    if #now > TRAIN_ROWS then
        panel.more:SetText(("And %d more: Train all covers them."):format(#now - TRAIN_ROWS))
        Place(panel.more, y + 4)
        y = y + 22
    else
        panel.more:Hide()
    end
    panel.map:Hide()
    panel.where:Hide()
    panel.rule2:Hide()

    -- The spells skipped here that you could learn now, to take back.
    local skipped = {}
    for _, spell in ipairs(data.spells) do
        if spell.skipped and not spell.known and Belongs(spell) and spell.level <= level then skipped[#skipped + 1] = spell end
    end
    if context == "weapons" then
        for _, w in ipairs(data.weapons) do
            if w.skipped and not w.known then skipped[#skipped + 1] = w end
        end
    end
    if #skipped > 0 then
        y = y + 6
        panel.skipped.sign:SetText(showSkipped and "-" or "+")
        panel.skipped.text:SetText(("%d skipped"):format(#skipped))
        panel.skipped.act:SetText(showSkipped and "hide" or "show")
        panel.skipped:SetScript("OnClick", function()
            showSkipped = not showSkipped
            xpcall(Paint, ns.Report)
        end)
        Place(panel.skipped, y)
        y = y + 24
        if showSkipped then
            for _, spell in ipairs(skipped) do
                local r = Row()
                r:SetWidth(inner)
                Place(r, y)
                r:Lay(spell, false, NAME_W)
                r:SetAlpha(0.7)
                r.price:ClearAllPoints()
                r.price:SetPoint("RIGHT", -52, 0)
                r.skip.text:ClearAllPoints()
                r.skip.text:SetPoint("RIGHT")
                r.skip.text:SetJustifyH("RIGHT")
                r.skip.text:SetText("Unskip")
                r.skip:ClearAllPoints()
                r.skip:SetPoint("RIGHT")
                r.skip:Show()
                r.skip:SetScript("OnClick", function()
                    Training.Skip(spell.id, false)
                    xpcall(Paint, ns.Report)
                end)
                y = y + ROW_H
            end
        end
    end

    -- What the next level brings, greyed: fewer of them when there's a lot
    -- to train now, so the panel stays on the screen.
    if nextLevel then
        y = Later(y + 14, nextHead:format(nextLevel), nextCost, nextList, math.max(2, math.min(5, 11 - math.min(#now, TRAIN_ROWS))))
    else
        panel.rule1:Hide()
        panel.nextHead:Hide()
        panel.nextCost:Hide()
    end

    y = Foot(y + 14, data, #now, nowCost)
    for i = used + 1, #rows do rows[i]:Hide() end
    panel:SetHeight(y)
end

---------------------------------------------------------------------------
-- Opening beside the spellbook and trainers.
---------------------------------------------------------------------------
-- What the trainer window open now teaches, from the spells its rows are:
-- "beast" (Beast Training, with no one on the other side), "pet" (a pet
-- trainer), "weapons" (a weapon master) or "class".
local function TrainerKind()
    if not UnitExists("npc") then return "beast" end
    local _, _, classID = UnitClass("player")
    local source = ns.SpellData[classID] or {}
    local pets, weapons = {}, {}
    for _, list in pairs(source.families or {}) do
        for _, entry in ipairs(list) do pets[entry[1]] = true end
    end
    for _, id in ipairs(source.weapons or {}) do weapons[id] = true end
    local function Of(id) return id and (pets[id] and "pet" or weapons[id] and "weapons") or nil end
    for i = 1, GetNumTrainerServices() do
        local info = C_TooltipInfo and C_TooltipInfo.GetTrainerService and C_TooltipInfo.GetTrainerService(i)
        local kind = Of(info and info.id)
        if kind then return kind end
    end
    -- The rows in sight may not say: the game's list can leave out what's
    -- learned, so a pet trainer with everything bought shows none at all,
    -- and looked like a class trainer (John, 13 Nov 2026, at a pet trainer:
    -- "bug, this is the pet trainer"). The visit saved for this trainer
    -- holds every row; and the pet trainers jsal.ui ships are known by name.
    local visit = ns.TrainerPrices.Here and ns.TrainerPrices.Here()
    for _, row in ipairs(visit and ns.TrainerPrices.RowsOf(visit) or {}) do
        local kind = Of(row.spell)
        if kind then return kind end
    end
    local name = Compat.Name("npc")
    for _, trainer in ipairs(ns.TrainerData and ns.TrainerData.pet or {}) do
        if name and trainer.name == name then return "pet" end
    end
    return "class"
end

local function OpenBeside(frame)
    if not Panel.running or dismissed == frame or not frame:IsShown() then return end
    -- A profession trainer teaches crafts, not class spells.
    if frame == ClassTrainerFrame and IsTradeskillTrainer and IsTradeskillTrainer() then return end
    if not panel then Build() end
    anchor = frame
    if frame == ClassTrainerFrame then
        local ok, kind = pcall(TrainerKind)
        context = ok and kind or "class"
    elseif frame == CraftFrame then
        context = "beast"
    else
        context = "book"
    end
    panel:SetFrameStrata(frame:GetFrameStrata())
    panel:SetFrameLevel(frame:GetFrameLevel() + 10)
    -- Standing in for the trainer: the game's window goes out of sight and
    -- the panel takes its place at the left of the screen.
    if StandsIn() then
        Conceal(frame)
        panel:SetFrameStrata(Above(frame:GetFrameStrata()))
        panel:SetFrameLevel(10)
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
        xpcall(Paint, ns.Report)
        panel:Show()
        return
    end
    if concealed and concealed.frame == frame then Reveal() end
    -- The spellbook is a page inside the spells window, starting below the
    -- window's title bar, so the panel lifts to line up with the window's top
    -- (measured on screen, then put in the panel's own scale).
    local lift = 0
    local window = PlayerSpellsFrame
    if window and frame == window.SpellBookFrame then
        local outer, inner = window:GetTop(), frame:GetTop()
        if outer and inner then
            lift = math.max(0, outer * window:GetEffectiveScale() - inner * frame:GetEffectiveScale()) / panel:GetEffectiveScale()
        end
    end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 6, lift)
    xpcall(Paint, ns.Report)
    panel:Show()
end

-- What the panel shows can change after it opens: a trainer's list fills in
-- a moment after its window does, and a first visit is saved a moment after
-- that. So each repaint looks again at what kind of trainer this is, and
-- opens afresh if the answer has changed.
local function Refresh()
    if not (panel and panel:IsShown()) then return end
    if anchor and anchor == ClassTrainerFrame then
        local ok, kind = pcall(TrainerKind)
        if ok and kind ~= context then OpenBeside(anchor) return end
    end
    xpcall(Paint, ns.Report)
end
Panel.Refresh = Refresh

local function Hook()
    if Compat.GamepadUI() then return end
    for _, find in ipairs(TARGETS) do
        local frame = find()
        if frame and not hooked[frame] then
            hooked[frame] = true
            -- Drawn a moment later, outside the game's own showing of the
            -- window, so nothing of ours runs inside it.
            frame:HookScript("OnShow", function()
                Compat.After(0, function() OpenBeside(frame) end)
            end)
            frame:HookScript("OnHide", function()
                if dismissed == frame then dismissed = nil end
                if concealed and concealed.frame == frame then Reveal() end
                if anchor == frame and panel then
                    panel:Hide()
                    anchor = nil
                end
            end)
            if frame:IsShown() then OpenBeside(frame) end
        end
    end
end

function Panel:OnEnable()
    local events = CreateFrame("Frame")
    -- The trainer window and the newer spellbook load with their own parts
    -- of the game, so each load is a chance to find them.
    events:RegisterEvent("ADDON_LOADED")
    for _, event in ipairs({ "PLAYER_MONEY", "SPELLS_CHANGED", "PLAYER_LEVEL_UP", "UNIT_PET", "TRAINER_UPDATE" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event)
        if event == "ADDON_LOADED" then
            Hook()
        elseif panel and panel:IsShown() then
            Compat.After(0.2, Refresh)
        end
    end)
    self.events = events
    -- A visit just saved has prices and levels the first paint didn't.
    if ns.TrainerPrices then ns.TrainerPrices.OnSaved = Refresh end
    Hook()
end

function Panel:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
    Reveal()
    if panel then panel:Hide() end
end
