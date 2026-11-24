-- The look every jsal.ui window shares: the jsal.io dark colours, flat fills
-- and 1px lines, which the game draws crisply at any scale, and softly
-- rounded corners on what you press and what holds things: buttons, text
-- boxes and cards a little, tags, counts, switches and a row of choices all
-- the way round.
local addonName, ns = ...
local Compat = ns.Compat

local Style = {}
ns.Style = Style

local function Hex(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

Style.colors, Style.hex = {}, {}
for key, hex in pairs({
    window = "191c23",
    titleBar = "15181e",
    well = "22262f",
    wellHover = "2b303b",
    line = "2a2e38",
    -- The line around a card: a step stronger than a rule, so a card's edge
    -- shows against its own fill.
    cardLine = "363b47",
    lineStrong = "3d424e",
    -- A scroll list's bar.
    thumb = "7a776d",
    text = "ece6d6",
    -- Between text and muted: a label that isn't the one chosen (a tab, a
    -- menu entry), which muted would make look switched off.
    secondary = "c4bfb0",
    muted = "9a9688",
    gold = "e3b04b",
    goldHover = "f6d489",
    -- Red and green are for text on a card, so both keep 4.5:1 against it.
    red = "ef7a66",
    green = "62b35a",
    onGold = "16130c",
    blue = "2f5db5",
    -- An order's states in Guild Crafts: amber while it waits for a crafter, sky while
    -- it's being made (green is done, gold what waits on you). Both keep 4.5:1 on a card.
    amber = "d68c3c",
    sky = "60a5eb",
    -- Behind "has the materials" and "needs the materials": green and gold, dimmed.
    goodFill = "203626",
    needFill = "3e3118",
    white = "ffffff",
    -- Daily Word's tiles, in the green, yellow and grey word-game players know.
    wordGreen = "56944f",
    wordYellow = "c2a23d",
    wordGrey = "3a3d44",
}) do
    Style.colors[key] = { Hex(hex) }
    Style.hex[key] = hex
end

function Style.Color(key)
    local c = Style.colors[key]
    return c[1], c[2], c[3]
end

-- A colour as the code that starts coloured words inside a line of text;
-- "|r" ends them.
function Style.Tint(key)
    return "|cff" .. Style.hex[key]
end

-- An item's name colour by its quality, as six hex digits. The game's own
-- colours, except rare blue and epic purple, lightened: the game's are near
-- 3:1 on these dark fills, too dim to read as text.
local QUALITY = { [0] = "9d9d9d", "ffffff", "1eff00", "4d9fff", "c07bff", "ff8000" }
function Style.Quality(quality)
    return QUALITY[quality or 1] or "ffffff"
end

-- Outfit, in Regular and SemiBold (its bold here), trimmed to Latin and
-- shipped in Media. If the game can't load it, text falls back to the game's
-- own font.
local FONTS = "Interface\\AddOns\\" .. addonName .. "\\Media\\Fonts\\"
Style.font = FONTS .. "Outfit-Regular.ttf"
Style.boldFont = FONTS .. "Outfit-SemiBold.ttf"
-- The wordmark keeps jsal.io's own: Inter Bold.
Style.brandFont = FONTS .. "Inter-Bold.ttf"

-- The game loads a font file the first time something uses it, and text
-- drawn before then can come up blank. Using both fonts here, at load,
-- means they're ready before any window is built.
local preload = CreateFrame("Frame", nil, UIParent)
preload:SetSize(1, 1)
preload:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100)
for _, path in ipairs({ Style.font, Style.boldFont, Style.brandFont }) do
    local text = preload:CreateFontString(nil, "OVERLAY")
    text:SetFont(path, 13, "")
    text:SetText("jsal.ui")
end

-- Text in the dashboard is drawn one size up: the window has room, and it
-- reads more easily there. Panels beside the game's windows keep their size.
local DASHBOARD_STEP = 1
-- In the dashboard and a page's own window nothing is drawn smaller than
-- this, unless `exact` asks for a size as given (a rank in the corner of an
-- icon, which has no room to grow).
local SMALLEST = 12

function Style.Text(parent, size, colorKey, layer, bold, exact)
    local text = parent:CreateFontString(nil, layer or "OVERLAY")
    size = size or 13
    if ns.Window and ns.Window.Contains and ns.Window.Contains(parent) then size = size + DASHBOARD_STEP end
    if not exact and ns.Window and ns.Window.Roomy and ns.Window.Roomy(parent) then size = math.max(size, SMALLEST) end
    text:SetFont(bold and Style.boldFont or Style.font, size, "")
    if not text:GetFont() then
        text:SetFont(STANDARD_TEXT_FONT, size, "")
    end
    text:SetTextColor(Style.Color(colorKey or "text"))
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    return text
end

-- The jsal.ui wordmark, as on jsal.io: the name in Inter Bold with ".ui" in gold.
function Style.Wordmark(parent, size)
    local text = Style.Text(parent, size)
    text:SetFont(Style.brandFont, size, "")
    if not text:GetFont() then
        text:SetFont(Style.boldFont, size, "")
    end
    text:SetText("jsal|cffe3b04b.ui|r")
    return text
end

-- A flat fill behind a frame's contents.
function Style.Fill(frame, colorKey, layer)
    local fill = frame:CreateTexture(nil, layer or "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(Style.Color(colorKey))
    return fill
end

-- A 1px line around a frame, drawn as four edge textures.
local EDGES = {
    { "TOPLEFT", "TOPRIGHT", true },
    { "BOTTOMLEFT", "BOTTOMRIGHT", true },
    { "TOPLEFT", "BOTTOMLEFT", false },
    { "TOPRIGHT", "BOTTOMRIGHT", false },
}

function Style.Border(frame, colorKey)
    local px = Compat.OnePixel(frame)
    local edges = {}
    for i, edge in ipairs(EDGES) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(Style.Color(colorKey))
        t:SetPoint(edge[1])
        t:SetPoint(edge[2])
        if edge[3] then t:SetHeight(px) else t:SetWidth(px) end
        Compat.Crisp(t)
        edges[i] = t
    end
    return edges
end

-- The same 1px line round a frame, with the frame filled inside it, in two pictures where a
-- fill and Style.Border are five: a square of the line's colour, and the fill a pixel inside it.
-- Pages lay out slower the more pieces they have, and a small talent square drawn as a fill and
-- a border is six. It
-- looks the same wherever the inside is filled; a frame with nothing inside its line still
-- needs Style.Border. Without a `fillKey` it's the line's square alone, one picture, for a frame
-- whose inside is always covered by something that can't be seen through (a game icon a pixel
-- in). Returns the line, as Style.Border's edges for Style.SetBorder, and the fill.
function Style.Lined(frame, lineKey, fillKey)
    local px = Compat.OnePixel(frame)
    local line = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    line:SetAllPoints()
    line:SetColorTexture(Style.Color(lineKey))
    Compat.Crisp(line)
    if not fillKey then return { line }, nil end
    local fill = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    fill:SetPoint("TOPLEFT", px, -px)
    fill:SetPoint("BOTTOMRIGHT", -px, px)
    fill:SetColorTexture(Style.Color(fillKey))
    Compat.Crisp(fill)
    return { line }, fill
