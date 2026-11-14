-- Settings: a switch for each part of jsal.ui, one group to a tab. A part is
-- a card: its name, what it does in one short line, and its switch; the
-- whole of what it does is a point away, in its tooltip. (John, 14 Nov 2026,
-- of a page of two-line descriptions: "it is mostly all text and a lot of
-- it".) Inside a tab, a small heading sits over each handful of parts that
-- belong together. A part with options of its own says how many, and a
-- click opens them under its card. The box at the top finds a part or an
-- option in any group. A part's switch applies after a reload, since
-- modules start once, at login (addons can't reload the game themselves on
-- Forever): a bar at the bottom says which changes are waiting, with a
-- button to undo them and one to reload. Options apply at once.
local _, ns = ...
local Style, Window = ns.Style, ns.Window

local CARD_H, OPTION_H, GAP, HEAD_H = 58, 38, 8, 26
local LIST_TOP, BAR_H = 84, 52
local SWITCH_W = 36

-- Where each part goes: a tab for each group, and inside it a heading for
-- each handful of parts that belong together. A part not listed joins the
-- last group's last handful.
local GROUPS = {
    { title = "Games", width = 100, sections = {
        { "Puzzles and chess", { "dailyword", "iconguess", "chess", "flight" } },
        { "Company", { "guild", "pet" } },
    } },
    { title = "Leveling", width = 110, sections = {
        { "Planning ahead", { "talents", "trainingpanel", "gear", "dungeons" } },
        { "As you play", { "nextlevel", "levelup", "journal", "questtags", "tametip" } },
    } },
    { title = "Professions", width = 130, sections = {
        { "Crafting", { "professionpanel", "profwindow", "shopping", "crafters" } },
    } },
    { title = "Around the UI", width = 150, sections = {
        { "Buttons and bars", { "launcher", "minimap", "menubar", "bagbutton" } },
        { "Helpers", { "vendor", "warnings", "waypoint", "foodtile", "rangecheck" } },
        { "Everything else", { "sharedFonts" } },
    } },
}

-- What each part does, in a line short enough to take in at a glance. The
-- part's own note, which says all of it, is the card's tooltip.
local SHORT = {
    dailyword = "One word a day, the same for everyone",
    iconguess = "Name the spell from its icon",
    chess = "Chess with guildmates, a move at a time",
    flight = "Route, time left and games while you fly",
    guild = "Guildmates' scores and the Guild Word",
    pet = "A small creature of your own to raise",
    talents = "Names your next talent",
    trainingpanel = "What to train now and next",
    gear = "The best upgrade for each slot",
    dungeons = "Bosses, loot and quests",
    nextlevel = "What your next level brings",
    levelup = "What's new on each level",
    journal = "Your story, stats and characters",
    questtags = "A quest's chain, and how long it takes",
    tametip = "Which beasts teach a new pet ability",
    professionpanel = "What to craft to reach the next rank",
    profwindow = "Extras in the game's profession window",
    shopping = "What to craft and buy, with prices",
    crafters = "Who in your guild makes what",
    launcher = "A small bar of buttons you can move",
    minimap = "Opens the dashboard from the minimap",
    menubar = "The game's menu bar, in jsal.ui's look",
    bagbutton = "One button for your bags and free space",
    vendor = "Repairs and sells grey items for you",
    warnings = "Full bags, and gear about to break",
    waypoint = "Where the map marker leads, and how far",
    foodtile = "A reminder when you aren't Well Fed",
    rangecheck = "Hunters: melee, dead zone or shooting",
    layers = "Your layer, and a way to change it",
    sharedFonts = "jsal.ui's font in other addons' lists",
}

-- A part's short line: its own, or its note up to the first full stop.
local function Short(module)
    if SHORT[module.key] then return SHORT[module.key] end
    local note = module.note or ""
    return note:match("^(.-)%. ") or note
end

-- The slash command a part's note names, for a tag beside its name.
local function Command(module)
    return (module.note or ""):match("(/jsal %a+)")
end

local function Grouped()
    local placed, groups = {}, {}
    for i, group in ipairs(GROUPS) do
        local all, sections = {}, {}
        for _, section in ipairs(group.sections) do
            local list = {}
            for _, key in ipairs(section[2]) do
                if ns.modules[key] then
                    list[#list + 1] = ns.modules[key]
                    all[#all + 1] = ns.modules[key]
                    placed[key] = true
                end
            end
            sections[#sections + 1] = { title = section[1], modules = list }
        end
        groups[i] = { title = group.title, width = group.width, modules = all, sections = sections }
    end
    local last = groups[#groups]
    for _, module in ipairs(ns.moduleOrder) do
        if not placed[module.key] then
            table.insert(last.modules, module)
            table.insert(last.sections[#last.sections].modules, module)
        end
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

-- A small label beside a part's name: gold for what a reload will do,
-- plain for its slash command.
local function Tag(parent, gold)
    local t = CreateFrame("Frame", nil, parent)
    t:SetHeight(15)
    Style.Fill(t, gold and "gold" or "line")
    t.text = Style.Text(t, 10, gold and "onGold" or "secondary", nil, gold)
    t.text:SetPoint("CENTER")
    function t:Say(text)
        self.text:SetText(text or "")
        local w = self.text.GetStringWidth and self.text:GetStringWidth()
        self:SetWidth(((type(w) == "number" and w > 0) and w or #(text or "") * 5.2) + 12)
        self:SetShown(text ~= nil and text ~= "")
    end
    return t
end

-- A card: a name, one line under it, and a switch at the right. Clicking
-- anywhere on it flips the switch, which calls row.onChange. Pointing at a
-- part's card shows the whole of what it does; at an option's, its line
-- when that was cut. A small card is one of a part's options, under it on a
-- darker fill.
local function Card(parent, width, small)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, small and OPTION_H or CARD_H)
    Style.Fill(row, small and "titleBar" or "well")
    row.hover = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(Style.Color("wellHover"))
    row.hover:Hide()
    -- Its left edge is gold while it's on, so a tab's state shows at a look.
    row.edge = row:CreateTexture(nil, "ARTWORK")
    row.edge:SetPoint("TOPLEFT")
    row.edge:SetPoint("BOTTOMLEFT")
    row.edge:SetWidth(3)
    row.switch = Style.Switch(row, function(on)
        if row.onChange then row.onChange(on) end
    end)
    row.switch:SetPoint("RIGHT", -12, 0)
    row.name = Style.Text(row, small and 12 or 14, "text", nil, not small)
    row.name:SetPoint("TOPLEFT", 16, small and -5 or -11)
    row.name:SetWordWrap(false)
    row.note = Style.Text(row, small and 11 or 12, "muted")
    row.note:SetPoint("TOPLEFT", 16, small and -21 or -33)
    row.note:SetWidth(width - 16 - SWITCH_W - 28)
    row.note:SetJustifyH("LEFT")
    row.note:SetWordWrap(false)
    row:SetScript("OnClick", function() row.switch:Click() end)
    row:SetScript("OnEnter", function(self)
        self.hover:Show()
        local cut = self.note.IsTruncated and self.note:IsTruncated()
        if self.full and self.full ~= "" and (not small or cut) then
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
    function row:Set(title, line, full, on)
        self.title, self.full = title, full
        self.name:SetText(title)
        self.note:SetText(line or "")
        self.switch:SetOn(on)
        self.edge:SetColorTexture(Style.Color(on and "gold" or "lineStrong"))
        self.name:SetTextColor(Style.Color(on and "text" or "muted"))
    end
    return row
end

Window.Page("settings", function(page)
    local width, height = Window.contentWidth, Window.contentHeight
    local rowW = width - 12
    local cardW = math.floor((rowW - 12) / 2)
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

    local summary = Style.Text(page, 12, "muted")
    summary:SetPoint("TOPRIGHT", page.heading, "BOTTOMLEFT", width, -(8 + 28 + 12 + 6))
    summary:SetJustifyH("RIGHT")

    ---------------------------------------------------------------------
    -- The parts, as cards two across, in a list that scrolls when there's
    -- more than fits.
    ---------------------------------------------------------------------
    local scroll, list = Style.Scroller(page, width, height - LIST_TOP - BAR_H - 12, rowW)
    scroll:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -(8 + LIST_TOP))
    local none = Style.Text(list, 13, "muted")
    none:SetPoint("TOPLEFT", 0, -14)
    none:SetWidth(rowW)

    local rows, optionRows, heads = {}, {}, {}
    local function PartRow(i)
        if rows[i] then return rows[i] end
        local row = Card(list, cardW)
        -- Beside the name: its slash command, and, once its switch is
        -- flipped, what the reload will do.
        row.command = Tag(row)
        row.tag = Tag(row, true)
        -- "2 options", under the switch: a click opens them under the card.
        row.options = CreateFrame("Button", nil, row)
        row.options:SetSize(70, 16)
        row.options:SetPoint("BOTTOMRIGHT", -12, 7)
        row.options.label = Style.Text(row.options, 11, "gold")
        row.options.label:SetPoint("RIGHT")
        row.options.label:SetJustifyH("RIGHT")
        row.options:SetScript("OnClick", function()
            openKey = openKey ~= row.module.key and row.module.key or nil
            Paint()
        end)
        rows[i] = row
        return row
    end
    local function OptionRow(i)
        if not optionRows[i] then
            optionRows[i] = Card(list, cardW, true)
            optionRows[i].edge:SetColorTexture(Style.Color("gold"))
        end
        return optionRows[i]
    end
    local function Head(i)
        if not heads[i] then heads[i] = Style.Text(list, 12, "gold", nil, true) end
        return heads[i]
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

        -- How many parts are on, said once at the top.
        local on, total = 0, 0
        for _, module in ipairs(ns.moduleOrder) do
            total = total + 1
            if ns.ModuleWanted(module) then on = on + 1 end
        end
        summary:SetText(("%d of %d parts are on  ·  point at one for all it does"):format(on, total))

        -- A part's card at (x, y), its options under it when they're open.
        -- Returns how tall it came to.
        local y, used, parts, headed = 0, 0, 0, 0
        local function Place(module, x, at)
            parts = parts + 1
            local row = PartRow(parts)
            row.module = module
            local wanted = ns.ModuleWanted(module)
            row:Set(module.title, module.failed and "Turned off after an error this session" or Short(module),
                module.failed and "Turned off after an error this session. BugSack has the details." or module.note or "", wanted)
            if module.failed then row.name:SetTextColor(Style.Color("muted")) end
            row.command:Say(Command(module))
            row.command:ClearAllPoints()
            row.command:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
            row.tag:Say(Changed(module) and (wanted and "on after a reload" or "off after a reload") or nil)
            -- Beside the name where there's room; after the line under it
            -- for a long name, so it never runs under the switch.
            local function Wide(text)
                local w = text.GetStringWidth and text:GetStringWidth()
                return type(w) == "number" and w or 0
            end
            local taken = 16 + Wide(row.name) + 8 + (row.command:IsShown() and (Wide(row.command.text) + 18) or 0)
            row.tag:ClearAllPoints()
            if taken + Wide(row.tag.text) + 12 > cardW - SWITCH_W - 24 then
                row.tag:SetPoint("LEFT", row.note, "LEFT", Wide(row.note) + 8, 0)
            else
                row.tag:SetPoint("LEFT", row.command:IsShown() and row.command or row.name, "RIGHT", row.command:IsShown() and 6 or 8, 0)
            end
            row.onChange = function(now)
                ns.db.modules[module.key] = now
                Paint()
            end
            local options = module.options or {}
            local open = #options > 0 and (openKey == module.key or finding)
            row.options:SetShown(#options > 0)
            row.options.label:SetText(#options == 1 and "1 option" or (#options .. " options"))
            row.options.selected = open
            -- With options, the switch sits above "N options".
            row.switch:ClearAllPoints()
            if #options > 0 then row.switch:SetPoint("TOPRIGHT", -12, -9) else row.switch:SetPoint("RIGHT", -12, 0) end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", x, -at)
            row:Show()
            local tall = CARD_H
            for _, option in ipairs(open and options or {}) do
                used = used + 1
                local o = OptionRow(used)
                o:Set(option.title, option.note, option.note, ns.OptionOn(module.key, option.key))
                o.edge:SetColorTexture(Style.Color("gold"))
                o.name:SetTextColor(Style.Color("text"))
                o.onChange = function(now)
                    ns.SetOption(module.key, option.key, now)
                    -- A part that redraws on an option change (the quick bar) does it now.
                    if module.running and type(module.OnOption) == "function" then
                        xpcall(function() module:OnOption(option.key, now) end, ns.Report)
                    end
                end
                o:ClearAllPoints()
                o:SetPoint("TOPLEFT", x, -(at + tall + 2))
                o:Show()
                tall = tall + 2 + OPTION_H
            end
            return tall
        end
        -- A handful of parts under a heading, two across: each goes to the
        -- shorter column, so one with its options open doesn't leave a gap.
        local function Section(title, modules)
            if #modules == 0 then return end
            if title then
                headed = headed + 1
                local head = Head(headed)
                head:SetText(title:upper())
                head:ClearAllPoints()
                head:SetPoint("TOPLEFT", 0, -(y + 6))
                head:Show()
                y = y + HEAD_H
            end
            local left, right = y, y
            for _, module in ipairs(modules) do
                if left <= right then
                    left = left + Place(module, 0, left) + GAP
                else
                    right = right + Place(module, cardW + 12, right) + GAP
                end
            end
            y = math.max(left, right) + 8
        end
        if finding then
            Section(nil, shown)
        else
            local sections = groups[chosen].sections
            for _, section in ipairs(sections) do
                Section(#sections > 1 and section.title or nil, section.modules)
            end
        end
        for i = parts + 1, #rows do rows[i]:Hide() end
        for i = headed + 1, #heads do heads[i]:Hide() end
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
