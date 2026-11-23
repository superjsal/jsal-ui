-- The Dungeon guide's Quests tab: the dungeon's quests by where they start, a chain as a card of its steps.
local _, ns = ...
local Style = ns.Style

local function QuestDone(id)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(id) and true or false end
    return IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(id) and true or false
end

ns.DungeonGuide = ns.DungeonGuide or {}

-- Made once, as the guide is built: returns the tab's table (Q), whose frames go on `guide.bossList`.
function ns.DungeonGuide.Quests(guide, Kit)
    local Starts, QuestHeld, QuestMark, GREEN, RED = Kit.Starts, Kit.QuestHeld, Kit.QuestMark, Kit.GREEN, Kit.RED
    local bossList, rightW, hint = guide.bossList, guide.rightW, guide.hint

    -- The quests tab, made to be read at a glance by anyone. A line of what
    -- there is, column headings, a bar for each place quests start in, a
    -- line for a quest that stands alone, and a card of numbered steps for a
    -- chain, with the step to start at marked.
    local Q = { lines = {}, heads = {}, priors = {}, cards = {}, steps = {} }
    -- Where the "who gives it" column starts, across the list.
    local WHO_X = math.floor(rightW * 0.42)

    -- The top of the list: what's here, a word when you're under level, and
    -- the column headings.
    function Q.Top()
        if Q.sum then return end
        Q.sum = Style.Text(bossList, 13, "text", nil, true)
        Q.more = Style.Text(bossList, 12, "muted")
        Q.more:SetPoint("LEFT", Q.sum, "RIGHT", 10, 0)
        Q.low = Style.Text(bossList, 12, "muted")
        Q.low:SetJustifyH("RIGHT")
        Q.cols = CreateFrame("Frame", nil, bossList)
        Q.cols:SetSize(rightW, 20)
        local quest = Style.Text(Q.cols, 10, "muted", nil, true)
        quest:SetPoint("LEFT", 10, 0)
        quest:SetText("QUEST")
        local who = Style.Text(Q.cols, 10, "muted", nil, true)
        who:SetPoint("LEFT", WHO_X, 0)
        who:SetText("WHO GIVES IT, AND WHERE")
        local level = Style.Text(Q.cols, 10, "muted", nil, true)
        level:SetPoint("RIGHT", -10, 0)
        level:SetText("LEVEL")
        Style.Rule(Q.cols, "BOTTOM", "lineStrong")
    end

    -- How wide a line of text is drawn, or a guess where that isn't known.
    function Q.Wide(text, guess)
        local w = text.GetStringWidth and text:GetStringWidth()
        return (type(w) == "number" and w > 0) and w or guess
    end

    local function QuestTip(frame)
        frame:EnableMouse(true)
        frame:SetScript("OnEnter", function(self)
            if not self.quest then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(("quest:%d"):format(self.quest))
            if self.ownQuest then GameTooltip:AddLine("This dungeon's quest.", 0.77, 0.75, 0.69) end
            if self.spot then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(("Click to pin %s on your map"):format(self.spot[2]), 0.89, 0.69, 0.29)
            end
            GameTooltip:Show()
        end)
        frame:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" and self.spot then Starts.Pin(self.spot) end
        end)
        frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        Style.Hover(frame)
    end

    -- The mark of a quest that's this dungeon's own: jsal.ui's Dungeons
    -- picture, small, where the words "this dungeon's quest" stood on
    -- every such step.
    local function OwnMark(parent)
        local m = CreateFrame("Frame", nil, parent)
        m:SetSize(18, 18)
        m.wide = 18
        m.icon = m:CreateTexture(nil, "ARTWORK")
        m.icon:SetAllPoints()
        m.icon:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Icons\\dungeons")
        return m
    end

    -- A quest that stands alone: its name, who gives it, the level.
    function Q.Line(i)
        if Q.lines[i] then return Q.lines[i] end
        local q = CreateFrame("Frame", nil, bossList)
        q:SetSize(rightW, 26)
        q.level = Style.Text(q, 12, "muted")
        q.level:SetPoint("RIGHT", -10, 0)
        q.level:SetJustifyH("RIGHT")
        q.mark = q:CreateTexture(nil, "ARTWORK")
        q.mark:SetSize(16, 16)
        q.mark:SetPoint("LEFT", 8, 0)
        q.name = Style.Text(q, 13, "text")
        q.name:SetPoint("LEFT", 30, 0)
        q.name:SetWordWrap(false)
        q.who = Style.Text(q, 12, "muted")
        q.who:SetPoint("LEFT", WHO_X, 0)
        q.who:SetPoint("RIGHT", q.level, "LEFT", -12, 0)
        q.who:SetJustifyH("LEFT")
        q.who:SetWordWrap(false)
        Style.Rule(q, "BOTTOM", "line")
        QuestTip(q)
        Q.lines[i] = q
        return q
    end

    -- A place quests start in: its name, how many, and its stops on the map.
    function Q.Head(i)
        if Q.heads[i] then return Q.heads[i] end
        local h = CreateFrame("Button", nil, bossList)
        h:SetSize(rightW, 30)
        Style.Fill(h, "well")
        -- The place is what the list is sorted by, so it's the largest
        -- thing in it.
        h.name = Style.Text(h, 14, "text", nil, true)
        h.name:SetPoint("LEFT", 10, 0)
        h.count = Style.Text(h, 12, "muted")
        h.count:SetPoint("LEFT", h.name, "RIGHT", 8, 0)
        h.link = Style.Text(h, 11, "gold")
        h.link:SetPoint("RIGHT", -10, 0)
        h.link:SetText("show on map")
        -- Each click pins the next stop, round again after the last.
        h:SetScript("OnClick", function(self)
            local stops = self.stops
            if not (stops and stops[1]) then return end
            self.at = (self.at or 0) % #stops + 1
            Starts.Pin(stops[self.at].spot, #stops > 1 and (" (stop %d of %d: click again for the next)"):format(self.at, #stops) or nil)
        end)
        Q.heads[i] = h
        return h
    end

    -- A finished quest, at the foot of the list: ticked, greyed, "done".
    function Q.Prior(i)
        if Q.priors[i] then return Q.priors[i] end
        local l = CreateFrame("Frame", nil, bossList)
        l:SetSize(rightW, 21)
        l.box = CreateFrame("Frame", nil, l)
        l.box:SetSize(12, 12)
        l.box:SetPoint("LEFT", 10, 0)
        l.fill = Style.Circle(l.box, "wordGreen", "wordGreen").fill
        l.tick = l.box:CreateTexture(nil, "OVERLAY")
        l.tick:SetSize(14, 14)
        l.tick:SetPoint("CENTER", 1, 0)
        l.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        l.tick:SetDesaturated(true)
        l.tick:SetVertexColor(1, 1, 1)
        l.name = Style.Text(l, 12, "muted")
        l.name:SetPoint("LEFT", l.box, "RIGHT", 8, 0)
        l.name:SetWordWrap(false)
        l.done = Style.Text(l, 11, "muted")
        l.done:SetPoint("LEFT", l.name, "RIGHT", 8, 0)
        l.done:SetText(GREEN .. "done|r")
        l:SetAlpha(0.75)
        Q.priors[i] = l
        return l
    end

    -- A chain: a card headed by the dungeon's quest, with how many steps.
    function Q.Card(i)
        if Q.cards[i] then return Q.cards[i] end
        local c = CreateFrame("Frame", nil, bossList)
        c:SetWidth(rightW - 8)
        Style.Fill(c, "well"):SetAlpha(0.5)
        c.edge = c:CreateTexture(nil, "ARTWORK")
        c.edge:SetColorTexture(Style.Color("gold"))
        c.edge:SetPoint("TOPLEFT")
        c.edge:SetPoint("BOTTOMLEFT")
        c.edge:SetWidth(3)
        c.title = Style.Text(c, 13, "text", nil, true)
        c.title:SetPoint("TOPLEFT", 14, -9)
        c.count = Style.Tag(c, "", nil, true)
        c.count:SetPoint("LEFT", c.title, "RIGHT", 8, 0)
        -- Where every step is this dungeon's own, the mark is here once,
        -- and not on each step. Pointing at it says what it means.
        c.own = OwnMark(c)
        c.own:SetPoint("LEFT", c.count, "RIGHT", 10, 0)
        c.own:EnableMouse(true)
        c.own:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Every step is this dungeon's quest")
            GameTooltip:Show()
        end)
        c.own:SetScript("OnLeave", function() GameTooltip:Hide() end)
        c.every = Style.Text(c, 11, "muted")
        c.every:SetPoint("LEFT", c.own, "RIGHT", 6, 0)
        c.every:SetText("every step")
        -- A card that ends in more than one of the dungeon's quests says so.
        c.opens = Style.Tag(c, "", nil, true)
        c.opens:SetPoint("LEFT", c.count, "RIGHT", 6, 0)
        c.level = Style.Text(c, 12, "muted")
        c.level:SetPoint("TOPRIGHT", -6, -10)
        c.level:SetJustifyH("RIGHT")
        Q.cards[i] = c
        return c
    end

    -- A step of a chain: its number on the line that joins them, its name,
    -- what it is, and who gives it.
    function Q.Step(i)
        if Q.steps[i] then return Q.steps[i] end
        local st = CreateFrame("Frame", nil, bossList)
        st:SetSize(rightW - 8, 24)
        -- Above its card: both are the list's children, and at one level the
        -- game may draw the card's fill over the step.
        st:SetFrameLevel(bossList:GetFrameLevel() + 3)
        -- The line that joins a chain's steps, plain enough to read as one.
        st.rail = st:CreateTexture(nil, "BACKGROUND")
        do
            local r, g, b = Style.Color("muted")
            st.rail:SetColorTexture(r, g, b, 0.6)
        end
        st.rail:SetPoint("TOPLEFT", 25, 0)
        st.rail:SetSize(2, 24)
        st.badge = CreateFrame("Frame", nil, st)
        st.badge:SetHeight(18)
        st.badge:SetPoint("CENTER", st, "LEFT", 26, 0)
        -- A circle, the picture a stop's sign on a road is drawn with. A
        -- run of numbers ("2-8") is wider than it's tall, and a circle
        -- pulled wide is an egg: that one is a box with round corners.
        st.disc = Style.Circle(st.badge, "line", "lineStrong")
        st.pill = Style.PillBox(st.badge, "line", "lineStrong")
        st.number = Style.Text(st.badge, 10, "muted", nil, true)
        st.number:SetPoint("CENTER")
        st.tick = st.badge:CreateTexture(nil, "OVERLAY")
        st.tick:SetSize(16, 16)
        st.tick:SetPoint("CENTER", 1, 0)
        st.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        st.tick:SetDesaturated(true)
        st.tick:SetVertexColor(1, 1, 1)
        st.name = Style.Text(st, 13, "muted")
        st.name:SetPoint("LEFT", 48, 0)
        st.name:SetWordWrap(false)
        -- The step to do now has the quest's mark after its name.
        st.mark = st:CreateTexture(nil, "ARTWORK")
        st.mark:SetSize(16, 16)
        st.mark:SetPoint("LEFT", st.name, "RIGHT", 6, 0)
        st.start = Style.Tag(st, "start here", true, true)
        st.start:SetPoint("LEFT", st.mark, "RIGHT", 4, 0)
        st.own = OwnMark(st)
        st.who = Style.Text(st, 12, "muted")
        st.who:SetPoint("RIGHT", -8, 0)
        st.who:SetJustifyH("LEFT")
        st.who:SetWordWrap(false)
        -- Its own level, where a card ends in quests of different levels.
        st.level = Style.Text(st, 12, "muted")
        st.level:SetPoint("RIGHT", -6, 0)
        st.level:SetJustifyH("RIGHT")
        QuestTip(st)
        Q.steps[i] = st
        return st
    end

    -- Who gives a quest: on a quest's own line the place is its heading, so
    -- it's the giver and the spot; on a step, the place is said too.
    function Q.Giver(s, place)
        if not (s and s[2]) then return "" end
        if s[3] == 3 then return Starts.Where(s) or "" end
        local zone, kind = Starts.Place(s)
        local spot = (s[5] ~= 0 and s[6] and s[6] > 0) and ("%.0f, %.0f"):format(s[6], s[7] or 0) or nil
        if not place then return spot and (s[2] .. "  ·  " .. spot) or s[2] end
        if kind == 2 then return s[2] .. "  ·  " .. (zone:gsub("^Inside ", "inside ")) end
        if kind ~= 1 then return s[2] end
        return s[2] .. "  ·  " .. zone .. (spot and (" " .. spot) or "")
    end

    -- The level column: the quest's own level. The level you can take it at
    -- is said only while you're under it, in red; once you can take it, it
    -- has nothing more to tell you.
    function Q.Level(q, mine)
        local take = q[4] or q[3]
        if take > mine then
            if take >= q[3] then return ("%sneeds level %d|r"):format(RED, take) end
            return ("level %d · %sneeds level %d|r"):format(q[3], RED, take)
        end
        return ("level %d"):format(q[3])
    end

    local WORDS = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten" }

    -- Hides what the tab has made past what a paint used: `lines` of its lines, `heads` of its places, and so on.
    function Q.HideFrom(lines, heads, priors, cards, steps)
        for k = lines + 1, #Q.lines do Q.lines[k]:Hide() end
        for k = heads + 1, #Q.heads do Q.heads[k]:Hide() end
        for k = priors + 1, #Q.priors do Q.priors[k]:Hide() end
        for k = cards + 1, #Q.cards do Q.cards[k]:Hide() end
        for k = steps + 1, #Q.steps do Q.steps[k]:Hide() end
    end

    -- Paints the quests tab from `by` down the list, and returns where it
    -- ended.
    function Q.Paint(quests, by)
        Q.Top()
        local mine = UnitLevel("player") or 1
        local byId, todo, finished = {}, {}, {}
        for _, q in ipairs(quests) do byId[q[1]] = q end
        for _, q in ipairs(quests) do
            local to = QuestDone(q[1]) and finished or todo
            to[#to + 1] = q
        end
        -- Each quest still to do, with its place and the one before it.
        local entries, opens = {}, {}
        for _, q in ipairs(todo) do
            local s = Starts.Get(q[1])
            local e = { q = q, s = s, before = s and s[8] or nil }
            e.place, e.kind = Starts.Place(s)
            if e.before and QuestDone(e.before) then opens[e.before] = true end
            entries[q[1]] = e
        end
        -- A later part: its first part is on the list and still to do. It
        -- goes with that one; the rest are what there is to pick up, and
        -- are placed further down, once their chains are known.
        local under, tops, later = {}, {}, 0
        for _, q in ipairs(todo) do
            local e = entries[q[1]]
            if e.before and entries[e.before] and e.before ~= q[1] then
                under[e.before] = under[e.before] or {}
                table.insert(under[e.before], e)
                later = later + 1
            else
                tops[#tops + 1] = e
            end
        end
        local function ByLevel(x, y)
            if x.q[3] ~= y.q[3] then return x.q[3] < y.q[3] end
            return x.q[1] < y.q[1]
        end
        for _, list in pairs(under) do table.sort(list, ByLevel) end
        table.sort(tops, ByLevel)

        -- The line at the top: what's here in plain words, and one word
        -- about your level in place of "needs level N" down every row.
        local now = #todo - later
        local tooLow, least = 0, nil
        for _, q in ipairs(todo) do
            local needs = q[4] or q[3]
            if needs > mine then
                tooLow = tooLow + 1
                least = least and math.min(least, needs) or needs
            end
        end
        -- "you can pick up" only when you can: under level for some, it's
        -- "to pick up", and the line at the right says how many are above you.
        Q.sum:SetText(#quests == 0 and "" or ("%d quest%s %s"):format(now, now == 1 and "" or "s", tooLow > 0 and "to pick up" or "you can pick up"))
        Q.sum:ClearAllPoints()
        Q.sum:SetPoint("TOPLEFT", 0, -(by + 4))
        local more = {}
        if later > 0 then more[#more + 1] = ("%d more follow%s those"):format(later, later == 1 and "s" or "") end
        if #finished > 0 then more[#more + 1] = ("%d done"):format(#finished) end
        Q.more:SetText(#more > 0 and ("· " .. table.concat(more, " · ")) or "")
        local many = tooLow == #todo and tooLow > 1 and "all of these need" or ("%d of these need%s"):format(tooLow, tooLow == 1 and "s" or "")
        Q.low:SetText(tooLow > 0 and ("%sYou're level %d: %s level %d or more|r"):format(RED, mine, many, least) or "")
        Q.low:ClearAllPoints()
        Q.low:SetPoint("TOPRIGHT", bossList, "TOPLEFT", rightW, -(by + 5))
        -- That line shows only when it has more to say than the count the
        -- tab already gives: some above your level, later parts, some done.
        local said = #quests > 0 and (tooLow > 0 or #more > 0)
        for _, region in ipairs({ Q.sum, Q.more, Q.low }) do region:SetShown(said) end
        Q.cols:SetShown(#quests > 0)
        hint:SetText((#quests > 0 and ns.DungeonQuestStarts) and "click a quest, a step or a place for a map pin" or "")
        if #quests > 0 then
            if said then by = by + 28 end
            Q.cols:ClearAllPoints()
            Q.cols:SetPoint("TOPLEFT", 0, -by)
            by = by + 28
        end

        local lines, heads, priors, cards, steps = 0, 0, 0, 0, 0
        local function Named(quest)
            local s = Starts.Get(quest)
            return (byId[quest] and byId[quest][2]) or (s and s[1] ~= "" and s[1]) or nil
        end
        -- What follows a quest and isn't one of this dungeon's, if anything.
        local function After(e)
            local after = Starts.Next(e.q[1])
            if after and not byId[after] and not under[e.q[1]] and not QuestDone(after) and Named(after) then return after end
        end
        -- A chain, in order: what leads up to the quest (back to the last
        -- one finished), the quest, what's under it, and what follows. Each
        -- is { id, name, s, own (one of this dungeon's), done }.
        local function Chain(e)
            local chain, lead, id = {}, {}, e.before
            while id and #lead < 12 and not entries[id] do
                lead[#lead + 1] = id
                if QuestDone(id) then break end
                local s = Starts.Get(id)
                id = s and s[8] or nil
            end
            for i = #lead, 1, -1 do
                if Named(lead[i]) then
                    chain[#chain + 1] = { id = lead[i], name = Named(lead[i]), s = Starts.Get(lead[i]), done = QuestDone(lead[i]) }
                end
            end
            local seen = {}
            local function Own(entry)
                if seen[entry] then return end
                seen[entry] = true
                chain[#chain + 1] = { id = entry.q[1], name = entry.q[2], s = entry.s, own = true, q = entry.q }
                for _, child in ipairs(under[entry.q[1]] or {}) do Own(child) end
                local after = After(entry)
                if after then chain[#chain + 1] = { id = after, name = Named(after), s = Starts.Get(after) } end
            end
            Own(e)
            -- A step in your quest log: what's before it is behind you,
            -- finished or never needed, so it's where the chain stands.
            local held
            for i, step in ipairs(chain) do
                if not step.done and QuestHeld(step.id) then held = i end
            end
            for i = 1, (held or 1) - 1 do chain[i].done = true end
            return chain
        end
        -- A run of three or more steps of one name, none of them the
        -- dungeon's own, is one line: "2-7  The True Masters, six parts",
        -- with the places it takes you through.
        local function Folded(chain, offset)
            offset = offset or 0
            local shown, i = {}, 1
            while i <= #chain do
                local j = i
                while not chain[i].own and chain[j + 1] and not chain[j + 1].own and chain[j + 1].name == chain[i].name do j = j + 1 end
                if j - i >= 2 then
                    local route, done = {}, 0
                    for k = i, j do
                        local zone, kind = Starts.Place(chain[k].s)
                        if kind == 1 and route[#route] ~= zone then route[#route + 1] = zone end
                        if chain[k].done then done = done + 1 end
                    end
                    if #route > 4 then route = { route[1], route[2], route[3], "…", route[#route] } end
                    local count = j - i + 1
                    shown[#shown + 1] = { number = ("%d–%d"):format(i + offset, j + offset), name = ("%s, %s parts"):format(chain[i].name, WORDS[count] or count),
                        who = table.concat(route, " → ") .. (done > 0 and done < count and ("  ·  %d done"):format(done) or ""),
                        done = done == count, first = chain[i + done] or chain[i] }
                else
                    j = i
                    shown[#shown + 1] = { number = tostring(i + offset), name = chain[i].name, who = Q.Giver(chain[i].s, true), done = chain[i].done,
                        own = chain[i].own, first = chain[i] }
                end
                i = j + 1
            end
            return shown
        end
        -- A block is what a card or a line shows: one of the dungeon's quests,
        -- or several whose chains share the steps that lead up to them
        -- (`lead`, with each one's own steps after it in `tails`).
        local function PaintCard(block)
            cards = cards + 1
            local c = Q.Card(cards)
            local e, count = block.list[1], 0
            local shown
            if block.tails then
                shown = Folded(block.lead)
                for _, tail in ipairs(block.tails) do
                    for _, step in ipairs(Folded(tail, #block.lead)) do shown[#shown + 1] = step end
                    count = math.max(count, #block.lead + #tail)
                end
            else
                shown, count = Folded(block.chain), #block.chain
            end
            local names = {}
            for i, entry in ipairs(block.list) do names[i] = entry.q[2] end
            c.title:SetText(#names <= 2 and table.concat(names, Style.Tint("muted") .. " and |r")
                or (names[1] .. Style.Tint("muted") .. (" and %d more"):format(#names - 1) .. "|r"))
            c.count:Say(count == 1 and "1 step" or ("%d-step chain"):format(count))
            c.opens:SetShown(#block.list > 1)
            if #block.list > 1 then c.opens:Say(("opens %d quests"):format(#block.list)) end
            -- Every step this dungeon's own: said once, in the heading.
            local every = true
            for _, step in ipairs(block.chain) do
                if not step.own then every = false end
            end
            c.own:SetShown(every)
            c.every:SetShown(every)
            -- The level, once for the card when its quests share one; else
            -- each quest's on its own step.
            local level, same = Q.Level(e.q, mine), true
            for _, entry in ipairs(block.list) do
                if Q.Level(entry.q, mine) ~= level then same = false end
            end
            c.level:SetText(same and level or "")
            local tall = 34 + #shown * 24 + 8
            c:SetHeight(tall)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", 4, -by)
            c:Show()
            -- Who gives a step is said on the first of a run that share it.
            local lastWho
            local y, begun = by + 34, false
            for _, step in ipairs(shown) do
                steps = steps + 1
                local st = Q.Step(steps)
                local start = not step.done and not begun
                begun = begun or start
                st.quest = step.first.id
                st.spot = Starts.Spot(step.first.id, QuestDone)
                st.number:SetText(step.done and "" or step.number)
                st.tick:SetShown(step.done == true)
                local run = not step.done and step.number:find("–", 1, true) ~= nil
                st.badge:SetWidth(run and (Q.Wide(st.number, #step.number * 5) + 10) or 18)
                local shape, other = run and st.pill or st.disc, run and st.disc or st.pill
                for _, part in ipairs({ shape.line, shape.fill }) do part:Show() end
                for _, part in ipairs({ other.line, other.fill }) do part:Hide() end
                if step.done then shape:Paint("wordGreen", "wordGreen") elseif start then shape:Paint("gold", "gold") else shape:Paint("line", "lineStrong") end
                st.number:SetTextColor(Style.Color(start and "onGold" or "muted"))
                st.name:SetText(step.name)
                st.name:SetTextColor(Style.Color(start and "text" or "muted"))
                -- The step to do now: its mark, and "start here" until
                -- it's in your log.
                local held = false
                if start then
                    local q = step.first.q
                    held = QuestMark(st.mark, step.first.id, q and (q[4] or q[3]), mine)
                else
                    st.mark:Hide()
                end
                local tagged = start and not held
                st.start:SetShown(tagged)
                st.ownQuest = step.own == true
                st.own:SetShown(step.own == true and not every)
                st.own:ClearAllPoints()
                st.own:SetPoint("LEFT", tagged and st.start or (start and st.mark or st.name), "RIGHT", start and 6 or 8, 0)
                -- The giver starts at its column, or past a long name's tags.
                local ends = 48 + Q.Wide(st.name, 0) + (start and 22 or 0) + (tagged and st.start.wide + 4 or 0)
                    + ((step.own and not every) and st.own.wide + 8 or 0)
                st.who:SetPoint("LEFT", math.max(WHO_X - 4, ends + 14), 0)
                local who = step.who
                if step.done then
                    who = ""
                elseif who == lastWho then
                    who = ""
                else
                    lastWho = who
                end
                st.who:SetText(who)
                local own = not same and step.own and step.first.q or nil
                st.level:SetText(own and Q.Level(own, mine) or "")
                st:SetAlpha(step.done and 0.6 or 1)
                st:ClearAllPoints()
                st:SetPoint("TOPLEFT", 4, -y)
                st:Show()
                y = y + 24
            end
            by = by + tall + 8
        end
        -- A quest alone, on a line. Who gives it is said on the first of a
        -- run of lines that share them.
        local lineWho
        local function PaintLine(e)
            lines = lines + 1
            local row = Q.Line(lines)
            row.quest = e.q[1]
            row.spot = Starts.Spot(e.q[1], QuestDone)
            row.name:SetText(e.q[2])
            QuestMark(row.mark, e.q[1], e.q[4] or e.q[3], mine)
            local who = Q.Giver(e.s, false)
            row.who:SetText(who == lineWho and "" or who)
            lineWho = who
            row.level:SetText(Q.Level(e.q, mine))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -by)
            row:Show()
            by = by + 26
        end

        -- What there is to pick up, as blocks. A chain's lead is its steps
        -- before the dungeon's own quest. Quests whose leads are the same
        -- steps, with one of them still to do, are one block: the lead
        -- once, then each quest's own steps.
        -- Returns the places they're filed under, in the order they're shown.
        local function Places()
            local blocks, shared = {}, {}
            for _, e in ipairs(tops) do
                local chain = Chain(e)
                local lead, tail, key, open = {}, {}, {}, false
                for _, step in ipairs(chain) do
                    if #tail == 0 and not step.own then
                        lead[#lead + 1] = step
                        key[#key + 1] = step.id
                        if not step.done then open = true end
                    else
                        tail[#tail + 1] = step
                    end
                end
                local id = open and table.concat(key, ",") or nil
                local block = id and shared[id]
                if block then
                    if not block.tails then block.lead, block.tails = lead, { block.tail } end
                    block.list[#block.list + 1] = e
                    block.tails[#block.tails + 1] = tail
                    for _, step in ipairs(tail) do block.chain[#block.chain + 1] = step end
                else
                    block = { list = { e }, chain = #chain > 1 and chain or nil, tail = tail }
                    if id then shared[id] = block end
                    blocks[#blocks + 1] = block
                end
            end
            -- A block is filed where its next step is: for a quest alone, where
            -- it starts; for a chain, where the first step still to do does.
            local places, order = {}, {}
            for _, block in ipairs(blocks) do
                local e = block.list[1]
                local name, kind = e.place, e.kind
                for _, step in ipairs(block.chain or {}) do
                    if not step.done then
                        if step.s then name, kind = Starts.Place(step.s) end
                        break
                    end
                end
                local place = places[name]
                if not place then
                    place = { name = name, kind = kind, blocks = {}, quests = 0 }
                    places[name] = place
                    order[#order + 1] = place
                end
                place.blocks[#place.blocks + 1] = block
                place.quests = place.quests + #block.list
            end
            -- Places, the ones with most to pick up first; inside the dungeon
            -- and the unknown last.
            table.sort(order, function(x, y)
                if x.kind ~= y.kind then return x.kind < y.kind end
                if x.quests ~= y.quests then return x.quests > y.quests end
                return x.name < y.name
            end)
            return order
        end
        for _, place in ipairs(Places()) do
            heads = heads + 1
            local h = Q.Head(heads)
            h.name:SetText(place.name)
            -- What's here: a quest alone is a line, a chain a card.
            local chains, spots = 0, {}
            for _, block in ipairs(place.blocks) do
                if block.chain then chains = chains + 1 end
                for _, e in ipairs(block.list) do
                    local spot = Starts.Spot(e.q[1], QuestDone)
                    if spot then spots[#spots + 1] = spot end
                end
            end
            local count = ("%d quest%s"):format(place.quests, place.quests == 1 and "" or "s")
            if chains > 0 then count = count .. ("  ·  %d chain%s"):format(chains, chains == 1 and "" or "s") end
            h.count:SetText(count)
            h.stops = Starts.Stops(spots)
            -- A different place under this bar starts again at its first stop.
            if h.place ~= place.name then h.place, h.at = place.name, nil end
            h.link:SetShown(#h.stops > 0)
            h.link:SetText(#h.stops > 1 and ("show on map · %d stops"):format(#h.stops) or "show on map")
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -by)
            h:Show()
            by = by + 36
            lineWho = nil
            for _, block in ipairs(place.blocks) do
                if block.chain then
                    PaintCard(block)
                    lineWho = nil
                else
                    PaintLine(block.list[1])
                end
            end
            by = by + 8
        end
        -- Finished, and opening nothing still to do: last.
        local closed = {}
        for _, q in ipairs(finished) do
            if not opens[q[1]] then closed[#closed + 1] = q end
        end
        if #closed > 0 then
            heads = heads + 1
            local h = Q.Head(heads)
            h.name:SetText("Done")
            h.count:SetText(("%d quest%s, with nothing after %s"):format(#closed, #closed == 1 and "" or "s", #closed == 1 and "it" or "them"))
            h.stops, h.place, h.at = nil, nil, nil
            h.link:Hide()
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -by)
            h:Show()
            by = by + 36
            for _, q in ipairs(closed) do
                priors = priors + 1
                local l = Q.Prior(priors)
                l.name:SetText(q[2])
                l:ClearAllPoints()
                l:SetPoint("TOPLEFT", 0, -by)
                l:Show()
                by = by + 21
            end
            by = by + 8
        end
        Q.HideFrom(lines, heads, priors, cards, steps)
        return by
    end
    return Q
end
