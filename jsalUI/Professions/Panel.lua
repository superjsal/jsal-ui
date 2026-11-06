-- A panel beside the profession window: your skill and the next rank, a
-- road there step by step (which recipe, how many, when to learn it), and
-- everything that road needs against what you have.
local _, ns = ...
local Style, Compat, Professions = ns.Style, ns.Compat, ns.Professions

local Panel = ns.NewModule("professionpanel", {
    title = "Profession road",
    note = "Beside the profession window: what to craft to reach the next rank.",
})

local WIDTH, PAD, STEP_H, ROW_H = 340, 14, 40, 28
local MAX_STEPS, MAX_ITEMS = 6, 8
-- The profession window, newer and older.
local TARGETS = {
    function() return ProfessionsFrame end,
    function() return TradeSkillFrame end,
}

local panel, anchor, dismissed
local hooked = {}
local steps, items = {}, {}

local function Line(name)
    if not name then return nil end
    local line = Professions.LineByName(name)
    if line then return line end
    for id, source in pairs(ns.ProfessionData) do
        if type(source) == "table" and source.name and name:find(source.name, 1, true) then return id end
    end
end

---------------------------------------------------------------------------
-- The frame.
---------------------------------------------------------------------------
local function Build()
    panel = CreateFrame("Frame", "jsalUIProfessionPanel", UIParent)
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
    panel.title = Style.Text(bar, 13, "text", nil, true)
    panel.title:SetPoint("LEFT", divider, "RIGHT", 10, 0)
    Style.CloseButton(bar, 36, function()
        dismissed = anchor
        panel:Hide()
    end):SetPoint("TOPRIGHT")

    panel.skill = Style.Text(panel, 11, "muted")
    panel.skill:SetPoint("TOPLEFT", PAD, -(36 + 12))
    panel.skill:SetWidth(WIDTH - PAD * 2)
    panel.track = CreateFrame("Frame", nil, panel)
    panel.track:SetSize(WIDTH - PAD * 2, 6)
    panel.track:SetPoint("TOPLEFT", PAD, -(36 + 32))
    Style.Fill(panel.track, "line")
    panel.fill = panel.track:CreateTexture(nil, "ARTWORK")
    panel.fill:SetPoint("TOPLEFT")
    panel.fill:SetPoint("BOTTOMLEFT")
    panel.fill:SetColorTexture(Style.Color("gold"))
    panel.marker = panel.track:CreateTexture(nil, "OVERLAY")
    panel.marker:SetColorTexture(Style.Color("text"))
    panel.marker:SetSize(2, 12)

    panel.roadHead = Style.Text(panel, 11, "gold", nil, true)
    panel.roadNote = Style.Text(panel, 11, "muted")
    panel.roadNote:SetJustifyH("RIGHT")
    panel.note = Style.Text(panel, 11, "muted")
    panel.note:SetWidth(WIDTH - PAD * 2)
    panel.rule = panel:CreateTexture(nil, "BORDER")
    panel.rule:SetColorTexture(Style.Color("line"))
    panel.rule:SetSize(WIDTH - PAD * 2, Compat.OnePixel(panel))
    panel.needHead = Style.Text(panel, 11, "gold", nil, true)
    panel.needHead:SetText("ALL YOU NEED")
    panel.needNote = Style.Text(panel, 11, "muted")
    panel.needNote:SetJustifyH("RIGHT")
    panel.needNote:SetText("bags and bank / need")
    panel.where = Style.Text(panel, 11, "muted")
    panel.where:SetWidth(WIDTH - PAD * 2)
    panel.pin = Style.Button(panel, "Show trainer on map", "primary", WIDTH - PAD * 2)
    panel.pin:SetHeight(28)
end

local function Tooltip(frame)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.item then GameTooltip:SetItemByID(self.item) elseif self.spell then GameTooltip:SetSpellByID(self.spell) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Step(i)
    local s = steps[i]
    if s then return s end
    s = CreateFrame("Frame", nil, panel)
    s:SetSize(WIDTH - PAD * 2, STEP_H)
    s.levels = Style.Text(s, 11, "muted", nil, true)
    s.levels:SetPoint("LEFT")
    s.levels:SetWidth(66)
    s.icon = s:CreateTexture(nil, "ARTWORK")
    s.icon:SetSize(22, 22)
    s.icon:SetPoint("LEFT", 70, 0)
    s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    s.name = Style.Text(s, 12, "text")
    s.name:SetPoint("BOTTOMLEFT", s.icon, "RIGHT", 10, 1)
    s.name:SetWidth(WIDTH - PAD * 2 - 102)
    s.name:SetWordWrap(false)
    s.detail = Style.Text(s, 11, "muted")
    s.detail:SetPoint("TOPLEFT", s.name, "BOTTOMLEFT", 0, -2)
    s.detail:SetWidth(WIDTH - PAD * 2 - 102)
    s.detail:SetWordWrap(false)
    Tooltip(s)
    steps[i] = s
    return s
