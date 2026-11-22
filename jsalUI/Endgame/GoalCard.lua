-- The Endgame page's YOUR GOAL AT 60 card, below level 60, two columns wide with a gold edge: your set's name,
-- one sentence on how far the first piece is, FROM HERE TO 60 (a road from your level to 60, each piece's
-- picture standing at the level it needs), then where they come from in three columns: DUNGEONS (each with
-- the level it's tuned to), QUESTS and CRAFTED, VENDORS, and anything else. Every piece's picture and name
-- carry the item's tooltip; a dungeon's name opens its guide. The facts are GoalFacts.lua's.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local PAD, ROAD_H, LIST_GAP, LINE, TALL = 16, 147, 24, 22, 36
local MUTED = "|cff9a9688"

local function Hex(q)
    return "|cff" .. Style.Quality(q or 1)
end

-- A small item picture in a thin frame of its quality's colour, with the item's tooltip.
local function Pic(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.edges = Style.Lined(f, "lineStrong", "window")
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 1, -1)
    f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        if not self.item then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.item)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function f:Item(id, q)
        self.item = id
        self.icon:SetTexture(Compat.ItemIcon(id))
        local hex = Style.Quality(q or 1)
        local r, g, b = tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
        for _, edge in ipairs(self.edges) do
            if edge.SetColorTexture then edge:SetColorTexture(r, g, b) end
        end
    end
    return f
end

local function Caps(parent, words)
    local t = Style.Text(parent, 11, "muted", nil, true)
    t:SetText(words)
    return t
end

