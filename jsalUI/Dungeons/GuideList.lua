-- The Dungeon guide's list down its left: every dungeon in its level group, a click shows it at the right.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

-- The list of dungeons, as the dashboard's menu is: the rows' width inside it, a
-- heading's height and a row's. The page sits PANEL_PAD in from the window's
-- edge, SIDE_UP under the title bar and SIDE_DOWN over the window's foot.
local SIDE_ROW_W, SIDE_HEAD, SIDE_ROW = 216, 28, 26
local PANEL_PAD, SIDE_UP, SIDE_DOWN = 22, 15, 17
-- The level the raids are for: below it the list starts with them folded.
local TOP_LEVEL = 60

local function TooHigh(d, level) return d.level > level + 3 end

-- The list's groups, by the level a dungeon is tuned to; raids on their own.
local GROUPS = {
    { label = "LEVELS 10-20", to = 19 },
    { label = "LEVELS 20-30", to = 29 },
    { label = "LEVELS 30-40", to = 39 },
    { label = "LEVELS 40-50", to = 49 },
    { label = "LEVELS 50-60", to = 60 },
    { label = "RAIDS", raid = true },
}
local function GroupOf(d)
    if d.raid then return #GROUPS end
    for g, group in ipairs(GROUPS) do
        if group.to and d.level <= group.to then return g end
    end
    return #GROUPS - 1
end

ns.DungeonGuide = ns.DungeonGuide or {}

