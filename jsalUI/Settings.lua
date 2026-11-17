-- Settings: a switch for each part of jsal.ui, a group of them at a time. A
-- bar of tabs under the page's name has a tab for each group (Games,
-- Professions, Leveling, Around the UI) with how many parts it holds, and
-- the page shows the open group's parts in two columns, a small heading
-- over each handful that belong together. A part is a row: its picture, its
-- name with a line under it on what it does, and its switch. The whole of
-- what it does is in a tooltip when it's pointed at. A part with options of
-- its own says how many, and a click opens them under its row. The box at
-- the top finds a part or an option in any group, and shows what it finds
-- under each group's name. A part's switch applies after a reload, since
-- modules start once, at login (addons can't reload the game themselves on
-- Forever): a bar at the foot says which changes are waiting, with a button
-- to undo them and one to reload. Options apply at once.
local _, ns = ...
local Style, Window = ns.Style, ns.Window

local ROW_H, OPTION_H, GROUP_H, HEAD_H, GROUP_GAP = 52, 30, 30, 24, 18
local TABS_Y, TOP, BAR_H, COLUMN_GAP, COLUMNS = 44, 86, 64, 40, 2
local SWITCH_W, TEXT_X = 36, 36

-- The groups, in the order of their tabs, and inside each a heading for each
-- handful of parts that belong together. A part not listed joins the last
-- group's last handful. A heading that names a part has another to go by
-- while that part isn't there.
local GROUPS = {
    { key = "games", title = "Games", sections = {
        { "Puzzles and chess", { "dailyword", "iconguess", "chess", "flight" }, { chess = "Puzzles" } },
        { "Company", { "guild", "pet", "palrun" } },
    } },
    { key = "professions", title = "Professions", sections = {
        { "Crafting", { "professionpanel", "profwindow", "shopping", "crafters", "orders", "craftprofit" } },
    } },
    { key = "leveling", title = "Leveling", sections = {
        { "Planning ahead", { "talents", "trainingpanel", "gear", "dungeons" } },
        { "As you play", { "nextlevel", "levelup", "journal", "questtags", "guidetags", "lootlog", "tametip", "rewardstar" } },
    } },
    { key = "around", title = "Around the UI", sections = {
        { "Buttons and bars", { "launcher", "minimap", "menubar", "bagbutton" } },
        { "Helpers", { "vendor", "warnings", "waypoint", "foodtile", "petfeed", "rangecheck" } },
        { "Everything else", { "sharedFonts" } },
    } },
}

-- What each part does, in a line short enough to take in at a glance: it's
-- under the part's name on its row. The part's own note, which says all of
-- it, is in the row's tooltip.
local SHORT = {
    dailyword = "One word a day, the same for everyone",
    iconguess = "Name the spell from its icon",
    palrun = "A platformer for your pal, timed",
    chess = "Chess with guildmates, move by move",
    flight = "Route, time left and games in flight",
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
    -- These two shipped in 0.3.43 with no line here, and their cards showed the start of the
    -- long note, cut off: "Left of RestedXP's guide window: bes...".
    guidetags = "Tags beside RestedXP's guide steps",
    lootlog = "Counts the quest items your kills drop",
    tametip = "Which beasts teach a new pet ability",
    rewardstar = "Stars the quest reward best for you",
    professionpanel = "What to craft to reach the next rank",
    profwindow = "Extras in the game's profession window",
    shopping = "What to craft and buy, with prices",
    crafters = "Who in your guild makes what",
    orders = "Ask the guild for a craft",
    craftprofit = "What your recipes earn at auction",
    launcher = "A small bar of buttons you can move",
    minimap = "Opens the dashboard from the minimap",
    menubar = "The game's menu bar, in jsal.ui's look",
    bagbutton = "One button for all your bags",
    vendor = "Repairs and sells grey items for you",
    warnings = "Full bags, and gear about to break",
    waypoint = "Where the map marker leads",
    foodtile = "A reminder when you aren't Well Fed",
    petfeed = "Hunters: feed your pet in one click",
    rangecheck = "Hunters: melee, dead zone or shooting",
    layers = "Your layer, and a way to change it",
    sharedFonts = "jsal.ui's font in other addons' lists",
}