-- The card, `width` wide. Paint(level) fills it and returns its height.
function ns.EndgameGoal(parent, width)
    local F = ns.EndgameGoalFacts
    local card = CreateFrame("Frame", nil, parent)
    card:SetWidth(width)
    Style.Box(card, 6, "well", "cardLine")
    if Style.Edge then Style.Edge(card, 6, "gold") end
    local inner = width - 2 * PAD
    local colW = math.floor((inner - 2 * LIST_GAP) / 3)
    card.colW = colW

    local title = Style.Text(card, 12, "gold", nil, true)
    title:SetPoint("TOPLEFT", PAD, -14)
    title:SetText("YOUR GOAL AT 60")
    local open = CreateFrame("Button", nil, card)
    open.text = Style.Text(open, 13, "gold", nil, true)
    open.text:SetPoint("RIGHT")
    open.text:SetText("Open Gear plan")
    open:SetSize(Style.Wide(open.text, 100), 20)
    open:SetPoint("TOPRIGHT", -PAD, -10)
    open:SetScript("OnEnter", function(self) self.text:SetTextColor(Style.Color("text")) end)
    open:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color("gold")) end)
    open:SetScript("OnClick", function()
        if ns.Gear then ns.Gear.openAt60 = true end
        Window.Open("gear")
    end)

    local name = Style.Text(card, 18, "text", nil, true)
    name:SetPoint("TOPLEFT", PAD, -42)
    name:SetWordWrap(false)
    local about = Style.Text(card, 12, "muted")
    about:SetPoint("BOTTOMLEFT", name, "BOTTOMRIGHT", 10, 2)
    local sentence = Style.Text(card, 13, "text")
    sentence:SetWidth(inner)
    sentence:SetJustifyH("LEFT")
    local roadHead = Caps(card, "FROM HERE TO 60")
    local road = CreateFrame("Frame", nil, card)
    road:SetSize(inner, ROAD_H)
    local track = card:CreateTexture(nil, "ARTWORK")
    track:SetColorTexture(Style.Color("line"))
    track:SetHeight(4)
    local you = card:CreateTexture(nil, "OVERLAY")
    you:SetColorTexture(Style.Color("gold"))
    you:SetSize(8, 8)
    local rule = card:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(Style.Color("line"))
    rule:SetHeight(1)
    local empty = Style.Text(card, 13, "muted")
    empty:SetWidth(inner)
    empty:SetJustifyH("LEFT")

    local pics, ticks, labels, rows, heads = {}, {}, {}, {}, {}
    local function RoadPic(i)
        if not pics[i] then pics[i] = Pic(road, F.ICON) end
        return pics[i]
    end
    local function Tick(i)
        if not ticks[i] then
            local t = card:CreateTexture(nil, "ARTWORK")
            t:SetColorTexture(Style.Color("lineStrong"))
            t:SetSize(1, 8)
            ticks[i] = t
        end
        return ticks[i]
    end
    local function Label(i)
        if not labels[i] then
            local t = Style.Text(card, 12, "muted")
            t:SetJustifyH("CENTER")
            labels[i] = t
        end
        return labels[i]
    end
    local function Head(i)
        if not heads[i] then heads[i] = Caps(card, "") end
        return heads[i]
    end
    -- A line of a list: a piece (picture, name in its quality's colour, its level at the right), or a group's
    -- own line (a dungeon or a vendor: its name, and "from 53" or "at 60"). A name too long for its room takes
    -- a second line.
    local function Row(i)
        if rows[i] then return rows[i] end
        local r = CreateFrame("Button", nil, card)
        r.pic = Pic(r, 16)
        r.pic:SetPoint("TOPLEFT", 0, -3)
        r.name = Style.Text(r, 13, "text")
        r.name:SetJustifyH("LEFT")
        r.right = Style.Text(r, 12, "muted")
        r.right:SetPoint("TOPRIGHT", 0, -4)
        r.right:SetJustifyH("RIGHT")
        r:SetScript("OnEnter", function(self)
            if self.item then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self.item)
                if self.how then GameTooltip:AddLine(self.how, Style.Color("text")) end
                GameTooltip:Show()
            elseif self.dungeon then
                self.name:SetTextColor(Style.Color("gold"))
            end
        end)
        r:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            if self.dungeon then self.name:SetTextColor(Style.Color("text")) end
        end)
        r:SetScript("OnClick", function(self)
            if self.dungeon and ns.Dungeons then
                ns.Dungeons.want = self.dungeon
                Window.Open("dungeons")
            end
        end)
        rows[i] = r
        return r
    end

    local function PaintRoad(g, level, top)
        roadHead:ClearAllPoints()
        roadHead:SetPoint("TOPLEFT", PAD, -top)
        road:ClearAllPoints()
        road:SetPoint("TOPLEFT", PAD, -(top + 18))
        local placed = F.Road(g.pieces, level, inner, ROAD_H)
        card.road = placed
        for i, at in ipairs(placed) do
            local f = RoadPic(i)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", road, "TOPLEFT", at.x, -at.y)
            f:Item(at.piece.id, at.piece.quality)
            f:Show()
        end
        for i = #placed + 1, #pics do pics[i]:Hide() end
        local trackY = top + 18 + ROAD_H + 10
        track:ClearAllPoints()
        track:SetPoint("TOPLEFT", PAD, -trackY)
        track:SetPoint("TOPRIGHT", -PAD, -trackY)
        local from = math.min(level, F.CAP - 1)
        you:ClearAllPoints()
        you:SetPoint("CENTER", card, "TOPLEFT", PAD + F.LevelX(from, level, inner), -(trackY + 2))
        -- A tick at each level a piece needs; your level, every fourth and 60 named under the track.
        local levels, named = {}, {}
        for _, at in ipairs(placed) do levels[at.level] = true end
        named[from], named[F.CAP] = true, true
        for l = from + 1, F.CAP - 1 do
            if l % 4 == 0 and l - from >= 2 and F.CAP - l >= 2 then named[l] = true end
        end
        local n = 0
        for l = from, F.CAP do
            if levels[l] or named[l] then
                n = n + 1
                local t = Tick(n)
                t:ClearAllPoints()
                t:SetPoint("TOP", card, "TOPLEFT", PAD + F.LevelX(l, level, inner), -(trackY - 2))
                t:Show()
            end
        end
        for i = n + 1, #ticks do ticks[i]:Hide() end
        local k = 0
        for l = from, F.CAP do
            if named[l] then
                k = k + 1
                local t = Label(k)
                t:SetText(l)
                t:SetTextColor(Style.Color(l == from and "gold" or "muted"))
                t:ClearAllPoints()
                t:SetPoint("TOP", card, "TOPLEFT", PAD + F.LevelX(l, level, inner), -(trackY + 12))
                t:Show()
            end
        end
        for i = k + 1, #labels do labels[i]:Hide() end
        track:Show() you:Show() roadHead:Show() road:Show()
        return trackY + 32
    end

    -- The three columns of where the pieces come from; returns where they end.
    local function PaintLists(g, top)
        local used, usedHeads = 0, 0
        local function Line(x, y, words, right, opts)
            used = used + 1
            local r = Row(used)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
            r.item, r.how, r.dungeon = opts.item, opts.how, opts.dungeon
            r.pic:SetShown(opts.item ~= nil)
            if opts.item then r.pic:Item(opts.item, opts.quality) end
            local left = opts.item and 22 or 0
            r.name:ClearAllPoints()
            r.name:SetPoint("TOPLEFT", left, -3)
            -- The words at the right first: the name keeps clear of them, never under them.
            r.right:SetText(right)
            local room = colW - left - (right ~= "" and math.max(30, Style.Wide(r.right, #right * 7) + 10) or 0)
            r.name:SetWidth(room)
            r.name:SetText(words)
            r.name:SetTextColor(Style.Color("text"))
            local plain = words:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local two = Style.Wide(r.name, #plain * 6.6) > room
            r.name:SetWordWrap(two)
            local h = two and TALL or LINE
            r:SetSize(colW, h)
            r:Show()
            return h
        end
        local function Heading(x, y, words)
            usedHeads = usedHeads + 1
            local t = Head(usedHeads)
            t:SetText(words)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
            t:Show()
            return 20
        end
        local function Piece(x, y, p, right)
            return Line(x, y, Hex(p.quality) .. (ns.EndgameItemName(p.id) or "...") .. "|r", right, { item = p.id, quality = p.quality, how = p.how })
        end
        local bottoms = {}
        -- DUNGEONS
        local x, y = PAD, top
        if #g.dungeons > 0 then
            y = y + Heading(x, y, "DUNGEONS")
            for _, d in ipairs(g.dungeons) do
                y = y + Line(x, y, d.name, d.level and ("from %d"):format(d.level) or "", { dungeon = d.dungeon }) + 2
                for _, p in ipairs(d.pieces) do y = y + Piece(x, y, p, "") end
                y = y + 8
            end
        end
        bottoms[1] = y
        -- QUESTS, then CRAFTED
        x, y = PAD + colW + LIST_GAP, top
        for _, block in ipairs({ { "QUESTS", g.quests }, { "CRAFTED", g.crafted } }) do
            if #block[2] > 0 then
                y = y + Heading(x, y, block[1])
                for _, p in ipairs(block[2]) do y = y + Piece(x, y, p, tostring(p.req)) end
                y = y + 10
            end
        end
        bottoms[2] = y
        -- VENDORS, then the rest
        x, y = PAD + 2 * (colW + LIST_GAP), top
        if #g.vendors > 0 then
            y = y + Heading(x, y, "VENDORS")
            for _, v in ipairs(g.vendors) do
                y = y + Line(x, y, v.name, ("at %d"):format(v.level), { how = v.place }) + 2
                for _, p in ipairs(v.pieces) do y = y + Piece(x, y, p, "") end
                y = y + 8
            end
        end
        for _, block in ipairs({ { "ELSEWHERE", g.elsewhere }, { "WHERE ISN'T KNOWN", g.unknown } }) do
            if #block[2] > 0 then
                y = y + Heading(x, y, block[1])
                for _, p in ipairs(block[2]) do y = y + Piece(x, y, p, tostring(p.req)) end
                y = y + 10
            end
        end
        bottoms[3] = y
        for i = used + 1, #rows do rows[i]:Hide() end
        for i = usedHeads + 1, #heads do heads[i]:Hide() end
        return math.max(bottoms[1], bottoms[2], bottoms[3])
    end

    local function HideAll()
        for _, r in ipairs({ roadHead, road, track, you, rule }) do r:Hide() end
        for _, t in ipairs(pics) do t:Hide() end
        for _, t in ipairs(ticks) do t:Hide() end
        for _, t in ipairs(labels) do t:Hide() end
        for _, r in ipairs(rows) do r:Hide() end
        for _, t in ipairs(heads) do t:Hide() end
    end

    function card.Paint(level)
        local Goal = ns.GearGoal
        local ok, s = pcall(function() return Goal and Goal.running and Goal.Summary and Goal.Summary() end)
        if not ok then ns.Report(s) end
        card.facts = nil
        if not (ok and s) then
            HideAll()
            name:SetText("") about:SetText("") sentence:SetText("")
            empty:ClearAllPoints()
            empty:SetPoint("TOPLEFT", PAD, -44)
            empty:SetText(not (Goal and Goal.running) and "The gear goal for 60 is switched off in Settings."
                or "WoWSims has no pre-raid set for your talent tree yet: make one of your own in the Gear plan.")
            empty:Show()
            card:SetHeight(96)
            return 96
        end
        empty:Hide()
        local g = F.Read(s)
        card.facts = g
        name:SetText(g.own and (g.name or "Your set") or ("WoWSims' " .. (g.name or "") .. " set"))
        if g.open > 0 then
            about:SetText(("before raids · %d piece%s chosen, %d slot%s empty"):format(g.chosen, g.chosen == 1 and "" or "s",
                g.open, g.open == 1 and "" or "s"))
        else
            about:SetText(("before raids · %d piece%s"):format(g.of, g.of == 1 and "" or "s"))
        end
        sentence:SetText(F.Sentence(g, level, function(id, words)
            local p
            for _, q in ipairs(g.pieces) do if q.id == id then p = q end end
            return Hex(p and p.quality) .. words .. "|r"
        end))
        sentence:ClearAllPoints()
        sentence:SetPoint("TOPLEFT", PAD, -72)
        local plain = (sentence:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        local y = 72 + math.max(1, math.ceil(#plain * 6.6 / inner)) * 18 + 12
        if #g.pieces == 0 then
            HideAll()
            card:SetHeight(y + 4)
            return y + 4
        end
        y = PaintRoad(g, level, y)
        rule:ClearAllPoints()
        rule:SetPoint("TOPLEFT", PAD, -y)
        rule:SetPoint("TOPRIGHT", -PAD, -y)
        rule:Show()
        y = PaintLists(g, y + 14) + 8
        card:SetHeight(y)
        return y
    end
    return card
end
