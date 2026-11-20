-- The Dungeon guide's Map tab: the dungeon's floor as the game's own map picture, a numbered
-- sign on each boss, the floors to pick from over it and the bosses listed beside it. A boss,
-- on the map or in the list, is a click to its loot. A boss with gear for you is marked: a
-- green dot on its sign when it drops something better than what you wear, your Gear plan's
-- star when it drops a piece you starred. A boss a quest in your log needs has a gold "!" at
-- its sign's other shoulder, and the quest's name under its own. A dungeon of Forever's own has no map
-- picture in the game: its map is Santiago Reyes's, a picture a floor, with no boss placed on it and his
-- credit under it.
local _, ns = ...
local Style = ns.Style

local Map = {}
ns.DungeonMap = Map

-- A floor's picture, and its twelve pieces: four across, each 256 square, the last column and
-- row running past the picture's edge.
local ART_W, ART_H, TILE, ACROSS, PIECES = 1002, 668, 256, 4, 12
local MAP_MAX, LIST_W, GAP, TOP, ROW_H, SIGN = 620, 320, 24, 30, 44, 26
local FLOORS = 7
-- The artist's pictures: where they are, how wide each is, and his credit, said under every one.
local ART = "Interface\\AddOns\\jsalUI\\Media\\Maps\\"
local ART_PX = 1024
local CREDIT = "Map by Santiago Reyes \194\183 Atlas de Azeroth: Forever \194\183 sreyesmaps.com"
-- A row needs this much height for its two lines; under it, a row is one line.
local TWO_LINES = 34
-- A boss's picture in its tooltip is this many of the tooltip's lines high.
local FACE_LINES = 8
-- The margin a tooltip keeps either side of the picture.
local PAD = 12
-- Why his maps have no boss on them, said under the list; the room the list leaves for it.
local UNMARKED = "These maps leave the bosses unmarked, so finding them is up to you."
local NOTE_GAP, NOTE_H = 16, 50

function Map.Has(d)
    return d ~= nil and ns.DungeonMaps ~= nil and ns.DungeonMaps[d.id] ~= nil
end

-- A floor's name: the one its map gives it, the game's own word for it where it has one
-- (DUNGEON_FLOOR_MARAUDON2 is "Zaetar's Grave"), or its number.
function Map.Floor(maps, i)
    if maps.names and maps.names[i] then return maps.names[i] end
    local own = maps.folder and _G["DUNGEON_FLOOR_" .. maps.folder:upper() .. i]
    return type(own) == "string" and own ~= "" and own or ("Floor " .. i)
end

-- What a boss has for you, in a few words: "best +6%", "starred, +24%", "starred". Nil for
-- nothing.
function Map.Gain(star, gain)
    local by
    if gain then
        local pct = math.floor(gain * 100 + 0.5)
        by = pct < 1 and "under 1%" or ("+" .. pct .. "%")
    end
    if star then return by and ("starred, " .. by) or "starred" end
    return by and ("best " .. by) or nil
end

-- What the page's "About this map" says of a dungeon's map: whose it is, or where its signs come
-- from.
function Map.About(d)
    local maps = Map.Has(d) and ns.DungeonMaps[d.id]
    if maps and maps.art then
        return "This map is Santiago Reyes's, drawn for his Atlas de Azeroth: Forever and used with his leave. "
            .. "More of his maps are at sreyesmaps.com."
    end
    return "The maps are the game's own pictures. Where each boss stands comes from later versions of the game, "
        .. "which kept the same pictures, so a sign may be a little off."
end

-- Which floor a boss is on, and where: nil for one with no place yet.
function Map.Place(d, k)
    local maps = Map.Has(d) and ns.DungeonMaps[d.id]
    local boss = maps and d.bosses[k]
    return boss and maps.bosses[boss[1]] or nil
end

