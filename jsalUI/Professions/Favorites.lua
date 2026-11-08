-- Favourite recipes: starred in the profession panel's "Not learned yet",
-- saved per character. At a profession trainer who can teach any of them
-- now, a small window beside the trainer's lists them with their cost, to
-- learn one at a time or all at once.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local Favorites = {}
ns.ProfFavorites = Favorites

local function Saved()
    ns.char.profFavorites = type(ns.char.profFavorites) == "table" and ns.char.profFavorites or {}
    return ns.char.profFavorites
end

function Favorites.Has(spell) return Saved()[spell] == true end

function Favorites.Toggle(spell)
    Saved()[spell] = not Saved()[spell] or nil
end

local function On()
    return ns.ProfWindow and ns.ProfWindow.On("favorites")
end

---------------------------------------------------------------------------
-- The window beside the trainer.
---------------------------------------------------------------------------
local WIDTH, PAD, ROW_H = 330, 14, 30
local frame, rows = nil, {}

local function Build()
    frame = CreateFrame("Frame", "jsalUIFavouritesPanel", UIParent)
    frame:SetWidth(WIDTH)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    Style.Fill(frame, "window")
    Style.Border(frame, "lineStrong")
    Style.Shadow(frame)
    local bar = CreateFrame("Frame", nil, frame)
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
    title:SetText("Favourites to learn")
    Style.CloseButton(bar, 36, function() frame:Hide() end):SetPoint("TOPRIGHT")
    frame.have = Style.Text(frame, 11, "muted")
    frame.have:SetText("You have")
    frame.money = Style.Text(frame, 11, "text")
    frame.money:SetJustifyH("RIGHT")
    frame.all = Style.Button(frame, "Learn all", "primary", WIDTH - PAD * 2)
    frame.all:SetHeight(28)
end

local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, frame)
    r:SetSize(WIDTH - PAD * 2, ROW_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(22, 22)
    r.icon:SetPoint("LEFT")
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.learn = Style.Button(r, "Learn", "plain", 56)
    r.learn:SetHeight(22)
    r.learn:SetPoint("RIGHT")
    r.price = Style.Text(r, 12, "text", nil, true)
    r.price:SetPoint("RIGHT", r.learn, "LEFT", -8, 0)
    r.price:SetJustifyH("RIGHT")
    r.name = Style.Text(r, 12, "text")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 10, 0)
    r.name:SetPoint("RIGHT", r.price, "LEFT", -8, 0)
    r.name:SetWordWrap(false)
    rows[i] = r
    return r
end

-- The starred recipes' names, to pick out the trainer's rows worth a closer
-- look; nil when a name can't be had, and then every row is looked at.
local function StarredNames()
    local names = {}
    for id in pairs(Saved()) do
        local name = Compat.SpellInfo(id)
        if not name then return nil end
        names[name] = true
    end
    return names
end

