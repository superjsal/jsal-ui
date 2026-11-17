-- A panel beside the profession window: where you stand in the rank, the
-- one thing to make now with what it takes, the steps after it one line
-- each (and when to train the next rank), and everything the road needs
-- against what you have.
local _, ns = ...
local Style, Compat, Professions, Road = ns.Style, ns.Compat, ns.Professions, ns.Road

local Panel = ns.NewModule("professionpanel", {
    title = "Profession road",
    note = "Beside the profession window: what to craft to reach the next rank.",
})

-- Wide enough to hold the road's prices beside each step.
local WIDTH, PAD, ROW_H = 440, 14, 30
-- A line of everything the road needs, and the row for training the next rank.
local NEED_H, RANK_H = 22, Road.RANK_H
local TAB_H = 26
local MAX_STEPS, MAX_ITEMS = 6, 8
-- The profession window, newer and older.
local TARGETS = {
    function() return ProfessionsFrame end,
    function() return TradeSkillFrame end,
}

local panel, anchor, dismissed
local Paint
-- The tab showing: the road with what it needs, or the recipes to learn.
local tab = "road"
local hooked = {}
local steps, items, unlearned = {}, {}, {}
local showAllUnlearned = false
local DETAIL_H = 42
local SOURCE = { [1] = "Trainer", [2] = "Vendor pattern", [3] = "Drop", [4] = "Quest" }

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
    panel.title = Style.Text(bar, 13, "text", nil, true)
    panel.title:SetPoint("LEFT", divider, "RIGHT", 10, 0)
    Style.CloseButton(bar, 36, function()
        dismissed = anchor
        panel:Hide()
    end):SetPoint("TOPRIGHT")

    -- Where you stand: the rank's name, your skill, and one bar from the
    -- rank's first point to its cap with the next rank's training marked.
    panel.skill = Style.Text(panel, 12, "muted")
    panel.skill:SetPoint("TOPLEFT", PAD, -(36 + 14))
    panel.points = Style.Text(panel, 17, "text", nil, true)
    panel.points:SetPoint("TOPRIGHT", -PAD, -(36 + 9))
    panel.points:SetJustifyH("RIGHT")
    panel.track = CreateFrame("Frame", nil, panel)
    panel.track:SetSize(WIDTH - PAD * 2, 6)
    panel.track:SetPoint("TOPLEFT", PAD, -(36 + 36))
    Style.Fill(panel.track, "line")
    panel.fill = panel.track:CreateTexture(nil, "ARTWORK")
    panel.fill:SetPoint("TOPLEFT")
    panel.fill:SetPoint("BOTTOMLEFT")
    panel.fill:SetColorTexture(Style.Color("gold"))
    panel.marker = panel.track:CreateTexture(nil, "OVERLAY")
    panel.marker:SetColorTexture(Style.Color("muted"))
    panel.marker:SetSize(Compat.OnePixel(panel), 12)
    panel.from = Style.Text(panel, 11, "muted")
    panel.from:SetPoint("TOPLEFT", panel.track, "BOTTOMLEFT", 0, -5)
    panel.cap = Style.Text(panel, 11, "muted")
    panel.cap:SetPoint("TOPRIGHT", panel.track, "BOTTOMRIGHT", 0, -5)
    panel.cap:SetJustifyH("RIGHT")
    panel.markText = Style.Text(panel, 11, "muted")

    -- Two tabs, when there are recipes to learn: the panel shows one list
    -- at a time, so it stays shorter than the screen.
    panel.tabs = Style.Tabs(panel, { { "road", "Your road" }, { "recipes", "Recipes to learn" } }, function(key)
        tab = key
        xpcall(Paint, ns.Report)
    end, WIDTH - PAD * 2, true)
    panel.tabs:SetPoint("TOPLEFT", PAD, -(36 + 68))

    panel.roadHead = Style.Text(panel, 12, "gold", nil, true)
    panel.roadNote = Style.Text(panel, 12, "muted")
    panel.roadNote:SetJustifyH("RIGHT")
    panel.thenHead = Style.Text(panel, 12, "gold", nil, true)
    panel.thenHead:SetText("THEN")
    panel.thenNote = Style.Text(panel, 12, "muted")
    panel.thenNote:SetJustifyH("RIGHT")
    panel.note = Style.Text(panel, 12, "muted")
    panel.note:SetWidth(WIDTH - PAD * 2)
    panel.rule = panel:CreateTexture(nil, "BORDER")
    panel.rule:SetColorTexture(Style.Color("line"))
    panel.rule:SetSize(WIDTH - PAD * 2, Compat.OnePixel(panel))
    panel.needHead = Style.Text(panel, 12, "gold", nil, true)
    panel.needNote = Style.Text(panel, 12, "muted")
    panel.needNote:SetJustifyH("RIGHT")
    panel.needNote:SetText("have / need")
    panel.where = Style.Text(panel, 12, "muted")
    panel.where:SetWidth(WIDTH - PAD * 2)
    panel.pin = Style.Button(panel, "Show trainer on map", "primary", WIDTH - PAD * 2)
    panel.pin:SetHeight(28)

    -- Recipes not learned yet: a rule, a heading with the count, and a
    -- "Show all" line under the first few.
    panel.rule2 = panel:CreateTexture(nil, "BORDER")
    panel.rule2:SetColorTexture(Style.Color("line"))
    panel.rule2:SetSize(WIDTH - PAD * 2, Compat.OnePixel(panel))
    panel.unlearnedHead = Style.Text(panel, 12, "gold", nil, true)
    panel.unlearnedHead:SetText("NOT LEARNED YET")
    panel.unlearnedCount = Style.Text(panel, 12, "muted")
    panel.unlearnedCount:SetJustifyH("RIGHT")
    panel.laterHead = Style.Text(panel, 12, "gold", nil, true)
    panel.laterHead:SetText("LATER")
    panel.laterCount = Style.Text(panel, 12, "muted")
    panel.laterCount:SetJustifyH("RIGHT")
    panel.showAll = CreateFrame("Button", nil, panel)
    panel.showAll:SetSize(WIDTH - PAD * 2, 18)
    panel.showAll.text = Style.Text(panel.showAll, 12, "muted")
    panel.showAll.text:SetPoint("LEFT")