-- A picture for each part's row: one of the menu bar's (Media\\Icons\\Menu)
-- where it has one that fits, else one drawn for the part
-- (tools/make_part_icons.mjs). White shapes, tinted gold while the part is
-- on and grey while it's off.
local ICON_PATH = "Interface\\AddOns\\jsalUI\\Media\\Icons\\"
local ICON = {
    dailyword = "Parts\\dailyword", iconguess = "Menu\\help", chess = "Parts\\chess", flight = "Parts\\flight",
    guild = "Menu\\guild", pet = "Parts\\pet", palrun = "Parts\\palrun",
    talents = "Menu\\talents", trainingpanel = "Menu\\spellbook", gear = "Menu\\legacy", dungeons = "Parts\\dungeons",
    nextlevel = "Parts\\nextlevel", levelup = "Parts\\levelup", journal = "Parts\\journal", questtags = "Menu\\quests",
    guidetags = "Menu\\quests", lootlog = "Menu\\collections",
    tametip = "Parts\\tametip", rewardstar = "Menu\\quests",
    professionpanel = "Menu\\professions", profwindow = "Parts\\profwindow", shopping = "Parts\\shopping", crafters = "Menu\\group", orders = "Menu\\guild",
    craftprofit = "Menu\\shop",
    launcher = "Parts\\launcher", minimap = "Parts\\minimap", menubar = "Parts\\menubar", bagbutton = "Menu\\bag",
    vendor = "Parts\\vendor", warnings = "Parts\\warnings", waypoint = "Parts\\waypoint", foodtile = "Parts\\foodtile",
    petfeed = "Parts\\foodtile",
    rangecheck = "Parts\\rangecheck", layers = "Parts\\layers", sharedFonts = "Parts\\sharedFonts",
}

-- A part's short line: its own, or its note up to the first full stop.
local function Short(module)
    if SHORT[module.key] then return SHORT[module.key] end
    local note = module.note or ""
    return note:match("^(.-)%. ") or note
end