-- The trainer's rows for starred recipes it can teach now: index, name,
-- icon, cost. Read as the trainer's list stands: changing its filters here
-- would set off another update, and another read. Only rows named like a
-- starred recipe are looked up by spell, since each lookup can make the
-- trainer redraw its list.
local function Offered()
    local list = {}
    if not next(Saved()) then return list end
    local names = StarredNames()
    local ok, err = pcall(function()
        for i = 1, GetNumTrainerServices() do
            local name, kind = Compat.TrainerService(i)
            local info = name and kind == "available" and (not names or names[name])
                and C_TooltipInfo and C_TooltipInfo.GetTrainerService and C_TooltipInfo.GetTrainerService(i)
            local id = info and info.id
            if id and Favorites.Has(id) then
                list[#list + 1] = { index = i, id = id, name = name, icon = GetTrainerServiceIcon and GetTrainerServiceIcon(i), cost = GetTrainerServiceCost(i) or 0 }
            end
        end
    end)
    if not ok then ns.Report(err) end
    return list
end

-- Buys by spell, with only what can be learned now listed, finding each
-- row again at the moment of buying (buying renumbers the list), highest
-- rows first so earlier ones keep their place. The filters go back after.
local function Learn(ids)
    local want = {}
    for _, id in ipairs(ids) do want[id] = true end
    local saved = {}
    for _, kind in ipairs({ "available", "unavailable", "used" }) do
        saved[kind] = GetTrainerServiceTypeFilter(kind) and true or false
    end
    SetTrainerServiceTypeFilter("available", true)
    SetTrainerServiceTypeFilter("unavailable", false)
    SetTrainerServiceTypeFilter("used", false)
    local list = Offered()
    local budget, bought = GetMoney(), 0
    local ok, err = pcall(function()
        for i = #list, 1, -1 do
            local s = list[i]
            if want[s.id] and s.cost <= budget then
                BuyTrainerService(s.index)
                budget, bought = budget - s.cost, bought + 1
            end
        end
    end)
    for kind, on in pairs(saved) do SetTrainerServiceTypeFilter(kind, on) end
    if not ok then return ns.Report(err) end
    if bought < #ids then ns.Print("Some favourites need more gold than you have.") end
end

-- The trainer fits each name against its price when it draws a row; a
-- redraw set off by the lookups above can fit them before the rows have
-- their full width, so the names are fitted again once it's settled.
local function RefitTrainerNames()
    local box = ClassTrainerFrame and ClassTrainerFrame:IsShown() and ClassTrainerFrame.ScrollBox
    if not (box and box.ForEachFrame) then return end
    box:ForEachFrame(function(button)
        if type(button.UpdateNameWidth) == "function" then pcall(button.UpdateNameWidth, button) end
    end)
end

local Paint
Paint = function()
    if not (On() and ClassTrainerFrame and ClassTrainerFrame:IsShown() and IsTradeskillTrainer and IsTradeskillTrainer()) then
        if frame then frame:Hide() end
        return
    end
    local list = Offered()
    if #list == 0 then
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    local y, total, ids = 36 + 10, 0, {}
    for i, s in ipairs(list) do
        local r = Row(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
        r.icon:SetTexture(s.icon)
        r.name:SetText(s.name)
        r.price:SetText(Compat.Money(s.cost))
        r.learn:SetScript("OnClick", function() Learn({ s.id }) end)
        r:Show()
        y = y + ROW_H
        total = total + s.cost
        ids[#ids + 1] = s.id
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    y = y + 8
    frame.have:ClearAllPoints()
    frame.have:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    frame.money:ClearAllPoints()
    frame.money:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -y)
    frame.money:SetText(Compat.Money(GetMoney()))
    y = y + 20
    frame.all:ClearAllPoints()
    frame.all:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    frame.all:SetLabel("Learn all · " .. Compat.Money(total))
    frame.all:SetScript("OnClick", function() Learn(ids) end)
    y = y + 28 + PAD
    frame:SetHeight(y)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", ClassTrainerFrame, "TOPRIGHT", 6, 0)
    frame:SetFrameStrata(ClassTrainerFrame:GetFrameStrata())
    frame:SetFrameLevel(ClassTrainerFrame:GetFrameLevel() + 10)
    frame:Show()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED", "PLAYER_MONEY", "TRAINER_SERVICE_INFO_NAME_UPDATE" }) do
    pcall(events.RegisterEvent, events, event)
end
local queued = false
events:SetScript("OnEvent", function(_, event)
    if event == "TRAINER_CLOSED" then
        if frame then frame:Hide() end
        return
    end
    -- The trainer redraws its list as names arrive: only the names are
    -- fitted again (reading the list here would ask for more names).
    if event == "TRAINER_SERVICE_INFO_NAME_UPDATE" then
        if On() then Compat.After(0.05, function() xpcall(RefitTrainerNames, ns.Report) end) end
        return
    end
    if queued then return end
    queued = true
    -- A moment later, so the trainer's own window is up and filled.
    Compat.After(0.2, function()
        queued = false
        xpcall(Paint, ns.Report)
        Compat.After(0.1, function() xpcall(RefitTrainerNames, ns.Report) end)
    end)
end)