end

-- The star beside a recipe: the game's favourite star, gold when on; a
-- plain dot where this client doesn't have that art.
local function SetStar(tex, on)
    local ok = tex.SetAtlas and pcall(tex.SetAtlas, tex, on and "auctionhouse-icon-favorite" or "auctionhouse-icon-favorite-off")
    if ok and tex.GetAtlas and tex:GetAtlas() then
        tex:SetVertexColor(1, 1, 1)
    else
        tex:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Chess\\dot")
        tex:SetVertexColor(Style.Color(on and "gold" or "lineStrong"))
    end
end

local function UnlearnedRow(i)
    local r = unlearned[i]
    if r then return r end
    r = CreateFrame("Frame", nil, panel)
    r:SetSize(WIDTH - PAD * 2, ROW_H)
    r.star = CreateFrame("Button", nil, r)
    r.star:SetSize(16, 16)
    r.star:SetPoint("LEFT")
    r.star.tex = r.star:CreateTexture(nil, "ARTWORK")
    r.star.tex:SetAllPoints()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT", 24, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.source = Style.Text(r, 12, "muted")
    r.source:SetPoint("RIGHT")
    r.source:SetJustifyH("RIGHT")
    r.name = Style.Text(r, 13, "text")
    r.name:SetWordWrap(false)
    r.where = Style.Text(r, 12, "muted")
    r.where:SetWordWrap(false)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.item then GameTooltip:SetItemByID(self.item) elseif self.spell then GameTooltip:SetSpellByID(self.spell) end
        local sources = self.detailed and ns.RecipeSourceText
        if sources and self.spell then
            GameTooltip:AddLine(" ")
            sources.Tooltip(GameTooltip, self.spell, self.faction)
            if self.canPin then GameTooltip:AddLine("Click for a map pin on the vendor.", 0.6, 0.59, 0.53) end
        end
        GameTooltip:AddLine("Click the star to keep it in your favourites.", 0.6, 0.59, 0.53)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnMouseUp", function(self)
        if self.detailed and self.canPin and self.spell then
            ns.RecipeSourceText.Pin(self.spell, self.faction)
        end
    end)
    Style.Hover(r, 6)
    unlearned[i] = r
    return r
end

-- A row on one line, or on two with where the recipe comes from under its
-- name and the skill it needs on the right.
local function LayoutRow(r, detailed)
    r:SetHeight(detailed and DETAIL_H or ROW_H)
    r.name:ClearAllPoints()
    r.source:ClearAllPoints()
    r.where:ClearAllPoints()
    if detailed then
        r.source:SetPoint("TOPRIGHT", 0, -5)
        r.name:SetPoint("TOPLEFT", 52, -5)
        r.name:SetPoint("TOPRIGHT", -34, -5)
        r.where:SetPoint("TOPLEFT", 52, -23)
        r.where:SetPoint("TOPRIGHT", 0, -23)
        r.where:Show()
    else
        r.source:SetPoint("RIGHT")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.name:SetPoint("RIGHT", r.source, "LEFT", -8, 0)
        r.where:Hide()
    end
end

-- The road's parts, each made the first time it's needed (Road.lua): a later
-- step's line, the card for the step in hand, and the row for training the
-- next rank.
local Needs, RecipeName, RecipeIcon = Road.Needs, Road.RecipeName, Road.RecipeIcon
local function Step(i)
    if not steps[i] then steps[i] = Road.Step(panel, WIDTH - PAD * 2, true) end
    return steps[i]
end

local function Card()
    if not panel.card then panel.card = Road.Card(panel, WIDTH - PAD * 2, true) end
    return panel.card
end

local function RankRow()
    if not panel.rankRow then panel.rankRow = Road.RankRow(panel, WIDTH - PAD * 2) end
    return panel.rankRow
end