-- The slash command a part's note names, for a line in its tooltip.
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
            local title = section[1]
            for key, without in pairs(section[3] or {}) do
                if not ns.modules[key] then title = without end
            end
            sections[#sections + 1] = { title = title, modules = list }
        end
        groups[i] = { key = group.key, title = group.title, modules = all, sections = sections }
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

-- A part's row: its picture, its name over a line on what it does, and its
-- switch at the right, with how many options it has before the switch and a
-- tag when a reload is owed for it or it stopped on an error. The switch is
-- the quiet kind: a page of bright ones, all on, is a wall of gold. A click
-- anywhere on the row flips it, which calls row.onChange. Pointing at the
-- row lights it and calls row.onPoint; the page shows the whole of what the
-- part does there.
local function PartRow(parent, width)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, ROW_H)
    row.wide = width
    -- The light under the pointer reaches a little past the row's sides.
    row.hover = Style.Round(row, 5, "well", "BACKGROUND", 1)
    row.hover:ClearAllPoints()
    row.hover:SetPoint("TOPLEFT", -6, 0)
    row.hover:SetPoint("BOTTOMRIGHT", 6, 0)
    row.hover:Hide()
    Style.Rule(row, "BOTTOM", "line")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetAlpha(0.8)
    row.switch = Style.Switch(row, function(on)
        if row.onChange then row.onChange(on) end
    end, true)
    row.switch:SetPoint("RIGHT")
    -- "2 options", before the switch: a click opens them under the row.
    row.options = CreateFrame("Button", nil, row)
    row.options:SetHeight(18)
    row.options:SetPoint("RIGHT", row.switch, "LEFT", -12, 0)
    row.options.label = Style.Text(row.options, 11, "muted")
    row.options.label:SetPoint("RIGHT")
    row.options.label:SetJustifyH("RIGHT")
    row.options.line = row.options:CreateTexture(nil, "ARTWORK")
    row.options.line:SetPoint("BOTTOMLEFT")
    row.options.line:SetPoint("BOTTOMRIGHT")
    row.options.line:SetHeight(1)
    row.tag = Style.Tag(row, "", true)
    row.name = Style.Text(row, 14, "text")
    row.name:SetPoint("TOPLEFT", TEXT_X, -9)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.short = Style.Text(row, 12, "muted")
    row.short:SetPoint("TOPLEFT", TEXT_X, -29)
    row.short:SetJustifyH("LEFT")
    row.short:SetWordWrap(false)
    row:SetScript("OnClick", function() row.switch:Click() end)
    -- The options' button is part of the row to the pointer: it lights the
    -- row and says the part too.
    local function Enter()
        row.hover:Show()
        if row.onPoint then row.onPoint(row) end
    end
    local function Leave()
        row.hover:Hide()
        if row.onLeave then row.onLeave(row) end
    end
    row:SetScript("OnEnter", Enter)
    row:SetScript("OnLeave", Leave)
    row.options:SetScript("OnEnter", Enter)
    row.options:SetScript("OnLeave", Leave)
    -- What it is, what it does in a line, and where it stands. `tag` is the
    -- word for its gold tag, or nil.
    function row:Set(title, short, on, options, open, tag)
        self.title = title
        self.name:SetText(title)
        self.name:SetTextColor(Style.Color(on and "text" or "muted"))
        self.short:SetText(short or "")
        self.switch:SetOn(on)
        self.icon:SetVertexColor(Style.Color(on and "gold" or "muted"))
        local taken = SWITCH_W
        self.options:SetShown(options > 0)
        self.options.selected = open
        if options > 0 then
            self.options.label:SetText(options == 1 and "1 option" or (options .. " options"))
            self.options.label:SetTextColor(Style.Color(open and "gold" or "muted"))
            self.options.line:SetColorTexture(Style.Color(open and "gold" or "lineStrong"))
            local wide = Style.Wide(self.options.label, 56) + 2
            self.options:SetWidth(wide)
            taken = taken + 12 + wide
        end
        self.tag:SetShown(tag ~= nil)
        if tag then
            self.tag:Say(tag)
            self.tag:ClearAllPoints()
            self.tag:SetPoint("RIGHT", self, "RIGHT", -(taken + 10), 0)
            taken = taken + 10 + self.tag:GetWidth()
        end
        -- The words have what's left, and are cut short rather than run under anything.
        local room = math.max(40, self.wide - TEXT_X - taken - 10)
        self.name:SetWidth(room)
        self.short:SetWidth(room)
    end
    -- A part's picture, by its key; none for a part that has none.
    function row:Picture(key)
        self.icon:SetShown(ICON[key] ~= nil)
        if ICON[key] then self.icon:SetTexture(ICON_PATH .. ICON[key]) end
    end
    return row
end

-- One of a part's options, under its row on a darker fill with a gold edge:
-- its name and its switch. What it does is said in a tooltip when it's
-- pointed at.
local function OptionRow(parent, width)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, OPTION_H)
    local fill = row:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", 13, 0)
    fill:SetPoint("BOTTOMRIGHT")
    fill:SetColorTexture(Style.Color("titleBar"))
    row.hover = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.hover:SetPoint("TOPLEFT", 13, 0)
    row.hover:SetPoint("BOTTOMRIGHT")
    row.hover:SetColorTexture(Style.Color("well"))
    row.hover:Hide()
    row.edge = row:CreateTexture(nil, "ARTWORK")
    row.edge:SetPoint("TOPLEFT", 13, 0)
    row.edge:SetPoint("BOTTOMLEFT", 13, 0)
    row.edge:SetWidth(2)
    row.edge:SetColorTexture(Style.Color("gold"))
    row.switch = Style.Switch(row, function(on)
        if row.onChange then row.onChange(on) end
    end, true)
    row.switch:SetPoint("RIGHT", -8, 0)
    row.name = Style.Text(row, 12, "text")
    row.name:SetPoint("LEFT", 26, 0)
    -- An option's name stops short of its switch, so a long one never runs
    -- on under it.
    row.name:SetWidth(width - 26 - SWITCH_W - 20)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnClick", function() row.switch:Click() end)
    row:SetScript("OnEnter", function(self)
        self.hover:Show()
        if self.onPoint then self.onPoint(self) end
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        if self.onLeave then self.onLeave(self) end
    end)
    function row:Set(title, full, on)
        self.title, self.full = title, full
        self.name:SetText(title)
        self.switch:SetOn(on)
    end
    return row
