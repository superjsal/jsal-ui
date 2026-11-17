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
    goldHover = "ecbe62",
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
local RADII = { [4] = true, [5] = true, [6] = true, [7] = true, [9] = true, [10] = true, [11] = true, [12] = true, [13] = true }

function Style.Rounded()
    return Enum ~= nil and Enum.UITextureSliceMode ~= nil and not ns.needsRestart
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
    function t:Paint(key, alpha)
        local r, g, b = Style.Color(key)
        if self.round then self:SetVertexColor(r, g, b, alpha or 1) else self:SetColorTexture(r, g, b, alpha or 1) end
    end
    t:Paint(colorKey or "well")
    return t
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
    function box:Paint(fill, line)
        if fill then self.fill:Paint(fill) end
        if line then self.line:Paint(line) end
    end
    return box
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
local OPEN_TIME = 0.14

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
    return group
end

-- A faint light over a row or card under the pointer, so it's clear what a
-- click or a tooltip will come from. It reaches `pad` past the row's sides
-- for rows whose icon sits on their edge. Call it after the row's own
-- OnEnter and OnLeave are set: it adds to them.
function Style.Hover(frame, pad)
    pad = pad or 0
    local glow = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
    glow:SetPoint("TOPLEFT", -pad, 0)
    glow:SetPoint("BOTTOMRIGHT", pad, 0)
    local r, g, b = Style.Color("text")
    glow:SetColorTexture(r, g, b, 0.06)
    glow:Hide()
    frame:HookScript("OnEnter", function() glow:Show() end)
    frame:HookScript("OnLeave", function() glow:Hide() end)
    return glow
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
-- the light under the pointer. `more`, when given, adds lines of its own.
function Style.ItemTip(frame, more)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.item then GameTooltip:SetItemByID(self.item) elseif self.spell then GameTooltip:SetSpellByID(self.spell) end
        if more then more(self) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Style.Hover(frame, 6)
end

-- Buttons, with softly rounded corners. "primary" is gold with dark text,
-- for the one main action on a page; "plain" is a well with a line around
-- it. Under the pointer both light up a step, and a plain one darkens while
-- it's pressed.
-- "tab" is one of a row of choices (a page's tabs, a filter, a spec), a pill:
-- the chosen one, set with SetSelected, has gold words on a dim gold fill in
-- a gold line, so a gold fill stays the mark of the main action.
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
    elseif b.kind == "primary" and enabled then
        fill = (b.hover and not b.down) and "goldHover" or "gold"
        line, text = fill, "onGold"
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
    b.box = Style.Box(b, b.kind == "tab" and 10 or 5, "well", "lineStrong")
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
    f.fill = Style.Fill(f, "window")
    f.edges = Style.Border(f, "lineStrong")
    f.shadow = Style.Shadow(f)
    Style.Opening(f, -8)
    tinsert(UISpecialFrames, name)

    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(32)
    Style.Fill(bar, "titleBar")
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

-- A tag: a small pill after a name, as wide as its words. Gold with dark
-- words for what to do or what's best, a plain fill for what a thing is.
function Style.Tag(parent, words, gold)
    local t = CreateFrame("Frame", nil, parent)
    t:SetHeight(20)
    t.fill = Style.Round(t, 10, gold and "gold" or "line")
    t.text = Style.Text(t, 11, gold and "onGold" or "secondary", nil, true)
    t.text:SetPoint("CENTER")
    function t:Say(text)
        self.text:SetText(text)
        self:SetWidth(Style.Wide(self.text, #text * 6) + 18)
    end
    t:Say(words or "")
    return t
end

-- An on/off switch, a pill with a round knob: gold when on.
function Style.Switch(parent, onChange)
    local s = CreateFrame("Button", nil, parent)
    s:SetSize(36, 20)
    s.box = Style.Box(s, 10, "well", "lineStrong")
    s.knob = Style.Round(s, 7, "muted", "ARTWORK")
    s.knob:ClearAllPoints()
    s.knob:SetSize(14, 14)
    function s:SetOn(on)
        self.on = on and true or false
        self.knob:ClearAllPoints()
        if self.on then
            self.knob:SetPoint("RIGHT", -3, 0)
            self.knob:Paint("onGold")
            self.box:Paint("gold", "gold")
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
