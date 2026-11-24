-- Fishing on the Professions page, a road of waters. Fishing has no crafts to plan, so its page is
-- its own: DO THIS NOW names the nearest water where no fish get away from you (your pole and lure
-- counted), with what players catch there; WHAT HELPS, your pole and lure and the next upgrades with
-- where each comes from; and the road to 300 across the bottom, a sign where it's time to change water
-- and a gold stop for each rank still to learn (a trainer's, the Expert book, Nat Pagle's quest). The
-- Professions page draws the top (the name, your skill, the row of professions) and hands the rest
-- here. Built once, when Fishing is first chosen; drawn when it's chosen, from what's read then.
local _, ns = ...
local Style, Compat, Road = ns.Style, ns.Compat, ns.Road

local FishingPage = {}
ns.FishingPage = FishingPage

local NOW_TOP, ROW_H, STRIP_H, HELP_H, SHOWN = 64, 30, 34, 44, 3
-- The road, as the Professions page lays its own: a stop every PITCH, STOP_W wide, the first FIRST_X
-- along; you stand YOU_X along the band; six stops fit across.
local PITCH, STOP_W, FIRST_X, YOU_X, BAND_H, ACROSS = 160, 152, 56, 30, 26, 6
local SIGN = Road.SIGN
local ROAD_H = Road.ACROSS_H + 4
local ORIGINAL = "Where fish get away is the original game's number, not yet Forever's."

-- The game's own name for a map.
local function ZoneName(map)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    return info and info.name or "..."
end

-- Puts the map pin where players fished from most in a zone, or says where that is.
local function PinWater(map)
    local c = ns.Fishing.Catches(map)
    if not c then return end
    local name = ZoneName(map)
    local set = ns.Waypoint and ns.Waypoint.Set or function(m, x, y) return Compat.SetWaypoint(m, x, y) end
    if set(map, c.x, c.y, name, "fishing") then
        ns.Print(("Map pin set where players fish most in %s."):format(name))
    else
        ns.Print(("Players fish most in %s at %.0f, %.0f."):format(name, c.x * 100, c.y * 100))
    end
end

-- Where a thing that helps comes from, in a word for its pill and a line under its name.
local function Source(g, level)
    local words, line
    if g.how == "vendor" then
        words = "vendor"
        local price = Compat.Money(g.copper or 0)
        if g.kind == "lure" then
            line = ("A lure for %d minutes, %s at fishing suppliers%s"):format(g.minutes or 10, price, g.limited and ", a few at a time" or "")
        elseif g.seller then
            line = ("%s from %s%s"):format(price, g.seller, g.limited and ", one at a time" or "")
        else
            line = ("%s at fishing suppliers"):format(price)
        end
    elseif g.how == "quest" then
        words = "quest"
        line = (g.from or 0) > 1 and ("%s, from level %d"):format(g.title, g.from) or g.title
    elseif g.how == "object" then
        words, line = "loot", ("From a %s in %s"):format(g.object, ZoneName(g.map))
    elseif g.how == "drop" then
        words, line = "drop", ("Dropped by %s"):format(g.npc)
    elseif g.how == "made" then
        words = "made"
        line = ("Made with %s"):format(Compat.ProfessionName(g.profession) or "Engineering")
    end
    if line and (g.level or 0) > (level or 0) and g.how ~= "quest" then line = line .. (", needs level %d"):format(g.level) end
    return words, line
end

---------------------------------------------------------------------------
-- The parts, made once.
---------------------------------------------------------------------------