end

function Style.SetBorder(edges, colorKey)
    for _, t in ipairs(edges) do
        if t.Paint then t:Paint(colorKey) else t:SetColorTexture(Style.Color(colorKey)) end
    end
end

-- Round corners. A white square with rounded corners (Media\Round, one for
-- each radius) is stretched over a frame with its corners kept at their own
-- size, and tinted. Where the game can't do that, or the pictures weren't
-- there when it started (a new file needs a restart), the same shape is
-- drawn square: everything works as before, with the corners it used to
-- have.
local ROUND = "Interface\\AddOns\\" .. addonName .. "\\Media\\Round\\r"
local RADII = { [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true, [12] = true, [13] = true }

function Style.Rounded()
    return Enum ~= nil and Enum.UITextureSliceMode ~= nil and not ns.needsRestart
end

-- Colours a shape: a picture is tinted, a square one filled.
local function PaintShape(self, key, alpha)
    local r, g, b = Style.Color(key)
    if self.round then self:SetVertexColor(r, g, b, alpha or 1) else self:SetColorTexture(r, g, b, alpha or 1) end
end

-- A filled shape with corners of `radius`, over the whole frame until it's
-- placed otherwise. Paint(colorKey, alpha) colours it.
function Style.Round(frame, radius, colorKey, layer, level)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, level or 0)
    t:SetAllPoints()
    if RADII[radius] and t.SetTextureSliceMargins and Style.Rounded() then
        t.round = true
        t:SetTexture(ROUND .. radius)
        t:SetTextureSliceMargins(radius, radius, radius, radius)
        t:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    end
    t.Paint = PaintShape
    t:Paint(colorKey or "well")
    return t
end

-- Colours a box: its fill, its line, or both; nil leaves one as it is.
local function PaintBox(self, fill, line)
    if fill then self.fill:Paint(fill) end
    if line then self.line:Paint(line) end
end

-- A box with round corners: a line a pixel wide round a fill, drawn as one
-- shape a pixel inside another. Paint(fillKey, lineKey) colours them; nil
-- leaves one as it is.
function Style.Box(frame, radius, fillKey, lineKey)
    local box = {
        line = Style.Round(frame, radius, lineKey, "BACKGROUND", 0),
        fill = Style.Round(frame, radius - 1, fillKey, "BACKGROUND", 1),
    }
    local px = Compat.OnePixel(frame)
    box.fill:ClearAllPoints()
    box.fill:SetPoint("TOPLEFT", px, -px)
    box.fill:SetPoint("BOTTOMRIGHT", -px, px)
    box.Paint = PaintBox
    return box
end

-- A disc with a line round it, for a round sign: one picture of a circle
-- drawn whole, twice, the fill a pixel inside the line. Paint(fillKey,
-- lineKey) colours them. Where round corners can't be drawn it's a square.
local CIRCLE = "Interface\\AddOns\\" .. addonName .. "\\Media\\Round\\circle"

function Style.Circle(frame, fillKey, lineKey)
    local function Disc(level, key)
        local t = frame:CreateTexture(nil, "BACKGROUND", nil, level)
        t:SetAllPoints()
        -- Round only where the corners are: a round sign among square
        -- buttons would look like a mistake.
        if t.SetTextureSliceMargins and Style.Rounded() then
            t.round = true
            t:SetTexture(CIRCLE)
        end
        t.Paint = PaintShape
        t:Paint(key)
        return t
    end
    local disc = { line = Disc(0, lineKey), fill = Disc(1, fillKey), Paint = PaintBox }
    local px = Compat.OnePixel(frame)
    disc.fill:ClearAllPoints()
    disc.fill:SetPoint("TOPLEFT", px, -px)
    disc.fill:SetPoint("BOTTOMRIGHT", -px, px)
    return disc
end

-- A round mark, as for a guildmate who's on: the circle's picture, one
-- piece, `size` across. Paint(colorKey) colours it. Where round corners
-- can't be drawn it's a square.
function Style.Dot(parent, size, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetSize(size, size)
    if t.SetTextureSliceMargins and Style.Rounded() then
        t.round = true
        t:SetTexture(CIRCLE)
    end
    t.Paint = PaintShape
    return t
end

-- A pill: a shape whose ends are half circles, whatever its size and the
-- screen's. It's the circle's picture in three pieces: its left half, a
-- flat middle, its right half. A sliced corner (Style.Round) is drawn at a
-- size of its own, about half what it's set to on a screen where a unit is
-- a pixel, so a shape that's round at its ends can't be made with one.
-- `radius` is half the pill's height, for one the caller places and sizes:
-- what this returns is placed, sized, shown and painted as a shape from
-- Style.Round is. Without a radius the pill fills its frame, as tall as the
-- frame comes to be, `inset` in from its edges. Where round shapes can't be
-- drawn its ends are square.
function Style.Pill(frame, radius, colorKey, layer, level, inset)
    layer, level = layer or "BACKGROUND", level or 0
    -- What a caller places: nothing to see, over the pill's whole
    -- rectangle, with the three pieces hung on it.
    local p = frame:CreateTexture(nil, layer, nil, level)
    p:SetColorTexture(0, 0, 0, 0)
    if inset then
        p:SetPoint("TOPLEFT", inset, -inset)
        p:SetPoint("BOTTOMRIGHT", -inset, inset)
    else
        p:SetAllPoints()
    end
    p.round = p.SetTextureSliceMargins ~= nil and Style.Rounded()
    p.left = frame:CreateTexture(nil, layer, nil, level)
    p.mid = frame:CreateTexture(nil, layer, nil, level)
    p.right = frame:CreateTexture(nil, layer, nil, level)
    if p.round then
        p.left:SetTexture(CIRCLE)
        p.left:SetTexCoord(0, 0.5, 0, 1)
        p.right:SetTexture(CIRCLE)
        p.right:SetTexCoord(0.5, 1, 0, 1)
    end
    -- An end is as wide as half the pill's height.
    local function Lay(r)
        p.radius = r
        p.left:ClearAllPoints()
        p.left:SetPoint("TOPLEFT", p, "TOPLEFT")
        p.left:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT")
        p.left:SetWidth(r)
        p.right:ClearAllPoints()
        p.right:SetPoint("TOPRIGHT", p, "TOPRIGHT")
        p.right:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT")
        p.right:SetWidth(r)
        p.mid:ClearAllPoints()
        p.mid:SetPoint("TOPLEFT", p, "TOPLEFT", r, 0)
        p.mid:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -r, 0)
    end
    if radius then
        Lay(radius)
    else
        local function Follow()
            local tall = frame:GetHeight()
            if type(tall) == "number" and tall > 0 then Lay(math.max(1, tall / 2 - (inset or 0))) end
        end
        frame:HookScript("OnSizeChanged", Follow)
        Follow()
    end
    function p:Paint(key, alpha)
        local r, g, b = Style.Color(key)
        alpha = alpha or 1
        if self.round then
            self.left:SetVertexColor(r, g, b, alpha)
            self.right:SetVertexColor(r, g, b, alpha)
        else
            self.left:SetColorTexture(r, g, b, alpha)
            self.right:SetColorTexture(r, g, b, alpha)
        end
        self.mid:SetColorTexture(r, g, b, alpha)
    end
    local show, hide = p.Show, p.Hide
    function p:Show()
        show(self)
        self.left:Show()
        self.mid:Show()
        self.right:Show()
    end
    function p:Hide()
        hide(self)
        self.left:Hide()
        self.mid:Hide()
        self.right:Hide()
    end
    function p:SetShown(on)
        if on then self:Show() else self:Hide() end
    end
    function p:SetAlpha(alpha)
        self.left:SetAlpha(alpha)
        self.mid:SetAlpha(alpha)
        self.right:SetAlpha(alpha)
    end
    p:Paint(colorKey or "well")
    return p
