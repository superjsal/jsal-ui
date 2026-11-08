-- The game's menu bar (character, spellbook, quest log and the rest) in
-- jsal.ui's look, matching the quick buttons: each button a dark tile with a
-- 1px line and a gold icon, in a dark frame. They stay the game's own buttons:
-- what a click opens, the tooltips, the greyed-out state and the alerts are
-- all the game's. Only how they look changes: the game's pictures are faded
-- (never removed or moved), and jsal.ui's tile sits over each button. An
-- alert the game would flash shows as a gold dot, as on the quick buttons.
local addonName, ns = ...
local Style = ns.Style

local MenuBar = ns.NewModule("menubar", {
    title = "Menu bar look",
    note = "The game's menu bar (character, spellbook, quest log and the rest) drawn like the quick buttons: gold icons on dark tiles. Turning it off takes a /reload.",
})
ns.MenuBar = MenuBar

local ICONS = "Interface\\AddOns\\" .. addonName .. "\\Media\\Icons\\Menu\\"

-- Each of the game's buttons and the icon jsal.ui draws on it. A button not
-- listed keeps the game's look.
MenuBar.ICONS = {
    CharacterMicroButton = "character",
    ProfessionMicroButton = "professions",
    SpellbookMicroButton = "spellbook",
    PlayerSpellsMicroButton = "spellbook",
    TalentMicroButton = "talents",
    LegacyMicroButton = "legacy",
    AchievementMicroButton = "legacy",
    QuestLogMicroButton = "quests",
    GuildMicroButton = "guild",
    LFDMicroButton = "group",
    CollectionsMicroButton = "collections",
    StoreMicroButton = "shop",
    HelpMicroButton = "help",
    MainMenuMicroButton = "help",
}

-- The pictures the game puts on a button besides its own four states: the
-- tile behind, the portrait, the guild emblem, the latency bar, the alert
-- glows. Faded to nothing; the game keeps showing and hiding them as before.
local ART = {
    "Background", "PushedBackground", "Shadow", "Portrait", "PushedShadow", "FlashContent",
    "Emblem", "HighlightEmblem", "MainMenuBarPerformanceBar", "NotificationOverlay",
}

-- jsal.ui's parts of each button, kept here rather than on the game's frames.
local skins = {}

local function Fade(button)
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local texture = button[get] and button[get](button)
        if texture then texture:SetAlpha(0) end
    end
    for _, key in ipairs(ART) do
        local region = button[key]
        if region and region.SetAlpha then region:SetAlpha(0) end
    end
    -- The alert border is flashed by changing its alpha, so it loses its
    -- picture instead; the gold dot stands in for it.
    if button.FlashBorder and button.FlashBorder.SetTexture then button.FlashBorder:SetTexture(nil) end
end

-- At rest a dark tile; under the pointer a step lighter with a gold line;
-- while its window is open, a gold line. A button the game has switched
-- off has a dim icon.
local function Paint(button)
    local s = skins[button]
    if not s then return end
    Fade(button)
    local enabled = button:IsEnabled()
    local open = button:GetButtonState() == "PUSHED"
    s.fill:SetColorTexture(Style.Color((s.hover and enabled) and "wellHover" or "well"))
    Style.SetBorder(s.edges, ((s.hover and enabled) or open) and "gold" or "lineStrong")
    if enabled then
        s.icon:SetVertexColor(Style.Color("gold"))
    else
        local r, g, b = Style.Color("muted")
        s.icon:SetVertexColor(r, g, b, 0.45)
    end
end

local function Alerting(button)
    local flash = button.FlashBorder
    local note = button.NotificationOverlay
    return (flash and flash:IsShown()) or (note and note:IsShown()) or false
end

local function Skin(button, icon)
    if skins[button] then return end
    local s = {}
    local tile = CreateFrame("Frame", nil, button)
    tile:SetPoint("CENTER")
    s.tile = tile
    s.fill = Style.Fill(tile, "well")
    s.edges = Style.Border(tile, "lineStrong")
    s.icon = tile:CreateTexture(nil, "ARTWORK")
    s.icon:SetTexture(ICONS .. icon)
    s.icon:SetPoint("CENTER")
    s.dot = tile:CreateTexture(nil, "OVERLAY")
    s.dot:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\Chess\\dot")
    s.dot:SetVertexColor(Style.Color("gold"))
    s.dot:SetSize(9, 9)
    s.dot:SetPoint("TOPRIGHT", 3, 3)
    s.dot:Hide()
    -- A square tile, 2px in from the button's sides so neighbours have a gap.
    local function Fit()
        local side = math.max(16, math.min(button:GetWidth(), button:GetHeight()) - 4)
        tile:SetSize(side, side)
        s.icon:SetSize(side * 0.62, side * 0.62)
    end
    Fit()
    skins[button] = s
    button:HookScript("OnSizeChanged", Fit)
    button:HookScript("OnEnter", function(self) s.hover = true; Paint(self) end)
    button:HookScript("OnLeave", function(self) s.hover = false; Paint(self) end)
    button:HookScript("OnEnable", Paint)
    button:HookScript("OnDisable", Paint)
    button:HookScript("OnShow", Paint)
    for _, method in ipairs({ "SetPushed", "SetNormal" }) do
        if type(button[method]) == "function" then hooksecurefunc(button, method, Paint) end
    end
    Paint(button)
end

-- The bar's own frame, as the quick buttons have: the game's frame art is
-- faded and jsal.ui's dark frame drawn just outside the buttons, under them.
local back
local function Frame()
    local menu = MicroMenu
    if not menu or back then return end
    if menu.BackgroundArt then menu.BackgroundArt:SetAlpha(0) end
    if menu.BorderArt then menu.BorderArt:SetAlpha(0) end
    back = CreateFrame("Frame", nil, menu)
    back:SetPoint("TOPLEFT", -4, 4)
    back:SetPoint("BOTTOMRIGHT", 4, -4)
    back:SetFrameLevel(math.max(0, menu:GetFrameLevel() - 1))
    Style.Fill(back, "window")
    Style.Border(back, "lineStrong")
    Style.Shadow(back, 10)
end

function MenuBar.PaintAll()
    for button in pairs(skins) do Paint(button) end
end

function MenuBar:OnEnable()
    local found = 0
    for name, icon in pairs(MenuBar.ICONS) do
        local button = _G[name]
        if type(button) == "table" and button.GetNormalTexture then
            Skin(button, icon)
            found = found + 1
        end
    end
    if found == 0 then return end
    Frame()
    -- The game repaints its buttons as windows open and close and as the
    -- player's level unlocks them; jsal.ui repaints after it.
    if type(UpdateMicroButtons) == "function" then hooksecurefunc("UpdateMicroButtons", MenuBar.PaintAll) end
    -- Alerts, checked twice a second.
    local driver = self.driver or CreateFrame("Frame")
    self.driver = driver
    local wait = 0
    driver:SetScript("OnUpdate", ns.Safe(self, function(_, elapsed)
        wait = wait + elapsed
        if wait < 0.5 then return end
        wait = 0
        for button, s in pairs(skins) do s.dot:SetShown(button:IsShown() and Alerting(button)) end
    end))
end

function MenuBar:OnDisable()
    if self.driver then self.driver:SetScript("OnUpdate", nil) end
end
