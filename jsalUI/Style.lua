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
    line = "2a2e38",
    lineStrong = "3d424e",
    text = "ece6d6",
    muted = "9a9688",
    gold = "e3b04b",
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

-- Buttons. "primary" is gold with dark text, for the one main action on a
-- page; "plain" is a well with a line around it.
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
        b.bg:SetColorTexture(Style.Color("gold"))
        b.label:SetTextColor(Style.Color("onGold"))
        Style.SetBorder(b.edges, b.hover and "text" or "gold")
    else
        b.bg:SetColorTexture(Style.Color("well"))
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

    -- jsal.io's mark and the wordmark, as on the dashboard, then the
    -- window's name after a thin divider.
    local mark = bar:CreateTexture(nil, "ARTWORK")
    mark:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Logo")
    mark:SetSize(18, 18)
    mark:SetPoint("LEFT", 12, 0)
    local word = Style.Wordmark(bar, 15)
    word:SetPoint("LEFT", mark, "RIGHT", 8, 0)
    local divider = bar:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(Style.Color("lineStrong"))
    divider:SetSize(Compat.OnePixel(bar), 16)
    divider:SetPoint("LEFT", word, "RIGHT", 12, 0)
    Compat.Crisp(divider)
    f.title = Style.Text(bar, 13, "text", nil, true)
    f.title:SetPoint("TOP", bar, "TOP", 0, 0)
    f.title:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
    f.title:SetPoint("LEFT", divider, "RIGHT", 12, 0)
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