end

-- A pill with a line round it, over its whole frame: one pill a pixel
-- inside another. Paint(fillKey, lineKey) colours them, as a box's.
function Style.PillBox(frame, fillKey, lineKey)
    return {
        line = Style.Pill(frame, nil, lineKey, "BACKGROUND", 0),
        fill = Style.Pill(frame, nil, fillKey, "BACKGROUND", 1, Compat.OnePixel(frame)),
        Paint = PaintBox,
    }
end

-- The mark of a card that's yours, next or current: its left edge in
-- colour, three wide, following the card's round corners. It's a frame of
-- its own above what's in the card (rows drawn over an edge cut it into
-- pieces), that shows only its own width of a shape as large and as round
-- as the card. Where the game can't keep what's in a frame to its bounds,
-- or corners aren't round, it's a straight bar clear of the corners.
function Style.Edge(card, radius, colorKey)
    local edge = CreateFrame("Frame", nil, card)
    edge:SetFrameLevel((card:GetFrameLevel() or 0) + 6)
    edge:SetWidth(3)
    if edge.SetClipsChildren and Style.Rounded() then
        edge:SetPoint("TOPLEFT")
        edge:SetPoint("BOTTOMLEFT")
        edge:SetClipsChildren(true)
        local whole = CreateFrame("Frame", nil, edge)
        whole:SetPoint("TOPLEFT", card, "TOPLEFT")
        whole:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT")
        edge.shape = Style.Round(whole, radius, colorKey or "gold", "ARTWORK")
    else
        edge:SetPoint("TOPLEFT", 0, -radius)
        edge:SetPoint("BOTTOMLEFT", 0, radius)
        edge.shape = Style.Fill(edge, colorKey or "gold", "ARTWORK")
        edge.shape.Paint = PaintShape
    end
    -- Another colour, for a card whose edge says the state it's in.
    function edge:Paint(key) self.shape:Paint(key) end
    return edge
end

-- The fill of a part that sits against a round box's edge, round only where
-- the box's corners are. `where` says which of the part's corners those
-- are: "TOP" (a bar across the box's top, when not given), "BOTTOM" (a strip
-- along its bottom), "LEFT" or "RIGHT" (a stretch at one end of a bar), or
-- one corner alone, as "BOTTOMLEFT" for a column down its left side that
-- stops short of the top. It's a round shape with a flat one over each half
-- that must stay square.
function Style.Cap(frame, radius, colorKey, where)
    where = where or "TOP"
    local round = Style.Round(frame, radius, colorKey)
    local function Flat(first, second, side)
        local t = frame:CreateTexture(nil, "BACKGROUND")
        t:SetColorTexture(Style.Color(colorKey))
        t:SetPoint(first)
        t:SetPoint(second)
        t:SetPoint(side, frame, "CENTER")
    end
    if where:find("TOP", 1, true) then
        Flat("BOTTOMLEFT", "BOTTOMRIGHT", "TOP")
    elseif where:find("BOTTOM", 1, true) then
        Flat("TOPLEFT", "TOPRIGHT", "BOTTOM")
    end
    if where:find("LEFT", 1, true) then
        Flat("TOPRIGHT", "BOTTOMRIGHT", "LEFT")
    elseif where:find("RIGHT", 1, true) then
        Flat("TOPLEFT", "BOTTOMLEFT", "RIGHT")
    end
    return round
end

-- A 1px rule along one side of a frame.
function Style.Rule(frame, side, colorKey)
    local t = frame:CreateTexture(nil, "BORDER")
    t:SetColorTexture(Style.Color(colorKey or "line"))
    local px = Compat.OnePixel(frame)
    if side == "BOTTOM" or side == "TOP" then
        t:SetPoint(side .. "LEFT")
        t:SetPoint(side .. "RIGHT")
        t:SetHeight(px)
    else
        t:SetPoint("TOP" .. side)
        t:SetPoint("BOTTOM" .. side)
        t:SetWidth(px)
    end
    Compat.Crisp(t)
    return t
end

-- A soft shadow around a window, so its edge stays clear over a bright zone
-- like sand or snow. One blurred square (Media\Shadow) is cut into four
-- corners and four edges reaching `size` beyond the frame, a little lower
-- than it, and drawn under the frame's own fill, which hides the middle.
-- The frame must be at least twice `size` tall and wide.
local SHADOW = "Interface\\AddOns\\" .. addonName .. "\\Media\\Shadow"
local SHADOW_ALPHA = 0.7