-- A round sign with a boss's number: gold for the next one to kill, dim once it's dead, a
-- gold ring while it's pointed at.
local function Sign(parent)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(SIGN, SIGN)
    s.disc = Style.Circle(s, "well", "lineStrong")
    s.label = Style.Text(s, 12, "text", nil, true)
    s.label:SetPoint("CENTER")
    -- The mark at the sign's shoulder, made the first time a sign needs one: a green dot, or the
    -- Gear plan's star on a dark one (the star alone was lost on the map).
    function s:Quest(on)
        if not (on or self.quest) then return end
        if not self.quest then
            local q = CreateFrame("Frame", nil, self)
            q:SetSize(13, 13)
            q:SetPoint("CENTER", self, "TOPLEFT", 3, -3)
            q:SetFrameLevel(self:GetFrameLevel() + 3)
            Style.Circle(q, "gold", "window")
            q.text = Style.Text(q, 10, "onGold", nil, true)
            q.text:SetPoint("CENTER")
            q.text:SetText("!")
            self.quest = q
        end
        self.quest:SetShown(on)
    end
    function s:Mark(star, gain)
        local on = star or gain ~= nil
        if not (on or self.mark) then return end
        if not self.mark then
            local m = CreateFrame("Frame", nil, self)
            m:SetSize(12, 12)
            m:SetPoint("CENTER", self, "TOPRIGHT", -3, -3)
            m:SetFrameLevel(self:GetFrameLevel() + 3)
            m.disc = Style.Circle(m, "green", "window")
            m.star = m:CreateTexture(nil, "OVERLAY")
            m.star:SetSize(14, 14)
            m.star:SetPoint("CENTER")
            m.star:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
            self.mark = m
        end
        self.mark:SetShown(on)
        if on then
            self.mark.disc:Paint(star and "window" or "green", "window")
            self.mark.star:SetShown(star)
        end
    end
    function s:Set(n, state)
        self.label:SetText(n)
        if state == "next" then
            self.disc:Paint("gold", "gold")
            self.label:SetTextColor(Style.Color("onGold"))
        elseif state == "hot" then
            self.disc:Paint("well", "gold")
            self.label:SetTextColor(Style.Color("gold"))
        elseif state == "dead" then
            self.disc:Paint("well", "line")
            self.label:SetTextColor(Style.Color("muted"))
        else
            self.disc:Paint("well", "lineStrong")
            self.label:SetTextColor(Style.Color("text"))
        end
    end
    return s
end

