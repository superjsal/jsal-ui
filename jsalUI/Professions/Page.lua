-- The Professions page: where you stand in the chosen profession on one
-- bar, your professions in a row under it, then two columns: the step to
-- do now with what it takes and the steps after it (with when the next
-- rank is learned), and everything the road needs with the nearest
-- trainer. The recipes you know are the ones seen the last time its
-- profession window was open. It reads as the profession panel does
-- (John, 13 Nov 2026, of the page as it was: "anything to change about
-- this as well?").
local _, ns = ...
local Style, Compat, Window, Professions = ns.Style, ns.Compat, ns.Window, ns.Professions

local GAP, TILE_H, STEP_H, NOTE_H, MAT_H, NEED_H, RANK_H = 28, 44, 30, 14, 36, 22, 38

-- A section heading: a title, a note, and a rule.
local function Section(parent, width)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(width, 20)
    s.title = Style.Text(s, 11, "gold", nil, true)
    s.title:SetPoint("LEFT")
    s.note = Style.Text(s, 11, "muted")
    s.note:SetPoint("RIGHT")
    s.note:SetJustifyH("RIGHT")
    Style.Rule(s, "BOTTOM", "line")
    return s
end

local function Tooltip(frame)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.item then GameTooltip:SetItemByID(self.item) elseif self.spell then GameTooltip:SetSpellByID(self.spell) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Style.Hover(frame, 6)
end

Window.Page("professions", function(page)
    local width, height = Window.contentWidth, Window.contentHeight
    local selected
    -- Down the page: the bar, the row of professions, then the two columns.
    local BAR_Y, TILES_Y = 60, 94
    local bodyY = TILES_Y + TILE_H + 18
    local leftW = math.floor((width - GAP) * 0.58)
    local rightX = leftW + GAP
    local rightW = width - rightX
    -- The guild view has the whole width under the row of professions.
    local roadW, top = width, bodyY

    -- The top: the chosen profession, your skill in it, its rank, and one
    -- bar from the rank's first point to its cap with the next rank marked.
    local title = Style.Text(page, 21, "text", nil, true)
    title:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    local points = Style.Text(page, 21, "text", nil, true)
    points:SetPoint("TOPRIGHT", page.heading, "BOTTOMLEFT", width, -8)
    points:SetJustifyH("RIGHT")
    local sub = Style.Text(page, 13, "muted")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetWidth(width - 80)
    sub:SetWordWrap(false)
    local track = CreateFrame("Frame", nil, page)
    track:SetSize(width, 6)
    track:SetPoint("TOPLEFT", 0, -BAR_Y)
    Style.Fill(track, "line")
    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT")
    fill:SetPoint("BOTTOMLEFT")
    fill:SetColorTexture(Style.Color("gold"))
    local marker = track:CreateTexture(nil, "OVERLAY")
    marker:SetColorTexture(Style.Color("muted"))
    marker:SetSize(Compat.OnePixel(page), 12)
    local from = Style.Text(page, 11, "muted")
    from:SetPoint("TOPLEFT", track, "BOTTOMLEFT", 0, -5)
    local capText = Style.Text(page, 11, "muted")
    capText:SetPoint("TOPRIGHT", track, "BOTTOMRIGHT", 0, -5)
    capText:SetJustifyH("RIGHT")
    local markText = Style.Text(page, 11, "muted")

    -- Your professions, in a row: a click chooses one.
    local cards = {}
    local function Card(i)
        if cards[i] then return cards[i] end
        local c = CreateFrame("Button", nil, page)
        c:SetHeight(TILE_H)
        Style.Fill(c, "well")
        c.edges = Style.Border(c, "cardLine")
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetSize(24, 24)
        c.icon:SetPoint("LEFT", 10, 0)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.name = Style.Text(c, 12, "text", nil, true)
        c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 8, 2)
        c.name:SetPoint("RIGHT", -6, 0)
        c.name:SetJustifyH("LEFT")
        c.name:SetWordWrap(false)
        c.sub = Style.Text(c, 11, "muted")
        c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -2)
        cards[i] = c
        return c
    end
    local none = Style.Text(page, 13, "muted")
    none:SetPoint("TOPLEFT", 0, -TILES_Y)
    none:SetWidth(width)

    -- Left: the step in hand and the steps after it, in a scrolling list.
    local scroll, list = Style.Scroller(page, leftW, height - bodyY, leftW - 8)
    scroll:SetPoint("TOPLEFT", 0, -bodyY)
    local innerW = leftW - 8
    local message = Style.Text(list, 13, "muted")
    message:SetWidth(innerW)
    message:SetJustifyH("LEFT")
    local nowHead = Section(list, innerW)
    local thenHead = Section(list, innerW)
    thenHead.title:SetText("THEN")
    local note = Style.Text(list, 12, "muted")
    note:SetWidth(innerW)
    note:SetJustifyH("LEFT")

    -- The step in hand, as a card: what to make, how many (and how many to
    -- be safe), and each thing it takes with what you have of it.
    local card = CreateFrame("Frame", nil, list)
    card:SetWidth(innerW)
    Style.Fill(card, "well")
    card.edge = card:CreateTexture(nil, "ARTWORK")
    card.edge:SetColorTexture(Style.Color("gold"))
    card.edge:SetPoint("TOPLEFT")
    card.edge:SetPoint("BOTTOMLEFT")
    card.edge:SetWidth(3)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(36, 36)
    card.icon:SetPoint("TOPLEFT", 14, -12)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.count = Style.Text(card, 20, "gold", nil, true)
    card.count:SetPoint("TOPRIGHT", -12, -10)
    card.count:SetJustifyH("RIGHT")
    card.safe = Style.Text(card, 11, "muted")
    card.safe:SetPoint("TOPRIGHT", -12, -36)
    card.safe:SetJustifyH("RIGHT")
    card.name = Style.Text(card, 15, "text", nil, true)
    card.name:SetPoint("TOPLEFT", 60, -11)
    card.name:SetPoint("RIGHT", card.count, "LEFT", -8, 0)
    card.name:SetJustifyH("LEFT")
    card.name:SetWordWrap(false)
    card.detail = Style.Text(card, 12, "muted")
    card.detail:SetPoint("TOPLEFT", 60, -33)
    card.detail:SetWidth(innerW - 60 - 12)
    card.detail:SetJustifyH("LEFT")
    card.detail:SetWordWrap(false)
    card.rule = card:CreateTexture(nil, "BORDER")
    card.rule:SetColorTexture(Style.Color("line"))
    card.rule:SetPoint("TOPLEFT", 14, -60)
    card.rule:SetSize(innerW - 28, Compat.OnePixel(card))
    Tooltip(card)
    local mats = {}
    local function Mat(i)
        if mats[i] then return mats[i] end
        local m = CreateFrame("Frame", nil, card)
        m:SetSize(innerW - 28, MAT_H)
        m.icon = m:CreateTexture(nil, "ARTWORK")
        m.icon:SetSize(18, 18)
        m.icon:SetPoint("TOPLEFT", 0, -2)
        m.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        m.count = Style.Text(m, 13, "muted")
        m.count:SetPoint("TOPRIGHT", 0, -2)
        m.count:SetJustifyH("RIGHT")
        m.name = Style.Text(m, 13, "text")
        m.name:SetPoint("TOPLEFT", 26, -2)
        m.name:SetPoint("RIGHT", m.count, "LEFT", -8, 0)
        m.name:SetJustifyH("LEFT")
        m.name:SetWordWrap(false)
        m.note = Style.Text(m, 11, "muted")
        m.note:SetPoint("TOPLEFT", 26, -19)
        m.note:SetWidth(innerW - 28 - 26)
        m.note:SetJustifyH("LEFT")
        m.note:SetWordWrap(false)
        Tooltip(m)
        mats[i] = m
        return m
    end

    -- A later step, on one line; a line under it only when there's
    -- something to do first (learn it, buy its pattern).
    local steps, needs = {}, {}
    local function Step(i)
        if steps[i] then return steps[i] end
        local s = CreateFrame("Frame", nil, list)
        s:SetSize(innerW, STEP_H)
        s.levels = Style.Text(s, 12, "muted")
        s.levels:SetPoint("TOPLEFT", 0, -6)
        s.icon = s:CreateTexture(nil, "ARTWORK")
        s.icon:SetSize(22, 22)
        s.icon:SetPoint("TOPLEFT", 76, -2)
        s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        s.count = Style.Text(s, 13, "text", nil, true)
        s.count:SetPoint("TOPRIGHT", 0, -5)
        s.count:SetJustifyH("RIGHT")
        s.name = Style.Text(s, 13, "text")
        s.name:SetPoint("TOPLEFT", 106, -5)
        s.name:SetPoint("RIGHT", s.count, "LEFT", -8, 0)
        s.name:SetJustifyH("LEFT")
        s.name:SetWordWrap(false)
        s.detail = Style.Text(s, 11, "gold")
        s.detail:SetPoint("TOPLEFT", 106, -23)
        s.detail:SetWidth(innerW - 106)
        s.detail:SetJustifyH("LEFT")
        s.detail:SetWordWrap(false)
        Style.Rule(s, "BOTTOM", "line")
        Tooltip(s)
        steps[i] = s
        return s
    end

    -- Learning the next rank, as a row of its own where the road reaches
    -- its skill. A click pins the nearest trainer who teaches it.
    local rankRow = CreateFrame("Button", nil, list)
    rankRow:SetSize(innerW, RANK_H - 4)
    Style.Fill(rankRow, "well")
    rankRow.edge = rankRow:CreateTexture(nil, "ARTWORK")
    rankRow.edge:SetColorTexture(Style.Color("gold"))
    rankRow.edge:SetPoint("TOPLEFT")
    rankRow.edge:SetPoint("BOTTOMLEFT")
    rankRow.edge:SetWidth(3)
    rankRow.title = Style.Text(rankRow, 12, "gold", nil, true)
    rankRow.title:SetPoint("TOPLEFT", 14, -4)
    rankRow.sub = Style.Text(rankRow, 11, "muted")
    rankRow.sub:SetPoint("TOPLEFT", 14, -19)
    rankRow.sub:SetWidth(innerW - 28)
    rankRow.sub:SetJustifyH("LEFT")
    rankRow.sub:SetWordWrap(false)
    rankRow:SetScript("OnClick", function(self)
        if self.trainer and ns.Trainers then ns.Trainers.Pin(self.trainer) end
    end)

    -- Right: everything the road needs, then the shopping list and the
    -- nearest trainer.
    local needHead = Section(page, rightW)
    needHead.note:SetText("have / need")
    local function Need(i)
        if needs[i] then return needs[i] end
        local r = CreateFrame("Frame", nil, page)
        r:SetSize(rightW, NEED_H)
        r.count = Style.Text(r, 12, "muted")
        r.count:SetPoint("RIGHT")
        r.count:SetJustifyH("RIGHT")
        r.name = Style.Text(r, 12, "text")
        r.name:SetPoint("LEFT")
        r.name:SetPoint("RIGHT", r.count, "LEFT", -8, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        Tooltip(r)
        needs[i] = r
        return r
    end
    local needMore = Style.Text(page, 11, "muted")
    local addRoad = Style.Button(page, "Add the whole road to my shopping list", "plain", rightW)
    addRoad:SetHeight(28)
    local where = Style.Text(page, 12, "muted")
    where:SetWidth(rightW)
    where:SetJustifyH("LEFT")
    where:SetWordWrap(false)
    local pin = Style.Button(page, "Show trainer on map", "primary", rightW)
    pin:SetHeight(28)
    -- How many lines of what's needed fit above the two buttons.
    local maxNeeds = math.max(3, math.floor((height - bodyY - 30 - 120) / NEED_H))

    local function Place(region, y)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
        region:Show()
    end
    local function PlaceRight(region, y)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, -(bodyY + y))
        region:Show()
    end

    local function RecipeName(recipe)
        return recipe.label or (recipe.item and Compat.ItemName(recipe.item)) or (Compat.SpellInfo(recipe.spell)) or "..."
    end
    local function RecipeIcon(recipe)
        return (recipe.item and Compat.ItemIcon(recipe.item)) or select(2, Compat.SpellInfo(recipe.spell))
    end

    ---------------------------------------------------------------------
    -- Guild crafters: a card beside your professions. Its view lists the
    -- guildmates who share, with their professions, and searches what they
    -- make, crafts someone online makes first.
    ---------------------------------------------------------------------
    local guildCard = CreateFrame("Button", nil, page)
    guildCard:SetHeight(TILE_H)
    Style.Fill(guildCard, "well")
    guildCard.edges = Style.Border(guildCard, "cardLine")
    local guildIcon = guildCard:CreateTexture(nil, "ARTWORK")
    guildIcon:SetSize(24, 24)
    guildIcon:SetPoint("LEFT", 10, 0)
    guildIcon:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Icons\\guild")
    local guildName = Style.Text(guildCard, 12, "text", nil, true)
    guildName:SetPoint("TOPLEFT", guildIcon, "TOPRIGHT", 8, 2)
    guildName:SetText("Guild crafters")
    local guildSub = Style.Text(guildCard, 11, "muted")
    guildSub:SetPoint("TOPLEFT", guildName, "BOTTOMLEFT", 0, -2)
    guildSub:SetText("who makes what")

    local G_ROW = 46
    local guildView = CreateFrame("Frame", nil, page)
    guildView:SetPoint("TOPLEFT", 0, -top)
    guildView:SetSize(roadW, height - top)
    guildView:Hide()
    local gHead = Section(guildView, roadW)
    gHead:SetPoint("TOPLEFT")
    gHead.title:SetText("GUILD CRAFTERS")
    local searchWell = CreateFrame("Frame", nil, guildView)
    searchWell:SetPoint("TOPLEFT", 0, -32)
    searchWell:SetSize(roadW, 34)
    Style.Fill(searchWell, "well")
    Style.Border(searchWell, "lineStrong")
    local search = CreateFrame("EditBox", nil, searchWell)
    search:SetAllPoints()
    search:SetTextInsets(10, 10, 0, 0)
    search:SetAutoFocus(false)
    search:SetMaxLetters(40)
    search:SetFont(Style.font, 14, "")
    search:SetTextColor(Style.Color("text"))
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    searchWell:EnableMouse(true)
    searchWell:SetScript("OnMouseDown", function() search:SetFocus() end)
    local searchHint = Style.Text(searchWell, 13, "muted")
    searchHint:SetPoint("LEFT", 10, 0)
    searchHint:SetText("Search what you need: a bag, a potion, bracers")
    local gMessage = Style.Text(guildView, 13, "muted")
    gMessage:SetPoint("TOPLEFT", 0, -82)
    gMessage:SetWidth(roadW)
    gMessage:SetJustifyH("LEFT")
    local gFoot = Style.Text(guildView, 11, "muted")
    gFoot:SetPoint("BOTTOMLEFT", 0, 0)
    gFoot:SetWidth(roadW)
    gFoot:SetJustifyH("LEFT")
    local gRows = {}
    local function GuildRow(i)
        if gRows[i] then return gRows[i] end
        local r = CreateFrame("Frame", nil, guildView)
        r:SetSize(roadW, G_ROW)
        Style.Rule(r, "BOTTOM", "line")
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(28, 28)
        r.icon:SetPoint("LEFT", 0, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = Style.Text(r, 13, "text")
        r.name:SetPoint("BOTTOMLEFT", r.icon, "RIGHT", 10, 1)
        r.name:SetWidth(roadW - 200)
        r.name:SetWordWrap(false)
        r.who = Style.Text(r, 11, "muted")
        r.who:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
        r.who:SetWidth(roadW - 200)
        r.who:SetWordWrap(false)
        r.whisper = Style.Button(r, "Whisper", "plain", 140)
        r.whisper:SetHeight(26)
        r.whisper:SetPoint("RIGHT", 0, 0)
        Tooltip(r)
        gRows[i] = r
        return r
    end

    -- Before anything is typed: the guildmates who share, a row each, online
    -- first, with their professions. A click on a profession lists what they
    -- make with it. (John, 14 Nov 2026, of the page with only a search box:
    -- "are we able to list the professions of guild members as well?")
    local PaintGuild
    local GV = { rows = {}, ROW = 44, TOP = 82, CHIPS_X = 190 }
    GV.max = math.max(1, math.floor((height - top - GV.TOP - 22 - 40) / GV.ROW))
    GV.cols = CreateFrame("Frame", nil, guildView)
    GV.cols:SetSize(roadW, 18)
    GV.cols:SetPoint("TOPLEFT", 0, -GV.TOP)
    for _, label in ipairs({ { "GUILDMATE", 22 }, { "PROFESSIONS", GV.CHIPS_X } }) do
        local t = Style.Text(GV.cols, 10, "muted", nil, true)
        t:SetPoint("TOPLEFT", label[2], 0)
        t:SetText(label[1])
    end
    Style.Rule(GV.cols, "BOTTOM", "lineStrong")
    -- One guildmate's profession, opened: whose it is, and the way back.
    GV.title = Style.Text(guildView, 13, "text", nil, true)
    GV.title:SetPoint("TOPLEFT", 0, -(GV.TOP + 4))
    GV.back = Style.Button(guildView, "All guildmates", "plain", 130)
    GV.back:SetHeight(24)
    GV.back:SetPoint("TOPRIGHT", guildView, "TOPLEFT", roadW, -(GV.TOP - 1))
    GV.back:SetScript("OnClick", function()
        GV.pick = nil
        xpcall(PaintGuild, ns.Report)
    end)

    -- A profession on a guildmate's row: its name and skill, to click.
    function GV.Chip(r, k)
        if r.chips[k] then return r.chips[k] end
        local c = CreateFrame("Button", nil, r)
        c:SetHeight(22)
        Style.Fill(c, "line")
        c.text = Style.Text(c, 11, "text")
        c.text:SetPoint("CENTER")
        Style.Hover(c)
        c:SetScript("OnClick", function(self)
            if not self.prof or self.prof.recipes == 0 then return end
            GV.pick = { name = self.person.name, line = self.prof.line, label = self.prof.name }
            search:SetText("")
            search:ClearFocus()
            xpcall(PaintGuild, ns.Report)
        end)
        r.chips[k] = c
        return c
    end

    function GV.Row(i)
        if GV.rows[i] then return GV.rows[i] end
        local r = CreateFrame("Frame", nil, guildView)
        r:SetSize(roadW, GV.ROW)
        r:SetPoint("TOPLEFT", 0, -(GV.TOP + 22 + (i - 1) * GV.ROW))
        Style.Rule(r, "BOTTOM", "line")
        -- Green while they're online.
        r.dot = r:CreateTexture(nil, "ARTWORK")
        r.dot:SetSize(7, 7)
        r.dot:SetPoint("TOPLEFT", 8, -11)
        r.name = Style.Text(r, 13, "text", nil, true)
        r.name:SetPoint("TOPLEFT", 22, -6)
        r.name:SetWidth(GV.CHIPS_X - 30)
        r.name:SetWordWrap(false)
        r.sub = Style.Text(r, 11, "muted")
        r.sub:SetPoint("TOPLEFT", 22, -25)
        r.sub:SetWidth(GV.CHIPS_X - 30)
        r.sub:SetWordWrap(false)
        r.chips = {}
        r.more = Style.Text(r, 11, "muted")
        r.whisper = Style.Button(r, "Whisper", "plain", 84)
        r.whisper:SetHeight(26)
        r.whisper:SetPoint("RIGHT", -2, 0)
        GV.rows[i] = r
        return r
    end

    -- The guildmates who share, down the view.
    function GV.Paint(people)
        local Crafters = ns.Crafters
        local on = 0
        for _, p in ipairs(people) do if p.online then on = on + 1 end end
        gHead.note:SetText(("%d guildmate%s sharing  ·  %d online"):format(#people, #people == 1 and "" or "s", on))
        GV.cols:Show()
        for i = 1, math.min(#people, GV.max) do
            local p, r = people[i], GV.Row(i)
            r:Show()
            r.dot:SetColorTexture(Style.Color(p.online and "green" or "lineStrong"))
            r.name:SetText(p.name)
            r.name:SetTextColor(Style.Color(p.online and "text" or "secondary"))
            r.sub:SetText(p.online and ("online" .. (p.zone and ("  ·  " .. p.zone) or "")) or Crafters.Ago(p.seen))
            local x, limit, left = GV.CHIPS_X, roadW - 100, 0
            for k, prof in ipairs(p.profs) do
                local c = GV.Chip(r, k)
                -- A gathering skill is shared in steps of 25: "125+".
                local words = ("%s  %d%s"):format(prof.name, prof.skill, prof.steps and "+" or "")
                c.text:SetText(words)
                -- One with recipes to list is brighter: it opens them.
                c.text:SetTextColor(Style.Color(prof.recipes > 0 and "text" or "muted"))
                local w = c.text.GetStringWidth and c.text:GetStringWidth()
                w = ((type(w) == "number" and w > 0) and w or #words * 6) + 16
                c.person, c.prof = p, prof
                if x + w > limit then
                    c:Hide()
                    left = left + 1
                else
                    c:SetWidth(w)
                    c:ClearAllPoints()
                    c:SetPoint("LEFT", x, 0)
                    c:Show()
                    x = x + w + 6
                end
            end
            for k = #p.profs + 1, #r.chips do r.chips[k]:Hide() end
            r.more:SetText(left > 0 and ("+" .. left) or "")
            r.more:ClearAllPoints()
            r.more:SetPoint("LEFT", x, 0)
            r.whisper:SetShown(p.online)
            r.whisper:SetScript("OnClick", function() Crafters.Whisper(p) end)
        end
        gFoot:SetText((#people > GV.max and ("And %d more. "):format(#people - GV.max) or "")
            .. "Click a profession to see what they make with it. Guildmates who have jsal.ui with Guild crafters on are listed.")
    end

    PaintGuild = function()
        local Crafters = ns.Crafters
        local sharing = Crafters.Count()
        gHead.note:SetText(sharing > 0 and ("%d guildmate%s sharing"):format(sharing, sharing == 1 and "" or "s") or "")
        local text = search:GetText()
        searchHint:SetShown(text == "" and not search:HasFocus())
        for _, r in ipairs(gRows) do r:Hide() end
        for _, r in ipairs(GV.rows) do r:Hide() end
        for _, region in ipairs({ GV.cols, GV.title, GV.back }) do region:Hide() end
        gFoot:SetText("")
        local typed = strtrim(text) ~= ""
        -- Typing goes back to the search of everyone's crafts.
        if typed then GV.pick = nil end
        local note
        if not IsInGuild() then
            note = "Guild crafters shows what your guildmates can make. Join a guild to use it."
        elseif sharing == 0 then
            note = "No recipes heard yet. Guildmates with jsal.ui share theirs once they've opened their profession windows, and their crafts show here as they come in."
        end
        local people = (not note and not typed and not GV.pick and Crafters.Sharing) and Crafters.Sharing() or nil
        if people and #people > 0 then
            gMessage:Hide()
            GV.Paint(people)
            return
        end
        local found, base = {}, 76
        if not note then
            if GV.pick then
                found, base = Crafters.Makes(GV.pick.name, GV.pick.line), GV.TOP + 30
                GV.title:SetText(("%s's %s  ·  %d recipe%s"):format(GV.pick.name, GV.pick.label, #found, #found == 1 and "" or "s"))
                GV.title:Show()
                GV.back:Show()
                if #found == 0 then note = "Nothing to list yet: the game is still loading their names." end
            elseif not typed then
                note = "Type what you need. Guildmates online now come first, with a button to whisper them."
            else
                found = Crafters.Search(text, 200)
                if #found == 0 then note = "No guildmate makes anything by that name yet." end
            end
        end
        gMessage:ClearAllPoints()
        gMessage:SetPoint("TOPLEFT", 0, -(base + 6))
        gMessage:SetText(note or "")
        gMessage:SetShown(note ~= nil)
        local fit = math.max(1, math.floor((height - top - base - 24) / G_ROW))
        for i = 1, math.min(#found, fit) do
            local entry, r = found[i], GuildRow(i)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -(base + (i - 1) * G_ROW))
            r:Show()
            r.item = entry.row.item
            r.spell = not entry.row.item and entry.row.spell or nil
            r.icon:SetTexture((entry.row.item and Compat.ItemIcon(entry.row.item)) or select(2, Compat.SpellInfo(entry.row.spell)))
            r.name:SetText(entry.name)
            local on, off = {}, {}
            for _, p in ipairs(entry.people) do
                if p.online then
                    on[#on + 1] = Style.Tint("green") .. p.name .. "|r"
                elseif #off < 3 then
                    off[#off + 1] = #off == 0 and (p.name .. " (" .. Crafters.Ago(p.seen) .. ")") or p.name
                end
            end
            local who = table.concat(on, ", ")
            if #off > 0 then who = who .. (who ~= "" and "   " or "") .. table.concat(off, ", ") end
            r.who:SetText(who)
            local first = entry.people[1]
            r.whisper:SetShown(first.online)
            if first.online then
                r.whisper.label:SetText("Whisper " .. (first.name:match("^%S+") or first.name))
                r.whisper:SetScript("OnClick", function() Crafters.Whisper(first, entry.name) end)
            end
        end
        if #found > fit then
            gFoot:SetText(GV.pick and ("Showing %d of %d."):format(fit, #found)
                or ("Showing %d of %d. Type more to narrow it."):format(fit, #found))
        end
    end
    search:SetScript("OnTextChanged", function() xpcall(PaintGuild, ns.Report) end)
    search:SetScript("OnEditFocusGained", function() searchHint:Hide() end)
    search:SetScript("OnEditFocusLost", function() searchHint:SetShown(search:GetText() == "") end)

    -- Everything of the road, out of sight: for the guild view, and before
    -- each painting of it.
    local function HideRoad(bar)
        for _, s in ipairs(steps) do s:Hide() end
        for _, r in ipairs(needs) do r:Hide() end
        for _, m in ipairs(mats) do m:Hide() end
        for _, region in ipairs({ nowHead, thenHead, note, card, rankRow, message, needHead, needMore, addRoad, where, pin }) do
            region:Hide()
        end
        if bar then
            for _, region in ipairs({ track, from, capText, markText, points }) do region:Hide() end
        end
    end

    local function Paint()
        local mine = Professions.Mine()
        none:SetShown(#mine == 0)
        none:SetText("No crafting professions yet. Learn one at a trainer, and its road shows here.")
        local guildOn = ns.Crafters and ns.Crafters.running
        if selected == "guild" and not guildOn then selected = nil end
        if selected ~= "guild" and (not selected or not Professions.Name(selected)) then
            selected = (mine[1] and mine[1].line) or (guildOn and "guild") or nil
        end
        -- The row of professions, with the guild's crafters last in it.
        local tiles = #mine + (guildOn and 1 or 0)
        local tileW = tiles > 0 and math.min(180, math.floor((width - (tiles - 1) * 10) / tiles)) or 180
        local tilesY = #mine > 0 and TILES_Y or (TILES_Y + none:GetStringHeight() + 12)
        guildCard:SetShown(guildOn)
        if guildOn then
            guildCard:ClearAllPoints()
            guildCard:SetSize(tileW, TILE_H)
            guildCard:SetPoint("TOPLEFT", #mine * (tileW + 10), -tilesY)
            Style.SetBorder(guildCard.edges, selected == "guild" and "gold" or "cardLine")
            guildCard:SetScript("OnClick", function()
                selected = "guild"
                Paint()
            end)
        end
        guildView:SetShown(selected == "guild")
        local current
        for i, p in ipairs(mine) do
            local c = Card(i)
            c:ClearAllPoints()
            c:SetSize(tileW, TILE_H)
            c:SetPoint("TOPLEFT", (i - 1) * (tileW + 10), -TILES_Y)
            c:Show()
            c.icon:SetTexture(p.icon)
            c.name:SetText(p.name)
            c.sub:SetText(("%d of %d"):format(p.skill, p.cap))
            Style.SetBorder(c.edges, p.line == selected and "gold" or "cardLine")
            c:SetScript("OnClick", function()
                selected = p.line
                Paint()
            end)
            if p.line == selected then current = p end
        end
        for i = #mine + 1, #cards do cards[i]:Hide() end

        HideRoad(true)
        scroll:SetShown(selected ~= "guild" and current ~= nil)
        if selected == "guild" then
            title:SetText("Guild crafters")
            sub:SetText("Who in your guild makes what, with a whisper to the ones online")
            PaintGuild()
            return
        end
        if not current then
            title:SetText("Professions")
            sub:SetText("What to craft, and how many, to reach each profession's next rank")
            return
        end

        -- Where you stand.
        local skill, cap, line = current.skill, current.cap, current.line
        local rank = Professions.Rank(cap)
        local rankIndex = 1
        for i, r in ipairs(Professions.RANKS) do if r == rank then rankIndex = i end end
        local floor = rankIndex > 1 and Professions.RANKS[rankIndex - 1].cap or 0
        title:SetText(current.name)
        points:SetText(skill)
        points:Show()
        sub:SetText(rank.name)
        local span = math.max(1, cap - floor)
        for _, region in ipairs({ track, from, capText }) do region:Show() end
        fill:SetWidth(math.max(1, width * math.max(0, math.min(1, (skill - floor) / span))))
        from:SetText(floor)
        capText:SetText(cap)
        local what, about
        if rank.at and Professions.RankFrom then what, about = Professions.RankFrom(line, rank.next) end
        local doing = what or (rank.next and ("train " .. rank.next)) or ""
        local ahead = rank.at ~= nil and skill < rank.at
        marker:SetShown(ahead)
        markText:SetShown(ahead)
        if ahead then
            local x = width * (rank.at - floor) / span
            marker:ClearAllPoints()
            marker:SetPoint("CENTER", track, "LEFT", x, 0)
            markText:SetText(("%d · %s"):format(rank.at, doing))
            markText:ClearAllPoints()
            markText:SetPoint("TOP", track, "BOTTOMLEFT", x, -5)
        end

        -- What you know: as last seen in its window, else every trainer
        -- recipe up to your skill.
        local seen = Professions.Remembered(line)
        local set = seen and seen.known
        if not set then
            set = {}
            for _, recipe in ipairs(Professions.Recipes(line)) do
                if recipe.how == 1 and recipe.learn <= skill then set[recipe.spell] = true end
            end
        end
        local function known(spell) return set[spell] end
        -- The road runs to the rank's cap, with a break where the next rank
        -- is learned, as the profession panel's does.
        local road, totals, stuck = Professions.Plan(line, skill, cap, known, rank.at)
        local crafts = 0
        for _, step in ipairs(road) do crafts = crafts + step.crafts end
        local unit = Professions.IsGathering(line) and "vein" or "craft"

        local y, ranked = 0, false
        local function Rank()
            local trainer = not what and ns.Trainers and ns.Trainers.Nearest("skill" .. line, rankIndex + 1) or nil
            local place = trainer and ns.Trainers.Zone(trainer)
            rankRow.trainer = trainer
            rankRow.title:SetText(skill >= rank.at and (doing:sub(1, 1):upper() .. doing:sub(2) .. " now") or ("At %d, %s"):format(rank.at, doing))
            local parts = {}
            if about then parts[#parts + 1] = about end
            if trainer then parts[#parts + 1] = trainer.name .. (place and (", " .. place) or "") .. " · click for a map pin" end
            if not what and (UnitLevel("player") or 0) < rank.level then parts[#parts + 1] = ("needs level %d"):format(rank.level) end
            if #parts == 0 then parts[1] = "Any trainer for it can teach you" end
            rankRow.sub:SetText(table.concat(parts, " · "))
            Place(rankRow, y)
            y = y + RANK_H
            ranked = true
        end

        if not seen and not Professions.IsGathering(line) then
            message:SetText(("Open your %s window once so this uses the recipes you know."):format(current.name))
            Place(message, y)
            y = y + message:GetStringHeight() + 12
        end

        -- The step in hand.
        local first = road[1]
        nowHead.title:SetText(first and "DO THIS NOW" or (skill >= cap and "AT THE CAP" or "NOTHING TO MAKE YET"))
        nowHead.note:SetText(first and ("%d → %d"):format(first.from, first.to) or "")
        Place(nowHead, y)
        y = y + 28
        if rank.at and skill >= rank.at then Rank() y = y + 4 end
        if first then
            local recipe = first.recipe
            card.item, card.spell = recipe.item, recipe.spell
            card.icon:SetTexture(RecipeIcon(recipe))
            card.name:SetText(RecipeName(recipe))
            card.count:SetText(("×%d"):format(first.crafts))
            card.safe:SetText((first.safe or 0) > first.crafts and ("%d to be safe"):format(first.safe) or "")
            if recipe.vein then
                card.detail:SetText(("Mine them: a sure point each until %d"):format(recipe.yellow))
            elseif first.buy then
                card.detail:SetText(ns.RecipeSourceText and ns.RecipeSourceText.BuyNote(recipe.spell)
                    or ("Buy the pattern from a vendor, from %d"):format(recipe.learn))
            elseif first.learn then
                card.detail:SetText(("Learn it at the trainer, from %d"):format(recipe.learn))
            elseif not recipe.yellow then
                card.detail:SetText("")
            elseif skill < recipe.yellow then
                card.detail:SetText(("a point every craft until %d"):format(recipe.yellow))
            else
                local odds = Professions.Chance and math.max(1, math.floor(Professions.Chance(recipe, skill) * 10 + 0.5)) or 10
                card.detail:SetText(odds >= 10 and "a point from nearly every craft" or ("a point from about %d crafts in 10"):format(odds))
            end
            local my, shown = 68, 0
            for i, reagent in ipairs(recipe.reagents) do
                shown = i
                local m = Mat(i)
                m:ClearAllPoints()
                m:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -my)
                m:Show()
                m.item = reagent.item
                local need = reagent.count * first.crafts
                local have = Compat.ItemCount(reagent.item, true)
                m.icon:SetTexture(Compat.ItemIcon(reagent.item))
                m.name:SetText(Compat.ItemName(reagent.item) or "...")
                m.count:SetText(("|cff%s%d|r / %d"):format(have >= need and Style.hex.green or Style.hex.red, have, need))
                local price = Professions.IsVendor(reagent.item)
                if have >= need then
                    m.note:SetText("you have enough")
                elseif price then
                    m.note:SetText(("vendor · %d more for %s"):format(need - have, Compat.Money((need - have) * price)))
                elseif Professions.MadeBy and Professions.MadeBy(line, reagent.item) then
                    m.note:SetText(("%d short · you can make it"):format(need - have))
                else
                    m.note:SetText(("%d short"):format(need - have))
                end
                my = my + MAT_H
            end
            card.rule:SetShown(shown > 0)
            card:SetHeight(shown > 0 and (my + 6) or 60)
            Place(card, y)
            y = y + card:GetHeight() + 16
        end

        -- The steps after it, with the next rank where it falls among them.
        if #road > 1 or ahead then
            thenHead.note:SetText(crafts > 0 and ("to %d · about %d %s%s"):format(cap, crafts, unit, crafts == 1 and "" or "s") or "")
            Place(thenHead, y)
            y = y + 28
        end
        for i = 2, #road do
            local step = road[i]
            if not ranked and rank.at and step.from >= rank.at then Rank() end
            local s = Step(i - 1)
            s.item, s.spell = step.recipe.item, step.recipe.spell
            s.levels:SetText(("%d → %d"):format(step.from, step.to))
            s.icon:SetTexture(RecipeIcon(step.recipe))
            s.name:SetText(RecipeName(step.recipe))
            s.count:SetText(("×%d"):format(step.crafts))
            local todo
            if step.buy then
                todo = ns.RecipeSourceText and ns.RecipeSourceText.BuyNote(step.recipe.spell)
                    or ("buy the pattern from a vendor, from %d"):format(step.recipe.learn)
            elseif step.learn then
                todo = ("learn it at the trainer, from %d"):format(step.recipe.learn)
            end
            s.detail:SetText(todo or "")
            s.detail:SetShown(todo ~= nil)
            s:SetHeight(STEP_H + (todo and NOTE_H or 0))
            Place(s, y)
            y = y + STEP_H + (todo and NOTE_H or 0)
        end
        if not ranked and ahead then Rank() end
        local last
        if stuck then
            last = ("Past %d, only patterns you'd have to find give skill."):format(stuck)
        elseif skill >= cap and not rank.at then
            last = "That's as far as it goes."
        end
        if last then
            note:SetText(last)
            Place(note, y + 4)
            y = y + note:GetStringHeight() + 10
        end
        list:SetHeight(math.max(1, y))
        scroll:UpdateScrollChildRect()

        -- Everything the road needs, the biggest shortfall first.
        local all = {}
        for item, need in pairs(totals) do
            all[#all + 1] = { item = item, need = need, have = Compat.ItemCount(item, true) }
        end
        table.sort(all, function(a, b)
            local sa, sb = a.need - a.have, b.need - b.have
            if sa ~= sb then return sa > sb end
            return a.item < b.item
        end)
        local ry = 0
        if #all > 0 then
            needHead.title:SetText(("EVERYTHING TO %d"):format(cap))
            PlaceRight(needHead, ry)
            ry = ry + 28
            for i, entry in ipairs(all) do
                if i > maxNeeds then break end
                local r = Need(i)
                PlaceRight(r, ry)
                r.item = entry.item
                r.name:SetText(Compat.ItemName(entry.item) or "...")
                r.count:SetText(("|cff%s%d|r / %d"):format(entry.have >= entry.need and Style.hex.green or Style.hex.red, entry.have, entry.need))
                ry = ry + NEED_H
            end
            if #all > maxNeeds then
                needMore:SetText(("and %d more, in the shopping list"):format(#all - maxNeeds))
                PlaceRight(needMore, ry + 2)
                ry = ry + 18
            end
            ry = ry + 12
        end
        -- The whole road onto the shopping list at once.
        local crafting = {}
        for _, step in ipairs(road) do
            if not step.recipe.vein then crafting[#crafting + 1] = step end
        end
        if ns.Shopping and ns.Shopping.running and #crafting > 0 then
            addRoad:SetScript("OnClick", function()
                for _, step in ipairs(crafting) do ns.Shopping.AddCraft(step.recipe.spell, step.crafts) end
            end)
            PlaceRight(addRoad, ry)
            ry = ry + 36
        end
        -- The nearest trainer for your rank, or the next one once you're
        -- ready for it.
        local needed = (rank.at and skill >= rank.at) and rankIndex + 1 or rankIndex
        local trainer = ns.Trainers and ns.Trainers.Nearest("skill" .. line, needed)
        if trainer then
            local place = ns.Trainers.Zone(trainer)
            where:SetText(("Nearest trainer: |cffece6d6%s|r%s"):format(trainer.name, place and (", " .. place) or ""))
            PlaceRight(where, ry + 2)
            ry = ry + 22
            pin:SetScript("OnClick", function() ns.Trainers.Pin(trainer) end)
            PlaceRight(pin, ry)
        end
    end

    page.Refresh = function() xpcall(Paint, ns.Report) end
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED", "ITEM_DATA_LOAD_RESULT" }) do
        pcall(events.RegisterEvent, events, event)
    end
    local queued = false
    events:SetScript("OnEvent", function()
        if not page:IsVisible() or queued then return end
        queued = true
        Compat.After(0.3, function()
            queued = false
            if page:IsVisible() then xpcall(Paint, ns.Report) end
        end)
    end)
end)
