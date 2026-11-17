-- Settings: a switch for each part of jsal.ui, all of them on one screen. A
-- part is a row: its picture, its name and its switch. The rows stand in
-- three columns by group, a small heading over each handful of parts that
-- belong together. What a part does is said at the foot of the page, in
-- full, while it's pointed at. A part with options of its own says how many,
-- and a click opens them under its row. The box at the top finds a part or
-- an option in any group. A part's switch applies after a reload, since
-- modules start once, at login (addons can't reload the game themselves on
-- Forever): a bar at the foot says which changes are waiting, with a button
-- to undo them and one to reload. Options apply at once.
local _, ns = ...
local Style, Window = ns.Style, ns.Window

local ROW_H, OPTION_H, GROUP_H, HEAD_H, GROUP_GAP = 36, 30, 30, 24, 18
local TOP, BAR_H, COLUMN_GAP, COLUMNS = 50, 64, 28, 3
local SWITCH_W = 36

-- Where each part goes: the column its group stands in, and inside the group
-- a heading for each handful of parts that belong together. A part not
-- listed joins the last group's last handful. A heading that names a part
-- has another to go by while that part isn't there.
local GROUPS = {
    { title = "Games", column = 1, sections = {
        { "Puzzles and chess", { "dailyword", "iconguess", "chess", "flight" }, { chess = "Puzzles" } },
        { "Company", { "guild", "pet", "palrun" } },
    } },
    { title = "Leveling", column = 2, sections = {
        { "Planning ahead", { "talents", "trainingpanel", "gear", "dungeons" } },
        { "As you play", { "nextlevel", "levelup", "journal", "questtags", "guidetags", "lootlog", "tametip", "rewardstar" } },
    } },
    { title = "Professions", column = 1, sections = {
        { "Crafting", { "professionpanel", "profwindow", "shopping", "crafters", "orders", "craftprofit" } },
    } },
    { title = "Around the UI", column = 3, sections = {
        { "Buttons and bars", { "launcher", "minimap", "menubar", "bagbutton" } },
        { "Helpers", { "vendor", "warnings", "waypoint", "foodtile", "petfeed", "rangecheck" } },
        { "Everything else", { "sharedFonts" } },
    } },
}

