-- Additions to the game's profession window, each with its own switch: the
-- skill where each recipe turns yellow, green and grey; how many of each
-- reagent are in your bags and bank; a bar while you craft several; and a
-- heads-up when you can train a profession's next rank. (The recipes you
-- haven't learned and the favourites at a trainer are in the profession
-- panel and Favorites.lua, and take their switches from here.)
local _, ns = ...
local Style, Compat, Professions = ns.Style, ns.Compat, ns.Professions

local Window = ns.NewModule("profwindow", {
    title = "Profession window",
    note = "Small additions to the game's profession window and trainers.",
    options = {
        { key = "thresholds", title = "Skill-up thresholds", default = true,
          note = "On each recipe: the skill where it turns yellow, green and grey." },
        { key = "bank", title = "Reagents in bags and bank", default = true,
          note = "Beside each reagent: how many are in your bags and in the bank." },
        { key = "unlearned", title = "Recipes not learned yet", default = true,
          note = "In the profession panel, with where each comes from; star the ones you want." },
        { key = "favorites", title = "Favourites at trainers", default = true,
          note = "At a profession trainer: your starred recipes it can teach you now." },
        { key = "timer", title = "Craft timer", default = true,
          note = "While you craft several: how many are done and the time left." },
        { key = "rank", title = "Next rank alert", default = true,
          note = "A heads-up when you can train a profession's next rank." },
    },
})
ns.ProfWindow = Window

-- Whether a part is on: the module running and its switch on.
function Window.On(key)
    return Window.running and ns.OptionOn("profwindow", key)
end

-- Every recipe by its spell, across the professions.
local bySpell
local function RecipeFor(spell)
    if not bySpell then
        -- Only the professions: the data also holds vendor prices.
        local index = {}
        for line, source in pairs(ns.ProfessionData) do
            if type(source) == "table" and type(source.recipes) == "table" then
                for _, recipe in ipairs(Professions.Recipes(line) or {}) do index[recipe.spell] = recipe end
            end
        end
        bySpell = index
    end
    return spell and bySpell[spell]
end
Window.RecipeFor = RecipeFor

