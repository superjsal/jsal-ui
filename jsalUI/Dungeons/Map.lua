-- The Dungeon guide's Map tab: the dungeon's floor as the game's own map picture, a numbered
-- sign on each boss, the floors to pick from over it and the bosses listed beside it. A boss,
-- on the map or in the list, is a click to its loot.
local _, ns = ...
local Style = ns.Style

local Map = {}
ns.DungeonMap = Map

-- A floor's picture, and its twelve pieces: four across, each 256 square, the last column and
-- row running past the picture's edge.
local ART_W, ART_H, TILE, ACROSS, PIECES = 1002, 668, 256, 4, 12
local MAP_MAX, LIST_W, GAP, TOP, ROW_H, SIGN = 620, 320, 24, 30, 44, 26
local FLOORS = 7

function Map.Has(d)
    return d ~= nil and ns.DungeonMaps ~= nil and ns.DungeonMaps[d.id] ~= nil
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
    pane.hint:SetText("Click a boss for its loot")

    -- The picture, kept to its own size: its pieces run past it.
    local canvas = CreateFrame("Frame", nil, pane)
    canvas:SetSize(mapW, mapH)
    canvas:SetPoint("TOPLEFT", 0, -TOP)
    if canvas.SetClipsChildren then canvas:SetClipsChildren(true) end
    Style.Fill(canvas, "titleBar")
    pane.tiles = {}
    for i = 1, PIECES do
        local t = canvas:CreateTexture(nil, "ARTWORK")
        t:SetSize(TILE * scale, TILE * scale)
        t:SetPoint("TOPLEFT", ((i - 1) % ACROSS) * TILE * scale, -math.floor((i - 1) / ACROSS) * TILE * scale)
        pane.tiles[i] = t
    end
    pane.canvas = canvas
    -- The pieces are set one a frame, and only while the map is in view. The game reads a
    -- piece's file as it comes on screen: all twelve at once made the window's opening frame
    -- about 100 ms long. Out of view they're let go, so nothing of the map is kept loaded.
    local want, set = nil, 0
    local function Feed(self)
        set = set + 1
        pane.tiles[set]:SetTexture(want .. set)
        if set >= PIECES then self:SetScript("OnUpdate", nil) end
    end
    local function Picture(path)
        if path == want then return end
        want, set = path, 0
        for _, t in ipairs(pane.tiles) do t:SetTexture(nil) end
        canvas:SetScript("OnUpdate", path and Feed or nil)
    end
    canvas:SetScript("OnHide", function() Picture(nil) end)

    local function Hot(k)
        if pane.hot == k then return end
        pane.hot = k
        Paint()
    end
    local function Clickable(frame)
        frame:EnableMouse(true)
        frame:SetScript("OnEnter", function(self) Hot(self.k) end)
        frame:SetScript("OnLeave", function() Hot(nil) end)
        frame:SetScript("OnMouseUp", function(self) if onBoss and self.k then onBoss(self.k) end end)
    end

    -- A sign on the map for each boss on this floor.
    pane.pins = {}
    local function Pin(i)
        if not pane.pins[i] then
            local p = Sign(canvas)
            p:SetFrameLevel(canvas:GetFrameLevel() + 2)
            Clickable(p)
            pane.pins[i] = p
        end
        return pane.pins[i]
    end

    -- The bosses beside the map, in the order you meet them.
    pane.rows = {}
    local function Row(i)
        if not pane.rows[i] then
            local r = CreateFrame("Frame", nil, pane)
            r:SetSize(LIST_W, ROW_H)
            r:SetPoint("TOPLEFT", mapW + GAP, -(TOP + (i - 1) * ROW_H))
            r.sign = Sign(r)
            r.sign:SetPoint("LEFT", 6, 0)
            r.name = Style.Text(r, 14, "secondary")
            r.name:SetPoint("TOPLEFT", r.sign, "TOPRIGHT", 12, 2)
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

    -- `killed(k)` says whether the dungeon's k-th boss is dead.
    function pane:Draw(d, killed)
        if self.dungeon ~= d then self.floor, self.hot = nil, nil end
        self.dungeon, self.killed = d, killed
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
        -- Opens on the floor the next boss is on.
        if not pane.floor then
            local place = next and Map.Place(d, next)
            pane.floor = place and place[1] or 1
        end
        for i = 1, FLOORS do
            pane.floors:Shown(i, maps.floors[i] ~= nil)
            if maps.floors[i] then pane.floors:Set(i, maps.floors[i]) end
        end
        pane.floors:Pick(pane.floor)
        pane.floors:SetShown(#maps.floors > 1)
        Picture("Interface\\WorldMap\\" .. maps.folder .. "\\" .. maps.folder .. pane.floor .. "_")

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
                p:ClearAllPoints()
                p:SetPoint("CENTER", canvas, "TOPLEFT", place[2] * mapW, -place[3] * mapH)
                p:Show()
            end
            local r = Row(k)
            r.k = k
            r.sign:Set(k, state)
            r.name:SetText(boss[3] or boss[2])
            r.name:SetTextColor(Style.Color((k == next or pane.hot == k) and "text" or (dead and "muted" or "secondary")))
            local where = place and maps.floors[place[1]] or "not on the map yet"
            r.note:SetText(dead and (where .. " · killed") or where)
            r:Show()
        end
        for i = used + 1, #pane.pins do pane.pins[i]:Hide() end
        for i = #d.bosses + 1, #pane.rows do pane.rows[i]:Hide() end
    end

    return pane
end
