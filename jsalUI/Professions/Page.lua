-- The Professions page: your professions on the left, and the chosen one's
-- whole road to its next rank on the right, step by step, with everything
-- it needs and the nearest trainer. The recipes you know are the ones seen
-- the last time its profession window was open.
local _, ns = ...
local Style, Compat, Window, Professions = ns.Style, ns.Compat, ns.Window, ns.Professions

local LIST_W, GAP, CARD_H, STEP_H, ROW_H = 230, 24, 64, 40, 28

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
end

Window.Page("professions", function(page)
    local width, height = Window.contentWidth, Window.contentHeight
    local roadW = width - LIST_W - GAP
    local selected

    local lead = Style.Text(page, 13, "muted")
    lead:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    lead:SetWidth(width)
    lead:SetText("What to craft, and how many, to reach each profession's next rank.")
    local top = 34

    -- Left: your professions.
    local cards = {}
    local function Card(i)
        if cards[i] then return cards[i] end
        local c = CreateFrame("Button", nil, page)
        c:SetSize(LIST_W, CARD_H)
        c:SetPoint("TOPLEFT", 0, -(top + (i - 1) * (CARD_H + 10)))
        Style.Fill(c, "well")
        c.edges = Style.Border(c, "line")
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetSize(32, 32)
        c.icon:SetPoint("TOPLEFT", 12, -12)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.name = Style.Text(c, 13, "text", nil, true)
        c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, 0)
        c.sub = Style.Text(c, 11, "muted")
        c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
        c.track = CreateFrame("Frame", nil, c)
        c.track:SetSize(LIST_W - 24, 4)
        c.track:SetPoint("BOTTOMLEFT", 12, 10)
        Style.Fill(c.track, "line")
        c.fill = c.track:CreateTexture(nil, "ARTWORK")
        c.fill:SetPoint("TOPLEFT")
        c.fill:SetPoint("BOTTOMLEFT")
        c.fill:SetColorTexture(Style.Color("gold"))
        cards[i] = c
        return c
    end
    local none = Style.Text(page, 13, "muted")
    none:SetPoint("TOPLEFT", 0, -top)
    none:SetWidth(LIST_W)

    -- Right: the road, in a scrolling list, and the nearest trainer under it.
    local head = Section(page, roadW)
    head:SetPoint("TOPLEFT", LIST_W + GAP, -top)
    local FOOT_H = 64
    local scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetSize(roadW, height - top - 30 - FOOT_H)
    scroll:SetPoint("TOPLEFT", LIST_W + GAP, -(top + 30))
    local list = CreateFrame("Frame", nil, scroll)
    list:SetSize(roadW - 8, 1)
    scroll:SetScrollChild(list)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local target = self:GetVerticalScroll() - delta * 60
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), target)))
    end)
    local message = Style.Text(list, 13, "muted")
    message:SetWidth(roadW - 8)
    local needHead = Section(list, roadW - 8)
    needHead.title:SetText("ALL YOU NEED")
    needHead.note:SetText("bags and bank / need")

    local where = Style.Text(page, 11, "muted")
    where:SetPoint("BOTTOMLEFT", LIST_W + GAP, 40)
    where:SetWidth(roadW)
    local pin = Style.Button(page, "Show trainer on map", "plain", 180)
    pin:SetHeight(28)
    pin:SetPoint("BOTTOMLEFT", LIST_W + GAP, 0)

    local steps, items = {}, {}
    local function Step(i)
        if steps[i] then return steps[i] end
        local s = CreateFrame("Frame", nil, list)
        s:SetSize(roadW - 8, STEP_H)
        s.levels = Style.Text(s, 12, "muted", nil, true)
        s.levels:SetPoint("LEFT")
        s.levels:SetWidth(76)
        s.icon = s:CreateTexture(nil, "ARTWORK")
        s.icon:SetSize(24, 24)
        s.icon:SetPoint("LEFT", 82, 0)
        s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        s.name = Style.Text(s, 13, "text")
        s.name:SetPoint("BOTTOMLEFT", s.icon, "RIGHT", 10, 1)
        s.name:SetWidth(roadW - 130)
        s.name:SetWordWrap(false)
        s.detail = Style.Text(s, 11, "muted")
        s.detail:SetPoint("TOPLEFT", s.name, "BOTTOMLEFT", 0, -2)
        s.detail:SetWidth(roadW - 130)
        s.detail:SetWordWrap(false)
        Tooltip(s)
        steps[i] = s
        return s
    end
    local function Item(i)
        if items[i] then return items[i] end
        local r = CreateFrame("Frame", nil, list)
        r:SetSize(roadW - 8, ROW_H)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(22, 22)
        r.icon:SetPoint("LEFT")
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = Style.Text(r, 12, "text")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 10, 0)
        r.name:SetWidth(220)
        r.name:SetWordWrap(false)
        r.count = Style.Text(r, 12, "muted")
        r.count:SetPoint("RIGHT")
        r.count:SetJustifyH("RIGHT")
        Tooltip(r)
        items[i] = r
        return r
    end
    local function Place(region, y)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
        region:Show()
    end

    local function RecipeName(recipe)
        return recipe.label or (recipe.item and Compat.ItemName(recipe.item)) or (Compat.SpellInfo(recipe.spell)) or "..."
    end

    ---------------------------------------------------------------------
    -- Guild crafters: a card under your professions, and on the right a
    -- search of what guildmates make, crafts someone online makes first.
    ---------------------------------------------------------------------
    local guildCard = CreateFrame("Button", nil, page)
    guildCard:SetSize(LIST_W, CARD_H)
    Style.Fill(guildCard, "well")
    guildCard.edges = Style.Border(guildCard, "line")
    local guildIcon = guildCard:CreateTexture(nil, "ARTWORK")
    guildIcon:SetSize(32, 32)
    guildIcon:SetPoint("TOPLEFT", 12, -12)
    guildIcon:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Icons\\guild")
    local guildName = Style.Text(guildCard, 13, "text", nil, true)
    guildName:SetPoint("TOPLEFT", guildIcon, "TOPRIGHT", 10, 0)
    guildName:SetText("Guild crafters")
    local guildSub = Style.Text(guildCard, 11, "muted")
    guildSub:SetPoint("TOPLEFT", guildName, "BOTTOMLEFT", 0, -3)
    guildSub:SetText("Who in the guild makes what")

    local G_ROW = 46
    local guildView = CreateFrame("Frame", nil, page)
    guildView:SetPoint("TOPLEFT", LIST_W + GAP, -top)
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
    local maxRows = math.max(1, math.floor((height - top - 82 - 24) / G_ROW))
    local gRows = {}
    local function GuildRow(i)
        if gRows[i] then return gRows[i] end
        local r = CreateFrame("Frame", nil, guildView)
        r:SetSize(roadW, G_ROW)
        r:SetPoint("TOPLEFT", 0, -(76 + (i - 1) * G_ROW))
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
        r.whisper = Style.Button(r, "Whisper", "primary", 140)
        r.whisper:SetHeight(26)
        r.whisper:SetPoint("RIGHT", 0, 0)
        Tooltip(r)
        gRows[i] = r
        return r
    end

    local function PaintGuild()
        local Crafters = ns.Crafters
        local sharing = Crafters.Count()
        gHead.note:SetText(sharing > 0 and ("%d guildmate%s sharing"):format(sharing, sharing == 1 and "" or "s") or "")
        local text = search:GetText()
        searchHint:SetShown(text == "" and not search:HasFocus())
        for _, r in ipairs(gRows) do r:Hide() end
        gFoot:SetText("")
        local note
        if not IsInGuild() then
            note = "Guild crafters shows what your guildmates can make. Join a guild to use it."
        elseif sharing == 0 then
            note = "No recipes heard yet. Guildmates with jsal.ui share theirs once they've opened their profession windows, and their crafts show here as they come in."
        elseif strtrim(text) == "" then
            note = "Type what you need. Guildmates online now come first, with a button to whisper them."
        end
        local found = not note and Crafters.Search(text, 200) or {}
        if not note and #found == 0 then note = "No guildmate makes anything by that name yet." end
        gMessage:SetText(note or "")
        gMessage:SetShown(note ~= nil)
        for i = 1, math.min(#found, maxRows) do
            local entry, r = found[i], GuildRow(i)
            r:Show()
            r.item = entry.row.item
            r.spell = not entry.row.item and entry.row.spell or nil
            r.icon:SetTexture((entry.row.item and Compat.ItemIcon(entry.row.item)) or select(2, Compat.SpellInfo(entry.row.spell)))
            r.name:SetText(entry.name)
            local on, off = {}, {}
            for _, p in ipairs(entry.people) do
                if p.online then
                    on[#on + 1] = "|cff56944f" .. p.name .. "|r"
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
        if #found > maxRows then
            gFoot:SetText(("Showing %d of %d. Type more to narrow it."):format(maxRows, #found))
        end
    end
    search:SetScript("OnTextChanged", function() xpcall(PaintGuild, ns.Report) end)
    search:SetScript("OnEditFocusGained", function() searchHint:Hide() end)
    search:SetScript("OnEditFocusLost", function() searchHint:SetShown(search:GetText() == "") end)

    local function Paint()
        local mine = Professions.Mine()
        none:SetShown(#mine == 0)
        none:SetText("No crafting professions yet. Learn one at a trainer, and its road shows here.")
        local guildOn = ns.Crafters and ns.Crafters.running
        if selected == "guild" and not guildOn then selected = nil end
        if selected ~= "guild" and (not selected or not Professions.Name(selected)) then
            selected = (mine[1] and mine[1].line) or (guildOn and "guild") or nil
        end
        guildCard:SetShown(guildOn)
        if guildOn then
            guildCard:ClearAllPoints()
            local below = #mine > 0 and #mine * (CARD_H + 10) or (none:GetStringHeight() + 16)
            guildCard:SetPoint("TOPLEFT", 0, -(top + below))
            Style.SetBorder(guildCard.edges, selected == "guild" and "gold" or "line")
            guildCard:SetScript("OnClick", function()
                selected = "guild"
                Paint()
            end)
        end
        guildView:SetShown(selected == "guild")
        local current
        for i, p in ipairs(mine) do
            local c = Card(i)
            c:Show()
            c.icon:SetTexture(p.icon)
            c.name:SetText(p.name)
            local rank = Professions.Rank(p.cap)
            c.sub:SetText(("%d of %d · %s"):format(p.skill, p.cap, rank.name))
            c.fill:SetWidth(math.max(1, (LIST_W - 24) * math.min(1, p.skill / math.max(1, p.cap))))
            Style.SetBorder(c.edges, p.line == selected and "gold" or "line")
            c:SetScript("OnClick", function()
                selected = p.line
                Paint()
            end)
            if p.line == selected then current = p end
        end
        for i = #mine + 1, #cards do cards[i]:Hide() end

        for _, s in ipairs(steps) do s:Hide() end
        for _, r in ipairs(items) do r:Hide() end
        needHead:Hide()
        scroll:SetShown(selected ~= "guild")
        if selected == "guild" then
            head:Hide()
            where:Hide()
            pin:Hide()
            PaintGuild()
            return
        end
        if not current then
            head:Hide()
            message:Hide()
            where:Hide()
            pin:Hide()
            return
        end
        head:Show()

        -- What you know: as last seen in its window, else every trainer
        -- recipe up to your skill.
        local seen = Professions.Remembered(current.line)
        local set = seen and seen.known
        if not set then
            set = {}
            for _, recipe in ipairs(Professions.Recipes(current.line)) do
                if recipe.how == 1 and recipe.learn <= current.skill then set[recipe.spell] = true end
            end
        end
        local function known(spell) return set[spell] end
        local target, rank = Professions.Target(current.skill, current.cap)
        local road, totals, stuck, made = Professions.Plan(current.line, current.skill, target, known)
        local crafts = 0
        for _, step in ipairs(road) do crafts = crafts + step.crafts end
        head.title:SetText(current.skill >= current.cap and "AT THE CAP" or ("YOUR WAY TO %d"):format(target))
        local unit = Professions.IsGathering(current.line) and "vein" or "craft"
        head.note:SetText(crafts > 0 and ("about %d %s%s"):format(crafts, unit, crafts == 1 and "" or "s") or "")

        local y = 0
        local notes = {}
        if not seen and not Professions.IsGathering(current.line) then
            notes[#notes + 1] = ("Open your %s window once so this uses the recipes you know."):format(current.name)
        end
        if rank.at then
            notes[#notes + 1] = ("%s from %d skill and level %d, at a trainer."):format(rank.next, rank.at, rank.level)
        end
        if stuck then notes[#notes + 1] = ("Past %d, only dropped or quest patterns give skill."):format(stuck) end
        message:SetText(table.concat(notes, " "))
        message:SetShown(#notes > 0)
        if #notes > 0 then
            Place(message, y)
            y = y + message:GetStringHeight() + 12
        end
        for i, step in ipairs(road) do
            local s = Step(i)
            Place(s, y)
            s.item, s.spell = step.recipe.item, step.recipe.spell
            s.levels:SetText(("%d → %d"):format(step.from, step.to))
            s.icon:SetTexture((step.recipe.item and Compat.ItemIcon(step.recipe.item)) or select(2, Compat.SpellInfo(step.recipe.spell)))
            s.name:SetText(("%s ×%d"):format(RecipeName(step.recipe), step.crafts))
            if step.recipe.vein then
                s.detail:SetText(("Mine them: a sure point each until %d"):format(step.recipe.yellow))
            elseif step.buy then
                s.detail:SetText(("Buy the pattern from a vendor, from %d"):format(step.recipe.learn))
            elseif step.learn then
                s.detail:SetText(("Learn it at the trainer, from %d"):format(step.recipe.learn))
            else
                local parts = {}
                for _, reagent in ipairs(step.recipe.reagents) do
                    parts[#parts + 1] = ("%d %s"):format(reagent.count * step.crafts, Compat.ItemName(reagent.item) or "...")
                end
                s.detail:SetText("needs " .. table.concat(parts, ", "))
            end
            y = y + STEP_H
        end

        local needs = {}
        for item, need in pairs(totals) do
            needs[#needs + 1] = { item = item, need = need, have = Compat.ItemCount(item, true) }
        end
        table.sort(needs, function(a, b)
            local sa, sb = a.need - a.have, b.need - b.have
            if sa ~= sb then return sa > sb end
            return a.item < b.item
        end)
        if #needs > 0 then
            y = y + 12
            Place(needHead, y)
            y = y + 30
            for i, entry in ipairs(needs) do
                local r = Item(i)
                Place(r, y)
                r.item = entry.item
                r.icon:SetTexture(Compat.ItemIcon(entry.item))
                r.name:SetText(Compat.ItemName(entry.item) or "...")
                local color = entry.have >= entry.need and "56944f" or "ff6b6b"
                local price = Professions.IsVendor(entry.item)
                local extra = price and (" · vendor " .. Compat.Money(price)) or (made[entry.item] and " · to make more" or "")
                r.count:SetText(("|cff%s%d|r / %d%s"):format(color, entry.have, entry.need, extra))
                y = y + ROW_H
            end
        end
        list:SetHeight(math.max(1, y))
        scroll:UpdateScrollChildRect()

        -- The nearest trainer for your rank, or the next one once you're
        -- ready for it.
        local rankIndex = 1
        for i, r in ipairs(Professions.RANKS) do if r == rank then rankIndex = i end end
        local needed = (rank.at and current.skill >= rank.at) and rankIndex + 1 or rankIndex
        local trainer = ns.Trainers and ns.Trainers.Nearest("skill" .. current.line, needed)
        where:SetShown(trainer ~= nil)
        pin:SetShown(trainer ~= nil)
        if trainer then
            local place = ns.Trainers.Zone(trainer)
            where:SetText(("Nearest trainer: |cffece6d6%s|r%s"):format(trainer.name, place and (", " .. place) or ""))
            pin:SetScript("OnClick", function() ns.Trainers.Pin(trainer) end)
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