-- One line of everything the road needs: its name, and have / need.
local function Item(i)
    local r = items[i]
    if r then return r end
    r = CreateFrame("Frame", nil, panel)
    r:SetSize(WIDTH - PAD * 2, NEED_H)
    r.count = Style.Text(r, 12, "muted")
    r.count:SetPoint("RIGHT")
    r.count:SetJustifyH("RIGHT")
    r.name = Style.Text(r, 12, "text")
    r.name:SetPoint("LEFT")
    r.name:SetPoint("RIGHT", r.count, "LEFT", -8, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    Style.ItemTip(r, Needs)
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

---------------------------------------------------------------------------
-- The recipes not learned yet, in groups: what your trainer teaches now,
-- what a vendor sells for coin (under each vendor's name once), what's
-- coming up, and the rest (drops, quests, reputations, other currencies)
-- behind one block to open. One long list of five hundred, with a world
-- drop and another side's quest at its head, was no help.
---------------------------------------------------------------------------
-- How many of a group show before the rest wait behind a line to click,
-- and how many an opened one shows at most (`many`).
local FEW = { trainer = 5, vendor = 3, vendors = 3, coming = 5, harder = 8, many = 12 }
-- What's been opened up: a group by name, a vendor by "v" and its ID. One
-- at a time, and never more than `many` of it, with the line that closes it
-- above its rows: an opened list ran off the bottom of the screen and took
-- its own "Show fewer" with it.
local opened = {}
local function Open(key)
    local was = opened[key]
    opened = { harder = (key == "harderAll") or nil }
    opened[key] = (not was) or nil
end

local function GroupHead(i)
    panel.heads = panel.heads or {}
    local h = panel.heads[i]
    if h then return h end
    h = { title = Style.Text(panel, 12, "gold", nil, true), note = Style.Text(panel, 12, "muted") }
    h.note:SetJustifyH("RIGHT")
    panel.heads[i] = h
    return h
end

-- A vendor's name over what they sell; a click pins them on the map.
local function VendorHead(i)
    panel.vendorHeads = panel.vendorHeads or {}
    local v = panel.vendorHeads[i]
    if v then return v end
    v = CreateFrame("Button", nil, panel)
    v:SetSize(WIDTH - PAD * 2, 24)
    Style.Fill(v, "well")
    v.link = Style.Text(v, 11, "gold")
    v.link:SetPoint("RIGHT", -10, 0)
    v.link:SetText("show on map")
    v.name = Style.Text(v, 12, "text", nil, true)
    v.name:SetPoint("LEFT", 10, 0)
    v.name:SetPoint("RIGHT", v.link, "LEFT", -8, 0)
    v.name:SetJustifyH("LEFT")
    v.name:SetWordWrap(false)
    v:SetScript("OnClick", function(self)
        if self.spell and ns.RecipeSourceText then ns.RecipeSourceText.Pin(self.spell, self.faction) end
    end)
    panel.vendorHeads[i] = v
    return v
end

-- "and 8 more · Show": opens a group up, or closes it again.
local function MoreLine(i)
    panel.mores = panel.mores or {}
    local m = panel.mores[i]
    if m then return m end
    m = CreateFrame("Button", nil, panel)
    m:SetSize(WIDTH - PAD * 2, 18)
    m.text = Style.Text(m, 11, "muted")
    m.text:SetPoint("LEFT", 52, 0)
    panel.mores[i] = m
    return m
end

local function HarderBlock()
    if panel.harder then return panel.harder end
    local b = CreateFrame("Button", nil, panel)
    b:SetSize(WIDTH - PAD * 2, 44)
    Style.Fill(b, "well")
    b.title = Style.Text(b, 12, "text", nil, true)
    b.title:SetPoint("TOPLEFT", 10, -7)
    b.title:SetText("Harder to get")
    b.link = Style.Text(b, 12, "gold")
    b.link:SetPoint("TOPRIGHT", -10, -7)
    b.sub = Style.Text(b, 11, "muted")
    b.sub:SetPoint("TOPLEFT", 10, -24)
    b.sub:SetWidth(WIDTH - PAD * 2 - 20)
    b.sub:SetJustifyH("LEFT")
    b.sub:SetWordWrap(false)
    b:SetScript("OnClick", function()
        Open("harder")
        xpcall(Paint, ns.Report)
    end)
    panel.harder = b
    return b
end

local function HideGroups()
    for _, h in ipairs(panel.heads or {}) do h.title:Hide(); h.note:Hide() end
    for _, v in ipairs(panel.vendorHeads or {}) do v:Hide() end
    for _, m in ipairs(panel.mores or {}) do m:Hide() end
    if panel.harder then panel.harder:Hide() end
end

-- Sorts the recipes not learned yet into their groups. Ones only the other
-- side can get are left out altogether.
local function Groups(missing, skill, sources, faction, favourites)
    local groups = { trainer = {}, vendors = {}, coming = {}, harder = {}, bought = 0, count = 0 }
    local byVendor = {}
    for _, recipe in ipairs(missing) do
        local kind, vendor = "trainer", nil
        if recipe.how ~= 1 then kind, vendor = sources.Kind(recipe.spell, faction) end
        if kind ~= "other" then groups.count = groups.count + 1 end
        if kind == "hard" then
            groups.harder[#groups.harder + 1] = recipe
        elseif kind ~= "other" and recipe.learn > skill then
            groups.coming[#groups.coming + 1] = recipe
        elseif kind == "trainer" then
            groups.trainer[#groups.trainer + 1] = recipe
        elseif kind == "vendor" then
            local group = byVendor[vendor.id]
            if not group then
                group = { vendor = vendor, list = {}, price = {} }
                byVendor[vendor.id] = group
                groups.vendors[#groups.vendors + 1] = group
            end
            group.list[#group.list + 1] = recipe
            group.price[recipe.spell] = vendor.copper
            groups.bought = groups.bought + 1
        end
    end
    local function Order(a, b)
        local fa, fb = favourites.Has(a.spell), favourites.Has(b.spell)
        if fa ~= fb then return fa end
        if a.learn ~= b.learn then return a.learn < b.learn end
        return a.spell < b.spell
    end
    table.sort(groups.trainer, Order)
    table.sort(groups.coming, function(a, b)
        if a.learn ~= b.learn then return a.learn < b.learn end
        return a.spell < b.spell
    end)
    table.sort(groups.harder, function(a, b)
        local ra, rb = a.learn <= skill, b.learn <= skill
        if ra ~= rb then return ra end
        return Order(a, b)
    end)
    for _, group in ipairs(groups.vendors) do table.sort(group.list, Order) end
    -- The vendor with the most to sell you first.
    table.sort(groups.vendors, function(a, b)
        if #a.list ~= #b.list then return #a.list > #b.list end
        return a.vendor.name < b.vendor.name
    end)
    return groups
end

local function PaintGroups(groups, y, skill, sources, faction, favourites)
    local heads, vendors, mores, listed = 0, 0, 0, 0
    local function Title(text, note)
        heads = heads + 1
        local h = GroupHead(heads)
        h.title:SetText(text)
        Place(h.title, y + 2)
        h.note:SetText(note or "")
        PlaceRight(h.note, y + 2)
        y = y + 24
    end
    -- One recipe: on one line with something at the right, or on two with
    -- where it comes from under its name.
    local function Row(recipe, right, color, where)
        listed = listed + 1
        local r = UnlearnedRow(listed)
        Place(r, y)
        LayoutRow(r, where ~= nil)
        r.item, r.spell = recipe.item, recipe.spell
        r.detailed, r.faction = true, faction
        r.icon:SetTexture(RecipeIcon(recipe))
        r.name:SetText(RecipeName(recipe))
        r.source:SetText(right or "")
        r.source:SetTextColor(Style.Color(color or "muted"))
        if where then r.where:SetText(where) end
        local vendor = where and sources.Vendors(recipe.spell, faction)[1]
        r.canPin = vendor and vendor.map and vendor.map > 0 or false
        SetStar(r.star.tex, favourites.Has(recipe.spell))
        r.star:SetScript("OnClick", function()
            favourites.Toggle(recipe.spell)
            xpcall(Paint, ns.Report)
        end)
        y = y + (where and DETAIL_H or ROW_H)
    end
    -- A line to click that opens a group or closes it; with no key, a
    -- line that only says how many more there are.
    local function More(key, text)
        mores = mores + 1
        local m = MoreLine(mores)
        m.text:SetText(key and opened[key] and "Show fewer" or text)
        m:SetScript("OnClick", key and function()
            Open(key)
            xpcall(Paint, ns.Report)
        end or nil)
        Place(m, y + 1)
        y = y + 22
    end
    -- Closed: the first few, then the line that opens the rest. Opened: the
    -- line that closes it, then up to `many`, then how many are left.
    local function List(list, key, few, right, color, rest)
        local open = opened[key] and #list > few
        if open then More(key, "") end
        local limit = open and math.min(#list, FEW.many) or few
        for i, recipe in ipairs(list) do
            if i > limit then break end
            Row(recipe, right and right(recipe), color)
        end
        if open and #list > limit then
            More(nil, ("and %d more"):format(#list - limit))
        elseif not open and #list > few then
            More(key, rest:format(#list - few))
        end
    end

    if #groups.trainer > 0 then
        Title("AT YOUR TRAINER NOW", #groups.trainer)
        List(groups.trainer, "trainer", FEW.trainer, nil, nil, "and %d more at your trainer · Show")
        y = y + 10
    end
    if #groups.vendors > 0 then
        Title("BUY FROM A VENDOR", groups.bought)
        local all = opened.vendors and #groups.vendors > FEW.vendors
        if all then More("vendors", "") end
        local limit = all and math.min(#groups.vendors, FEW.many) or FEW.vendors
        for i, group in ipairs(groups.vendors) do
            if i > limit then break end
            vendors = vendors + 1
            local v = VendorHead(vendors)
            local zone = sources.Area and sources.Area(group.vendor.area)
            v.name:SetText(group.vendor.name .. (zone and (", " .. zone) or ""))
            v.spell, v.faction = group.list[1].spell, faction
            v.link:SetShown((group.vendor.map or 0) > 0)
            Place(v, y)
            y = y + 28
            List(group.list, "v" .. group.vendor.id, FEW.vendor,
                function(recipe) return Compat.Money(group.price[recipe.spell]) end, "text",
                "and %d more from " .. group.vendor.name .. " · Show")
            y = y + 4
        end
        if all and #groups.vendors > limit then
            More(nil, ("and %d more vendors"):format(#groups.vendors - limit))
        elseif not all and #groups.vendors > FEW.vendors then
            More("vendors", ("and %d more vendors · Show"):format(#groups.vendors - FEW.vendors))
        end
        y = y + 6
    end
    if #groups.coming > 0 then
        Title("COMING UP", "at skill")
        List(groups.coming, "coming", FEW.coming, function(recipe) return recipe.learn end, "muted", "and %d more later · Show")
        y = y + 10
    end
    if #groups.harder > 0 then
        local b = HarderBlock()
        b.sub:SetText(("%d from drops, quests, reputations and special currencies"):format(#groups.harder))
        b.link:SetText(opened.harder and "Hide" or "Show")
        Place(b, y)
        y = y + 50
        if opened.harder then
            local all = opened.harderAll and #groups.harder > FEW.harder
            if all then More("harderAll", "") end
            local limit = all and math.min(#groups.harder, FEW.many) or FEW.harder
            for i, recipe in ipairs(groups.harder) do
                if i > limit then break end
                Row(recipe, recipe.learn, recipe.learn <= skill and "green" or "muted",
                    sources.Line(recipe.spell, faction) or SOURCE[recipe.how] or "Other")
            end
            if all and #groups.harder > limit then
                More(nil, ("and %d more"):format(#groups.harder - limit))
            elseif not all and #groups.harder > FEW.harder then
                More("harderAll", ("and %d more · Show more"):format(#groups.harder - FEW.harder))
            end
        end
    end
    return y, listed
end

---------------------------------------------------------------------------
-- Painting.
---------------------------------------------------------------------------
function Paint()
    local name, skill, cap = Compat.OpenProfession()
    local line = Line(name)
    if not (line and skill and cap) then return panel:Hide() end
    panel.title:SetText(Professions.Name(line))

    -- Where the road goes: the skill the next rank is learned at while
    -- you're below it, else this rank's cap.
    local rank = Professions.Rank(cap)
    -- The skill its next rank is learned at: the usual, or the profession's own.
    local rankAt = Professions.At(line, rank)
    local rankIndex = 1
    for i, r in ipairs(Professions.RANKS) do if r == rank then rankIndex = i end end
    local floor = rankIndex > 1 and Professions.RANKS[rankIndex - 1].cap or 0
    panel.skill:SetText(rank.name)
    panel.points:SetText(skill)
    local width = WIDTH - PAD * 2
    local span = math.max(1, cap - floor)
    panel.fill:SetWidth(math.max(1, width * math.max(0, math.min(1, (skill - floor) / span))))
    panel.from:SetText(floor)
    panel.cap:SetText(cap)
    -- The next rank can be trained before this one's cap: marked on the bar
    -- until you're there.
    local ahead = rankAt ~= nil and skill < rankAt
    panel.marker:SetShown(ahead)
    panel.markText:SetShown(ahead)
    panel.cap:Show()
    if ahead then
        local x = width * (rankAt - floor) / span
        panel.marker:ClearAllPoints()
        panel.marker:SetPoint("CENTER", panel.track, "LEFT", x, 0)
        panel.markText:SetText(("%d · train %s"):format(rankAt, rank.next))
        Road.PlaceMark(panel.markText, panel.track, x, width, panel.from, panel.cap, rankAt >= cap)
    end

    -- What you know, asked once for the whole list, and kept for the
    -- Professions page, which can't ask while this window is closed.
    local known, saved = {}, {}
    for _, recipe in ipairs(Professions.Recipes(line)) do
        known[recipe.spell] = Compat.KnowsRecipe(recipe.spell)
        if known[recipe.spell] then saved[#saved + 1] = recipe.spell end
    end
    Professions.Remember(line, skill, cap, saved)
    -- The road runs to this rank's cap, and no step runs across the skill
    -- the next rank is trained at, so that has a place of its own on it.
    local road, totals, stuck, made = Professions.Plan(line, skill, cap, function(spell) return known[spell] end, rankAt)

    -- Recipes not learned yet, with where each comes from: starred ones
    -- first, then by the skill they're learned at.
    local missing = {}
    local favourites = ns.ProfFavorites
    local wanted = ns.ProfWindow and ns.ProfWindow.On("unlearned") and favourites and not Professions.IsGathering(line)
    -- With "Where recipes come from" on: the ones your skill is high enough
    -- for come first, under their own heading, and each row names its source.
    local sources = wanted and ns.ProfWindow.On("sources") and ns.RecipeSourceText or nil
    local faction = sources and UnitFactionGroup and UnitFactionGroup("player") or nil
    local ready = 0
    local groups
    if wanted then
        for _, recipe in ipairs(Professions.Recipes(line)) do
            if not known[recipe.spell] then
                missing[#missing + 1] = recipe
                if sources and recipe.learn <= skill then ready = ready + 1 end
            end
        end
        -- With where each comes from known, they're sorted into groups.
        if sources and sources.Kind then groups = Groups(missing, skill, sources, faction, favourites) end
        table.sort(missing, function(a, b)
            if sources then
                local ra, rb = a.learn <= skill, b.learn <= skill
                if ra ~= rb then return ra end
            end
            local fa, fb = favourites.Has(a.spell), favourites.Has(b.spell)
            if fa ~= fb then return fa end
            if a.learn ~= b.learn then return a.learn < b.learn end
            return a.spell < b.spell
        end)
    end

    -- With recipes to learn there are two tabs; without, only the road.
    local view = (#missing > 0 and tab == "recipes") and "recipes" or "road"
    local y = 36 + 68
    panel.tabs:SetShown(#missing > 0)
    panel.tabs:Set("recipes", nil, groups and groups.count or #missing)
    panel.tabs:Pick(view)
    if #missing > 0 then y = y + TAB_H + 12 end

    local shown, count, listed, later, mats, ranked = 0, 0, 0, false, 0, false
    HideGroups()
    if view == "road" then
        local crafts = 0
        for _, step in ipairs(road) do crafts = crafts + step.crafts end
        local unit = Professions.IsGathering(line) and "vein" or "craft"

        -- Training the next rank: from the skill it opens at, or now.
        local function Rank(y)
            local r = RankRow()
            Road.PaintRank(r, line, rank, rankIndex, rankAt, skill)
            Place(r, y)
            ranked = true
            return RANK_H
        end

        -- The step in hand.
        local first = road[1]
        panel.roadHead:SetText(first and "DO THIS NOW" or (skill >= cap and "AT THE CAP" or "NOTHING TO MAKE YET"))
        Place(panel.roadHead, y + 2)
        panel.roadNote:SetText(first and ("%d → %d"):format(first.from, first.to) or "")
        PlaceRight(panel.roadNote, y + 2)
        y = y + 24
        if rankAt and skill >= rankAt then y = y + Rank(y) + 4 end
        if first then
            local card = Card()
            local recipe = first.recipe
            mats = Road.PaintCard(card, line, first, skill)
            Place(card, y)
            y = y + card:GetHeight() + 8
            -- The step's crafts onto the shopping list.
            local shop = ns.Shopping and ns.Shopping.running and not recipe.vein
            if shop then
                if not panel.addStep then
                    panel.addStep = Style.Button(panel, "Add this step to my shopping list", "plain", WIDTH - PAD * 2)
                    panel.addStep:SetHeight(26)
                end
                panel.addStep:SetScript("OnClick", function() ns.Shopping.AddCraft(recipe.spell, first.crafts) end)
                Place(panel.addStep, y)
                y = y + 34
            elseif panel.addStep then
                panel.addStep:Hide()
            end
        else
            if panel.card then panel.card:Hide() end
            if panel.addStep then panel.addStep:Hide() end
        end

        -- The steps after it, one line each, with the next rank's training
        -- where it falls among them.
        local more = #road > 1 or (rankAt ~= nil and skill < rankAt)
        if more then
            y = y + 8
            Place(panel.thenHead, y + 2)
            panel.thenNote:SetText(crafts > 0 and ("to %d · about %d %s%s"):format(cap, crafts, unit, crafts == 1 and "" or "s") or "")
            PlaceRight(panel.thenNote, y + 2)
            y = y + 24
        else
            panel.thenHead:Hide()
            panel.thenNote:Hide()
        end
        for i = 2, #road do
            if i - 1 > MAX_STEPS then break end
            local step = road[i]
            if not ranked and rankAt and step.from >= rankAt then y = y + Rank(y) end
            shown = i - 1
            local s = Step(shown)
            local tall = Road.PaintStep(s, step)
            Place(s, y)
            y = y + tall
        end
        -- A road that ends before the next rank opens still says when it does.
        if not ranked and rankAt and skill < rankAt and #road - 1 <= MAX_STEPS then y = y + Rank(y) end

        -- More steps than fit, or a road that stops short.
        local note
        if #road - 1 > MAX_STEPS then
            note = ("Then %d more step%s."):format(#road - 1 - MAX_STEPS, #road - 1 - MAX_STEPS == 1 and "" or "s")
        end
        if stuck then
            note = (note and (note .. " ") or "") .. ("Past %d, only patterns you'd have to find give skill."):format(stuck)
        elseif skill >= cap and not rankAt then
            note = "That's as far as it goes."
        end
        if note then
            panel.note:SetText(note)
            Place(panel.note, y + 4)
            y = y + panel.note:GetStringHeight() + 10
        else
            panel.note:Hide()
        end

        -- The whole road onto the shopping list at once.
        local crafting = {}
        for _, step in ipairs(road) do
            if not step.recipe.vein then crafting[#crafting + 1] = step end
        end
        if ns.Shopping and ns.Shopping.running and #crafting > 1 then
            if not panel.addRoad then
                panel.addRoad = Style.Button(panel, "Add the whole road to my shopping list", "plain", WIDTH - PAD * 2)
                panel.addRoad:SetHeight(26)
            end
            panel.addRoad:SetScript("OnClick", function()
                for _, step in ipairs(crafting) do ns.Shopping.AddCraft(step.recipe.spell, step.crafts) end
            end)
            Place(panel.addRoad, y + 4)
            y = y + 34
        elseif panel.addRoad then
            panel.addRoad:Hide()
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
        if #list > 0 then
            y = y + 8
            Place(panel.rule, y)
            y = y + 12
            panel.needHead:SetText(("EVERYTHING TO %d"):format(cap))
            Place(panel.needHead, y + 2)
            PlaceRight(panel.needNote, y + 2)
            y = y + 24
            for i, entry in ipairs(list) do
                if i > MAX_ITEMS then break end
                count = i
                local r = Item(i)
                Place(r, y)
                r.item, r.spell = entry.item, nil
                r.name:SetText(Compat.ItemName(entry.item) or "...")
                local color = entry.have >= entry.need and Style.hex.green or Style.hex.red
                r.count:SetText(("|cff%s%d|r / %d"):format(color, entry.have, entry.need))
                y = y + NEED_H
            end
            if #list > MAX_ITEMS then
                panel.needMore = panel.needMore or Style.Text(panel, 11, "muted")
                panel.needMore:SetText(("and %d more, in the shopping list"):format(#list - MAX_ITEMS))
                Place(panel.needMore, y + 2)
                y = y + 18
            elseif panel.needMore then
                panel.needMore:Hide()
            end
        else
            panel.rule:Hide()
            panel.needHead:Hide()
            panel.needNote:Hide()
            if panel.needMore then panel.needMore:Hide() end
        end
        panel.unlearnedHead:Hide()
        panel.unlearnedCount:Hide()
        panel.showAll:Hide()
    else
        for _, region in ipairs({ panel.roadHead, panel.roadNote, panel.thenHead, panel.thenNote, panel.note, panel.rule,
                                  panel.needHead, panel.needNote }) do
            region:Hide()
        end
        for _, key in ipairs({ "addRoad", "addStep", "card", "needMore" }) do
            if panel[key] then panel[key]:Hide() end
        end

        if groups then
            panel.unlearnedHead:Hide()
            panel.unlearnedCount:Hide()
            panel.showAll:Hide()
            y, listed = PaintGroups(groups, y, skill, sources, faction, favourites)
        else
            Place(panel.unlearnedHead, y + 2)
            panel.unlearnedHead:SetText(ready > 0 and "READY TO LEARN" or "NOT LEARNED YET")
            panel.unlearnedCount:SetText(ready > 0 and ready or #missing)
            PlaceRight(panel.unlearnedCount, y + 2)
            y = y + 24
            -- A tab of their own gives them room: more at first, and more again
            -- with Show all.
            local few = sources and 7 or 12
            local limit = showAllUnlearned and (sources and 14 or 22) or few
            for i, recipe in ipairs(missing) do
                if i > limit then break end
                listed = i
                if ready > 0 and i == ready + 1 then
                    y = y + 6
                    Place(panel.laterHead, y + 2)
                    panel.laterCount:SetText(#missing - ready)
                    PlaceRight(panel.laterCount, y + 2)
                    later = true
                    y = y + 24
                end
                local r = UnlearnedRow(i)
                Place(r, y)
                LayoutRow(r, sources ~= nil)
                r.item, r.spell = recipe.item, recipe.spell
                r.detailed, r.faction = sources ~= nil, faction
                r.icon:SetTexture(RecipeIcon(recipe))
                r.name:SetText(RecipeName(recipe))
                if sources then
                    r.source:SetText(recipe.learn)
                    r.source:SetTextColor(Style.Color(recipe.learn <= skill and "green" or "muted"))
                    r.where:SetText(sources.Line(recipe.spell, faction) or SOURCE[recipe.how] or "Other")
                    local vendor = sources.Vendors(recipe.spell, faction)[1]
                    r.canPin = vendor and vendor.map and vendor.map > 0 or false
                else
                    r.source:SetText(("%s · %d"):format(SOURCE[recipe.how] or "Other", recipe.learn))
                    r.source:SetTextColor(Style.Color("muted"))
                    r.canPin = false
                end
                SetStar(r.star.tex, favourites.Has(recipe.spell))
                r.star:SetScript("OnClick", function()
                    favourites.Toggle(recipe.spell)
                    xpcall(Paint, ns.Report)
                end)
                y = y + (sources and DETAIL_H or ROW_H)
            end
            if #missing > few then
                local rest = #missing - listed
                panel.showAll.text:SetText(showAllUnlearned
                    and (rest > 0 and ("%d more · Show fewer"):format(rest) or "Show fewer")
                    or ("%d more · Show all"):format(rest))
                panel.showAll:SetScript("OnClick", function()
                    showAllUnlearned = not showAllUnlearned
                    xpcall(Paint, ns.Report)
                end)
                Place(panel.showAll, y + 2)
                y = y + 22
            else
                panel.showAll:Hide()
            end
        end
    end
    for i = shown + 1, #steps do steps[i]:Hide() end
    if panel.card then
        for i = mats + 1, #panel.card.mats do panel.card.mats[i]:Hide() end
    end
    if panel.rankRow and not ranked then panel.rankRow:Hide() end
    for i = count + 1, #items do items[i]:Hide() end
    for i = listed + 1, #unlearned do unlearned[i]:Hide() end
    panel.rule2:Hide()
    if not later then
        panel.laterHead:Hide()
        panel.laterCount:Hide()
    end

    -- The nearest trainer who teaches your rank, or the next one once
    -- you're ready for it, with a map pin.
    local needed = (rankAt and skill >= rankAt) and rankIndex + 1 or rankIndex
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
-- Whether the panel belongs on screen: its window is open and the panel
-- wasn't closed there.
local function Wanted()
    return Panel.running and anchor ~= nil and anchor:IsShown() and dismissed ~= anchor
end

-- The game's own window can have tabs sticking out of its right edge (one
-- per profession); the panel starts after them, measured on screen and put
-- in its own scale. A reach of more than a tab's width is something else (an
-- open menu), so it's ignored.
-- The shopping list opens beside the window the same way.
function ns.TabsReach(frame, beside)
    local reach, right = 0, frame:GetRight()
    if right then
        local scale = frame:GetEffectiveScale()
        local edges = { frame:GetChildren() }
        edges[#edges + 1] = frame.ProfessionsOverviewTab
        for _, tab in ipairs(frame.rightProfessionTabs or {}) do edges[#edges + 1] = tab end
        for _, child in ipairs(edges) do
            local edge = child ~= beside and child:IsShown() and child:GetRight()
            if edge then
                local past = edge * child:GetEffectiveScale() - right * scale
                if past > reach and past <= 100 * scale then reach = past end
            end
        end
        reach = reach / beside:GetEffectiveScale()
    end
    return reach
end

local function PlaceBeside(frame)
    local reach = ns.TabsReach(frame, panel)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 6 + reach, 0)
end

-- The layer above a window's own, and never lower than jsal.ui's main
-- window's. On the profession window's layer the panel sat among other
-- addons' unit frames and bars, and they drew over it.
local LAYERS = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }
local function Above(strata)
    for i, layer in ipairs(LAYERS) do
        if layer == strata then return LAYERS[math.max(4, math.min(i + 1, #LAYERS))] end
    end
    return "DIALOG"
end

local function OpenBeside(frame)
    if not Panel.running or dismissed == frame or not frame:IsShown() then return end
    if not panel then Build() end
    anchor = frame
    panel:SetFrameStrata(Above(frame:GetFrameStrata()))
    panel:SetFrameLevel(10)
    PlaceBeside(frame)
    panel:Show()
    xpcall(Paint, ns.Report)
    -- The panel opens a frame after the window, when the tabs may not have
    -- settled yet, so it measures them again a moment later.
    Compat.After(0.1, function()
        if anchor == frame and frame:IsShown() then PlaceBeside(frame) end
    end)
    -- If the profession's details weren't in yet, look again every tenth of
    -- a second for up to a second.
    local tries = 0
    local function Retry()
        tries = tries + 1
        if anchor ~= frame or not Wanted() or panel:IsShown() or tries > 10 then return end
        panel:Show()
        xpcall(Paint, ns.Report)
        if not panel:IsShown() then Compat.After(0.1, Retry) end
    end
    if not panel:IsShown() then Compat.After(0.1, Retry) end
end

local function Hook()
    if Compat.GamepadUI() then return end
    for _, find in ipairs(TARGETS) do
        local frame = find()
        if frame and not hooked[frame] then
            hooked[frame] = true
            -- Drawn a frame later, outside the game's own showing of it.
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

-- Paints the panel again, if it is up.
function Panel.Refresh()
    if panel and panel:IsShown() then xpcall(Paint, ns.Report) end
end

function Panel:OnEnable()
    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    for _, event in ipairs({ "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "SKILL_LINES_CHANGED",
                             "BAG_UPDATE_DELAYED", "ITEM_DATA_LOAD_RESULT", "NEW_RECIPE_LEARNED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    -- A burst of updates (crafting, item names arriving) repaints once. On
    -- the first open after a reload the profession's details arrive after
    -- the window shows, so an update also brings back a panel that hid
    -- for lack of them, unless it was closed, and does it on the next frame.
    local queued = false
    events:SetScript("OnEvent", function(_, event)
        if event == "ADDON_LOADED" then return Hook() end
        if not (panel and Wanted()) or queued then return end
        queued = true
        Compat.After(panel:IsShown() and 0.3 or 0, function()
            queued = false
            if Wanted() then
                panel:Show()
                xpcall(Paint, ns.Report)
            end
        end)
    end)
    self.events = events
    Hook()
end

function Panel:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
    if panel then panel:Hide() end
end