function Style.Shadow(frame, size)
    size = size or 20
    local drop = math.floor(size / 4 + 0.5)
    local pieces = {}
    local function Piece(l, r, t, b)
        local tex = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        tex:SetTexture(SHADOW)
        tex:SetTexCoord(l, r, t, b)
        tex:SetVertexColor(0, 0, 0, SHADOW_ALPHA)
        pieces[#pieces + 1] = tex
        return tex
    end
    local tl, tr = Piece(0, 0.5, 0, 0.5), Piece(0.5, 1, 0, 0.5)
    local bl, br = Piece(0, 0.5, 0.5, 1), Piece(0.5, 1, 0.5, 1)
    for _, corner in ipairs({ tl, tr, bl, br }) do corner:SetSize(size * 2, size * 2) end
    tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -size, size - drop)
    tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", size, size - drop)
    bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -size, -size - drop)
    br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", size, -size - drop)
    -- The edges stretch a thin strip from the middle of the square.
    local top = Piece(0.49, 0.51, 0, 0.5)
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
    top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    local bottom = Piece(0.49, 0.51, 0.5, 1)
    bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT")
    bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    local left = Piece(0, 0.5, 0.49, 0.51)
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
    left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    local right = Piece(0.5, 1, 0.49, 0.51)
    right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT")
    right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    -- All eight, for whoever wants to hide the shadow.
    return pieces
end

-- Opening: a window fades in as it rises `from` pixels into place (a
-- negative `from` starts it below), quick enough not to wait on. The first
-- step sets the start, the second brings it home, so it always ends exactly
-- where it was placed or dragged to.
-- Closing is the same in reverse: Hide fades it as it sinks back the way it
-- came, and it's hidden when that ends. Whatever hides it gets that: its
-- close button, Escape, a menu entry. HideNow hides it at once, for when it
-- can't wait (a fight starting). Shown again while it's closing, it stays.
local OPEN_TIME, CLOSE_TIME = 0.14, 0.11

function Style.Opening(frame, from)
    local group = frame.CreateAnimationGroup and frame:CreateAnimationGroup()
    if not group then return end
    local function Step(kind, order, duration)
        local a = group:CreateAnimation(kind)
        a:SetOrder(order)
        a:SetDuration(duration)
        return a
    end
    Step("Translation", 1, 0):SetOffset(0, from)
    local hidden = Step("Alpha", 1, 0)
    hidden:SetFromAlpha(0)
    hidden:SetToAlpha(0)
    local rise = Step("Translation", 2, OPEN_TIME)
    rise:SetOffset(0, -from)
    rise:SetSmoothing("OUT")
    local fade = Step("Alpha", 2, OPEN_TIME)
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    frame:HookScript("OnShow", function()
        group:Stop()
        group:Play()
    end)

    local closing = frame:CreateAnimationGroup()
    local sink = closing:CreateAnimation("Translation")
    sink:SetDuration(CLOSE_TIME)
    sink:SetOffset(0, from)
    sink:SetSmoothing("IN")
    local out = closing:CreateAnimation("Alpha")
    out:SetDuration(CLOSE_TIME)
    out:SetFromAlpha(1)
    out:SetToAlpha(0)
    local hide, show = frame.Hide, frame.Show
    closing:SetScript("OnFinished", function()
        frame.closing = nil
        hide(frame)
    end)
    function frame:HideNow()
        closing:Stop()
        self.closing = nil
        hide(self)
    end
    function frame:Hide()
        if self.closing then return end
        -- One that isn't on screen has nothing to fade.
        if not (self:IsShown() and self:IsVisible()) then return hide(self) end
        group:Stop()
        closing:Play()
        -- Where the fade didn't start, it's hidden at once.
        if closing:IsPlaying() then self.closing = true else hide(self) end
    end
    function frame:Show()
        if self.closing then
            closing:Stop()
            self.closing = nil
        end
        show(self)
    end
    return group
end

-- A faint light over a row or card under the pointer, so it's clear what a
-- click or a tooltip will come from. It reaches `pad` past the row's sides
-- for rows whose icon sits on their edge. On a round card, `radius` is the
-- card's: the light is then the shape of the card's fill, a pixel inside
-- its line, and follows its corners; on a pill it's "pill". Call it after
-- the row's own OnEnter and OnLeave are set: it adds to them.
function Style.Hover(frame, pad, radius)
    pad = pad or 0
    local glow
    if radius == "pill" then
        glow = Style.Pill(frame, nil, "text", "BACKGROUND", 7, Compat.OnePixel(frame))
        glow:SetAlpha(0.06)
    elseif radius then
        local px = Compat.OnePixel(frame)
        glow = Style.Round(frame, radius - 1, "text", "BACKGROUND", 7)
        glow:ClearAllPoints()
        glow:SetPoint("TOPLEFT", px, -px)
        glow:SetPoint("BOTTOMRIGHT", -px, px)
        glow:SetAlpha(0.06)
    else
        glow = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
        glow:SetPoint("TOPLEFT", -pad, 0)
        glow:SetPoint("BOTTOMRIGHT", pad, 0)
        local r, g, b = Style.Color("text")
        glow:SetColorTexture(r, g, b, 0.06)
    end
    glow:Hide()
    frame:HookScript("OnEnter", function() glow:Show() end)
    frame:HookScript("OnLeave", function() glow:Hide() end)
    return glow
end

-- A talent's ranks as a row of small squares, five at most: the ranks you
-- already have are dim gold, the ones being taken are gold, the rest are
-- dark. Set(had, of, taking) paints it; `wide` is the room it takes.
function Style.Pips(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(52, 8)
    p.wide = 52
    p.dots = {}
    -- Round ticks where round shapes can be drawn, the circle's picture tinted; squares where
    -- they can't.
    local round = Style.Rounded()
    for i = 1, 5 do
        local t = p:CreateTexture(nil, "ARTWORK")
        t:SetSize(8, 8)
        t:SetPoint("LEFT", (i - 1) * 11, 0)
        if round and t.SetTextureSliceMargins then
            t:SetTexture(CIRCLE)
            t.round = true
        end
        p.dots[i] = t
    end
    local function Tint(t, r, g, b, a)
        if t.round then t:SetVertexColor(r, g, b, a or 1) else t:SetColorTexture(r, g, b, a or 1) end
    end
    function p:Set(had, of, taking)
        of = math.max(1, math.min(5, of or 1))
        had, taking = had or 0, taking or 0
        local r, g, b = Style.Color("gold")
        for i, t in ipairs(self.dots) do
            t:SetShown(i <= of)
            if i <= had then
                Tint(t, r, g, b, 0.45)
            elseif i <= had + taking then
                Tint(t, r, g, b, 1)
            else
                Tint(t, Style.Color("lineStrong"))
            end
        end
        self.wide = of * 11 - 3
        self:SetWidth(self.wide)
    end
    return p
end

-- A text's width, or a guess where the game hasn't one to give.
function Style.Wide(text, guess)
    local w = text.GetStringWidth and text:GetStringWidth()
    return (type(w) == "number" and w > 0) and w or guess
end

-- A small section heading: a title in gold, a count after it, a note at the
-- right, and a rule under it.
function Style.Section(parent, width)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(width, 20)
    s.title = Style.Text(s, 11, "gold", nil, true)
    s.title:SetPoint("LEFT")
    s.count = Style.Text(s, 11, "muted", nil, true)
    s.count:SetPoint("LEFT", s.title, "RIGHT", 8, 0)
    s.note = Style.Text(s, 11, "muted")
    s.note:SetPoint("RIGHT")
    s.note:SetJustifyH("RIGHT")
    Style.Rule(s, "BOTTOM", "line")
    return s
end

-- The game's tooltip for what a row shows (its `item`, or its `spell`), with
-- the light under the pointer. `more`, when given, adds lines of its own;
-- `radius` is a round card's, for a light that follows its corners; `pad`
-- is how far the light reaches past a row's sides, 6 unless given (none for
-- a row inside a card, whose sides are the card's).
-- A tooltip that's up for a frame is built again from what the frame now
-- says, for a frame painted afresh while it's pointed at (a craft landing
-- changes its counts). Only on a paint that happens anyway, and only for the
-- frame the tooltip belongs to.
function Style.Retip(frame)
    if GameTooltip:IsShown() and GameTooltip:IsOwned(frame) then
        local enter = frame:GetScript("OnEnter")
        if enter then enter(frame) end
    end
