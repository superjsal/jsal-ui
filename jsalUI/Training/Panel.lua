-- A small Training panel that opens beside the spellbook, a class, pet or
-- weapon trainer and Beast Training: what you can train now and what it
-- costs against your gold, what the next level brings, and where you trained
-- last, with a map pin and a way into the Training Planner. Beside a trainer
-- it shows only what that trainer teaches.
local _, ns = ...
local Style, Compat, Training, Window = ns.Style, ns.Compat, ns.Training, ns.Window

local Panel = ns.NewModule("trainingpanel", {
    title = "Training beside the spellbook",
    note = "What you can train now and next, beside the spellbook and at trainers.",
})

local WIDTH, PAD, ROW_H, MAX_ROWS = 330, 14, 30, 8
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
            for _, row in ipairs(t.rows) do
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

local function Row()
    used = used + 1
    local r = rows[used]
    if not r then
        r = CreateFrame("Frame", nil, panel)
        r:SetSize(WIDTH - PAD * 2, ROW_H)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(22, 22)
        r.icon:SetPoint("LEFT")
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = Style.Text(r, 12, "text")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 10, 0)
        r.name:SetWordWrap(false)
        r.rank = Style.Text(r, 11, "muted")
        r.rank:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
        r.price = Style.Text(r, 12, "text", nil, true)
        r.price:SetPoint("RIGHT")
        r.price:SetJustifyH("RIGHT")
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(self)
            if not self.spellID then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[used] = r
    end
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
    local word = Style.Wordmark(bar, 15)
    word:SetPoint("LEFT", mark, "RIGHT", 8, 0)
    local divider = bar:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(Style.Color("lineStrong"))
    divider:SetSize(Compat.OnePixel(bar), 16)
    divider:SetPoint("LEFT", word, "RIGHT", 10, 0)
    local title = Style.Text(bar, 13, "text", nil, true)
    title:SetPoint("LEFT", divider, "RIGHT", 10, 0)
    title:SetText("Training")
    Style.CloseButton(bar, 36, function()
        dismissed = anchor
        panel:Hide()
    end):SetPoint("TOPRIGHT")

    panel.nowHead = Style.Text(panel, 11, "gold", nil, true)
    panel.nowCost = Style.Text(panel, 13, "text", nil, true)
    panel.nowCost:SetJustifyH("RIGHT")
    panel.empty = Style.Text(panel, 12, "muted")
    panel.empty:SetWidth(WIDTH - PAD * 2)

    panel.track = CreateFrame("Frame", nil, panel)
    panel.track:SetSize(WIDTH - PAD * 2, 5)
    Style.Fill(panel.track, "line")
    panel.fill = panel.track:CreateTexture(nil, "ARTWORK")
    panel.fill:SetPoint("TOPLEFT")
    panel.fill:SetPoint("BOTTOMLEFT")
    panel.fill:SetColorTexture(Style.Color("gold"))
    panel.have = Style.Text(panel, 11, "muted")
    panel.spare = Style.Text(panel, 11, "muted")
    panel.spare:SetJustifyH("RIGHT")

    panel.rule1 = panel:CreateTexture(nil, "BORDER")
    panel.rule1:SetColorTexture(Style.Color("line"))
    panel.rule1:SetSize(WIDTH - PAD * 2, Compat.OnePixel(panel))
    panel.nextHead = Style.Text(panel, 11, "gold", nil, true)
    panel.nextCost = Style.Text(panel, 13, "text", nil, true)
    panel.nextCost:SetJustifyH("RIGHT")
    panel.more = Style.Text(panel, 11, "muted")

    panel.rule2 = panel:CreateTexture(nil, "BORDER")
    panel.rule2:SetColorTexture(Style.Color("line"))
    panel.rule2:SetSize(WIDTH - PAD * 2, Compat.OnePixel(panel))
    panel.where = Style.Text(panel, 11, "muted")
    panel.where:SetWidth(WIDTH - PAD * 2)

    panel.map = Style.Button(panel, "Show on map", "plain", 100)
    panel.map:SetHeight(28)
    panel.open = Style.Button(panel, "Open planner", "primary", 100)
    panel.open:SetHeight(28)
    panel.open:SetScript("OnClick", function() Window.Open("training") end)
    panel.train = Style.Button(panel, "Train all", "primary", 100)
    panel.train:SetHeight(28)
end