end

Window.Page("settings", function(page)
    local width, height = Window.fullWidth, Window.contentHeight
    local colW = math.floor((width - 12 - COLUMN_GAP * (COLUMNS - 1)) / COLUMNS)
    local groups = Grouped()
    local open, openKey, words = groups[1].key, nil, ""
    local Paint

    ---------------------------------------------------------------------
    -- The top: the page's name, how many parts are on, the guided setup and
    -- Unlock Mode again, and a box to find a part in.
    ---------------------------------------------------------------------
    local title = Style.Text(page, 23, "text", nil, true)
    title:SetPoint("TOPLEFT")
    title:SetText("Settings")
    local summary = Style.Text(page, 13, "muted")
    summary:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 14, 3)

    local find = Style.Field(page, 260)
    find.well:SetHeight(28)
    find.well:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -2)
    find.hint = Style.Text(find.well, 12, "muted")
    find.hint:SetPoint("LEFT", 10, 0)
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
        local again = Style.Button(page, "Set up again", "plain", 120)
        again:SetPoint("RIGHT", find.well, "LEFT", -8, 0)
        again:SetScript("OnClick", function()
            ns.Window.Toggle()
            ns.Setup.Open()
        end)
        -- And jsal.ui's own Unlock Mode, to move its pieces (/jsal unlock).
        if ns.Unlock and ns.Unlock.Open then
            local move = Style.Button(page, "Move pieces", "plain", 120)
            move:SetPoint("RIGHT", again, "LEFT", -8, 0)
            move:SetScript("OnClick", function()
                ns.Window.Toggle()
                ns.Unlock.Open()
            end)
        end
    end

    ---------------------------------------------------------------------
    -- A tab for each group, with how many parts it holds. One group's parts
    -- show at a time, so there's a handful to read and not all of them.
    ---------------------------------------------------------------------
    local items = {}
    for i, group in ipairs(groups) do items[i] = { group.key, group.title } end
    local tabs = Style.Tabs(page, items, function(key)
        open, openKey = key, nil
        Paint()
    end)
    tabs:SetPoint("TOPLEFT", 0, -TABS_Y)
    for _, group in ipairs(groups) do tabs:Set(group.key, nil, #group.modules) end

    ---------------------------------------------------------------------
    -- The open group's parts, a row each, in two columns. The list scrolls
    -- when options are open and a column runs past the foot.
    ---------------------------------------------------------------------
    local scroll, list = Style.Scroller(page, width, height - TOP - BAR_H - 12, width, 0)
    scroll:SetPoint("TOPLEFT", 0, -TOP)
    local none = Style.Text(list, 13, "muted")
    none:SetPoint("TOPLEFT", 6, -14)
    none:SetWidth(width - 12)

    local rows, optionRows, groupHeads, heads = {}, {}, {}, {}
    local function Row(i)
        if not rows[i] then
            local row = PartRow(list, colW)
            row.options:SetScript("OnClick", function()
                openKey = openKey ~= row.module.key and row.module.key or nil
                Paint()
            end)
            rows[i] = row
        end
        return rows[i]
    end
    local function Option(i)
        if not optionRows[i] then optionRows[i] = OptionRow(list, colW) end
        return optionRows[i]
    end
    -- A group's name in gold over what the box found in it, with a rule.
    local function GroupHead(i)
        if not groupHeads[i] then groupHeads[i] = Style.Section(list, colW) end
        return groupHeads[i]
    end
    local function Head(i)
        if not heads[i] then heads[i] = Style.Text(list, 10, "muted", nil, true) end
        return heads[i]
    end

    ---------------------------------------------------------------------
    -- The foot: the version, quietly; or, while a change waits for a
    -- reload, the bar that lists the changes.
    ---------------------------------------------------------------------
    local version = Style.Text(page, 11, "muted")
    version:SetPoint("BOTTOMLEFT", 0, 4)
    version:SetText("jsal.ui " .. ns.version .. ", free from jsal.io")

    local bar = CreateFrame("Frame", nil, page)
    bar:SetPoint("BOTTOMLEFT")
    bar:SetSize(width, BAR_H)
    Style.Box(bar, 6, "well", "gold")
    local reload = Window.ReloadButton(bar, "jsalUISettingsReloadButton", "Reload now", 124, true)
    reload:SetHeight(30)
    reload:SetPoint("RIGHT", -16, 0)
    local undo = Style.Button(bar, "Undo", "plain", 84)
    undo:SetHeight(30)
    undo:SetPoint("RIGHT", reload, "LEFT", -8, 0)
    local barTitle = Style.Text(bar, 14, "text", nil, true)
    barTitle:SetPoint("TOPLEFT", 16, -13)
    local barList = Style.Text(bar, 12, "muted")
    barList:SetPoint("TOPLEFT", barTitle, "BOTTOMLEFT", 0, -3)
    barList:SetWidth(width - 16 - 124 - 84 - 8 - 16 - 16)
    barList:SetWordWrap(false)
    undo:SetScript("OnClick", function()
        for _, module in ipairs(ns.moduleOrder) do
            if Changed(module) then ns.db.modules[module.key] = module.wantedAtStart end
        end
        Paint()
    end)

    -- The whole of what a part or an option does, in a tooltip while it's
    -- pointed at: its row has room for a line only.
    local function Point(titleText, full, command, owner)
        if not ((full and full ~= "") or command) then return end
        GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
        GameTooltip:SetText(titleText)
        if full and full ~= "" then GameTooltip:AddLine(full, 1, 1, 1, true) end
        if command then GameTooltip:AddLine(command, Style.Color("gold")) end
        GameTooltip:Show()
    end
    local function Unpoint()
        GameTooltip:Hide()
    end

    local function PaintBar()
        local names = {}
        for _, module in ipairs(ns.moduleOrder) do
            if Changed(module) then
                names[#names + 1] = module.title .. (ns.ModuleWanted(module) and " on" or " off")
            end
        end
        bar:SetShown(#names > 0)
        version:SetShown(#names == 0)
        if #names == 0 then return end
        barTitle:SetText(#names == 1 and "1 change waits for a reload" or (#names .. " changes wait for a reload"))
        barList:SetText(table.concat(names, ", "))
    end

    Paint = function()
        -- With words in the box, the parts that have them in any group, each
        -- with its options open, under their groups' names; else the open
        -- group's.
        local finding = words ~= ""
        local on, total = 0, 0
        for _, module in ipairs(ns.moduleOrder) do
            total = total + 1
            if ns.ModuleWanted(module) then on = on + 1 end
        end
        summary:SetText(("%d of %d parts are on"):format(on, total))
        tabs:Pick(not finding and open or nil)

        local parts, used, grouped, headed, shown = 0, 0, 0, 0, 0
        -- A part's row at (x, y), its options under it when they're open.
        -- Returns how tall it came to.
        local function Place(module, x, at)
            parts = parts + 1
            local row = Row(parts)
            row.module = module
            local wanted = ns.ModuleWanted(module)
            local options = module.options or {}
            local opened = #options > 0 and (openKey == module.key or finding)
            local full = module.failed and "Turned off after an error this session. BugSack has the details." or module.note or ""
            row:Set(module.title, Short(module), wanted, #options, opened,
                module.failed and "error" or (Changed(module) and "reload") or nil)
            if module.failed then row.name:SetTextColor(Style.Color("muted")) end
            row:Picture(module.key)
            row.onPoint = function(self) Point(module.title, full, Command(module), self) end
            row.onLeave = Unpoint
            row.onChange = function(now)
                ns.db.modules[module.key] = now
                Paint()
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", x, -at)
            row:Show()
            local tall = ROW_H
            for _, option in ipairs(opened and options or {}) do
                used = used + 1
                local o = Option(used)
                o:Set(option.title, option.note, ns.OptionOn(module.key, option.key))
                o.onPoint = function(self) Point(option.title, option.note or "", nil, self) end
                o.onLeave = Unpoint
                o.onChange = function(now)
                    ns.SetOption(module.key, option.key, now)
                    -- A part that redraws on an option change (the quick bar) does it now.
                    if module.running and type(module.OnOption) == "function" then
                        xpcall(function() module:OnOption(option.key, now) end, ns.Report)
                    end
                end
                o:ClearAllPoints()
                o:SetPoint("TOPLEFT", x, -(at + tall))
                o:Show()
                tall = tall + OPTION_H
            end
            return tall + (tall > ROW_H and 6 or 0)
        end

        -- How far down each column has got, and where a column starts.
        local at = {}
        for column = 1, COLUMNS do at[column] = 0 end
        local function X(column) return 6 + (column - 1) * (colW + COLUMN_GAP) end
        local function Shorter()
            local best = 1
            for column = 2, COLUMNS do
                if at[column] < at[best] then best = column end
            end
            return best
        end
        -- A handful of parts down a column, under a small heading (or under
        -- the room one takes, with no words, to stand level with its
        -- neighbour's).
        local function Handful(column, heading, modules)
            local y = at[column] + (at[column] > 0 and 10 or 0)
            if heading ~= "" then
                headed = headed + 1
                local small = Head(headed)
                small:SetText(heading:upper())
                small:ClearAllPoints()
                small:SetPoint("TOPLEFT", X(column), -(y + 2))
                small:Show()
            end
            y = y + HEAD_H
            for _, module in ipairs(modules) do
                y = y + Place(module, X(column), y)
                shown = shown + 1
            end
            at[column] = y
        end

        if finding then
            for _, group in ipairs(groups) do
                local found = {}
                for _, module in ipairs(group.modules) do
                    if Matches(module, words) then found[#found + 1] = module end
                end
                if #found > 0 then
                    local column = Shorter()
                    local y = at[column] + (at[column] > 0 and GROUP_GAP or 0)
                    grouped = grouped + 1
                    local head = GroupHead(grouped)
                    head.title:SetText(group.title:upper())
                    head.note:SetText("")
                    head:ClearAllPoints()
                    head:SetPoint("TOPLEFT", X(column), -y)
                    head:Show()
                    y = y + GROUP_H
                    for _, module in ipairs(found) do
                        y = y + Place(module, X(column), y)
                        shown = shown + 1
                    end
                    at[column] = y
                end
            end
        else
            local group = groups[1]
            for _, g in ipairs(groups) do
                if g.key == open then group = g end
            end
            local sections = {}
            for _, section in ipairs(group.sections) do
                if #section.modules > 0 then sections[#sections + 1] = section end
            end
            if #sections == 1 and #sections[1].modules > 3 then
                -- One handful alone: its first half down the first column
                -- and the rest down the second, so the page isn't half empty.
                local all, half = sections[1].modules, math.ceil(#sections[1].modules / 2)
                local first, rest = {}, {}
                for i, module in ipairs(all) do
                    if i <= half then first[#first + 1] = module else rest[#rest + 1] = module end
                end
                Handful(1, sections[1].title, first)
                Handful(2, "", rest)
            else
                for _, section in ipairs(sections) do Handful(Shorter(), section.title, section.modules) end
            end
        end
        for i = parts + 1, #rows do rows[i]:Hide() end
        for i = used + 1, #optionRows do optionRows[i]:Hide() end
        for i = grouped + 1, #groupHeads do groupHeads[i]:Hide() end
        for i = headed + 1, #heads do heads[i]:Hide() end
        none:SetShown(shown == 0)
        if shown == 0 then
            none:SetText(finding and ("Nothing in jsal.ui matches \"%s\"."):format(words) or "Nothing here.")
        end
        local tallest = 1
        for column = 1, COLUMNS do tallest = math.max(tallest, at[column] or 0) end
        list:SetHeight(tallest)
        scroll:UpdateScrollChildRect()
        scroll:Place()
        PaintBar()
    end

    page.Refresh = function()
        Paint()
    end
end, nil, true)