-- `onBoss(k)` is called with a boss's place in the dungeon's order when it's clicked.
function Map.Build(parent, width, onBoss)
    local pane = CreateFrame("Frame", nil, parent)
    local mapW = math.min(MAP_MAX, width - LIST_W - GAP)
    local scale = mapW / ART_W
    local mapH = math.floor(ART_H * scale + 0.5)
    pane.height = TOP + mapH
    pane:SetSize(width, pane.height)
    local Paint

    -- The floors, as small tabs over the map: as many as the dungeon has.
    local items = {}
    for i = 1, FLOORS do items[i] = { i, "Floor " .. i } end
    pane.floors = Style.Tabs(pane, items, function(key)
        pane.floor = key
        Paint()
    end, nil, true)
    pane.floors:SetPoint("TOPLEFT", 0, 0)
    pane.hint = Style.Text(pane, 12, "muted")
    pane.hint:SetPoint("TOPRIGHT", pane, "TOPLEFT", mapW, -6)
    local HINT = "Click a boss for its loot"
    pane.hint:SetText(HINT)
    -- The artist's credit, at the page's foot under his map, on the line of its other small print.
    pane.credit = Style.Text(pane, 12, "muted")
    pane.credit:SetPoint("LEFT", parent, "BOTTOMLEFT", 0, 9)
    pane.credit:SetText(CREDIT)
    pane.credit:Hide()
    pane.unmarked = Style.Text(pane, 12, "muted")
    pane.unmarked:SetWidth(LIST_W - 20)
    pane.unmarked:SetJustifyH("LEFT")
    pane.unmarked:SetText(UNMARKED)
    pane.unmarked:Hide()

    -- The picture, kept to its own size: its pieces run past it.
    local canvas = CreateFrame("Frame", nil, pane)
    canvas:SetSize(mapW, mapH)
    canvas:SetPoint("TOPLEFT", 0, -TOP)
    if canvas.SetClipsChildren then canvas:SetClipsChildren(true) end
    Style.Fill(canvas, "titleBar")
    pane.tiles = {}
    for i = 1, PIECES do pane.tiles[i] = canvas:CreateTexture(nil, "ARTWORK") end
    pane.canvas = canvas
    -- The pieces are set one a frame, and only while the map is in view. The game reads a
    -- piece's file as it comes on screen: all twelve at once made the window's opening frame
    -- about 100 ms long. Out of view they're let go, so nothing of the map is kept loaded.
    -- A floor's picture is its twelve pieces by `want`, a path; the artist's is one picture,
    -- `whole`, the map's own shape.
    local want, whole, set = nil, false, 0
    -- The view: how far in the picture is zoomed (1: all of it), where its corner then is
    -- (`x` and `y`, nothing or less: the picture always fills the map), and how far in it may
    -- go, `most`: until the picture is drawn at its own size, past which it only goes soft. Both
    -- kinds are drawn smaller than they are, so they can go in by half as much again or more.
    local view = { zoom = 1, x = 0, y = 0, most = 1 }
    pane.view = view
    local function Tile(i)
        local t = pane.tiles[i]
        t:ClearAllPoints()
        if whole then
            t:SetSize(mapW * view.zoom, mapH * view.zoom)
            t:SetPoint("TOPLEFT", view.x, -view.y)
        else
            local size = TILE * scale * view.zoom
            t:SetSize(size, size)
            t:SetPoint("TOPLEFT", view.x + ((i - 1) % ACROSS) * size, -(view.y + math.floor((i - 1) / ACROSS) * size))
        end
    end
    local function PlaceSign(p)
        p:ClearAllPoints()
        p:SetPoint("CENTER", canvas, "TOPLEFT", view.x + p.x * view.zoom, -(view.y + p.y * view.zoom))
    end
    -- The view moved: every piece set so far and every sign shown goes to its new place.
    local function Lay()
        view.x = math.max(mapW - mapW * view.zoom, math.min(0, view.x))
        view.y = math.max(mapH - mapH * view.zoom, math.min(0, view.y))
        for i = 1, set do Tile(i) end
        for _, p in ipairs(pane.pins) do
            if p:IsShown() and p.x then PlaceSign(p) end
        end
    end
    local function Feed(self)
        set = set + 1
        Tile(set)
        pane.tiles[set]:SetTexture(whole and want or (want .. set))
        if set >= (whole and 1 or PIECES) then self:SetScript("OnUpdate", nil) end
    end
    local dragger = CreateFrame("Frame", nil, canvas)
    local function Picture(path, one)
        one = one and true or false
        if path == want and one == whole then return end
        want, whole, set = path, one, 0
        for _, t in ipairs(pane.tiles) do t:SetTexture(nil) end
        canvas:SetScript("OnUpdate", path and Feed or nil)
        -- Another picture starts whole.
        view.zoom, view.x, view.y = 1, 0, 0
        view.most = (one and ART_PX or ART_W) / mapW
        if view.most < 1.1 then view.most = 1 end
        canvas:EnableMouseWheel(view.most > 1)
        dragger:SetScript("OnUpdate", nil)
    end
    canvas:SetScript("OnHide", function() Picture(nil) end)

    -- Where the pointer is on the map, from its top left corner.
    local function Pointer()
        local x, y = GetCursorPosition()
        local s = canvas:GetEffectiveScale() or 1
        return x / s - (canvas:GetLeft() or 0), (canvas:GetTop() or 0) - y / s
    end
    -- The wheel zooms on what's under the pointer; a drag moves the picture about once it's
    -- zoomed. The drag is followed each frame only while the button is down.
    local STEP = 1.25
    canvas:SetScript("OnMouseWheel", function(_, delta)
        local zoom = math.max(1, math.min(view.most, view.zoom * (delta > 0 and STEP or 1 / STEP)))
        if zoom == view.zoom then return end
        local px, py = Pointer()
        view.x = px - (px - view.x) * zoom / view.zoom
        view.y = py - (py - view.y) * zoom / view.zoom
        view.zoom = zoom
        Lay()
    end)
    canvas:EnableMouse(true)
    canvas:SetScript("OnMouseDown", function()
        if view.zoom <= 1 then return end
        local fromX, fromY = Pointer()
        local x0, y0 = view.x, view.y
        dragger:SetScript("OnUpdate", function()
            local px, py = Pointer()
            local x, y = x0 + px - fromX, y0 + py - fromY
            if x ~= view.x or y ~= view.y then
                view.x, view.y = x, y
                Lay()
            end
        end)
    end)
    canvas:SetScript("OnMouseUp", function() dragger:SetScript("OnUpdate", nil) end)

    local function Hot(k)
        if pane.hot == k then return end
        pane.hot = k
        Paint()
    end
    -- A sign on the map has a tooltip: the boss's name, its floor and whether it's dead, what
    -- it has for you and the quests that need it (`pane.tip`, the page's to say), and that a
    -- click opens its loot. The list's rows have none: a tooltip following the pointer down a
    -- list is a lot of movement, and a row says most of it already.
    -- The boss's picture is its own model, drawn by the game where its model is known (the
    -- fourth of its place), over empty lines left for it under its name. The model's frame is
    -- the tooltip's child, well over it: as the map's own frame it was drawn behind the
    -- tooltip's fill, a dim shape in the gap, and sized by another frame's measure. So that no
    -- other tooltip ever has it, it's hidden when the pointer leaves the sign and whenever the
    -- tooltip itself goes. It's made the first time a boss with one is pointed at.
    -- The boss's name and its floor are set in the middle of the tooltip, over the picture.
    -- The tooltip is the game's own and every tooltip uses its lines, so what's changed on it
    -- for a boss (its lines' width and set, the width asked of it for the picture) is put back
    -- when the tooltip goes, and before the next boss's.
    local function Restore()
        for i = 1, pane.heads or 0 do
            local line = _G["GameTooltipTextLeft" .. i]
            if line then
                line:SetJustifyH("LEFT")
                line:SetWidth(0)
            end
        end
        pane.heads = nil
        if pane.widened and GameTooltip.SetMinimumWidth then GameTooltip:SetMinimumWidth(0) end
        pane.widened = nil
    end
    local function Centre(lines)
        for i = 1, lines do
            local line = _G["GameTooltipTextLeft" .. i]
            if line then
                local inset = (line:GetLeft() or 0) - (GameTooltip:GetLeft() or 0)
                line:SetWidth((GameTooltip:GetWidth() or 0) - inset * 2)
                line:SetJustifyH("CENTER")
            end
        end
        pane.heads = lines
    end
    local function Face(display, first)
        -- The model stands in a dark box with a line round it, a picture in its frame.
        local m, box = pane.face, pane.faceBox
        if not m then
            box = CreateFrame("Frame", nil, GameTooltip)
            Style.Fill(box, "titleBar")
            Style.Border(box, "lineStrong")
            m = CreateFrame("PlayerModel", nil, box)
            m:SetPoint("TOPLEFT", 1, -1)
            m:SetPoint("BOTTOMRIGHT", -1, 1)
            pane.face, pane.faceBox = m, box
        end
        local top, foot = _G["GameTooltipTextLeft" .. first], _G["GameTooltipTextLeft" .. (first + FACE_LINES - 1)]
        local size = top and foot and top.GetTop and top:GetTop() and foot:GetBottom() and (top:GetTop() - foot:GetBottom()) or 64
        box:SetFrameLevel((GameTooltip:GetFrameLevel() or 1) + 10)
        m:SetFrameLevel((GameTooltip:GetFrameLevel() or 1) + 11)
        box:SetSize(size, size)
        -- A tooltip with few words is narrower than the box, which then stood out past its
        -- edge: it's asked to be at least the box's width and a margin, and laid out again.
        if GameTooltip.SetMinimumWidth and (GameTooltip:GetWidth() or 0) < size + PAD * 2 then
            GameTooltip:SetMinimumWidth(size + PAD * 2)
            pane.widened = true
            GameTooltip:Show()
        end
        -- In the middle of the tooltip's width, its top at the first of the lines left for it.
        box:ClearAllPoints()
        local down = top and top:GetTop() and GameTooltip:GetTop() and (GameTooltip:GetTop() - top:GetTop()) or 40
        box:SetPoint("TOP", GameTooltip, "TOP", 0, -down)
        box:Show()
        -- Shown first: the game loads a model only into a frame that's showing, and this one
        -- is hidden between tooltips (set while hidden, the picture's place stayed empty).
        m:Show()
        if m.ClearModel then m:ClearModel() end
        -- At the game's own distance, which takes each model whole: nearer, the big ones (a
        -- fire lord, a stone giant) were cut off at the box's edges.
        m:SetDisplayInfo(display)
    end
    local function Tip(sign)
        local d, k = pane.dungeon, sign.k
        local boss = d and k and d.bosses[k]
        if not (boss and GameTooltip) then return end
        if not pane.hooked and GameTooltip.HookScript then
            pane.hooked = true
            GameTooltip:HookScript("OnHide", function()
                if pane.faceBox then pane.faceBox:Hide() end
                Restore()
            end)
        end
        Restore()
        GameTooltip:SetOwner(sign, "ANCHOR_RIGHT")
        GameTooltip:SetText(boss[3] or boss[2], 1, 1, 1)
        local place = Map.Place(d, k)
        local where = pane.manyFloors and place and Map.Floor(ns.DungeonMaps[d.id], place[1]) or ""
        if pane.killed and pane.killed(k) then where = where ~= "" and (where .. " · killed") or "Killed" end
        if where ~= "" then GameTooltip:AddLine(where, 0.6, 0.59, 0.53) end
        local face, first = place and place[4], nil
        if face then
            -- A line of space over the picture, as there is under it.
            GameTooltip:AddLine(" ")
            first = GameTooltip:NumLines() + 1
            for _ = 1, FACE_LINES do GameTooltip:AddLine(" ") end
        end
        if pane.tip then pane.tip(GameTooltip, k) end
        if onBoss then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click for its loot", 0.6, 0.59, 0.53)
        end
        GameTooltip:Show()
        if face then Face(face, first) elseif pane.faceBox then pane.faceBox:Hide() end
        Centre(where ~= "" and 2 or 1)
    end
    local function Clickable(frame, tips)
        frame:EnableMouse(true)
        frame:SetScript("OnEnter", function(self)
            Hot(self.k)
            if tips then Tip(self) end
        end)
        frame:SetScript("OnLeave", function()
            Hot(nil)
            if tips and GameTooltip then GameTooltip:Hide() end
            if tips and pane.faceBox then pane.faceBox:Hide() end
        end)
        frame:SetScript("OnMouseUp", function(self) if onBoss and self.k then onBoss(self.k) end end)
    end

    -- A sign on the map for each boss on this floor.
    pane.pins = {}
    local function Pin(i)
        if not pane.pins[i] then
            local p = Sign(canvas)
            p:SetFrameLevel(canvas:GetFrameLevel() + 2)
            Clickable(p, true)
            pane.pins[i] = p
        end
        return pane.pins[i]
    end

    -- The bosses beside the map, in the order you meet them. The list is the map's legend, so
    -- all of it stays in view: where the rows don't fit the map's height (Blackrock Depths has
    -- 21 bosses, and nine rows fit), each is as high as its share of it, and under TWO_LINES
    -- high a row is one line: a plain number for its sign, the name, and no note, the bosses
    -- not on the floor shown dim instead. They ran out of the window's foot.
    pane.rows = {}
    local function Row(i)
        if not pane.rows[i] then
            local r = CreateFrame("Frame", nil, pane)
            r:SetSize(LIST_W, ROW_H)
            r.sign = Sign(r)
            r.sign:SetPoint("LEFT", 6, 0)
            r.num = Style.Text(r, 12, "secondary", nil, true)
            r.num:SetPoint("RIGHT", r, "LEFT", 30, 0)
            r.name = Style.Text(r, 14, "secondary")
            r.name:SetWidth(LIST_W - SIGN - 24)
            r.name:SetJustifyH("LEFT")
            r.name:SetWordWrap(false)
            r.note = Style.Text(r, 11, "muted")
            r.note:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
            Style.Hover(r, 0, 6)
            Clickable(r)
            pane.rows[i] = r
        end
        return pane.rows[i]
    end

    -- `killed(k)` says whether the dungeon's k-th boss is dead; `gear(k)`, where given, whether
    -- it drops a piece you starred and the most a drop of its betters what you wear. That is
    -- asked here, once a boss, and not on every paint: pointing at a boss paints again.
    -- `quests`, where given, is the bosses your quests need: { [k] = the quest's name }.
    pane.star, pane.gain = {}, {}
    -- `tip(tooltip, k)`, where given, adds what a boss's tooltip says of you.
    function pane:Draw(d, killed, gear, quests, tip)
        if self.dungeon ~= d then self.floor, self.hot = nil, nil end
        self.dungeon, self.killed, self.quests, self.tip = d, killed, quests or nil, tip
        for k = 1, math.max(#d.bosses, #self.star) do
            self.star[k], self.gain[k] = false, nil
            if gear and d.bosses[k] then self.star[k], self.gain[k] = gear(k) end
        end
        Paint()
    end

    Paint = function()
        local d = pane.dungeon
        local maps = Map.Has(d) and ns.DungeonMaps[d.id]
        if not maps then return end
        local next
        for k = 1, #d.bosses do
            if not (pane.killed and pane.killed(k)) then next = k break end
        end
        -- Its floors: those of the folder's pictures that are this dungeon's (a folder can hold
        -- several wings').
        local first, count = nil, 0
        for i = 1, FLOORS do
            local own = maps.floors[i] == true
            pane.floors:Shown(i, own)
            if own then
                pane.floors:Set(i, Map.Floor(maps, i))
                first, count = first or i, count + 1
            end
        end
        -- Opens on the floor the next boss is on, or the first when that one has no place.
        if not pane.floor then
            local place = next and Map.Place(d, next)
            pane.floor = place and place[1] or first or 1
        end
        pane.floors:Pick(pane.floor)
        pane.floors:SetShown(count > 1)
        pane.manyFloors = count > 1
        pane.credit:SetShown(maps.art ~= nil)
        if maps.art then
            Picture(ART .. maps.art[pane.floor] .. ".jpg", true)
        else
            Picture("Interface\\WorldMap\\" .. maps.folder .. "\\" .. maps.folder .. (maps.plain and "" or (pane.floor .. "_")))
        end
        -- A map with no boss placed on it says nothing of places: not on the map, not on a row.
        local placed = false
        for _ in pairs(maps.bosses) do placed = true break end
        pane.hint:SetText(placed and HINT or "")

        -- Two bosses in one spot (Razorfen Kraul's first and third share a skull) are set side
        -- by side, so neither sign hides the other.
        local taken = {}
        local function Clear(x, y)
            for _, t in ipairs(taken) do
                if math.abs(t[1] - x) < SIGN * 0.8 and math.abs(t[2] - y) < SIGN * 0.8 then return Clear(t[1] + SIGN * 0.9, y) end
            end
            taken[#taken + 1] = { x, y }
            return x, y
        end

        local high = math.min(ROW_H, math.floor((mapH - (maps.art and NOTE_H or 0)) / math.max(1, #d.bosses)))
        local tight = high < TWO_LINES
        local used = 0
        for k, boss in ipairs(d.bosses) do
            local dead = pane.killed and pane.killed(k) or false
            local state = (pane.hot == k and "hot") or (k == next and "next") or (dead and "dead") or nil
            local place = Map.Place(d, k)
            if place and place[1] == pane.floor then
                used = used + 1
                local p = Pin(used)
                p.k = k
                p:Set(k, state)
                p:Mark(pane.star[k], pane.gain[k])
                p:Quest(pane.quests ~= nil and pane.quests[k] ~= nil)
                p.x, p.y = Clear(place[2] * mapW, place[3] * mapH)
                PlaceSign(p)
                p:Show()
            end
            local r = Row(k)
            r.k = k
            r:SetHeight(high)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", mapW + GAP, -(TOP + (k - 1) * high))
            r.sign:SetShown(not tight)
            r.num:SetShown(tight)
            r.name:ClearAllPoints()
            local has = Map.Gain(pane.star[k], pane.gain[k])
            has = has and (Style.Tint("green") .. has .. "|r")
            local quest = pane.quests and pane.quests[k]
            if tight then
                local dim = dead or not (place and place[1] == pane.floor)
                -- One line: what it has for you goes after its name, the star as itself.
                local star = pane.star[k] and ns.Gear and ns.Gear.STAR
                local by = pane.gain[k] and Map.Gain(false, pane.gain[k]):gsub("best ", "")
                r.name:SetText((boss[3] or boss[2]) .. (star and ("  " .. star) or "") .. (by and ("  " .. Style.Tint("green") .. by .. "|r") or "")
                    .. (quest and ("  " .. Style.Tint("gold") .. "!|r") or ""))
                r.num:SetText(k)
                r.num:SetTextColor(Style.Color(((k == next or pane.hot == k) and "gold") or (dim and "muted" or "secondary")))
                r.name:SetPoint("LEFT", r, "LEFT", 42, 0)
                r.name:SetTextColor(Style.Color(((k == next or pane.hot == k) and "text") or (dim and "muted" or "secondary")))
                r.note:SetText("")
            else
                r.sign:Set(k, state)
                r.sign:Mark(pane.star[k], pane.gain[k])
                r.sign:Quest(quest ~= nil)
                r.name:SetText(boss[3] or boss[2])
                r.name:SetPoint("TOPLEFT", r.sign, "TOPRIGHT", 12, 2)
                r.name:SetTextColor(Style.Color((k == next or pane.hot == k) and "text" or (dead and "muted" or "secondary")))
                -- Which floor it's on, where there's more than one to say.
                local where = (not place and (placed and "not on the map yet" or "")) or (count > 1 and Map.Floor(maps, place[1])) or ""
                if dead then
                    r.note:SetText(where ~= "" and (where .. " · killed") or "killed")
                else
                    -- The quest that needs it is said in place of its floor.
                    if quest then where = Style.Tint("gold") .. quest .. "|r" end
                    r.note:SetText(has and (where ~= "" and (where .. " · " .. has) or has) or where)
                end
            end
            r:Show()
        end
        pane.unmarked:SetShown(maps.art ~= nil)
        if maps.art then
            pane.unmarked:ClearAllPoints()
            pane.unmarked:SetPoint("TOPLEFT", mapW + GAP, -(TOP + #d.bosses * high + NOTE_GAP))
        end
        for i = used + 1, #pane.pins do pane.pins[i]:Hide() end
        for i = #d.bosses + 1, #pane.rows do pane.rows[i]:Hide() end
    end

    return pane
end