-- Buys everything the trainer offers now that isn't skipped. The list shows
-- only what can be learned while it runs, and goes from the last row up:
-- buying one renumbers the rows after it. Gold is counted down here, as the
-- game's own count only drops once the trainer answers.
local function TrainAll(skippedIDs, skippedNames)
    local saved = {}
    for _, kind in ipairs({ "available", "unavailable", "used" }) do
        saved[kind] = GetTrainerServiceTypeFilter(kind) and true or false
    end
    SetTrainerServiceTypeFilter("available", true)
    SetTrainerServiceTypeFilter("unavailable", false)
    SetTrainerServiceTypeFilter("used", false)
    local budget, bought, spent, short = GetMoney(), 0, 0, 0
    local ok, err = pcall(function()
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
    for kind, on in pairs(saved) do SetTrainerServiceTypeFilter(kind, on) end
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

local function SpellRows(list, y)
    for i, spell in ipairs(list) do
        if i > MAX_ROWS then break end
        local r = Row()
        Place(r, y)
        r.spellID = spell.id
        r.icon:SetTexture(spell.icon)
        -- A long name gives way before the rank and price.
        r.name:SetWidth(0)
        r.name:SetText(spell.name)
        r.name:SetWidth(math.min(r.name:GetStringWidth() + 2, 170))
        r.rank:SetText(spell.rank or "")
        r.price:SetText(PriceText(spell))
        y = y + ROW_H
    end
    return y
end

local function Paint()
    local data = Training.Read()
    if not data then panel:Hide() return end
    used = 0
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
    local nowHead, nextHead = ("READY NOW · LEVEL %d"):format(level), "NEXT · LEVEL %d"
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
            nowHead = ("READY NOW · %s, LEVEL %d"):format((pet.name or "PET"):upper(), pet.level or 0)
            nextHead = "NEXT · PET LEVEL %d"
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

    local y = 36 + 12
    panel.nowHead:SetText(nowHead)
    Place(panel.nowHead, y + 2)
    panel.nowCost:SetText(nowCost > 0 and Compat.Money(nowCost) or "")
    PlaceRight(panel.nowCost, y)
    y = y + 24
    if #now == 0 then
        panel.empty:SetText("Nothing to train right now.")
        Place(panel.empty, y)
        y = y + 22
        panel.track:Hide()
        panel.have:Hide()
        panel.spare:Hide()
    else
        panel.empty:Hide()
        y = SpellRows(now, y)
        if #now > MAX_ROWS then
            panel.more:SetText(("And %d more in the planner."):format(#now - MAX_ROWS))
            Place(panel.more, y)
            y = y + 18
        end
        -- The visit's total against your gold.
        y = y + 6
        Place(panel.track, y)
        panel.fill:SetWidth(math.max(1, (WIDTH - PAD * 2) * (nowCost > 0 and math.min(1, money / nowCost) or 1)))
        y = y + 11
        panel.have:SetText("You have " .. Compat.Money(money))
        Place(panel.have, y)
        if nowCost == 0 then
            panel.spare:SetText("")
        elseif money >= nowCost then
            panel.spare:SetText(Compat.Money(money - nowCost) .. " to spare")
        else
            panel.spare:SetText("|cffe3b04b" .. Compat.Money(nowCost - money) .. " short|r")
        end
        PlaceRight(panel.spare, y)
        y = y + 18
    end

    -- Next.
    if nextLevel then
        y = y + 8
        Place(panel.rule1, y)
        y = y + 12
        panel.nextHead:SetText(nextHead:format(nextLevel))
        Place(panel.nextHead, y + 2)
        panel.nextCost:SetText(nextCost > 0 and Compat.Money(nextCost) or "")
        PlaceRight(panel.nextCost, y)
        y = y + 24
        y = SpellRows(nextList, y)
    else
        panel.rule1:Hide()
        panel.nextHead:Hide()
        panel.nextCost:Hide()
    end
    if #now <= MAX_ROWS then panel.more:Hide() end

    y = y + 8
    Place(panel.rule2, y)
    y = y + 12
    local half = (WIDTH - PAD * 2 - 8) / 2

    -- At a class, pet or weapon trainer: train everything not skipped, and
    -- the planner.
    if context == "class" or context == "pet" or context == "weapons" then
        local skippedIDs, skippedNames = {}, {}
        for _, list in ipairs({ data.spells, data.weapons }) do
            for _, spell in ipairs(list) do
                if spell.skipped then
                    skippedIDs[spell.id] = true
                    skippedNames[spell.name .. "|" .. (spell.rank or "")] = true
                end
            end
        end
        panel.where:SetText("Train all buys everything here you haven't skipped.")
        Place(panel.where, y)
        y = y + 26
        panel.map:Hide()
        panel.train:SetLabel(nowCost > 0 and ("Train all · " .. Compat.Money(nowCost)) or "Train all")
        panel.train:SetEnabled(#now > 0)
        panel.train:SetScript("OnClick", function() TrainAll(skippedIDs, skippedNames) end)
        panel.train:SetWidth(WIDTH - PAD * 2 - 8 - 110)
        panel.open:SetWidth(110)
        panel.open:SetKind("plain")
        Place(panel.train, y)
        Place(panel.open, y, WIDTH - PAD - 110)
        y = y + 28 + PAD
        for i = used + 1, #rows do rows[i]:Hide() end
        panel:SetHeight(y)
        return
    end
    panel.train:Hide()
    panel.open:SetKind("primary")

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
    for i = 1, GetNumTrainerServices() do
        local info = C_TooltipInfo and C_TooltipInfo.GetTrainerService and C_TooltipInfo.GetTrainerService(i)
        local id = info and info.id
        if id and pets[id] then return "pet" end
        if id and weapons[id] then return "weapons" end
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
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 6, 0)
    xpcall(Paint, ns.Report)
    panel:Show()
end

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
            Compat.After(0.2, function()
                if panel:IsShown() then xpcall(Paint, ns.Report) end
            end)
        end
    end)
    self.events = events
    Hook()
end

function Panel:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
    if panel then panel:Hide() end
end
