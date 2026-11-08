-- The look every jsal.ui window shares: the jsal.io dark colours, flat fills
-- and 1px lines, all things the game draws crisply at any scale.
local addonName, ns = ...
local Compat = ns.Compat

local Style = {}
ns.Style = Style

local function Hex(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

Style.colors = {}
for key, hex in pairs({
    window = "191c23",
    titleBar = "15181e",
    well = "22262f",
    wellHover = "2b303b",
    line = "2a2e38",
    lineStrong = "3d424e",
    text = "ece6d6",
    muted = "9a9688",
    gold = "e3b04b",
    goldHover = "ecbe62",
    onGold = "16130c",
    blue = "2f5db5",
    white = "ffffff",
    -- Daily Word's tiles, in the green, yellow and grey word-game players know.
    wordGreen = "56944f",
    wordYellow = "c2a23d",
    wordGrey = "3a3d44",
}) do
    Style.colors[key] = { Hex(hex) }
end

function Style.Color(key)
    local c = Style.colors[key]
    return c[1], c[2], c[3]
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

function Style.Text(parent, size, colorKey, layer, bold)
    local text = parent:CreateFontString(nil, layer or "OVERLAY")
    size = size or 13
    if ns.Window and ns.Window.Contains and ns.Window.Contains(parent) then size = size + DASHBOARD_STEP end
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
        t:SetColorTexture(Style.Color(colorKey))
    end
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
    local function Piece(l, r, t, b)
        local tex = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        tex:SetTexture(SHADOW)
        tex:SetTexCoord(l, r, t, b)
        tex:SetVertexColor(0, 0, 0, SHADOW_ALPHA)
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

-- Buttons. "primary" is gold with dark text, for the one main action on a
-- page; "plain" is a well with a line around it. Under the pointer both
-- light up a step.
-- A tone overrides the kind for a game's answer buttons: "right" is gold,
-- "wrong" is dimmed.
local function PaintButton(b)
    local enabled = b:IsEnabled()
    if b.tone == "right" then
        b.bg:SetColorTexture(Style.Color("gold"))
        b.label:SetTextColor(Style.Color("onGold"))
        Style.SetBorder(b.edges, "gold")
    elseif b.tone == "wrong" then
        b.bg:SetColorTexture(Style.Color("line"))
        b.label:SetTextColor(Style.Color("muted"))
        Style.SetBorder(b.edges, "line")
    elseif b.kind == "primary" and enabled then
        b.bg:SetColorTexture(Style.Color(b.hover and "goldHover" or "gold"))
        b.label:SetTextColor(Style.Color("onGold"))
        Style.SetBorder(b.edges, b.hover and "goldHover" or "gold")
    else
        b.bg:SetColorTexture(Style.Color((enabled and b.hover) and "wellHover" or "well"))
        b.label:SetTextColor(Style.Color(enabled and "text" or "muted"))
        Style.SetBorder(b.edges, (enabled and b.hover) and "gold" or "lineStrong")
    end
end

function Style.Button(parent, label, kind, width)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 140, 28)
    b.kind = kind or "plain"
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.edges = Style.Border(b, "lineStrong")
    b.label = Style.Text(b, 13, "text", nil, true)
    b.label:SetPoint("CENTER")
    b.label:SetJustifyH("CENTER")
    b.label:SetText(label)
    b:SetMotionScriptsWhileDisabled(true)
    b:SetScript("OnEnter", function() b.hover = true; PaintButton(b) end)
    b:SetScript("OnLeave", function() b.hover = false; PaintButton(b) end)
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
    PaintButton(b)
    return b
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
    Style.Fill(well, "well")
    Style.Border(well, "lineStrong")
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
    Style.Fill(f, "window")
    Style.Border(f, "lineStrong")
    Style.Shadow(f)
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

-- A card: a well with a line around it and a small heading in its corner.
function Style.Card(parent, heading)
    local card = CreateFrame("Frame", nil, parent)
    Style.Fill(card, "well")
    Style.Border(card, "line")
    card.heading = Style.Text(card, 11, "muted", nil, true)
    card.heading:SetPoint("TOPLEFT", 12, -10)
    card.heading:SetText(heading:upper())
    return card
end

-- An on/off switch: gold when on.
function Style.Switch(parent, onChange)
    local s = CreateFrame("Button", nil, parent)
    s:SetSize(36, 20)
    s.track = Style.Fill(s, "well")
    s.edges = Style.Border(s, "lineStrong")
    s.knob = s:CreateTexture(nil, "ARTWORK")
    s.knob:SetSize(12, 12)
    function s:SetOn(on)
        self.on = on and true or false
        self.knob:ClearAllPoints()
        if self.on then
            self.knob:SetPoint("RIGHT", -4, 0)
            self.knob:SetColorTexture(Style.Color("onGold"))
            self.track:SetColorTexture(Style.Color("gold"))
            Style.SetBorder(self.edges, "gold")
        else
            self.knob:SetPoint("LEFT", 4, 0)
            self.knob:SetColorTexture(Style.Color("muted"))
            self.track:SetColorTexture(Style.Color("well"))
            Style.SetBorder(self.edges, "lineStrong")
        end
    end
    s:SetScript("OnClick", function(self)
        self:SetOn(not self.on)
        if onChange then onChange(self.on) end
    end)
    s:SetOn(false)
    return s
end