end

---------------------------------------------------------------------------
-- jsal.ui's lines on an item's tooltip, wherever it shows (bags, loot,
-- vendors, the auction house, a chat link): one section at the foot, under
-- jsal.ui's mark and name, so it's plain where they come from; each part's
-- lines in a set order, and none at all when no part has anything to say.
-- A part adds itself with Style.ItemLines(order, fn): fn(lines, id, tooltip)
-- puts its lines in `lines` with lines:AddLine(text, r, g, b, wrap), as on a
-- tooltip. The game's compare tooltips (what you wear, beside the one you
-- point at) get none.
---------------------------------------------------------------------------
Style.MARK = "|TInterface\\AddOns\\jsalUI\\Media\\Logo:14:14|t"
local itemParts, itemHooked = {}, false

local function ItemSection(tooltip, id)
    if not (id and tooltip and tooltip.AddLine) then return end
    if tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2 then return end
    local got = {}
    local lines = { AddLine = function(_, text, r, g, b, wrap) got[#got + 1] = { text, r, g, b, wrap } end }
    for _, part in ipairs(itemParts) do xpcall(part.fn, ns.Report, lines, id, tooltip) end
    if #got == 0 then return end
    local mr, mg, mb = Style.Color("muted")
    tooltip:AddLine(" ")
    tooltip:AddLine(Style.MARK .. " jsal.ui", mr, mg, mb)
    for _, l in ipairs(got) do tooltip:AddLine(l[1], l[2], l[3], l[4], l[5]) end
    if tooltip.Show then tooltip:Show() end
end
Style.ItemSection = ItemSection

function Style.ItemLines(order, fn)
    itemParts[#itemParts + 1] = { order = order, fn = fn }
    table.sort(itemParts, function(a, b) return a.order < b.order end)
    if itemHooked then return end
    itemHooked = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            -- In a dungeon the item's ID can come hidden; a hidden one is nil here.
            ItemSection(tooltip, Compat.Plain(data and data.id))
        end)
    elseif GameTooltip and GameTooltip.HookScript then
        for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
            if tip then
                tip:HookScript("OnTooltipSetItem", function(tooltip)
                    local _, link = tooltip:GetItem()
                    ItemSection(tooltip, link and tonumber(link:match("item:(%d+)")))
                end)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Text boxes that take a shift-clicked item: while one has the cursor, a
-- shift-click on an item anywhere (bags, chat, a tooltip's link) puts its
-- link there, as the game does for the chat box. One hook for every such
-- box; each box's part guards its own. Only the box with the cursor takes
-- it, so a link meant for chat still goes to chat.
---------------------------------------------------------------------------
local linkBoxes, linksHooked = {}, false
local function TakeLink(link)
    if type(link) ~= "string" or not link:find("|Hitem:") then return end
    for _, take in ipairs(linkBoxes) do take(link) end
end

-- `box` takes a shift-clicked item link while it has the cursor; `module` is
-- the part it belongs to, whose guard it runs under.
function Style.TakesLinks(box, module)
    linkBoxes[#linkBoxes + 1] = ns.Safe(module, function(link)
        if box:HasFocus() then box:SetText(link) end
    end)
    if linksHooked or not (ChatFrameUtil and ChatFrameUtil.InsertLink) then return end
    linksHooked = true
    -- The game's shift-click calls ChatFrameUtil.InsertLink by that name.
    hooksecurefunc(ChatFrameUtil, "InsertLink", function(link) xpcall(TakeLink, ns.Report, link) end)
end

-- A piece's tooltip belongs to its picture and name, not its whole line: over
-- the rest of a line it covered what's under the pointer, and a line with two
-- pieces on it showed one piece's tooltip over the other's name. A hot area
-- is made once on its line (`owner`) and placed and sized by its line; under
-- the pointer it shows `tip(hot)`, lights its line as the line itself does,
-- and passes a click to it, so a line is picked by a click anywhere on it.
function Style.HotArea(owner, tip)
    local hot = CreateFrame("Frame", nil, owner)
    hot:EnableMouse(true)
    hot:SetScript("OnEnter", function(self)
        local enter = owner:GetScript("OnEnter")
        if enter then enter(owner) end
        tip(self)
    end)
    hot:SetScript("OnLeave", function()
        local leave = owner:GetScript("OnLeave")
        if leave then leave(owner) end
        GameTooltip:Hide()
    end)
    hot:SetScript("OnMouseUp", function(_, button)
        local click = owner:GetScript("OnClick") or owner:GetScript("OnMouseUp")
        if click then click(owner, button) end
    end)
    return hot
end

-- The game builds an item's or a spell's tooltip again once something it shows has come in (a
-- reagent's or a tool's name the game hadn't loaded yet, the first time a recipe is pointed at). It
-- clears every line and draws its own, and the lines a row adds under them would go with them
-- until the row is pointed at again. A tooltip that belongs to a row made here is built whole
-- again right after, with the row's lines under the game's, as at the first look.
local tipRows, rebuildHooked = setmetatable({}, { __mode = "k" }), false
local function AfterRebuild(tooltip)
    if tooltip ~= GameTooltip or not tooltip:IsShown() then return end
    local owner = tooltip:GetOwner()
    local enter = owner and tipRows[owner] and owner:GetScript("OnEnter")
    if enter then enter(owner) end
end

function Style.ItemTip(frame, more, radius, pad)
    tipRows[frame] = true
    if not rebuildHooked and hooksecurefunc and GameTooltip and type(GameTooltip.RebuildFromTooltipInfo) == "function" then
        rebuildHooked = true
        hooksecurefunc(GameTooltip, "RebuildFromTooltipInfo", function(tooltip) xpcall(AfterRebuild, ns.Report, tooltip) end)
    end
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.item then GameTooltip:SetItemByID(self.item) elseif self.spell then GameTooltip:SetSpellByID(self.spell) end
        if more then more(self) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Style.Hover(frame, radius and 0 or (pad or 6), radius)
end

-- A page's small print (where its numbers come from, how far to trust
-- them): one quiet link, "About these numbers", read when it's pointed at
-- and not printed on the page. `note` is its words, a paragraph a line, or
-- a function that gives them; `about.note` can be set later. A blank line
-- parts one paragraph from the next, so each reads on its own.
function Style.About(parent, note)
    local b = CreateFrame("Button", nil, parent)
    b.note = note
    b.text = Style.Text(b, 12, "muted")
    b.text:SetPoint("RIGHT")
    b.text:SetText("About these numbers")
    b:SetSize(Style.Wide(b.text, 124), 18)
    Style.Rule(b, "BOTTOM", "lineStrong")
    -- Named for what it's about where that isn't numbers ("About this map"); its tooltip takes
    -- the name.
    function b:Say(words)
        if self.text:GetText() == words then return end
        self.text:SetText(words)
        self:SetWidth(Style.Wide(self.text, 124))
    end
    b:SetScript("OnEnter", function(self)
        self.text:SetTextColor(Style.Color("text"))
        local words = type(self.note) == "function" and self.note() or self.note
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText(self.text:GetText() or "About these numbers")
        local first = true
        for line in (words or ""):gmatch("[^\n]+") do
            if not first then GameTooltip:AddLine(" ") end
            GameTooltip:AddLine(line, 0.77, 0.75, 0.69, true)
            first = false
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self.text:SetTextColor(Style.Color("muted"))
        GameTooltip:Hide()
    end)
    return b
end

-- Buttons, with softly rounded corners. "primary" is gold with dark text,
-- for the one main action on a page; "plain" is a well with a line around
-- it. Under the pointer both light up a step, and a plain one darkens while
-- it's pressed.
-- "gilt" is for an action offered on every row of a list: a plain button
-- at rest, so a long list isn't a column of gold, and gold under the pointer.
-- "tab" is one of a row of choices (a page's tabs, a filter, a spec), a pill:
-- the chosen one, set with SetSelected, has gold words on a dim gold fill in
-- a gold line, so a gold fill stays the mark of the main action.
-- "done" says something is already done: muted words in a quiet line, not
-- lit under the pointer, though a click still does what it says.
-- A tone overrides the kind for a game's answer buttons: "right" is gold,
-- "wrong" is dimmed.
local function PaintButton(b)
    local enabled = b:IsEnabled()
    local chosen = b.kind == "tab" and b.selected and not b.tone
    local lit = enabled and (b.hover or b.down) and true or false
    local fill, line, text
    if b.tone == "right" then
        fill, line, text = "gold", "gold", "onGold"
    elseif b.tone == "wrong" then
        fill, line, text = "line", "line", "muted"
    elseif b.kind == "done" then
        fill, line, text = "well", "line", "muted"
    elseif b.kind == "primary" and enabled then
        fill = (b.hover and not b.down) and "goldHover" or "gold"
        line, text = fill, "onGold"
    elseif b.kind == "gilt" and lit then
        fill, line, text = "gold", "gold", "onGold"
    elseif chosen then
        fill, line, text = "needFill", "gold", "gold"
    elseif b.kind == "tab" then
        fill, line, text = lit and "wellHover" or "well", "lineStrong", lit and "text" or "secondary"
    else
        fill = (b.down and enabled) and "titleBar" or (lit and "wellHover" or "well")
        line, text = lit and "gold" or (enabled and "lineStrong" or "line"), enabled and "text" or "muted"
    end
    b.box:Paint(fill, line)
    b.label:SetTextColor(Style.Color(text))
end

function Style.Button(parent, label, kind, width)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 140, 28)
    b.kind = kind or "plain"
    b.box = b.kind == "tab" and Style.PillBox(b, "well", "lineStrong") or Style.Box(b, 5, "well", "lineStrong")
    -- Its fill and its line, for a page that shows or hides them itself.
    b.bg, b.edges = b.box.fill, { b.box.line }
    b.label = Style.Text(b, 13, "text", nil, true)
    b.label:SetPoint("CENTER")
    b.label:SetJustifyH("CENTER")
    b.label:SetText(label)
    b:SetMotionScriptsWhileDisabled(true)
    b:SetScript("OnEnter", function() b.hover = true; PaintButton(b) end)
    b:SetScript("OnLeave", function() b.hover = false; PaintButton(b) end)
    b:SetScript("OnMouseDown", function() b.down = true; PaintButton(b) end)
    b:SetScript("OnMouseUp", function() b.down = false; PaintButton(b) end)
    b:SetScript("OnEnable", PaintButton)
    b:SetScript("OnDisable", PaintButton)
    function b:SetLabel(text) self.label:SetText(text) end
    function b:SetKind(kind)
        self.kind = kind
        PaintButton(self)
    end
    function b:SetTone(tone)
        self.tone = tone
        PaintButton(self)
    end
    function b:SetSelected(on)
        self.selected = on and true or false
        PaintButton(self)
    end
    PaintButton(b)
    return b
end

-- A page's tabs, as one long pill: a segment for each choice, the chosen one
-- lit. `items` is a list of { key, label }; onPick(key) is called when one
-- is clicked. Pick(key) marks one as chosen without calling it. Set(key,
-- words, n, hot) changes a segment's words (nil keeps them) and the number
-- in a small pill after them: nil for none, `hot` for a gold one, a number
-- that waits on you. With `width` the segments share that much evenly, else
-- each is as wide as what it says; `small` is the size for a narrow window.
function Style.Tabs(parent, items, onPick, width, small)
    local bar = CreateFrame("Frame", nil, parent)
    local high, pad, badgeHigh = small and 20 or 24, small and 10 or 16, small and 14 or 18
    bar:SetHeight(high + 6)
    Style.PillBox(bar, "titleBar", "line")
    bar.buttons, bar.byKey = {}, {}
    local function Paint(b)
        local lit = b.selected or b.hover
        b.box.line:SetShown(b.selected == true)
        b.box.fill:SetShown(b.selected == true)
        b.label:SetTextColor(Style.Color(lit and "text" or "secondary"))
    end
    for i, item in ipairs(items) do
        local b = CreateFrame("Button", nil, bar)
        b.key, b.words = item[1], item[2]
        b.box = Style.PillBox(b, "wellHover", "lineStrong")
        b.label = Style.Text(b, small and 12 or 13, "secondary", nil, true)
        b.label:SetText(item[2])
        b.badge = CreateFrame("Frame", nil, b)
        b.badge:SetHeight(badgeHigh)
        b.badge:SetPoint("LEFT", b.label, "RIGHT", 6, 0)
        b.badge.fill = Style.Pill(b.badge, nil, "line")
        b.count = Style.Text(b.badge, small and 10 or 11, "secondary", nil, true)
        b.count:SetPoint("CENTER")
        b.badge:Hide()
        b:SetScript("OnClick", function()
            bar:Pick(b.key)
            if onPick then onPick(b.key) end
        end)
        b:SetScript("OnEnter", function() b.hover = true; Paint(b) end)
        b:SetScript("OnLeave", function() b.hover = false; Paint(b) end)
        bar.buttons[i], bar.byKey[b.key] = b, b
    end
    -- Each segment's words, and its number, in the middle of it.
    function bar:Layout()
        local x = 3
        local each = width and math.floor((width - 6 - (#self.buttons - 1) * 2) / #self.buttons)
        for _, b in ipairs(self.buttons) do
            b:SetShown(not b.gone)
            if not b.gone then
                local inner = Style.Wide(b.label, #b.words * (small and 7 or 8))
                if b.n then inner = inner + 6 + b.badgeWide end
                local wide = each or (inner + pad * 2)
                b:SetSize(wide, high)
                b:ClearAllPoints()
                b:SetPoint("LEFT", x, 0)
                b.label:ClearAllPoints()
                b.label:SetPoint("LEFT", math.floor((wide - inner) / 2), 0)
                x = x + wide + 2
            end
        end
        self:SetWidth(x + 1)
    end
    -- A tab that isn't for what's shown is left out, and the rest close up.
    function bar:Shown(key, shown)
        local b = self.byKey[key]
        if (b.gone or false) == (not shown) then return end
        b.gone = not shown
        self:Layout()
    end
    function bar:Set(key, words, n, hot)
        local b = self.byKey[key]
        if words then
            b.words = words
            b.label:SetText(words)
        end
        b.n = n
        b.badge:SetShown(n ~= nil)
        if n then
            b.count:SetText(n)
            b.count:SetTextColor(Style.Color(hot and "onGold" or "secondary"))
            b.badge.fill:Paint(hot and "gold" or "line")
            b.badgeWide = math.max(badgeHigh, Style.Wide(b.count, #tostring(n) * 7) + 10)
            b.badge:SetWidth(b.badgeWide)
        end
        self:Layout()
    end
    function bar:Pick(key)
        for _, b in ipairs(self.buttons) do
            b.selected = b.key == key
            Paint(b)
        end
    end
    bar:Layout()
    bar:Pick(nil)
    return bar
end

-- A list that scrolls with the mouse wheel. A thin bar at its right shows
-- where it is whenever there's more than fits, and follows by itself as the
-- list grows, shrinks or moves. Returns the scroll frame, to place, and the
-- frame to put the rows in: `childWidth` wide (the list's own width when not
-- given; narrower leaves the bar a gutter). The bar sits `barX` to the right
-- of the list's edge, and a turn of the wheel moves the list `step` pixels.
function Style.Scroller(parent, width, height, childWidth, barX, step)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetSize(width, height)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(childWidth or width, 1)
    scroll:SetScrollChild(child)
    -- The bar belongs to the parent, so it can sit past the list's edge.
    local bar = parent:CreateTexture(nil, "OVERLAY")
    bar:SetColorTexture(Style.Color("thumb"))
    bar:SetWidth(3)
    bar:Hide()
    function scroll:Place()
        local range, h = self:GetVerticalScrollRange() or 0, self:GetHeight()
        local show = range > 0.5 and self:IsVisible()
        bar:SetShown(show)
        if not show then return end
        local size = math.max(24, h * h / (h + range))
        local at = math.max(0, math.min(1, (self:GetVerticalScroll() or 0) / range))
        bar:SetHeight(size)
        bar:ClearAllPoints()
        bar:SetPoint("TOPRIGHT", self, "TOPRIGHT", barX or 0, -(h - size) * at)
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local target = self:GetVerticalScroll() - delta * (step or 60)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), target)))
        self:Place()
    end)
    -- The list got longer or shorter: keep it in range, and move the bar.
    scroll:SetScript("OnScrollRangeChanged", function(self)
        local range = self:GetVerticalScrollRange() or 0
        if (self:GetVerticalScroll() or 0) > range then self:SetVerticalScroll(range) end
        self:Place()
    end)
    scroll:SetScript("OnVerticalScroll", function(self) self:Place() end)
    scroll:SetScript("OnShow", function(self) self:Place() end)
    scroll:SetScript("OnHide", function(self) self:Place() end)
    return scroll, child
end

-- A close cross for a title bar, drawn from two thin strokes.
function Style.CloseButton(parent, size, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local strokes = {}
    for i, angle in ipairs({ math.rad(45), math.rad(-45) }) do
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetSize(14, 1.5)
        t:SetPoint("CENTER")
        t:SetColorTexture(Style.Color("muted"))
        t:SetRotation(angle)
        strokes[i] = t
    end
    local function Paint(colorKey)
        for _, t in ipairs(strokes) do t:SetColorTexture(Style.Color(colorKey)) end
    end
    b:SetScript("OnEnter", function() Paint("text") end)
    b:SetScript("OnLeave", function() Paint("muted") end)
    b:SetScript("OnClick", onClick)
    return b
end

-- A text box in a well: click anywhere on the well to type, Escape to stop.
-- The box is returned; its well (to place it) is box.well.
function Style.Field(parent, width, numeric)
    local well = CreateFrame("Frame", nil, parent)
    well:SetSize(width, 26)
    Style.Box(well, 5, "well", "lineStrong")
    local e = CreateFrame("EditBox", nil, well)
    e:SetPoint("TOPLEFT", 8, 0)
    e:SetPoint("BOTTOMRIGHT", -8, 0)
    e:SetAutoFocus(false)
    e:SetFont(Style.font, 12, "")
    e:SetTextColor(Style.Color("text"))
    if numeric then e:SetNumeric(true); e:SetMaxLetters(3); e:SetJustifyH("CENTER") end
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    well:EnableMouse(true)
    well:SetScript("OnMouseDown", function() e:SetFocus() end)
    e.well = well
    return e
end

-- A gold-edged banner high in the middle of the screen for news worth
-- stopping for (a profession rank to train, a starred item dropping): the
-- news in gold, a line under it. A click runs onClick and closes it; it
-- fades after a while.
local banner
local BANNER_SHOW, BANNER_FADE = 10, 1
function Style.Banner(title, line, onClick)
    if not banner then
        banner = CreateFrame("Button", "jsalUIBanner", UIParent)
        banner:SetSize(440, 64)
        banner:SetPoint("TOP", UIParent, "TOP", 0, -290)
        banner:SetFrameStrata("HIGH")
        Style.Fill(banner, "window")
        Style.Border(banner, "gold")
        Style.Shadow(banner)
        Style.Opening(banner, 16)
        local mark = banner:CreateTexture(nil, "ARTWORK")
        mark:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Logo")
        mark:SetSize(36, 36)
        mark:SetPoint("LEFT", 14, 0)
        banner.title = Style.Text(banner, 16, "gold", nil, true)
        banner.title:SetPoint("TOPLEFT", mark, "TOPRIGHT", 12, 0)
        banner.title:SetPoint("RIGHT", -14, 0)
        banner.title:SetWordWrap(false)
        banner.line = Style.Text(banner, 12, "text")
        banner.line:SetPoint("BOTTOMLEFT", mark, "BOTTOMRIGHT", 12, 0)
        banner.line:SetPoint("RIGHT", -14, 0)
        banner.line:SetWordWrap(false)
        banner:SetScript("OnUpdate", function(self, elapsed)
            self.age = (self.age or 0) + elapsed
            if self.age >= BANNER_SHOW + BANNER_FADE then
                self:Hide()
            elseif self.age > BANNER_SHOW then
                self:SetAlpha(1 - (self.age - BANNER_SHOW) / BANNER_FADE)
            end
        end)
    end
    banner.title:SetText(title)
    banner.line:SetText(line)
    banner:SetScript("OnClick", function(self)
        if onClick then onClick() end
        self:Hide()
    end)
    banner.age = 0
    banner:SetAlpha(1)
    banner:Show()
    return banner
end

-- A window of its own: a title bar to drag it by, a close cross, and Escape
-- closes it like the game's own windows.
function Style.Panel(name, width, height, title)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(width, height)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:Hide()
    -- Kept on the frame, for a window that can do without them (the
    -- companion out of its window hides all three).
    local box = Style.Box(f, 6, "window", "lineStrong")
    f.fill, f.edges = box.fill, { box.line }
    f.shadow = Style.Shadow(f)
    Style.Opening(f, -8)
    tinsert(UISpecialFrames, name)

    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(32)
    Style.Cap(bar, 6, "titleBar")
    Style.Rule(bar, "BOTTOM", "line")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() f:StartMoving() end)
    bar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    f.bar = bar

    -- Windows outside the dashboard: jsal.io's j mark, then the window's
    -- name after a thin divider. Only the dashboard spells out jsal.ui.
    local mark = bar:CreateTexture(nil, "ARTWORK")
    mark:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Logo")
    mark:SetSize(18, 18)
    mark:SetPoint("LEFT", 12, 0)
    local divider = bar:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(Style.Color("lineStrong"))
    divider:SetSize(Compat.OnePixel(bar), 16)
    divider:SetPoint("LEFT", mark, "RIGHT", 10, 0)
    Compat.Crisp(divider)
    f.title = Style.Text(bar, 13, "text", nil, true)
    f.title:SetPoint("TOP", bar, "TOP", 0, 0)
    f.title:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
    f.title:SetPoint("LEFT", divider, "RIGHT", 10, 0)
    f.title:SetPoint("RIGHT", bar, "RIGHT", -40, 0)
    f.title:SetJustifyV("MIDDLE")
    f.title:SetText(title)
    Style.CloseButton(bar, 32, function() f:Hide() end):SetPoint("TOPRIGHT")
    return f
end

-- A card: a well with a line around it, its corners a little round, and a
-- small heading in its corner.
function Style.Card(parent, heading)
    local card = CreateFrame("Frame", nil, parent)
    card.box = Style.Box(card, 6, "well", "cardLine")
    card.heading = Style.Text(card, 11, "muted", nil, true)
    card.heading:SetPoint("TOPLEFT", 12, -10)
    card.heading:SetText(heading:upper())
    return card
end

-- A tag: a small pill after a name, as wide as its words (`wide`). Its
-- tone: gold (or true) is gold with dark words, for what to do or what's
-- best; "green" has green words, for what's good for you, and "red" red
-- ones, for what's worse; none is a plain
-- fill, for what a thing is. Say(text) changes its words, Tone(tone) its
-- colours. `small` is the size for a row in a dense list.
local TAG_TONES = { gold = { "gold", "onGold" }, green = { "line", "green" }, red = { "line", "red" }, plain = { "line", "secondary" } }

function Style.Tag(parent, words, tone, small)
    local t = CreateFrame("Frame", nil, parent)
    t:SetHeight(small and 16 or 20)
    t.fill = Style.Pill(t, nil, "line")
    t.text = Style.Text(t, small and 10 or 11, "secondary", nil, true)
    t.text:SetPoint("CENTER")
    function t:Say(text)
        self.text:SetText(text)
        self.wide = Style.Wide(self.text, #text * (small and 5.2 or 6)) + (small and 14 or 18)
        self:SetWidth(self.wide)
    end
    function t:Tone(to)
        local c = TAG_TONES[to == true and "gold" or to or "plain"]
        self.fill:Paint(c[1])
        self.text:SetTextColor(Style.Color(c[2]))
    end
    t:Tone(tone)
    t:Say(words or "")
    return t
end

-- An on/off switch, a pill with a round knob: gold when on. A `quiet` one
-- is dim gold with a gold knob when on, for a page of many switches, where
-- bright ones, all on, are a wall of gold.
function Style.Switch(parent, onChange, quiet)
    local s = CreateFrame("Button", nil, parent)
    s:SetSize(36, 20)
    s.box = Style.PillBox(s, "well", "lineStrong")
    s.knob = Style.Pill(s, 7, "muted", "ARTWORK")
    s.knob:ClearAllPoints()
    s.knob:SetSize(14, 14)
    function s:SetOn(on)
        self.on = on and true or false
        self.knob:ClearAllPoints()
        if self.on then
            self.knob:SetPoint("RIGHT", -3, 0)
            self.knob:Paint(quiet and "gold" or "onGold")
            self.box:Paint(quiet and "needFill" or "gold", quiet and "needFill" or "gold")
        else
            self.knob:SetPoint("LEFT", 3, 0)
            self.knob:Paint("muted")
            self.box:Paint("well", "lineStrong")
        end
    end
    s:SetScript("OnClick", function(self)
        self:SetOn(not self.on)
        if onChange then onChange(self.on) end
    end)
    s:SetOn(false)
    return s
end