end

local function Item(i)
    local r = items[i]
    if r then return r end
    r = CreateFrame("Frame", nil, panel)
    r:SetSize(WIDTH - PAD * 2, ROW_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(22, 22)
    r.icon:SetPoint("LEFT")
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = Style.Text(r, 12, "text")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 10, 0)
    r.name:SetWidth(170)
    r.name:SetWordWrap(false)
    r.count = Style.Text(r, 11, "muted")
    r.count:SetPoint("RIGHT")
    r.count:SetJustifyH("RIGHT")
    Tooltip(r)
    items[i] = r
    return r
end

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

-- A recipe's name: the item it makes, or the spell for an enchant.
local function RecipeName(recipe)
    return (recipe.item and Compat.ItemName(recipe.item)) or (Compat.SpellInfo(recipe.spell)) or "..."
end

local function RecipeIcon(recipe)
    return (recipe.item and Compat.ItemIcon(recipe.item)) or select(2, Compat.SpellInfo(recipe.spell))
end

---------------------------------------------------------------------------
-- Painting.
---------------------------------------------------------------------------
local function Paint()
    local name, skill, cap = Compat.OpenProfession()
    local line = Line(name)
    if not (line and skill and cap) then return panel:Hide() end
    panel.title:SetText(Professions.Name(line))

    -- Where the road goes: the skill the next rank is learned at while
    -- you're below it, else this rank's cap.
    local rank = Professions.Rank(cap)
    local target = (rank.at and skill < rank.at) and rank.at or cap
    local text = ("%d of %d · %s"):format(skill, cap, rank.name)
    if rank.at then
        text = text .. (" · %s from %d, level %d"):format(rank.next, rank.at, rank.level)
    end
    panel.skill:SetText(text)
    local width = WIDTH - PAD * 2
    panel.fill:SetWidth(math.max(1, width * math.min(1, skill / cap)))
    panel.marker:ClearAllPoints()
    panel.marker:SetPoint("CENTER", panel.track, "LEFT", width * target / cap, 0)
    panel.marker:SetShown(target < cap)

    -- What you know, asked once for the whole list, and kept for the
    -- Professions page, which can't ask while this window is closed.
    local known, saved = {}, {}
    for _, recipe in ipairs(Professions.Recipes(line)) do
        known[recipe.spell] = Compat.KnowsRecipe(recipe.spell)
        if known[recipe.spell] then saved[#saved + 1] = recipe.spell end
    end
    Professions.Remember(line, skill, cap, saved)
    local road, totals, stuck, made = Professions.Plan(line, skill, target, function(spell) return known[spell] end)

    local y = 36 + 52
    local crafts = 0
    for _, step in ipairs(road) do crafts = crafts + step.crafts end
    panel.roadHead:SetText(skill >= cap and "AT THE CAP" or ("YOUR WAY TO %d"):format(target))
    Place(panel.roadHead, y + 2)
    panel.roadNote:SetText(crafts > 0 and ("about %d craft%s"):format(crafts, crafts == 1 and "" or "s") or "")
    PlaceRight(panel.roadNote, y)
    y = y + 24

    local shown = 0
    for i, step in ipairs(road) do
        if i > MAX_STEPS then break end
        shown = i
        local s = Step(i)
        Place(s, y)
        s.item, s.spell = step.recipe.item, step.recipe.spell
        s.levels:SetText(("%d → %d"):format(step.from, step.to))
        s.icon:SetTexture(RecipeIcon(step.recipe))
        s.name:SetText(("%s ×%d"):format(RecipeName(step.recipe), step.crafts))
        if step.learn then
            s.detail:SetText(("Learn it at the trainer, from %d"):format(step.recipe.learn))
        elseif i == 1 then
            local can = Professions.CanMake(step.recipe)
            s.detail:SetText(can > 0 and ("|cff56944fYou can make %d|r"):format(can) or "Gather what it needs below")
        else
            local parts = {}
            for _, reagent in ipairs(step.recipe.reagents) do
                parts[#parts + 1] = ("%d %s"):format(reagent.count * step.crafts, Compat.ItemName(reagent.item) or "...")
            end
            s.detail:SetText("needs " .. table.concat(parts, ", "))
        end
        y = y + STEP_H
    end
    for i = shown + 1, #steps do steps[i]:Hide() end

    -- More steps than fit, or a road that stops short.
    local note
    if #road > MAX_STEPS then
        note = ("Then %d more step%s."):format(#road - MAX_STEPS, #road - MAX_STEPS == 1 and "" or "s")
    end
    if stuck then
        note = (note and (note .. " ") or "") .. ("Past %d, no recipe you know or can train gives skill: look for patterns."):format(stuck)
    elseif skill >= cap then
        note = rank.at and ("Learn %s at the trainer, at level %d, to go on."):format(rank.next, rank.level) or "That's as far as it goes."
    end
    if note then
        panel.note:SetText(note)
        Place(panel.note, y + 2)
        y = y + panel.note:GetStringHeight() + 8
    else
        panel.note:Hide()
    end

    -- Everything the road needs, the biggest shortfall first.
    local list = {}
    for item, need in pairs(totals) do
        list[#list + 1] = { item = item, need = need, have = Compat.ItemCount(item, true) }
    end
    table.sort(list, function(a, b)
        local sa, sb = a.need - a.have, b.need - b.have
        if sa ~= sb then return sa > sb end
        return a.item < b.item
    end)
    local count = 0
    if #list > 0 then
        y = y + 8
        Place(panel.rule, y)
        y = y + 12
        Place(panel.needHead, y + 2)
        PlaceRight(panel.needNote, y + 2)
        y = y + 24
        for i, entry in ipairs(list) do
            if i > MAX_ITEMS then break end
            count = i
            local r = Item(i)
            Place(r, y)
            r.item, r.spell = entry.item, nil
            r.icon:SetTexture(Compat.ItemIcon(entry.item))
            r.name:SetText(Compat.ItemName(entry.item) or "...")
            local color = entry.have >= entry.need and "56944f" or "ff6b6b"
            local price = Professions.IsVendor(entry.item)
            local extra = price and (" · vendor " .. Compat.Money(price))
                or (made[entry.item] and " · to make more" or "")
            r.count:SetText(("|cff%s%d|r / %d%s"):format(color, entry.have, entry.need, extra))
            y = y + ROW_H
        end
    else
        panel.rule:Hide()
        panel.needHead:Hide()
        panel.needNote:Hide()
    end
    for i = count + 1, #items do items[i]:Hide() end

    -- The nearest trainer who teaches your rank, or the next one once
    -- you're ready for it, with a map pin.
    local rankIndex = 1
    for i, r in ipairs(Professions.RANKS) do if r == rank then rankIndex = i end end
    local needed = (rank.at and skill >= rank.at) and rankIndex + 1 or rankIndex
    local trainer = ns.Trainers and ns.Trainers.Nearest("skill" .. line, needed)
    if trainer then
        y = y + 10
        local place = ns.Trainers.Zone(trainer)
        panel.where:SetText(("Nearest trainer: |cffece6d6%s|r%s"):format(trainer.name, place and (", " .. place) or ""))
        Place(panel.where, y)
        y = y + 22
        panel.pin:SetScript("OnClick", function() ns.Trainers.Pin(trainer) end)
        Place(panel.pin, y)
        y = y + 28
    else
        panel.where:Hide()
        panel.pin:Hide()
    end
    panel:SetHeight(y + PAD)
end

---------------------------------------------------------------------------
-- Opening beside the profession window.
---------------------------------------------------------------------------
local function OpenBeside(frame)
    if not Panel.running or dismissed == frame or not frame:IsShown() then return end
    if not panel then Build() end
    anchor = frame
    panel:SetFrameStrata(frame:GetFrameStrata())
    panel:SetFrameLevel(frame:GetFrameLevel() + 10)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 6, 0)
    panel:Show()
    xpcall(Paint, ns.Report)
end

local function Hook()
    if Compat.GamepadUI() then return end
    for _, find in ipairs(TARGETS) do
        local frame = find()
        if frame and not hooked[frame] then
            hooked[frame] = true
            -- Drawn a moment later, outside the game's own showing of it.
            frame:HookScript("OnShow", function()
                Compat.After(0.1, function() OpenBeside(frame) end)
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
    events:RegisterEvent("ADDON_LOADED")
    for _, event in ipairs({ "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "SKILL_LINES_CHANGED",
                             "BAG_UPDATE_DELAYED", "ITEM_DATA_LOAD_RESULT", "NEW_RECIPE_LEARNED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    -- A burst of updates (crafting, item names arriving) repaints once.
    local queued = false
    events:SetScript("OnEvent", function(_, event)
        if event == "ADDON_LOADED" then return Hook() end
        if not (panel and panel:IsShown()) or queued then return end
        queued = true
        Compat.After(0.3, function()
            queued = false
            if panel:IsShown() then xpcall(Paint, ns.Report) end
        end)
    end)
    self.events = events
    Hook()
end

function Panel:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
    if panel then panel:Hide() end
end
