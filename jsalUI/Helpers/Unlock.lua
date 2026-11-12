-- jsal.ui's movable pieces, and its own Unlock Mode for them (/jsal unlock,
-- or Move pieces in Settings): every piece shown and named, even one that's
-- hidden just now, on a grid, snapping to the grid, the centre and each
-- other, with exact X and Y for the one picked. It needs nothing else
-- installed (John, 12 Nov 2026: jsal.ui independent of EllesmereUI, "we need
-- the precise x,y numbers as well in case someone likes it that way").
-- When EllesmereUI is on, the pieces are also in its Unlock Mode, through
-- its public call for other addons' elements, a moment after login as its
-- own parts do. Each piece still drags on its own with neither.
local _, ns = ...
local Compat, Style = ns.Compat, ns.Style

local Unlock = {}
ns.Unlock = Unlock

local pieces = {}

-- A piece: key, label, frame() (the frame, or nil if it isn't built),
-- load() and save(point, relative, x, y) for its saved spot, and hidden()
-- for when it isn't in use.
function Unlock.Add(piece)
    pieces[piece.key] = piece
    if Unlock.registered then Unlock.Register() end
end

local function Element(piece)
    local function Apply()
        local frame = piece.frame()
        local at = piece.load()
        if frame and at and at[1] then
            frame:ClearAllPoints()
            frame:SetPoint(at[1], UIParent, at[2] or at[1], at[3] or 0, at[4] or 0)
        end
    end
    local element = {
        key = "jsalUI_" .. piece.key,
        label = piece.label,
        group = "jsal.ui",
        order = 900,
        noResize = true,
        isHidden = function() return piece.hidden and piece.hidden() or not piece.frame() end,
        getFrame = function() return piece.frame() end,
        getSize = function()
            local frame = piece.frame()
            if frame then return frame:GetWidth(), frame:GetHeight() end
            return 32, 32
        end,
        savePos = function(_, point, relative, x, y)
            if not point then return end
            piece.save(point, relative or point, x or 0, y or 0)
            if not EllesmereUI._unlockActive then Apply() end
        end,
        loadPos = function()
            local at = piece.load()
            if not (at and at[1]) then return nil end
            return { point = at[1], relPoint = at[2] or at[1], x = at[3] or 0, y = at[4] or 0 }
        end,
        clearPos = function() piece.save(nil) end,
        applyPos = Apply,
    }
    local make = EllesmereUI.MakeUnlockElement
    return make and make(element) or element
end

function Unlock.Register()
    if not (EllesmereUI and EllesmereUI.RegisterUnlockElements) then return false end
    local list = {}
    for _, piece in pairs(pieces) do list[#list + 1] = Element(piece) end
    if #list == 0 then return false end
    local ok = pcall(EllesmereUI.RegisterUnlockElements, EllesmereUI, list)
    Unlock.registered = ok
    return ok
end

ns.OnLogin(function()
    Compat.After(2, function() xpcall(Unlock.Register, ns.Report) end)
end)

---------------------------------------------------------------------------
-- jsal.ui's own Unlock Mode.
---------------------------------------------------------------------------
local GRID, SNAP = 32, 8          -- the grid's step, and how near counts as on a line
Unlock.GRID, Unlock.SNAP = GRID, SNAP

-- How far across and up a frame each anchor point is.
local FX = { TOPLEFT = 0, LEFT = 0, BOTTOMLEFT = 0, TOP = 0.5, CENTER = 0.5, BOTTOM = 0.5, TOPRIGHT = 1, RIGHT = 1, BOTTOMRIGHT = 1 }
local FY = { TOPLEFT = 1, TOP = 1, TOPRIGHT = 1, LEFT = 0.5, CENTER = 0.5, RIGHT = 0.5, BOTTOMLEFT = 0, BOTTOM = 0, BOTTOMRIGHT = 0 }

-- A piece w by h, placed with its `point` at `rel` of a screen W by H plus
-- (x, y): where its bottom left corner is.
function Unlock.Rect(point, rel, x, y, w, h, W, H)
    point, rel = FX[point] and point or "CENTER", FX[rel] and rel or (FX[point] and point or "CENTER")
    local ax, ay = W * FX[rel] + (x or 0), H * FY[rel] + (y or 0)
    return ax - w * FX[point], ay - h * FY[point]
end

-- And back: the (x, y) that puts its `point` at the same point of the
-- screen, for a piece whose bottom left corner is at (left, bottom).
-- Rounded to whole units, which is what the boxes show.
function Unlock.Offset(point, left, bottom, w, h, W, H)
    point = FX[point] and point or "CENTER"
    local x = left + w * FX[point] - W * FX[point]
    local y = bottom + h * FY[point] - H * FY[point]
    return math.floor(x + 0.5), math.floor(y + 0.5)
end

-- Where a piece being dragged settles. Its edges and middle are pulled onto
-- the screen's centre lines, onto the other pieces' edges and middles, and
-- failing those onto the grid, when within SNAP. `others` are rectangles
-- { left, bottom, w, h }. Returns the left and bottom, and the vertical and
-- horizontal line it snapped to, if any, to draw.
function Unlock.Snap(left, bottom, w, h, W, H, others, grid)
    local function Pull(start, size, lines)
        local best, line, delta = start, nil, SNAP + 1
        for _, edge in ipairs({ 0, size / 2, size }) do
            for _, l in ipairs(lines) do
                local d = math.abs(start + edge - l)
                if d < delta then best, line, delta = l - edge, l, d end
            end
        end
        return best, line
    end
    local xs, ys = { W / 2 }, { H / 2 }
    for _, o in ipairs(others or {}) do
        xs[#xs + 1], xs[#xs + 2], xs[#xs + 3] = o[1], o[1] + o[3] / 2, o[1] + o[3]
        ys[#ys + 1], ys[#ys + 2], ys[#ys + 3] = o[2], o[2] + o[4] / 2, o[2] + o[4]
    end
    local nx, vx = Pull(left, w, xs)
    local ny, hy = Pull(bottom, h, ys)
    -- No line near: the grid, counted from the centre as it's drawn.
    if not vx and grid then
        local g = {}
        local from = W / 2 - math.floor(W / 2 / GRID) * GRID
        for gx = from, W, GRID do g[#g + 1] = gx end
        nx = Pull(left, w, g)
    end
    if not hy and grid then
        local g = {}
        local from = H / 2 - math.floor(H / 2 / GRID) * GRID
        for gy = from, H, GRID do g[#g + 1] = gy end
        ny = Pull(bottom, h, g)
    end
    return nx, ny, vx, hy
end

-- What a piece is called on its tab: "jsal.ui bag button" is "Bag button".
local function Name(piece)
    local name = (piece.label or piece.key):gsub("^jsal%.ui ", "")
    return name:sub(1, 1):upper() .. name:sub(2)
end

local overlay, panel, guideV, guideH, movers, picked, dragging
local started = {}                  -- where each piece was as Unlock Mode opened
local useGrid, useSnap = true, true

local function Screen()
    return UIParent:GetWidth(), UIParent:GetHeight()
end

-- A piece's size on the screen, and where its bottom left corner is now.
local function Measure(piece)
    local W, H = Screen()
    local frame = piece.frame and piece.frame()
    local w, h, ratio = 0, 0, 1
    if frame then
        ratio = (frame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
        w, h = (frame:GetWidth() or 0) * ratio, (frame:GetHeight() or 0) * ratio
    end
    if (w or 0) < 4 or (h or 0) < 4 then
        local sw, sh = 40, 40
        if piece.size then sw, sh = piece.size() end
        sw, sh = sw or 40, sh or 40
        w, h = sw, sh
    end
    local at = piece.load and piece.load()
    if at and at[1] then
        local left, bottom = Unlock.Rect(at[1], at[2] or at[1], at[3], at[4], w, h, W, H)
        return w, h, left, bottom, at[1]
    end
    if frame and frame:GetLeft() then
        return w, h, frame:GetLeft() * ratio, frame:GetBottom() * ratio, "CENTER"
    end
    return w, h, (W - w) / 2, (H - h) / 2, "CENTER"
end

local Paint

-- A mover's tab: its name, and for the picked one its anchor and numbers too.
local function Tab(m)
    local text = Name(m.piece)
    if m == picked and m.x then text = ("%s   %s %d, %d"):format(text, m.anchor, m.x, m.y) end
    m.tab.text:SetText(text)
    m.tab:SetWidth((m.tab.text:GetStringWidth() or 60) + 14)
end

-- Puts a piece's mover at (left, bottom), and the piece itself with it.
local function Put(m, left, bottom)
    local W, H = Screen()
    m.left, m.bottom = left, bottom
    m:ClearAllPoints()
    m:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    m.x, m.y = Unlock.Offset(m.anchor, left, bottom, m.w, m.h, W, H)
    local frame = m.piece.frame and m.piece.frame()
    if frame then
        frame:ClearAllPoints()
        frame:SetPoint(m.anchor, UIParent, m.anchor, m.x, m.y)
    end
    Tab(m)
end

-- Keeps where a piece is now, in its own saved spot.
local function Keep(m)
    m.piece.save(m.anchor, m.anchor, m.x, m.y)
end

local function Pick(m)
    picked = m
    for _, other in pairs(movers or {}) do
        local on = other == m
        other.fill:SetColorTexture(Style.Color("gold"))
        other.fill:SetAlpha(on and 0.32 or 0.14)
        other.tab:SetAlpha(on and 1 or 0.85)
        Tab(other)
    end
    if Paint then Paint() end
end

-- Exact numbers: the picked piece's point at (x, y).
function Unlock.Place(key, x, y)
    local m = movers and movers[key]
    if not (m and tonumber(x) and tonumber(y)) then return false end
    local W, H = Screen()
    local left, bottom = Unlock.Rect(m.anchor, m.anchor, tonumber(x), tonumber(y), m.w, m.h, W, H)
    Put(m, left, bottom)
    Keep(m)
    if Paint then Paint() end
    return true
end

-- Exact size, for a piece that can be resized (it has `resize(w, h)`, which
-- returns the size it took): it keeps its anchor where it was.
function Unlock.Resize(key, w, h)
    local m = movers and movers[key]
    if not (m and m.piece.resize and tonumber(w) and tonumber(h)) then return false end
    w, h = m.piece.resize(tonumber(w), tonumber(h))
    local W, H = Screen()
    m.w, m.h = w, h
    m:SetSize(w, h)
    local left, bottom = Unlock.Rect(m.anchor, m.anchor, m.x, m.y, w, h, W, H)
    Put(m, left, bottom)
    Keep(m)
    if Paint then Paint() end
    return true
end

-- A drag let go (or moved to) with its bottom left at (left, bottom);
-- `free` skips the snapping, as Shift does.
function Unlock.Drop(key, left, bottom, free, keep)
    local m = movers and movers[key]
    if not m then return end
    local W, H = Screen()
    local vx, hy
    if useSnap and not free then
        local others = {}
        for _, o in pairs(movers) do
            if o ~= m then others[#others + 1] = { o.left, o.bottom, o.w, o.h } end
        end
        left, bottom, vx, hy = Unlock.Snap(left, bottom, m.w, m.h, W, H, others, useGrid)
    end
    Put(m, left, bottom)
    guideV:SetShown(vx ~= nil)
    if vx then guideV:ClearAllPoints(); guideV:SetPoint("TOP", UIParent, "TOPLEFT", vx, 0); guideV:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", vx, 0) end
    guideH:SetShown(hy ~= nil)
    if hy then guideH:ClearAllPoints(); guideH:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, hy); guideH:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, hy) end
    if keep ~= false then Keep(m) end
    if Paint then Paint() end
end

-- Right-click: back where it was when Unlock Mode opened.
function Unlock.Undo(key)
    local m = movers and movers[key]
    local at = started[key]
    if not (m and at) then return end
    m.piece.save(at[1], at[2], at[3], at[4])
    local W, H = Screen()
    local left, bottom = Unlock.Rect(at[1] or "CENTER", at[2] or at[1], at[3], at[4], m.w, m.h, W, H)
    if at[1] then
        m.anchor = at[1]
        Put(m, left, bottom)
        m.piece.save(at[1], at[2], at[3], at[4])
    end
    if Paint then Paint() end
end

local function Mover(piece)
    local m = CreateFrame("Button", nil, overlay)
    m.piece = piece
    m:SetFrameLevel(overlay:GetFrameLevel() + 10)
    m:EnableMouse(true)
    m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    m.fill = Style.Fill(m, "gold")
    m.edges = Style.Border(m, "gold")
    m.tab = CreateFrame("Frame", nil, m)
    m.tab:SetHeight(20)
    Style.Fill(m.tab, "window")
    Style.Border(m.tab, "gold")
    m.tab.text = Style.Text(m.tab, 12, "gold", nil, true)
    m.tab.text:SetPoint("LEFT", 7, 0)
    m.tab.text:SetText(Name(piece))
    m.tab:SetWidth((m.tab.text:GetStringWidth() or 60) + 14)
    m:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        Pick(self)
        local scale = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        dragging = { m = self, dx = cx / scale - self.left, dy = cy / scale - self.bottom }
    end)
    m:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            Pick(self)
            return Unlock.Undo(self.piece.key)
        end
        if dragging and dragging.m == self then
            dragging = nil
            Keep(self)
            guideV:Hide()
            guideH:Hide()
        end
    end)
    return m
end

-- Lays every piece's mover where the piece is.
local function Lay()
    local W, H = Screen()
    for key, piece in pairs(pieces) do
        local m = movers[key] or Mover(piece)
        movers[key] = m
        local w, h, left, bottom, point = Measure(piece)
        m.w, m.h, m.anchor = w, h, point
        m:SetSize(w, h)
        local hidden = (piece.hidden and piece.hidden()) or not (piece.frame and piece.frame() and piece.frame():IsShown())
        m.hidden = hidden
        m.tab:ClearAllPoints()
        -- The tab above, or below a piece near the top of the screen.
        if bottom + h > H - 30 then
            m.tab:SetPoint("TOPLEFT", m, "BOTTOMLEFT", 0, -4)
        else
            m.tab:SetPoint("BOTTOMLEFT", m, "TOPLEFT", 0, 4)
        end
        Put(m, left, bottom)
        local at = piece.load and piece.load()
        started[key] = at and { at[1], at[2], at[3], at[4] } or { nil }
        m:Show()
    end
end

local function Build()
    overlay = CreateFrame("Frame", "jsalUIUnlock", UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("DIALOG")
    overlay:Hide()
    tinsert(UISpecialFrames, "jsalUIUnlock")
    local dim = overlay:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, 0.28)
    -- The grid, from the centre out, and the centre lines in gold.
    overlay.grid = {}
    local W, H = Screen()
    local function Line(vertical, at, gold)
        local t = overlay:CreateTexture(nil, "BORDER")
        if gold then t:SetColorTexture(Style.Color("gold")); t:SetAlpha(0.35)
        else t:SetColorTexture(1, 1, 1, 0.07) end
        if vertical then
            t:SetWidth(1)
            t:SetPoint("TOP", UIParent, "TOPLEFT", at, 0)
            t:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", at, 0)
        else
            t:SetHeight(1)
            t:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, at)
            t:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, at)
        end
        if not gold then overlay.grid[#overlay.grid + 1] = t end
        return t
    end
    for gx = W / 2 - math.floor(W / 2 / GRID) * GRID, W, GRID do Line(true, gx) end
    for gy = H / 2 - math.floor(H / 2 / GRID) * GRID, H, GRID do Line(false, gy) end
    Line(true, W / 2, true)
    Line(false, H / 2, true)
    guideV = overlay:CreateTexture(nil, "OVERLAY")
    guideV:SetColorTexture(Style.Color("gold"))
    guideV:SetWidth(2)
    guideV:Hide()
    guideH = overlay:CreateTexture(nil, "OVERLAY")
    guideH:SetColorTexture(Style.Color("gold"))
    guideH:SetHeight(2)
    guideH:Hide()
    movers = {}

    -- Dragging: the picked piece follows the pointer, snapping as it goes.
    overlay:SetScript("OnUpdate", function()
        if not dragging then return end
        local scale = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        Unlock.Drop(dragging.m.piece.key, cx / scale - dragging.dx, cy / scale - dragging.dy, IsShiftKeyDown and IsShiftKeyDown(), false)
    end)
    overlay:SetScript("OnHide", function()
        if dragging then Keep(dragging.m) end
        dragging = nil
        if panel then panel:Hide() end
    end)

    -- The panel: what to do, the picked piece's numbers, two switches, and Done.
    panel = CreateFrame("Frame", nil, overlay)
    panel:SetSize(660, 152)
    panel:SetPoint("TOP", UIParent, "TOP", 0, -200)
    panel:SetFrameLevel(overlay:GetFrameLevel() + 40)
    panel:EnableMouse(true)
    Style.Fill(panel, "window")
    Style.Border(panel, "lineStrong")
    Style.Rule(panel, "TOP", "gold")
    local title = Style.Text(panel, 17, "text", nil, true)
    title:SetPoint("TOPLEFT", 20, -16)
    title:SetText("Unlock Mode")
    local help = Style.Text(panel, 12, "muted")
    help:SetPoint("TOPLEFT", 20, -42)
    help:SetWidth(620)
    help:SetJustifyH("LEFT")
    help:SetText("Drag any jsal.ui piece to move it. It snaps to the grid, the centre and the other pieces; hold Shift to place it freely. Right-click a piece to put it back where it started.")

    -- The picked piece: its name and anchor, and its X and Y to type into.
    panel.which = Style.Text(panel, 13, "text", nil, true)
    panel.which:SetPoint("TOPLEFT", 20, -80)
    panel.which:SetWidth(240)
    panel.which:SetJustifyH("LEFT")
    local function Box(label, x, apply)
        local l = Style.Text(panel, 12, "muted")
        l:SetPoint("TOPLEFT", x, -80)
        l:SetText(label)
        local e = Style.Field(panel, 60)
        e.well:SetPoint("TOPLEFT", x + 16, -75)
        e:SetJustifyH("CENTER")
        -- Applied before the box lets go: letting go repaints the boxes with
        -- the numbers as they were, so reading them after would undo the typing.
        e:SetScript("OnEnterPressed", function(self)
            if picked then apply() end
            self:ClearFocus()
        end)
        e:SetScript("OnEditFocusLost", function() if Paint then Paint() end end)
        e.label = l
        return e
    end
    local function Move() Unlock.Place(picked.piece.key, panel.x:GetText(), panel.y:GetText()) end
    local function Size() Unlock.Resize(picked.piece.key, panel.w:GetText(), panel.h:GetText()) end
    panel.x = Box("X", 270, Move)
    panel.y = Box("Y", 355, Move)
    -- Width and height, for a piece that can be resized (the range check).
    panel.w = Box("W", 455, Size)
    panel.h = Box("H", 540, Size)

    local function Switch(label, x, get, set)
        local s = Style.Switch(panel, set)
        s:SetPoint("BOTTOMLEFT", x, 18)
        s:SetOn(get())
        local t = Style.Text(panel, 13, "text")
        t:SetPoint("LEFT", s, "RIGHT", 8, 0)
        t:SetText(label)
        return s
    end
    Switch("Grid", 20, function() return useGrid end, function(on)
        useGrid = on
        for _, t in ipairs(overlay.grid) do t:SetShown(on) end
    end)
    Switch("Snap", 116, function() return useSnap end, function(on) useSnap = on end)
    local undo = Style.Button(panel, "Undo all", "plain", 110)
    undo:SetPoint("BOTTOMRIGHT", -126, 16)
    undo:SetScript("OnClick", function()
        for key in pairs(movers) do Unlock.Undo(key) end
    end)
    local done = Style.Button(panel, "Done", "primary", 96)
    done:SetPoint("BOTTOMRIGHT", -20, 16)
    done:SetScript("OnClick", function() Unlock.Close() end)
end

Paint = function()
    if not panel then return end
    local m = picked
    if not m then
        panel.which:SetText("Pick a piece to type its position.")
        panel.x:SetText("")
        panel.y:SetText("")
        for _, e in ipairs({ panel.w, panel.h }) do
            e.well:Hide()
            e.label:Hide()
        end
        return
    end
    panel.which:SetText(("%s  ·  %s%s"):format(Name(m.piece), m.anchor, m.hidden and "  ·  hidden for now" or ""))
    if not panel.x:HasFocus() then panel.x:SetText(tostring(m.x)) end
    if not panel.y:HasFocus() then panel.y:SetText(tostring(m.y)) end
    local sized = m.piece.resize ~= nil
    for _, e in ipairs({ panel.w, panel.h }) do
        e.well:SetShown(sized)
        e.label:SetShown(sized)
    end
    if sized then
        if not panel.w:HasFocus() then panel.w:SetText(tostring(math.floor(m.w + 0.5))) end
        if not panel.h:HasFocus() then panel.h:SetText(tostring(math.floor(m.h + 0.5))) end
    end
end

function Unlock.Open()
    if Compat.InCombat() then return ns.Print("Unlock Mode opens once combat ends.") end
    if not next(pieces) then return ns.Print("There's nothing of jsal.ui's to move: switch on the quick buttons, the bag button, the food reminder or the range check in Settings.") end
    if not overlay then Build() end
    picked = nil
    Lay()
    overlay:Show()
    panel:Show()
    Paint()
end

function Unlock.Close()
    if overlay then overlay:Hide() end
end

function Unlock.IsOpen()
    return overlay ~= nil and overlay:IsShown()
end

-- For the tests, and for anything that wants to pick a piece by name.
function Unlock.Movers() return movers end
function Unlock.Pick(key)
    if movers and movers[key] then Pick(movers[key]) end
end

ns.Command("unlock", function() Unlock.Open() end)

-- A fight starting closes it, keeping where everything is: the game won't
-- let some pieces be moved in combat.
local fights = CreateFrame("Frame")
fights:RegisterEvent("PLAYER_REGEN_DISABLED")
fights:SetScript("OnEvent", function() if Unlock.IsOpen() then Unlock.Close() end end)