-- What each part does, in a line short enough to take in at a glance: it
-- follows the part's name at the foot of the page, over the part's own note,
-- which says all of it.
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
            local title = section[1]
            for key, without in pairs(section[3] or {}) do
                if not ns.modules[key] then title = without end
            end
            sections[#sections + 1] = { title = title, modules = list }
        end
        groups[i] = { title = group.title, column = group.column, modules = all, sections = sections }
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

-- A part's row: its picture in a small tile, its name, and its switch at the
-- right, with how many options it has before the switch and a tag when a
-- reload is owed for it or it stopped on an error. A click anywhere on it
-- flips the switch, which calls row.onChange. Pointing at it lights it and
-- calls row.onPoint; the page says there what the part does.
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
    local tile = CreateFrame("Frame", nil, row)
    tile:SetSize(28, 28)
    tile:SetPoint("LEFT")
    Style.Box(tile, 5, "titleBar", "line")
    row.icon = tile:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("CENTER")
    row.switch = Style.Switch(row, function(on)
        if row.onChange then row.onChange(on) end
    end)
    row.switch:SetPoint("RIGHT")
    -- "2 options", before the switch: a click opens them under the row.
    row.options = CreateFrame("Button", nil, row)
    row.options:SetHeight(20)
    row.options:SetPoint("RIGHT", row.switch, "LEFT", -12, 0)
    row.options.label = Style.Text(row.options, 11, "muted")
    row.options.label:SetPoint("RIGHT")
    row.options.label:SetJustifyH("RIGHT")
    row.tag = Style.Tag(row, "", true)
    row.name = Style.Text(row, 13, "text")
    row.name:SetPoint("LEFT", tile, "RIGHT", 10, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
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
    -- What it is and where it stands. `tag` is the word for its gold tag, or nil.
    function row:Set(title, on, options, open, tag)
        self.title = title
        self.name:SetText(title)
        self.name:SetTextColor(Style.Color(on and "text" or "muted"))
        self.switch:SetOn(on)
        self.icon:SetVertexColor(Style.Color(on and "gold" or "muted"))
        local taken = SWITCH_W
        self.options:SetShown(options > 0)
        self.options.selected = open
        if options > 0 then
            self.options.label:SetText(options == 1 and "1 option" or (options .. " options"))
            self.options.label:SetTextColor(Style.Color(open and "gold" or "muted"))
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
        -- The name has what's left, and is cut short rather than run under anything.
        self.name:SetWidth(math.max(40, self.wide - 38 - taken - 10))
    end
    -- A part's picture, by its key; none for a part that has none.
    function row:Picture(key)
        self.icon:SetShown(ICON[key] ~= nil)
        if ICON[key] then self.icon:SetTexture(ICON_PATH .. ICON[key]) end
    end
    return row
end

-- One of a part's options, under its row on a darker fill with a gold edge:
-- its name and its switch. What it does is said where the part's is, when
-- it's pointed at.
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
    end)
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
    local openKey, words = nil, ""
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
    -- Every part on one screen, a row each, in three columns by group. The
    -- list scrolls when options are open and a column runs past the foot.
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
    -- A group's heading: its name in gold, how many of its parts are on at
    -- the right, and a rule under it.
    local function GroupHead(i)
        if not groupHeads[i] then groupHeads[i] = Style.Section(list, colW) end
        return groupHeads[i]
    end
    local function Head(i)
        if not heads[i] then heads[i] = Style.Text(list, 10, "muted", nil, true) end
        return heads[i]
    end

    ---------------------------------------------------------------------
    -- The foot. With nothing waiting it says all of the part or option under
    -- the pointer: its picture, name, short line and command, then what it
    -- does in full. While a change waits for a reload, the bar that lists
    -- the changes is there in its place, and a pointed part's words are in a
    -- tooltip.
    ---------------------------------------------------------------------
    local info = CreateFrame("Frame", nil, page)
    info:SetPoint("BOTTOMLEFT")
    info:SetSize(width, BAR_H)
    Style.Box(info, 6, "well", "cardLine")
    local infoTile = CreateFrame("Frame", nil, info)
    infoTile:SetSize(40, 40)
    infoTile:SetPoint("LEFT", 14, 0)
    Style.Box(infoTile, 5, "titleBar", "line")
    info.icon = infoTile:CreateTexture(nil, "ARTWORK")
    info.icon:SetSize(28, 28)
    info.icon:SetPoint("CENTER")
    info.icon:SetVertexColor(Style.Color("gold"))
    info.tile = infoTile
    info.title = Style.Text(info, 14, "text", nil, true)
    info.title:SetPoint("TOPLEFT", 68, -11)
    info.short = Style.Text(info, 12, "secondary")
    info.short:SetPoint("LEFT", info.title, "RIGHT", 10, 0)
    info.command = Style.Tag(info, "")
    info.command:SetPoint("LEFT", info.short, "RIGHT", 10, 0)
    info.note = Style.Text(info, 12, "muted")
    info.note:SetPoint("TOPLEFT", 68, -33)
    info.note:SetWidth(width - 68 - 16)
    info.note:SetJustifyH("LEFT")
    if info.note.SetMaxLines then info.note:SetMaxLines(2) end
    info.idle = Style.Text(info, 12, "muted")
    info.idle:SetPoint("LEFT", 16, 0)
    info.idle:SetText("Point at a part for all it does")
    info.version = Style.Text(info, 11, "muted")
    info.version:SetPoint("RIGHT", -16, 0)
    info.version:SetJustifyH("RIGHT")
    info.version:SetText("jsal.ui " .. ns.version .. ", free from jsal.io")

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

    -- What's under the pointer, said at the foot: (title, short line, all of
    -- it, its command, its picture's key), or nothing to put the hint back.
    local function Say(titleText, short, full, command, key)
        local pointed = titleText ~= nil
        for _, region in ipairs({ info.tile, info.title, info.short, info.note }) do region:SetShown(pointed) end
        info.idle:SetShown(not pointed)
        info.version:SetShown(not pointed)
        info.command:SetShown(pointed and command ~= nil)
        if not pointed then return end
        info.title:SetText(titleText)
        info.short:SetText(short or "")
        info.note:SetText(full or "")
        if command then info.command:Say(command) end
        info.icon:SetShown(key ~= nil and ICON[key] ~= nil)
        if key and ICON[key] then info.icon:SetTexture(ICON_PATH .. ICON[key]) end
    end
    local function Point(titleText, short, full, command, key, owner)
        if bar:IsShown() then
            if full and full ~= "" then
                GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
                GameTooltip:SetText(titleText)
                GameTooltip:AddLine(full, 1, 1, 1, true)
                GameTooltip:Show()
            end
        else
            Say(titleText, short, full, command, key)
        end
    end
    local function Unpoint()
        GameTooltip:Hide()
        Say(nil)
    end

    local function PaintBar()
        local names = {}
        for _, module in ipairs(ns.moduleOrder) do
            if Changed(module) then
                names[#names + 1] = module.title .. (ns.ModuleWanted(module) and " on" or " off")
            end
        end
        bar:SetShown(#names > 0)
        info:SetShown(#names == 0)
        if #names == 0 then return end
        barTitle:SetText(#names == 1 and "1 change waits for a reload" or (#names .. " changes wait for a reload"))
        barList:SetText(table.concat(names, ", "))
    end

    Paint = function()
        -- With words in the box, only the parts that have them, each with
        -- its options open, still under their groups.
        local finding = words ~= ""
        local on, total = 0, 0
        for _, module in ipairs(ns.moduleOrder) do
            total = total + 1
            if ns.ModuleWanted(module) then on = on + 1 end
        end
        summary:SetText(("%d of %d parts are on"):format(on, total))

        local parts, used, grouped, headed, shown = 0, 0, 0, 0, 0
        -- A part's row at (x, y), its options under it when they're open.
        -- Returns how tall it came to.
        local function Place(module, x, at)
            parts = parts + 1
            local row = Row(parts)
            row.module = module
            local wanted = ns.ModuleWanted(module)
            local options = module.options or {}
            local open = #options > 0 and (openKey == module.key or finding)
            local full = module.failed and "Turned off after an error this session. BugSack has the details." or module.note or ""
            row:Set(module.title, wanted, #options, open,
                module.failed and "error" or (Changed(module) and "reload") or nil)
            if module.failed then row.name:SetTextColor(Style.Color("muted")) end
            row:Picture(module.key)
            row.onPoint = function(self) Point(module.title, Short(module), full, Command(module), module.key, self) end
            row.onLeave = Unpoint
            row.onChange = function(now)
                ns.db.modules[module.key] = now
                Paint()
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", x, -at)
            row:Show()
            local tall = ROW_H
            for _, option in ipairs(open and options or {}) do
                used = used + 1
                local o = Option(used)
                o:Set(option.title, option.note, ns.OptionOn(module.key, option.key))
                o.onPoint = function(self) Point(option.title, module.title, option.note or "", nil, module.key, self) end
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

        local at = {}
        for _, group in ipairs(groups) do
            local column = math.max(1, math.min(COLUMNS, group.column or COLUMNS))
            local x = 6 + (column - 1) * (colW + COLUMN_GAP)
            -- What this group shows, a list for each of its headings.
            local lists, any, groupOn = {}, 0, 0
            for i, section in ipairs(group.sections) do
                lists[i] = {}
                for _, module in ipairs(section.modules) do
                    if ns.ModuleWanted(module) then groupOn = groupOn + 1 end
                    if not finding or Matches(module, words) then
                        lists[i][#lists[i] + 1] = module
                        any = any + 1
                    end
                end
            end
            if any > 0 then
                local y = at[column] and (at[column] + GROUP_GAP) or 0
                grouped = grouped + 1
                local head = GroupHead(grouped)
                head.title:SetText(group.title:upper())
                head.note:SetText(("%d of %d on"):format(groupOn, #group.modules))
                head:ClearAllPoints()
                head:SetPoint("TOPLEFT", x, -y)
                head:Show()
                y = y + GROUP_H
                for i, section in ipairs(group.sections) do
                    if #lists[i] > 0 then
                        headed = headed + 1
                        local small = Head(headed)
                        small:SetText(section.title:upper())
                        small:ClearAllPoints()
                        small:SetPoint("TOPLEFT", x, -(y + 2))
                        small:Show()
                        y = y + HEAD_H
                        for _, module in ipairs(lists[i]) do
                            y = y + Place(module, x, y)
                            shown = shown + 1
                        end
                        y = y + 6
                    end
                end
                at[column] = y
            end
        end
        for i = parts + 1, #rows do rows[i]:Hide() end
        for i = used + 1, #optionRows do optionRows[i]:Hide() end
        for i = grouped + 1, #groupHeads do groupHeads[i]:Hide() end
        for i = headed + 1, #heads do heads[i]:Hide() end
        none:SetShown(shown == 0)
        if shown == 0 then none:SetText(("Nothing in jsal.ui matches \"%s\"."):format(words)) end
        local tallest = 1
        for column = 1, COLUMNS do tallest = math.max(tallest, at[column] or 0) end
        list:SetHeight(tallest)
        scroll:UpdateScrollChildRect()
        scroll:Place()
        PaintBar()
    end

    page.Refresh = function()
        Say(nil)
        Paint()
    end
end, nil, true)