-- DO THIS NOW: the water, its three most caught fish, a strip along its foot.
local function NowCard(page, width)
    local card = CreateFrame("Button", nil, page)
    card:SetWidth(width)
    Style.Box(card, 6, "well", "cardLine")
    card.edge = Style.Edge(card, 6)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(36, 36)
    card.icon:SetPoint("TOPLEFT", 14, -14)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.name = Style.Text(card, 15, "text", nil, true)
    card.name:SetPoint("TOPLEFT", 62, -14)
    card.name:SetPoint("RIGHT", -14, 0)
    card.name:SetWordWrap(false)
    card.detail = Style.Text(card, 12, "muted")
    card.detail:SetPoint("TOPLEFT", 62, -35)
    card.detail:SetPoint("RIGHT", -14, 0)
    card.detail:SetWordWrap(false)
    card.rows = {}
    for i = 1, SHOWN do
        local r = CreateFrame("Frame", nil, card)
        r:SetSize(width - 2, ROW_H)
        r:SetPoint("TOPLEFT", 1, -(NOW_TOP + (i - 1) * ROW_H))
        Style.Rule(r, "TOP", "line")
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(18, 18)
        r.icon:SetPoint("LEFT", 14, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.share = Style.Text(r, 13, "text")
        r.share:SetPoint("RIGHT", -14, 0)
        r.share:SetJustifyH("RIGHT")
        -- A short bar of the share, gold on the road's dark.
        r.track = r:CreateTexture(nil, "ARTWORK")
        r.track:SetColorTexture(Style.Color("lineStrong"))
        r.track:SetSize(60, 4)
        r.track:SetPoint("RIGHT", -60, 0)
        r.bar = r:CreateTexture(nil, "OVERLAY")
        r.bar:SetColorTexture(Style.Color("gold"))
        r.bar:SetHeight(4)
        r.bar:SetPoint("LEFT", r.track, "LEFT")
        r.name = Style.Text(r, 13, "text")
        r.name:SetPoint("LEFT", 42, 0)
        r.name:SetWordWrap(false)
        r.tag = Style.Tag(r, "cook", nil, true)
        r.tag:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
        Style.ItemTip(r, Road.Needs, nil, 0)
        card.rows[i] = r
    end
    card.strip = CreateFrame("Frame", nil, card)
    card.strip:SetPoint("BOTTOMLEFT", 1, 1)
    card.strip:SetPoint("BOTTOMRIGHT", -1, 1)
    card.strip:SetHeight(STRIP_H)
    Style.Cap(card.strip, 5, "titleBar", "BOTTOM")
    Style.Rule(card.strip, "TOP", "cardLine")
    card.foot = Style.Text(card.strip, 12, "muted")
    card.foot:SetPoint("LEFT", 13, 0)
    card.map = CreateFrame("Button", nil, card.strip)
    card.map.text = Style.Text(card.map, 12, "gold", nil, true)
    card.map.text:SetPoint("RIGHT")
    card.map.text:SetText("Show on map")
    card.map:SetSize(Style.Wide(card.map.text, 84), 22)
    card.map:SetPoint("RIGHT", -13, 0)
    card.map:SetScript("OnEnter", function(self) self.text:SetTextColor(Style.Color("goldHover")) end)
    card.map:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color("gold")) end)
    return card
end

