-- Settings: a switch for each part of jsal.ui, in two columns under four
-- headings, so they all fit on one screen; hovering a part shows what it
-- does. A part with options of its own has a Settings button that opens
-- them in a small panel. A part's switch applies after a reload, since
-- modules start once, at login (addons can't reload the game themselves on
-- Forever, so the page asks for /reload); options apply at once.
local _, ns = ...
local Style, Window = ns.Style, ns.Window

local ROW_HEIGHT, COLUMN_GAP = 34, 28

-- Where each part goes. A part not listed joins the last heading.
local GROUPS = {
    { title = "GAMES", keys = { "dailyword", "iconguess", "chess", "flight", "guild" } },
    { title = "LEVELING", keys = { "talents", "trainingpanel", "levelup", "journal", "dungeons", "gear" } },
    { title = "PROFESSIONS", keys = { "professionpanel", "profwindow", "shopping", "crafters" } },
    { title = "AROUND THE UI", keys = { "launcher", "minimap", "vendor", "warnings", "waypoint", "menubar", "bagbutton", "sharedFonts" } },
}

local function Grouped()
    local placed, groups = {}, {}
    for i, group in ipairs(GROUPS) do
        local list = {}
        for _, key in ipairs(group.keys) do
            if ns.modules[key] then
                list[#list + 1] = ns.modules[key]
                placed[key] = true
            end
        end
        groups[i] = { title = group.title, modules = list }
    end
    local last = groups[#groups].modules
    for _, module in ipairs(ns.moduleOrder) do
        if not placed[module.key] then last[#last + 1] = module end
    end
    return groups
end

-- One row: a switch, then the name. Hovering shows row.title and row.note;
-- clicking the name flips the switch too, which calls row.onChange.
local function Row(parent, width)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, ROW_HEIGHT)
    row.hover = Style.Fill(row, "well")
    row.hover:Hide()
    Style.Rule(row, "BOTTOM", "line")
    row.switch = Style.Switch(row, function(on)
        if row.onChange then row.onChange(on) end
    end)
    row.switch:SetPoint("LEFT", 0, 0)
    row.name = Style.Text(row, 13, "text")
    row.name:SetPoint("LEFT", row.switch, "RIGHT", 10, 0)
    row:SetScript("OnClick", function() row.switch:Click() end)
    row:SetScript("OnEnter", function(self)
        self.hover:Show()
        if self.note and self.note ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText(self.title)
            GameTooltip:AddLine(self.note, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)
    function row:SetTitle(text)
        self.title = text
        self.name:SetText(text)
    end
    return row
end

Window.Page("settings", function(page)
    local intro = Style.Text(page, 13, "muted")
    intro:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    intro:SetWidth(Window.contentWidth - 150)
    intro:SetJustifyH("LEFT")
    intro:SetText("Turn parts of jsal.ui on or off. Changes apply after you type /reload. Hover a part to see what it does.")
    -- The guided setup, again, for anyone who skipped it or wants to start over.
    if ns.Setup then
        local again = Style.Button(page, "Set up again", "plain", 130)
        again:SetHeight(26)
        again:SetPoint("TOPRIGHT", page.heading, "BOTTOMLEFT", Window.contentWidth, -4)
        again:SetScript("OnClick", function()
            ns.Window.Toggle()
            ns.Setup.Open()
        end)
    end

    local width = math.floor((Window.contentWidth - COLUMN_GAP) / 2)

    ---------------------------------------------------------------------
    -- The options panel: one part's own switches, opened from its
    -- Settings button, just below it. A click anywhere else on the page
    -- closes it.
    ---------------------------------------------------------------------
    local panel = CreateFrame("Frame", nil, page)
    panel:SetWidth(width)
    panel:SetFrameLevel(page:GetFrameLevel() + 20)
    panel:EnableMouse(true)
    Style.Fill(panel, "window")
    Style.Border(panel, "gold")
    Style.Shadow(panel, 12)
    panel:Hide()
    local catcher = CreateFrame("Button", nil, page)
    catcher:SetAllPoints(page)
    catcher:SetFrameLevel(page:GetFrameLevel() + 19)
    catcher:Hide()
    panel.title = Style.Text(panel, 14, "text", nil, true)
    panel.title:SetPoint("TOPLEFT", 12, -12)
    local optionRows, openButton = {}, nil

    local function ClosePanel()
        panel:Hide()
        catcher:Hide()
        if openButton then openButton:SetKind("plain") end
        openButton = nil
    end
    catcher:SetScript("OnClick", ClosePanel)
    Style.CloseButton(panel, 24, ClosePanel):SetPoint("TOPRIGHT", -6, -6)
    page:HookScript("OnHide", ClosePanel)

    local function OpenPanel(module, button)
        if openButton == button then return ClosePanel() end
        ClosePanel()
        panel.title:SetText(module.title)
        for _, r in ipairs(optionRows) do r:Hide() end
        for i, option in ipairs(module.options) do
            local r = optionRows[i] or Row(panel, width - 24)
            optionRows[i] = r
            r:SetTitle(option.title)
            r.note = option.note
            r.onChange = function(on)
                ns.SetOption(module.key, option.key, on)
                -- A part that redraws on an option change (the quick bar) does it now.
                if module.running and type(module.OnOption) == "function" then
                    xpcall(function() module:OnOption(option.key, on) end, ns.Report)
                end
            end
            r.switch:SetOn(ns.OptionOn(module.key, option.key))
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 12, -38 - (i - 1) * ROW_HEIGHT)
            r:Show()
        end
        panel:SetHeight(38 + #module.options * ROW_HEIGHT + 10)
        panel:ClearAllPoints()
        panel:SetPoint("TOPRIGHT", button:GetParent(), "BOTTOMRIGHT", 0, -2)
        openButton = button
        button:SetKind("primary")
        catcher:Show()
        panel:Show()
    end

    ---------------------------------------------------------------------
    -- The parts, two headings to a column.
    ---------------------------------------------------------------------
    local pending = Style.Text(page, 13, "gold", nil, true)
    pending:SetText("Type /reload to apply your changes.")
    pending:Hide()

    local rows, depth = {}, { 0, 0 }
    for i, group in ipairs(Grouped()) do
        local column = i <= 2 and 1 or 2
        local x = (column - 1) * (width + COLUMN_GAP)
        local y = depth[column] - (depth[column] < 0 and 16 or 0)
        local heading = Style.Text(page, 11, "gold", nil, true)
        heading:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", x, y - 16)
        heading:SetText(group.title)
        y = y - 34
        for _, module in ipairs(group.modules) do
            local row = Row(page, width)
            row:SetTitle(module.title)
            row:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", x, y)
            row.module = module
            row.onChange = function(on)
                ns.db.modules[module.key] = on
                pending:Show()
            end
            if module.options and #module.options > 0 then
                row.settings = Style.Button(row, "Settings", "plain", 76)
                row.settings:SetHeight(22)
                row.settings:SetPoint("RIGHT", 0, 0)
                row.settings:SetScript("OnClick", function(self) OpenPanel(module, self) end)
            end
            rows[#rows + 1] = row
            y = y - ROW_HEIGHT
        end
        depth[column] = y
    end
    pending:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, math.min(depth[1], depth[2]) - 20)

    local footer = Style.Text(page, 11, "muted")
    footer:SetPoint("BOTTOMLEFT")
    footer:SetText("jsal.ui " .. ns.version .. ", free from jsal.io")

    page.Refresh = function()
        for _, row in ipairs(rows) do
            local module = row.module
            row.switch:SetOn(ns.ModuleWanted(module))
            if module.failed then
                row.note = "Turned off after an error this session. BugSack has the details."
                row.name:SetTextColor(Style.Color("muted"))
            else
                row.note = module.note or ""
                row.name:SetTextColor(Style.Color("text"))
            end
        end
    end
end)
