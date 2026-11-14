-- Settings: a switch for each part of jsal.ui, one group to a tab, each part
-- with what it does written under its name. A part with options of its own
-- has an Options button that opens them under it. The box at the top finds
-- a part or an option in any group. A part's switch applies after a reload,
-- since modules start once, at login (addons can't reload the game
-- themselves on Forever): a bar at the bottom says which changes are
-- waiting, with a button to undo them and one to reload. Options apply at
-- once.
local _, ns = ...
local Style, Window = ns.Style, ns.Window

local ROW_H, OPTION_H, INSET = 62, 50, 18
local LIST_TOP, BAR_H = 84, 52
local SWITCH_W, OPTIONS_W = 36, 86

-- Where each part goes. A part not listed joins the last group.
local GROUPS = {
    { title = "Games", width = 100, keys = { "dailyword", "iconguess", "chess", "flight", "guild", "pet" } },
    { title = "Leveling", width = 110, keys = { "talents", "trainingpanel", "tametip", "nextlevel", "levelup", "journal", "dungeons", "gear", "questtags" } },
    { title = "Professions", width = 130, keys = { "professionpanel", "profwindow", "shopping", "crafters" } },
    { title = "Around the UI", width = 150, keys = { "launcher", "minimap", "vendor", "warnings", "waypoint", "menubar", "bagbutton", "rangecheck", "foodtile", "sharedFonts" } },
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
        groups[i] = { title = group.title, width = group.width, modules = list }
    end
    local last = groups[#groups].modules
    for _, module in ipairs(ns.moduleOrder) do
        if not placed[module.key] then last[#last + 1] = module end
    end
    return groups
end

-- Whether a part's switch differs from how the game loaded it.
local function Changed(module)
    local was = module.wantedAtStart
    return was ~= nil and ns.ModuleWanted(module) ~= was
end

-- Whether a part, or one of its options, has the words typed in the box.
local function Matches(module, words)
    local text = (module.title or "") .. " " .. (module.note or "")
    for _, option in ipairs(module.options or {}) do
        text = text .. " " .. (option.title or "") .. " " .. (option.note or "")
    end
    return text:lower():find(words, 1, true) ~= nil
end

-- One row: a name with what it does under it (two lines at most; hovering
-- the row shows the whole of it when it was cut), and a switch at the right.
-- Clicking anywhere on the row flips the switch, which calls row.onChange.
-- A small row is one of a part's options, set in under it on a darker fill.
local function Row(parent, width, small)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, small and OPTION_H or ROW_H)
    if small then
        local fill = row:CreateTexture(nil, "BACKGROUND", nil, -1)
        fill:SetAllPoints()
        fill:SetColorTexture(Style.Color("titleBar"))
    end
    row.hover = Style.Fill(row, "well")
    row.hover:Hide()
    Style.Rule(row, "BOTTOM", "line")
    row.switch = Style.Switch(row, function(on)
        if row.onChange then row.onChange(on) end
    end)
    row.switch:SetPoint("RIGHT", small and -INSET or 0, 0)
    row.name = Style.Text(row, small and 13 or 14, "text", nil, not small)
    row.name:SetPoint("TOPLEFT", small and INSET or 0, small and -8 or -10)
    row.note = Style.Text(row, 12, "muted")
    row.note:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.note:SetWidth(width - SWITCH_W - 20 - (small and INSET * 2 or OPTIONS_W + 12))
    row.note:SetJustifyH("LEFT")
    if row.note.SetMaxLines then row.note:SetMaxLines(2) end
    row:SetScript("OnClick", function() row.switch:Click() end)
    row:SetScript("OnEnter", function(self)
        self.hover:Show()
        local cut = self.note.IsTruncated and self.note:IsTruncated()
        if cut and self.full and self.full ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText(self.title)
            GameTooltip:AddLine(self.full, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)
    function row:Set(title, note)
        self.title, self.full = title, note
        self.name:SetText(title)
        self.note:SetText(note or "")
    end
    return row
end

Window.Page("settings", function(page)
    local width, height = Window.contentWidth, Window.contentHeight
    local rowW = width - 12
    local groups = Grouped()
    local chosen, openKey, words = 1, nil, ""
    local Paint

    ---------------------------------------------------------------------
    -- The top: a box to find a part in, the guided setup again, and a tab
    -- for each group.
    ---------------------------------------------------------------------
    local find = Style.Field(page, 300)
    find.well:SetHeight(28)
    find.well:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    find.hint = Style.Text(find.well, 12, "muted")
    find.hint:SetPoint("LEFT", 8, 0)
    find.hint:SetText("Find a part or option")
    find:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        words = strtrim(text):lower()
        find.hint:SetShown(text == "")
        if Paint then Paint() end
    end)
    find:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    page:HookScript("OnHide", function() find:ClearFocus() end)

    -- The guided setup, again, for anyone who skipped it or wants to start over.
    if ns.Setup then
        local again = Style.Button(page, "Set up again", "plain", 130)
        again:SetHeight(28)
        again:SetPoint("TOPRIGHT", page.heading, "BOTTOMLEFT", width, -8)
        again:SetScript("OnClick", function()
            ns.Window.Toggle()
            ns.Setup.Open()
        end)
        -- And jsal.ui's own Unlock Mode, to move its pieces (/jsal unlock).
        if ns.Unlock and ns.Unlock.Open then
            local move = Style.Button(page, "Move pieces", "plain", 130)
            move:SetHeight(28)
            move:SetPoint("TOPRIGHT", again, "TOPLEFT", -8, 0)
            move:SetScript("OnClick", function()
                ns.Window.Toggle()
                ns.Unlock.Open()
            end)
        end
    end

    local tabs, x = {}, 0
    for i, group in ipairs(groups) do
        local b = Style.Button(page, "", "tab", group.width)
        b:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", x, -(8 + 28 + 12))
        b:SetLabel(("%s  |cff9a9688%d|r"):format(group.title, #group.modules))
        b:SetScript("OnClick", function()
            chosen, openKey = i, nil
            find:SetText("")
            find:ClearFocus()
            Paint()
        end)
        tabs[i] = b
        x = x + group.width + 6
    end

    ---------------------------------------------------------------------
    -- The parts, in a list that scrolls when a part's options are open
    -- and there's more than fits.
    ---------------------------------------------------------------------
    local scroll, list = Style.Scroller(page, width, height - LIST_TOP - BAR_H - 12, rowW)
    scroll:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -(8 + LIST_TOP))
    local none = Style.Text(list, 13, "muted")
    none:SetPoint("TOPLEFT", 0, -14)
    none:SetWidth(rowW)

    local rows, optionRows = {}, {}
    local function PartRow(i)
        if rows[i] then return rows[i] end
        local row = Row(list, rowW)
        -- Beside the name once its switch is flipped: what the reload will do.
        row.tag = Style.Text(row, 11, "gold", nil, true)
        row.tag:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
        row.options = Style.Button(row, "Options", "tab", OPTIONS_W)
        row.options:SetHeight(24)
        row.options:SetPoint("RIGHT", row.switch, "LEFT", -12, 0)
        row.options:SetScript("OnClick", function()
            openKey = openKey ~= row.module.key and row.module.key or nil
            Paint()
        end)
        rows[i] = row
        return row
    end
    local function OptionRow(i)
        if not optionRows[i] then optionRows[i] = Row(list, rowW, true) end
        return optionRows[i]
    end

    ---------------------------------------------------------------------
    -- The bar at the bottom while a change waits for a reload.
    ---------------------------------------------------------------------
    local bar = CreateFrame("Frame", nil, page)
    bar:SetPoint("BOTTOMLEFT")
    bar:SetSize(width, BAR_H)
    Style.Fill(bar, "well")
    Style.Border(bar, "gold")
    local reload = Window.ReloadButton(bar, "jsalUISettingsReloadButton", "Reload now", 124, true)
    reload:SetHeight(30)
    reload:SetPoint("RIGHT", -12, 0)
    local undo = Style.Button(bar, "Undo", "plain", 84)
    undo:SetHeight(30)
    undo:SetPoint("RIGHT", reload, "LEFT", -8, 0)
    local barTitle = Style.Text(bar, 13, "text", nil, true)
    barTitle:SetPoint("TOPLEFT", 14, -9)
    local barList = Style.Text(bar, 12, "muted")
    barList:SetPoint("TOPLEFT", barTitle, "BOTTOMLEFT", 0, -2)
    barList:SetWidth(width - 14 - 124 - 84 - 8 - 12 - 16)
    barList:SetWordWrap(false)
    undo:SetScript("OnClick", function()
        for _, module in ipairs(ns.moduleOrder) do
            if Changed(module) then ns.db.modules[module.key] = module.wantedAtStart end
        end
        Paint()
    end)

    local footer = Style.Text(page, 11, "muted")
    footer:SetPoint("BOTTOMLEFT")
    footer:SetText("jsal.ui " .. ns.version .. ", free from jsal.io")

    local function PaintBar()
        local names = {}
        for _, module in ipairs(ns.moduleOrder) do
            if Changed(module) then
                names[#names + 1] = module.title .. (ns.ModuleWanted(module) and " on" or " off")
            end
        end
        bar:SetShown(#names > 0)
        footer:SetShown(#names == 0)
        if #names == 0 then return end
        barTitle:SetText(#names == 1 and "1 change waits for a reload" or (#names .. " changes wait for a reload"))
        barList:SetText(table.concat(names, ", "))
    end

    Paint = function()
        -- With words in the box, every part that has them, from any group,
        -- each with its options open.
        local finding = words ~= ""
        local shown = {}
        if finding then
            for _, group in ipairs(groups) do
                for _, module in ipairs(group.modules) do
                    if Matches(module, words) then shown[#shown + 1] = module end
                end
            end
        else
            shown = groups[chosen].modules
        end
        for i, b in ipairs(tabs) do b:SetSelected(not finding and i == chosen) end

        local y, used = 0, 0
        for i, module in ipairs(shown) do
            local row = PartRow(i)
            row.module = module
            local on = ns.ModuleWanted(module)
            row:Set(module.title, module.failed and "Turned off after an error this session. BugSack has the details."
                or module.note or "")
            row.name:SetTextColor(Style.Color((module.failed or not on) and "muted" or "text"))
            row.tag:SetText(Changed(module) and (on and "On after a reload" or "Off after a reload") or "")
            row.switch:SetOn(on)
            row.onChange = function(now)
                ns.db.modules[module.key] = now
                Paint()
            end
            local options = module.options or {}
            local open = #options > 0 and (openKey == module.key or finding)
            row.options:SetShown(#options > 0)
            row.options:SetLabel(#options == 1 and "1 option" or (#options .. " options"))
            row.options:SetSelected(open)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:Show()
            y = y + ROW_H
            for _, option in ipairs(open and options or {}) do
                used = used + 1
                local o = OptionRow(used)
                o:Set(option.title, option.note)
                o.switch:SetOn(ns.OptionOn(module.key, option.key))
                o.onChange = function(now)
                    ns.SetOption(module.key, option.key, now)
                    -- A part that redraws on an option change (the quick bar) does it now.
                    if module.running and type(module.OnOption) == "function" then
                        xpcall(function() module:OnOption(option.key, now) end, ns.Report)
                    end
                end
                o:ClearAllPoints()
                o:SetPoint("TOPLEFT", 0, -y)
                o:Show()
                y = y + OPTION_H
            end
        end
        for i = #shown + 1, #rows do rows[i]:Hide() end
        for i = used + 1, #optionRows do optionRows[i]:Hide() end
        none:SetShown(#shown == 0)
        if #shown == 0 then none:SetText(("Nothing in jsal.ui matches \"%s\"."):format(words)) end
        list:SetHeight(math.max(1, y))
        scroll:UpdateScrollChildRect()
        scroll:Place()
        PaintBar()
    end

    page.Refresh = function() Paint() end
end)