-- WHAT HELPS: a row a thing, its picture, name and pill, where it comes from under, its bonus right.
local function HelpBox(page, width)
    local box = CreateFrame("Frame", nil, page)
    box:SetWidth(width)
    Style.Box(box, 6, "well", "cardLine")
    box.rows = {}
    for i = 1, 4 do
        local r = CreateFrame("Frame", nil, box)
        r:SetSize(width - 2, HELP_H)
        r:SetPoint("TOPLEFT", 1, -(1 + (i - 1) * HELP_H))
        if i > 1 then Style.Rule(r, "TOP", "line") end
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(26, 26)
        r.icon:SetPoint("LEFT", 13, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.bonus = Style.Text(r, 14, "text", nil, true)
        r.bonus:SetPoint("RIGHT", -14, 0)
        r.bonus:SetJustifyH("RIGHT")
        r.name = Style.Text(r, 13, "text")
        r.name:SetPoint("TOPLEFT", 50, -6)
        r.name:SetWordWrap(false)
        r.tag = Style.Tag(r, "", nil, true)
        r.tag:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
        r.sub = Style.Text(r, 11, "muted")
        r.sub:SetPoint("TOPLEFT", 50, -24)
        r.sub:SetPoint("RIGHT", r.bonus, "LEFT", -10, 0)
        r.sub:SetWordWrap(false)
        Style.ItemTip(r, Road.Needs, nil, 0)
        box.rows[i] = r
    end
    box.strip = CreateFrame("Frame", nil, box)
    box.strip:SetPoint("BOTTOMLEFT", 1, 1)
    box.strip:SetPoint("BOTTOMRIGHT", -1, 1)
    box.strip:SetHeight(STRIP_H)
    Style.Cap(box.strip, 5, "titleBar", "BOTTOM")
    Style.Rule(box.strip, "TOP", "cardLine")
    box.foot = Style.Text(box.strip, 12, "muted")
    box.foot:SetPoint("LEFT", 13, 0)
    box.foot:SetPoint("RIGHT", -13, 0)
    box.foot:SetWordWrap(false)
    -- The rest of what helps, in the strip's tooltip.
    box.strip:EnableMouse(true)
    box.strip:SetScript("OnEnter", function(self)
        if not (self.rest and #self.rest > 0) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("More that helps", Style.Color("gold"))
        for _, g in ipairs(self.rest) do
            local words, line = Source(g, UnitLevel("player"))
            GameTooltip:AddDoubleLine(Compat.ItemName(g.item) or "...", ("+%d"):format(g.bonus), 1, 1, 1, Style.Color("green"))
            if line then GameTooltip:AddLine((words and (words .. ": ") or "") .. line, Style.Color("muted")) end
        end
        GameTooltip:Show()
    end)
    box.strip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return box
end

-- A water on the road: a round sign at the skill where its fish stop getting away, the picture of
-- what's caught most there, the zones' names under it, and a cook tag or "no catches seen yet".
local function WaterStop(lane)
    local s = CreateFrame("Button", nil, lane)
    s:SetSize(STOP_W, Road.ACROSS_H)
    s.sign = CreateFrame("Frame", nil, s)
    s.sign:SetSize(SIGN, SIGN)
    s.sign:SetPoint("TOP")
    s.disc = Style.Circle(s.sign, "well", "lineStrong")
    s.level = Style.Text(s.sign, 12, "text", nil, true)
    s.level:SetPoint("CENTER")
    s.level:SetJustifyH("CENTER")
    s.icon = s:CreateTexture(nil, "ARTWORK")
    s.icon:SetSize(36, 36)
    s.icon:SetPoint("TOP", 0, -(SIGN + 12))
    s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    s.name = Style.Text(s, 13, "text")
    s.name:SetPoint("TOP", 0, -(SIGN + 12 + 36 + 6))
    s.name:SetSize(STOP_W - 12, 32)
    s.name:SetJustifyH("CENTER")
    s.name:SetJustifyV("TOP")
    s.note = Style.Text(s, 11, "muted")
    s.note:SetPoint("TOP", s.name, "BOTTOM", 0, 0)
    s.note:SetJustifyH("CENTER")
    s.tag = Style.Tag(s, "cook", nil, true)
    s.tag:SetPoint("TOP", s.name, "BOTTOM", 0, 0)
    s:SetScript("OnClick", function(self) if self.pin then PinWater(self.pin) end end)
    s:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(("No fish get away from %d"):format(self.at or 0), Style.Color("text"))
        for _, map in ipairs(self.zones or {}) do
            local c = ns.Fishing.Catches(map)
            local top = c and c.list[1]
            GameTooltip:AddDoubleLine(ZoneName(map), top and (("%s %d%%"):format(Compat.ItemName(top.item) or "...", top.share)) or "no catches seen yet",
                1, 1, 1, Style.Color(top and "secondary" or "muted"))
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Where fish stop getting away is the original game's number.", Style.Color("muted"))
        if self.pin then GameTooltip:AddLine("Click to show where players fish there on your map.", Style.Color("muted")) end
        GameTooltip:Show()
    end)
    s:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Style.Hover(s, 0)
    return s
end

---------------------------------------------------------------------------
-- The page.
---------------------------------------------------------------------------

-- Makes Fishing's parts on the Professions page. `o`: the page's width, where the cards start down
-- it (bodyY), a card's width, where the right card starts, and the skill's number at the top right.
function FishingPage.Build(page, o)
    local width, bodyY, cardW, rightX = o.width, o.bodyY, o.cardW, o.rightX
    local view = { parts = {} }
    local function Part(region) view.parts[#view.parts + 1] = region return region end

    -- Under your skill at the top right: what your pole and lure add.
    local bonus = Part(Style.Text(page, 13, "muted"))
    bonus:SetPoint("TOPRIGHT", o.points, "BOTTOMRIGHT", 0, -4)
    bonus:SetJustifyH("RIGHT")

    local nowHead = Part(Style.Section(page, cardW))
    nowHead.title:SetText("DO THIS NOW")
    local card = Part(NowCard(page, cardW))
    local fine = Part(Style.Text(page, 12, "muted"))
    fine:SetWidth(cardW)
    fine:SetText(ORIGINAL)

    local helpHead = Part(Style.Section(page, cardW))
    helpHead.title:SetText("WHAT HELPS")
    local help = Part(HelpBox(page, cardW))
    local where = Part(Style.Text(page, 12, "muted"))
    where:SetWidth(cardW - 90)
    where:SetWordWrap(false)
    local pin = Part(CreateFrame("Button", nil, page))
    pin.text = Style.Text(pin, 11, "muted")
    pin.text:SetPoint("RIGHT")
    pin.text:SetText("show on map")
    pin:SetSize(Style.Wide(pin.text, 76), 18)
    pin:SetScript("OnEnter", function(self) self.text:SetTextColor(Style.Color("gold")) end)
    pin:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color("muted")) end)

    -- The road across the bottom, as the page's own: a band you travel along, the gold to where you
    -- are, the signs a stop apart (spread from you to the edge when there are fewer than six).
    local roadHead = Part(Style.Section(page, width))
    roadHead.title:SetText(("YOUR ROAD TO %d"):format(ns.Fishing.TOP))
    roadHead.note:SetText("where the water changes")
    local scroll = Part(CreateFrame("ScrollFrame", nil, page))
    scroll:SetSize(width, ROAD_H)
    local lane = CreateFrame("Frame", nil, scroll)
    lane:SetSize(width, ROAD_H)
    scroll:SetScrollChild(lane)
    local band = CreateFrame("Frame", nil, lane)
    band:SetPoint("TOPLEFT", 0, -(SIGN - BAND_H) / 2)
    band:SetSize(width, BAND_H)
    Style.Box(band, 13, "titleBar", "lineStrong")
    local done = CreateFrame("Frame", nil, band)
    done:SetPoint("TOPLEFT", 1, -1)
    done:SetSize(FIRST_X, BAND_H - 2)
    Style.Cap(done, 12, "needFill", "LEFT")
    local markLayer = CreateFrame("Frame", nil, band)
    markLayer:SetAllPoints()
    markLayer:SetFrameLevel((done:GetFrameLevel() or 0) + 1)
    local you = markLayer:CreateTexture(nil, "ARTWORK")
    you:SetColorTexture(Style.Color("gold"))
    you:SetSize(12, 12)
    you:SetRotation(math.rad(45))
    local youText = Style.Text(lane, 10, "gold", nil, true)
    youText:SetJustifyH("CENTER")
    local floorText = Style.Text(lane, 10, "muted", nil, true)
    floorText:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 2, -8)
    local waters, ranks = {}, {}
    local thumb = Part(page:CreateTexture(nil, "OVERLAY"))
    thumb:SetColorTexture(Style.Color("thumb"))
    thumb:SetHeight(3)
    local most = 0
    local function PlaceRoad()
        local at = math.max(0, math.min(most, scroll:GetHorizontalScroll() or 0))
        scroll:SetHorizontalScroll(at)
        thumb:SetShown(most > 0 and scroll:IsShown())
        if most > 0 then
            local size = math.max(40, width * width / (width + most))
            thumb:SetWidth(size)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", (width - size) * at / most, -2)
        end
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetHorizontalScroll((self:GetHorizontalScroll() or 0) - delta * PITCH)
        PlaceRoad()
    end)
    local legend = Part(Style.Text(page, 11, "muted"))
    legend:SetPoint("BOTTOMLEFT", 0, 0)
    legend:SetWidth(width)
    legend:SetWordWrap(false)

    function view:Hide()
        for _, region in ipairs(self.parts) do region:Hide() end
        self.shown = false
    end

    -- DO THIS NOW, from your skill with its bonus. Returns how tall it came to.
    local function PaintNow(current, here, cook)
        local skill = current.skill + current.bonus
        local map, clear, ok = ns.Fishing.Best(skill, here)
        nowHead:ClearAllPoints()
        nowHead:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -bodyY)
        nowHead:Show()
        nowHead.note:SetText(current.bonus ~= 0 and ("%d with %s"):format(skill, view.words) or "")
        if not map then
            card:Hide()
            fine:Hide()
            return 28
        end
        local name = ZoneName(map)
        card.icon:SetTexture(current.icon)
        card.name:SetText(("Fish in %s"):format(name))
        card.detail:SetText(ok and "The nearest water where no fish get away from you"
            or ("Some fish get away here until %d, fewer as your skill rises"):format(clear))
        local c = ns.Fishing.Catches(map)
        local list = c and c.list or {}
        local shown = 0
        for i, r in ipairs(card.rows) do
            local entry = list[i]
            r:SetShown(entry ~= nil)
            if entry then
                shown = i
                r.item = entry.item
                r.icon:SetTexture(Compat.ItemIcon(entry.item))
                r.name:SetText(Compat.ItemName(entry.item) or "...")
                r.share:SetText(("%d%%"):format(entry.share))
                r.bar:SetWidth(math.max(1, 60 * entry.share / 100))
                local wanted = cook[entry.item]
                r.tag:SetShown(wanted ~= nil)
                r.facts = { { "Caught there", ("%d%% of %d"):format(entry.share, c.total) } }
                if wanted then r.facts[2] = { "On your Cooking path", ("%d to %d"):format(wanted.from, wanted.to) } end
                r.hint = "From what players caught in Forever."
            end
        end
        card.foot:SetText(c and "What players caught there in Forever" or "Nothing seen caught there yet")
        card.map:SetShown(c ~= nil)
        card.map:SetScript("OnClick", function() PinWater(map) end)
        card:SetScript("OnClick", function() PinWater(map) end)
        card:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(name, Style.Color("text"))
            GameTooltip:AddLine(" ")
            local mr, mg, mb = Style.Color("muted")
            local gr, gg, gb = Style.Color("gold")
            GameTooltip:AddDoubleLine("No fish get away from", tostring(clear), 1, 1, 1, 1, 1, 1)
            GameTooltip:AddDoubleLine("Your skill, with " .. view.words, tostring(skill), 1, 1, 1, Style.Color(ok and "green" or "red"))
            if #list > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Most caught", "share", gr, gg, gb, mr, mg, mb)
                for _, entry in ipairs(list) do
                    GameTooltip:AddDoubleLine(Compat.ItemName(entry.item) or "...", ("%d%%"):format(entry.share), 1, 1, 1, 1, 1, 1)
                end
            end
            local onPath = {}
            for _, entry in ipairs(list) do
                if cook[entry.item] then onPath[#onPath + 1] = entry.item end
            end
            if #onPath > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("On your Cooking path", gr, gg, gb)
                for _, item in ipairs(onPath) do
                    GameTooltip:AddDoubleLine(Compat.ItemName(item) or "...", ("for %d to %d"):format(cook[item].from, cook[item].to), 1, 1, 1, 1, 1, 1)
                end
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Where fish get away is the original game's number", mr, mg, mb)
            if c then GameTooltip:AddLine(("The shares are from %d catches by players in Forever"):format(c.total), mr, mg, mb) end
            local hereClear = here and ns.Fishing.Zone(here.map)
            if here and here.map ~= map and hereClear and hereClear > skill then
                GameTooltip:AddLine(("Here in %s, some get away until %d"):format(ZoneName(here.map), hereClear), mr, mg, mb)
            end
            if c then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Click to show where they fished on your map", mr, mg, mb)
            end
            GameTooltip:Show()
        end)
        card:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local tall = NOW_TOP + shown * ROW_H + STRIP_H
        card:SetHeight(tall)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(bodyY + 28))
        card:Show()
        fine:ClearAllPoints()
        fine:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -10)
        fine:Show()
        return 28 + tall + 10 + 16
    end

    -- WHAT HELPS and the nearest trainer under it. Returns how tall they came to.
    local function PaintHelps(current)
        local level = UnitLevel("player") or 1
        local rows, lure, lureOn, rest = ns.Fishing.Helps(current.skill, level, 4)
        helpHead:ClearAllPoints()
        helpHead:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, -bodyY)
        helpHead:Show()
        for i, r in ipairs(help.rows) do
            local row = rows[i]
            r:SetShown(row ~= nil)
            if row then
                local g = row.gear
                r.item = g.item
                r.icon:SetTexture(Compat.ItemIcon(g.item))
                r.name:SetText(Compat.ItemName(g.item) or "...")
                local words, line = Source(g, level)
                if row.held == "hand" then
                    words, line = nil, "In your hands"
                elseif row.held == "bags" then
                    words, line = nil, row.count and ("In your bags, %d"):format(row.count) or "In your bags"
                end
                r.tag:SetShown(words ~= nil)
                if words then r.tag:Say(words) end
                r.sub:SetText(line or "")
                r.bonus:SetText(g.bonus > 0 and ("+%d"):format(g.bonus) or "")
                r.bonus:SetTextColor(Style.Color(row.held and "text" or "green"))
                r.facts = { { "Fishing", ("+%d"):format(g.bonus) } }
                if g.kind == "lure" then r.facts[2] = { "Lasts", ("%d minutes"):format(g.minutes or 10) } end
                r.hint = nil
            end
        end
        local skill = current.skill + current.bonus
        local foot
        if lureOn then
            foot = ("Your lure is on: you fish at %d"):format(skill)
        elseif lure then
            foot = ("With %s on, you'd fish at %d"):format(Compat.ItemName(lure.item) or "a lure", skill + lure.bonus)
        end
        help.foot:SetText(foot or "")
        help.strip.rest = rest
        local tall = 2 + #rows * HELP_H + STRIP_H
        help:SetHeight(tall)
        help:ClearAllPoints()
        help:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, -(bodyY + 28))
        help:Show()
        local y = 28 + tall
        -- The nearest trainer for your rank, or the next once you're ready for it, as every
        -- profession has; Fishing's trainers teach up to Journeyman.
        local P = ns.Professions
        local rank = P.Rank(current.cap)
        local rankIndex = 1
        for i, r in ipairs(P.RANKS) do if r == rank then rankIndex = i end end
        local at = P.At(ns.Fishing.LINE, rank)
        local needed = (at and current.skill >= at) and rankIndex + 1 or rankIndex
        local trainer = ns.Trainers and ns.Trainers.Nearest("skill" .. ns.Fishing.LINE, needed, current.skill)
        if trainer then
            local place = ns.Trainers.Zone(trainer)
            where:SetText(("Nearest trainer: |cffece6d6%s|r%s"):format(trainer.name, place and (", " .. place) or ""))
            where:ClearAllPoints()
            where:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, -(bodyY + y + 10))
            where:Show()
            pin:SetScript("OnClick", function() ns.Trainers.Pin(trainer) end)
            pin:ClearAllPoints()
            pin:SetPoint("TOPRIGHT", page, "TOPLEFT", width, -(bodyY + y + 8))
            pin:Show()
            y = y + 28
        end
        return y
    end

    -- A rank stop, made when first needed.
    local function RankAt(i)
        if not ranks[i] then
            ranks[i] = Road.RankStop(lane, STOP_W, true)
            ranks[i]:SetFrameLevel((lane:GetFrameLevel() or 0) + 3)
        end
        return ranks[i]
    end
    local function WaterAt(i)
        if not waters[i] then
            waters[i] = WaterStop(lane)
            waters[i]:SetFrameLevel((lane:GetFrameLevel() or 0) + 3)
        end
        return waters[i]
    end

    -- The road to 300, `y` down the page.
    local function PaintRoad(current, here, cook, y)
        local P = ns.Professions
        local skill, cap = current.skill, current.cap
        local items = ns.Fishing.Road(skill, cap, here)
        roadHead:ClearAllPoints()
        roadHead:SetPoint("TOPLEFT", 0, -y)
        roadHead:Show()
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", 0, -(y + 30))
        scroll:Show()
        local places = math.max(1, #items)
        local function Middle(k)
            if places >= ACROSS then return FIRST_X + k * PITCH + STOP_W / 2 end
            return YOU_X + (k + 1) * (width - STOP_W / 2 - YOU_X) / places
        end
        local w, r = 0, 0
        for k, item in ipairs(items) do
            local stop
            if item.kind == "water" then
                w = w + 1
                stop = WaterAt(w)
                local last = item.at >= ns.Fishing.TOP
                stop.at, stop.zones = item.at, item.zones
                stop.level:SetText(item.at)
                stop.disc:Paint("well", last and "gold" or "lineStrong")
                stop.level:SetTextColor(Style.Color(last and "gold" or "text"))
                local names, top, pinned = {}, nil, nil
                for _, map in ipairs(item.zones) do
                    if #names < 2 then names[#names + 1] = ZoneName(map) end
                    local c = ns.Fishing.Catches(map)
                    if c and not top then top, pinned = c.list[1], map end
                end
                stop.pin = pinned
                stop.name:SetText(table.concat(names, ", "))
                stop.icon:SetShown(top ~= nil)
                if top then stop.icon:SetTexture(Compat.ItemIcon(top.item)) end
                -- With no picture, the names move up to the sign.
                stop.name:ClearAllPoints()
                stop.name:SetPoint("TOP", 0, -(SIGN + 12 + (top and 42 or 2)))
                local wanted = top ~= nil and cook[top.item] ~= nil
                stop.tag:SetShown(wanted)
                stop.note:SetShown(top == nil)
                stop.note:SetText("no catches seen yet")
            else
                r = r + 1
                stop = RankAt(r)
                Road.PaintRankStop(stop, ns.Fishing.LINE, item.rank, item.index, item.at, skill)
            end
            stop:ClearAllPoints()
            stop:SetPoint("TOPLEFT", Middle(k - 1) - STOP_W / 2, 0)
            stop:Show()
        end
        for i = w + 1, #waters do waters[i]:Hide() end
        for i = r + 1, #ranks do ranks[i]:Hide() end
        -- You, between the road's start (your rank's first point, or your skill where it's lower)
        -- and the first sign ahead, by your skill between their numbers.
        local rank = P.Rank(cap)
        local floor = 0
        for i, each in ipairs(P.RANKS) do
            if each == rank and i > 1 then floor = P.RANKS[i - 1].cap end
        end
        floor = math.min(floor, skill)
        local first = items[1]
        local aheadX = first and (Middle(0) - SIGN / 2 - 10) or (width - 20)
        local along = first and math.max(0, math.min(1, (skill - floor) / math.max(1, first.at - floor))) or 1
        local youX = 10 + along * math.max(0, aheadX - 10)
        done:SetShown(youX >= 12)
        done:SetWidth(math.max(12, youX - 1))
        you:ClearAllPoints()
        you:SetPoint("CENTER", band, "LEFT", math.max(10, youX), 0)
        youText:SetText(tostring(skill))
        youText:ClearAllPoints()
        youText:SetPoint("TOP", band, "BOTTOMLEFT", math.max(YOU_X, youX), -8)
        floorText:SetText(floor)
        floorText:SetShown(youX > 60)
        local long = places >= ACROSS and math.max(width, FIRST_X + (places - 1) * PITCH + STOP_W + 2) or width
        lane:SetWidth(long)
        band:SetWidth(long)
        most = long - width
        scroll:UpdateScrollChildRect()
        PlaceRoad()
        legend:SetText("Point at a sign for what's caught there. Where fish stop getting away is the original game's number."
            .. (most > 0 and "  The mouse wheel moves along the road." or ""))
        legend:Show()
    end

    -- Draws Fishing for `current` (Fishing.Mine()'s).
    function view:Paint(current)
        self.shown = true
        local pole, lureOn = ns.Fishing.Held()
        self.words = ns.Fishing.BonusWords(current.bonus, pole and pole.bonus or 0, lureOn)
        bonus:SetText(current.bonus ~= 0 and ("%+d from %s"):format(current.bonus, self.words) or "")
        bonus:SetShown(current.bonus ~= 0)
        local here = ns.Fishing.Here()
        local cook = ns.Fishing.CookNeeds()
        local left = PaintNow(current, here, cook)
        local right = PaintHelps(current)
        PaintRoad(current, here, cook, bodyY + math.max(left, right) + 22)
    end

    -- Drawn again when your zone, what you wear or what's on your pole changes, while it shows.
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "ZONE_CHANGED_NEW_AREA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    local queued = false
    events:SetScript("OnEvent", function(_, event, unit)
        unit = Compat.Plain(unit)
        if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
        if not (view.shown and page:IsVisible()) or queued then return end
        queued = true
        Compat.After(0.3, function()
            queued = false
            if view.shown and page:IsVisible() and page.Refresh then page.Refresh() end
        end)
    end)
    view:Hide()
    return view
end