-- Made once, as the guide is built, on `guide.page`: returns the list's table (List). A click on a dungeon
-- sets `guide.chosen` and paints the page.
function ns.DungeonGuide.List(guide, Kit)
    local SIDE_W, Fits, InOrder, Facts, GREEN, QUEST_SIGN = Kit.SIDE_W, Kit.Fits, Kit.InOrder, Kit.Facts, Kit.GREEN,
        Kit.QUEST_SIGN
    local D, page, wait = ns.Dungeons, guide.page, guide.wait

    -----------------------------------------------------------------
    -- Down the left: every dungeon in its level group, in the look of the
    -- dashboard's menu. A click on a group's heading folds or opens it; a
    -- click on a dungeon shows it at the right. Rows are made only for the
    -- groups that are open, and kept for the next paint. Pointing at a row
    -- says what it leaves out, and asks the game for that dungeon's items,
    -- so a click on it is mostly drawn at once: no other dungeon's are asked
    -- for. `held` is how many quests in your log are for each dungeon, read
    -- from the log once and kept until the game says the log changed.
    -----------------------------------------------------------------
    local List = { heads = {}, rows = {}, reveal = true }
    local side = CreateFrame("Frame", nil, page)
    side:SetPoint("TOPLEFT", -(PANEL_PAD - 1), SIDE_UP)
    side:SetPoint("BOTTOMLEFT", -(PANEL_PAD - 1), -SIDE_DOWN)
    side:SetWidth(SIDE_W)
    Style.Cap(side, 6, "titleBar", "BOTTOMLEFT")
    Style.Rule(side, "RIGHT", "line")
    -- The list runs from the page's top to its foot, as the page is tall.
    List.scroll, List.child = Style.Scroller(side, SIDE_ROW_W, 100, SIDE_ROW_W, 6, 52)
    List.scroll:ClearAllPoints()
    List.scroll:SetPoint("TOPLEFT", 12, -SIDE_UP)
    List.scroll:SetPoint("BOTTOMRIGHT", -12, SIDE_DOWN)

    -- A group's heading: + or a dash, its name in gold, and at its right how
    -- many it holds, after "your level" where one is right for you.
    function List.Head(g)
        if List.heads[g] then return List.heads[g] end
        local h = CreateFrame("Button", nil, List.child)
        h:SetSize(SIDE_ROW_W, SIDE_HEAD)
        h.sign = Style.Text(h, 14, "gold", nil, true)
        h.sign:SetPoint("LEFT", 4, 0)
        h.label = Style.Text(h, 11, "gold", nil, true)
        h.label:SetPoint("LEFT", 18, 0)
        h.note = Style.Text(h, 11, "muted")
        h.note:SetPoint("RIGHT", -4, 0)
        h.note:SetJustifyH("RIGHT")
        h:SetScript("OnClick", function()
            List.open[g] = not List.open[g] or nil
            List.Paint()
            List.Fit(List.content or 0)
        end)
        Style.Hover(h, 0, 5)
        List.heads[g] = h
        return h
    end

    -- A dungeon's row: its name, and at its right the starred pieces that drop
    -- there, a ? when a quest in your log is for it, and its level. The chosen
    -- one is filled, with a gold mark down its left, as the menu's open page.
    function List.Row(i)
        if List.rows[i] then return List.rows[i] end
        local r = CreateFrame("Button", nil, List.child)
        r:SetSize(SIDE_ROW_W, SIDE_ROW)
        r.lit = Style.Round(r, 5, "well")
        r.mark = r:CreateTexture(nil, "ARTWORK")
        r.mark:SetColorTexture(Style.Color("gold"))
        r.mark:SetSize(3, 18)
        r.mark:SetPoint("LEFT", 0, 0)
        r.level = Style.Text(r, 12, "muted")
        r.level:SetPoint("RIGHT", -8, 0)
        r.level:SetJustifyH("RIGHT")
        r.marks = Style.Text(r, 12, "gold", nil, true)
        r.marks:SetPoint("RIGHT", -32, 0)
        r.marks:SetJustifyH("RIGHT")
        r.name = Style.Text(r, 13, "secondary")
        r.name:SetPoint("LEFT", 12, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.size = select(2, r.name:GetFont())
        r:SetScript("OnClick", List.Click)
        r:SetScript("OnEnter", List.Enter)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        Style.Hover(r, 0, 5)
        List.rows[i] = r
        return r
    end

    function List.Click(self)
        if not self.dungeon then return end
        guide.chosen = self.dungeon
        guide.Paint()
    end

    -- Pointed at: the dungeon's name, level and place, its bosses you've
    -- killed, and what its marks stand for. Beside the list, at the row.
    function List.Enter(self)
        local d = self.dungeon
        if not d then return end
        if not wait.asked[d] then wait.Count(d) end
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 6, 2)
        GameTooltip:SetText(d.name, 1, 1, 1)
        GameTooltip:AddLine(table.concat(Facts(d), " \194\183 "), 0.6, 0.59, 0.53)
        local game, killed = D.GameKills(), 0
        for _, b in ipairs(d.bosses) do
            if D.KillCount(b[2], game, b[3]) > 0 then killed = killed + 1 end
        end
        GameTooltip:AddLine(("%d of %d bosses killed"):format(killed, #d.bosses), 0.6, 0.59, 0.53)
        local stars, quests = self.stars or 0, self.quests or 0
        if stars > 0 then
            GameTooltip:AddLine(stars == 1 and "1 piece you starred drops here" or ("%d pieces you starred drop here"):format(stars), 0.89, 0.69, 0.29)
        end
        if quests > 0 then
            GameTooltip:AddLine(QUEST_SIGN .. " " .. (quests == 1 and "A quest in your log is for here"
                or ("%d quests in your log are for here"):format(quests)), 0.89, 0.69, 0.29)
        end
        GameTooltip:Show()
    end

    -- How many quests in your log are for each dungeon: { [dungeon id] = n }.
    function List.Quests()
        if List.held then return List.held end
        local held, log = {}, C_QuestLog
        if log and log.GetNumQuestLogEntries and log.GetInfo then
            if not List.questFor then
                List.questFor = {}
                for id, quests in pairs(ns.DungeonQuests or {}) do
                    for _, q in ipairs(quests) do
                        local list = List.questFor[q[1]] or {}
                        list[#list + 1] = id
                        List.questFor[q[1]] = list
                    end
                end
            end
            local count = log.GetNumQuestLogEntries()
            for i = 1, count or 0 do
                local info = log.GetInfo(i)
                local ids = info and not info.isHeader and info.questID and List.questFor[info.questID]
                for _, id in ipairs(ids or {}) do held[id] = (held[id] or 0) + 1 end
            end
        end
        List.held = held
        return held
    end

    -- The groups that start open: each with a dungeon right for your level
    -- (or, with none, the one your level is in) and the one after the last of
    -- them, the raids only at the top level. Folded, a group is its count.
    function List.Opening(members, level)
        local open, last = {}, nil
        for g in ipairs(GROUPS) do
            for _, d in ipairs(members[g] or {}) do
                if Fits(d, level) then
                    open[g], last = true, g
                    break
                end
            end
        end
        if not last then
            last = GroupOf({ level = level })
            open[last] = true
        end
        local after = GROUPS[last + 1]
        if after and members[last + 1] and not (after.raid and level < TOP_LEVEL) then open[last + 1] = true end
        return open
    end

    function List.Paint()
        local chosen = guide.chosen
        local level = UnitLevel("player") or 1
        local faction = Compat.Faction()
        List.dirty, List.shown = nil, chosen
        local members = {}
        for _, d in ipairs(InOrder(faction)) do
            local g = GroupOf(d)
            members[g] = members[g] or {}
            table.insert(members[g], d)
        end
        List.open = List.open or List.Opening(members, level)
        -- A dungeon shown from elsewhere opens its group, and is brought into view.
        local reveal = List.reveal and chosen
        if reveal then List.open[GroupOf(chosen)] = true end
        List.reveal = nil
        local held = List.Quests()
        local y, i, chosenY = 0, 0, nil
        for g, group in ipairs(GROUPS) do
            local inGroup = members[g]
            if inGroup then
                local h = List.Head(g)
                local fits = 0
                for _, d in ipairs(inGroup) do if Fits(d, level) then fits = fits + 1 end end
                h.label:SetText(group.label)
                h.note:SetText(fits > 0 and (GREEN .. "your level|r \194\183 " .. #inGroup) or tostring(#inGroup))
                h.sign:SetText(List.open[g] and "\226\128\147" or "+")
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", 0, -y)
                h:Show()
                y = y + SIDE_HEAD
                for _, d in ipairs(List.open[g] and inGroup or {}) do
                    i = i + 1
                    local r = List.Row(i)
                    r.dungeon = d
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", 0, -y)
                    local on = d == chosen
                    if on then chosenY = y end
                    r.lit:SetShown(on)
                    r.mark:SetShown(on)
                    r.name:SetText(d.name)
                    r.name:SetTextColor(Style.Color(on and "text" or "secondary"))
                    if r.size then r.name:SetFont(on and Style.boldFont or Style.font, r.size, "") end
                    r.level:SetText((Fits(d, level) and GREEN or "") .. d.level .. (Fits(d, level) and "|r" or ""))
                    r.stars = ns.Gear and ns.Gear.StarsIn and #ns.Gear.StarsIn(d) or 0
                    r.quests = held[d.id] or 0
                    local said = (r.stars > 0 and (ns.Gear.STAR .. " " .. r.stars) or "")
                        .. (r.stars > 0 and r.quests > 0 and "  " or "") .. (r.quests > 0 and QUEST_SIGN or "")
                    r.marks:SetText(said)
                    -- The name gives way to the marks; its tooltip has it whole.
                    local marks = said ~= "" and r.marks:GetStringWidth()
                    marks = type(marks) == "number" and marks + 6 or 0
                    r.name:SetWidth(SIDE_ROW_W - 12 - 32 - marks)
                    -- Well above your level, dimmed, as in the guide's other lists.
                    r:SetAlpha(TooHigh(d, level) and not on and 0.5 or 1)
                    r:Show()
                    y = y + SIDE_ROW
                end
                if List.open[g] then y = y + 6 end
            elseif List.heads[g] then
                List.heads[g]:Hide()
            end
        end
        for k = i + 1, #List.rows do List.rows[k]:Hide() end
        List.need = y
        List.child:SetHeight(math.max(1, y))
        if reveal and chosenY then
            local room = List.scroll:GetHeight()
            local range = math.max(0, y - ((type(room) == "number" and room > 0) and room or y))
            List.scroll:SetVerticalScroll(math.max(0, math.min(range, chosenY - 2 * SIDE_ROW)))
        end
    end
    return List
end