local function Guard(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns.Report(err) end
end

---------------------------------------------------------------------------
-- Skill-up thresholds: three small numbers at the right of each recipe in
-- the game's list. Its rows are reused as it scrolls, so each is redrawn
-- whenever the list fills it.
---------------------------------------------------------------------------
-- Green is halfway between yellow and grey, as the game works it out.
local function Thresholds(recipe)
    local green = math.floor((recipe.yellow + recipe.grey) / 2)
    return ("|cffffd84a%d|r  |cff5ec85e%d|r  |cff9d9d9d%d|r"):format(recipe.yellow, green, recipe.grey)
end

local function RecipeOfRow(row)
    local data = row.GetElementData and row:GetElementData()
    local node = data and data.GetData and data:GetData() or data
    local info = type(node) == "table" and node.recipeInfo
    return info and RecipeFor(info.recipeID)
end

local function DecorateRow(row)
    local recipe = Window.On("thresholds") and RecipeOfRow(row)
    if not recipe or recipe.yellow <= 0 then
        if row.jsalThresholds then row.jsalThresholds:Hide() end
        return
    end
    if not row.jsalThresholds then
        row.jsalThresholds = row:CreateFontString(nil, "OVERLAY")
        row.jsalThresholds:SetFont(Style.font, 10, "")
        row.jsalThresholds:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.jsalThresholds:SetJustifyH("RIGHT")
    end
    row.jsalThresholds:SetText(Thresholds(recipe))
    row.jsalThresholds:Show()
    -- The game sizes the name afresh each time it fills a row; a long one is
    -- cut short of the numbers (the game's tooltip then gives it in full).
    local label, count = row.Label, row.Count
    if type(label) == "table" and label.SetWidth and label.GetWidth then
        local countWidth = (type(count) == "table" and count:IsShown()) and count:GetStringWidth() or 0
        local left, right = label:GetLeft(), row:GetRight()
        local room
        if left and right then
            room = right - 8 - row.jsalThresholds:GetStringWidth() - 8 - countWidth - left
        else
            local skillUps = row.SkillUps and row.SkillUps:GetWidth() or 0
            room = row:GetWidth() - skillUps - 10 - 8 - row.jsalThresholds:GetStringWidth() - 8 - countWidth
        end
        if room > 20 and label:GetWidth() > room then label:SetWidth(room) end
    end
end

local listHooked
local function HookList()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local box = page and page.RecipeList and page.RecipeList.ScrollBox
    if listHooked or not box then return end
    listHooked = true
    -- Each row the list fills is handed to DecorateRow, whatever order the
    -- list's helper passes it in.
    local function Each(...)
        for i = 1, select("#", ...) do
            local frame = select(i, ...)
            if type(frame) == "table" and frame.GetElementData then return Guard(DecorateRow, frame) end
        end
    end
    if ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
        ScrollUtil.AddInitializedFrameCallback(box, Each, Window, true)
    elseif box.ForEachFrame then
        hooksecurefunc(box, "Update", function() box:ForEachFrame(function(frame) Guard(DecorateRow, frame) end) end)
    end
end

---------------------------------------------------------------------------
-- Reagents in bags and bank: under each reagent of the picked recipe.
---------------------------------------------------------------------------
local schematic

local function DecorateReagents()
    local slots = schematic and schematic.reagentSlots
    if type(slots) ~= "table" then return end
    for _, list in pairs(slots) do
        for _, slot in ipairs(type(list) == "table" and list or {}) do
            local info = slot.GetReagentSlotSchematic and slot:GetReagentSlotSchematic()
            local reagent = info and info.reagents and info.reagents[1]
            local item = reagent and reagent.itemID
            local under = slot.Name or slot.Button
            if item and under and Window.On("bank") then
                if not slot.jsalCount then
                    slot.jsalCount = slot:CreateFontString(nil, "OVERLAY")
                    slot.jsalCount:SetFont(Style.font, 10, "")
                    slot.jsalCount:SetTextColor(0.79, 0.71, 0.54)
                end
                slot.jsalCount:ClearAllPoints()
                slot.jsalCount:SetPoint("TOPLEFT", under, "BOTTOMLEFT", 0, -1)
                local bags = Compat.ItemCount(item, false)
                local bank = math.max(0, Compat.ItemCount(item, true) - bags)
                slot.jsalCount:SetText(("bags |cfff0e2c0%d|r · bank |cfff0e2c0%d|r"):format(bags, bank))
                slot.jsalCount:Show()
            elseif slot.jsalCount then
                slot.jsalCount:Hide()
            end
        end
    end
end

local formHooked
local function HookForm()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local form = page and page.SchematicForm
    if formHooked or not form then return end
    formHooked = true
    schematic = form
    if form.Init then
        hooksecurefunc(form, "Init", function() Guard(DecorateReagents) end)
    end
end

---------------------------------------------------------------------------
-- Craft timer: while you craft several of a recipe, a bar over the
-- profession window with what, how many are done and the time left.
---------------------------------------------------------------------------
local timer, run

local function BuildTimer()
    timer = CreateFrame("Frame", "jsalUICraftTimer", UIParent)
    timer:SetSize(420, 48)
    timer:SetFrameStrata("HIGH")
    timer:SetClampedToScreen(true)
    timer:Hide()
    Style.Fill(timer, "window")
    Style.Border(timer, "lineStrong")
    timer.time = Style.Text(timer, 18, "gold", nil, true)
    timer.time:SetPoint("LEFT", 14, 0)
    timer.time:SetWidth(50)
    timer.icon = timer:CreateTexture(nil, "ARTWORK")
    timer.icon:SetSize(28, 28)
    timer.icon:SetPoint("RIGHT", -12, 0)
    timer.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    timer.name = Style.Text(timer, 12, "text")
    timer.name:SetPoint("TOPLEFT", 74, -10)
    timer.name:SetWordWrap(false)
    timer.count = Style.Text(timer, 11, "muted")
    timer.count:SetPoint("TOPRIGHT", timer.icon, "TOPLEFT", -10, 2)
    timer.count:SetJustifyH("RIGHT")
    timer.track = CreateFrame("Frame", nil, timer)
    timer.track:SetPoint("TOPLEFT", 74, -28)
    timer.track:SetPoint("RIGHT", timer.icon, "LEFT", -10, 0)
    timer.track:SetHeight(8)
    Style.Fill(timer.track, "line")
    timer.fill = timer.track:CreateTexture(nil, "ARTWORK")
    timer.fill:SetPoint("TOPLEFT")
    timer.fill:SetPoint("BOTTOMLEFT")
    timer.fill:SetColorTexture(Style.Color("gold"))
end

local function PlaceTimer()
    timer:ClearAllPoints()
    if ProfessionsFrame and ProfessionsFrame:IsShown() then
        timer:SetPoint("BOTTOM", ProfessionsFrame, "TOP", 0, 8)
    else
        timer:SetPoint("TOP", UIParent, "TOP", 0, -160)
    end
end

local function PaintTimer()
    if not run then return end
    local now = GetTime()
    local castLeft = run.castEnd and math.max(0, run.castEnd - now) or 0
    local each = run.each or 0
    local left = castLeft + math.max(0, run.total - run.done - (run.castEnd and 1 or 0)) * each
    local partial = (run.castEnd and each > 0) and (1 - castLeft / each) or 0
    timer.time:SetText(("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60)))
    timer.count:SetText(("|cffece6d6%d / %d|r crafted"):format(run.done, run.total))
    timer.fill:SetWidth(math.max(1, timer.track:GetWidth() * math.min(1, (run.done + partial) / run.total)))
end

local function StopRun(after)
    run = nil
    if not timer then return end
    timer:SetScript("OnUpdate", nil)
    if after then
        Compat.After(after, function() if not run then timer:Hide() end end)
    else
        timer:Hide()
    end
end

local function StartRun(recipeID, count)
    count = tonumber(count) or 1
    if not Window.On("timer") or count < 2 or not recipeID then return end
    if not timer then BuildTimer() end
    local info = C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(recipeID)
    run = { spell = recipeID, total = count, done = 0 }
    timer.name:SetText(info and info.name or (Compat.SpellInfo(recipeID)) or "")
    timer.icon:SetTexture(info and info.icon or select(2, Compat.SpellInfo(recipeID)))
    PlaceTimer()
    PaintTimer()
    timer:Show()
    timer:SetScript("OnUpdate", function() Guard(PaintTimer) end)
end

local function OnCast(event, unit, _, spellID)
    if unit ~= "player" or not run or spellID ~= run.spell then return end
    if event == "UNIT_SPELLCAST_START" then
        local _, _, _, startMS, endMS = UnitCastingInfo("player")
        if startMS and endMS then
            run.each = (endMS - startMS) / 1000
            run.castEnd = endMS / 1000
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        run.done = run.done + 1
        run.castEnd = nil
        if run.done >= run.total then
            PaintTimer()
            StopRun(2)
        end
    else
        -- Interrupted, failed or stopped: the run is over.
        StopRun(1)
    end
end

---------------------------------------------------------------------------
-- Next rank alert: once per profession and rank, when your skill and level
-- are enough to train the next one, with the nearest trainer.
---------------------------------------------------------------------------
local function CheckRanks()
    if not Window.On("rank") then return end
    ns.char.rankAlerts = type(ns.char.rankAlerts) == "table" and ns.char.rankAlerts or {}
    local level = UnitLevel("player")
    for _, p in ipairs(Professions.Mine()) do
        local rank = Professions.Rank(p.cap)
        local index
        for i, r in ipairs(Professions.RANKS) do if r == rank then index = i end end
        local key = p.line .. ":" .. (index or 0)
        if rank.at and p.skill >= rank.at and level >= rank.level and not ns.char.rankAlerts[key] then
            ns.char.rankAlerts[key] = true
            local trainer = ns.Trainers and ns.Trainers.Nearest("skill" .. p.line, (index or 1) + 1)
            local place = trainer and ns.Trainers.Zone(trainer)
            local text = ("%s %d: you can train %s now."):format(p.name, p.skill, rank.next)
            if UIErrorsFrame then UIErrorsFrame:AddMessage(text, Style.Color("gold")) end
            ns.Print(text .. (trainer and (" Nearest trainer: %s%s."):format(trainer.name, place and (", " .. place) or "") or ""))
        end
    end
end

---------------------------------------------------------------------------
-- Starting.
---------------------------------------------------------------------------
local function HookWindow()
    Guard(HookList)
    Guard(HookForm)
end

function Window:OnEnable()
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "ADDON_LOADED", "TRADE_SKILL_SHOW", "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED",
                             "PLAYER_LEVEL_UP", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
                             "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_STOP" }) do
        pcall(events.RegisterEvent, events, event)
    end
    local queued = false
    events:SetScript("OnEvent", function(_, event, ...)
        if event == "ADDON_LOADED" or event == "TRADE_SKILL_SHOW" then
            HookWindow()
        elseif event == "BAG_UPDATE_DELAYED" then
            if schematic and schematic:IsVisible() then Guard(DecorateReagents) end
        elseif event:find("^UNIT_SPELLCAST_") then
            -- A stop right after a success is the cast ending normally.
            if event == "UNIT_SPELLCAST_STOP" then return end
            Guard(OnCast, event, ...)
        elseif not queued then
            queued = true
            Compat.After(1, function()
                queued = false
                Guard(CheckRanks)
            end)
        end
    end)
    self.events = events
    if C_TradeSkillUI and C_TradeSkillUI.CraftRecipe then
        hooksecurefunc(C_TradeSkillUI, "CraftRecipe", function(recipeID, count) Guard(StartRun, recipeID, count) end)
    end
    HookWindow()
    Compat.After(10, function() Guard(CheckRanks) end)
end

function Window:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
    StopRun()
end
