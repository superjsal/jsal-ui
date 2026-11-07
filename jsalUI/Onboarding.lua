-- Setup: a short guided tour the first time jsal.ui runs, and any time from
-- Settings or /jsal setup. Seven steps down the side (welcome, how you play,
-- the look, your other addons, which parts of jsal.ui, your guild, done),
-- each one skippable; parts switched on or off apply after a reload, which
-- the last step offers. It closes as a fight starts, like the dashboard,
-- since its Reload button is the game's own secure one.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local Setup = {}
ns.Setup = Setup

local WIDTH, HEIGHT, SIDE, PAD = 780, 520, 190, 22
local STEPS = {
    { key = "welcome", label = "Welcome" },
    { key = "you", label = "You" },
    { key = "look", label = "The look" },
    { key = "addons", label = "Your addons" },
    { key = "parts", label = "jsal.ui parts" },
    { key = "guild", label = "Your guild" },
    { key = "done", label = "Done" },
}

-- The parts, in groups a player can understand at a glance; each switch
-- turns its whole group on or off.
local GROUPS = {
    { label = "Journal and session recap", keys = { "journal" } },
    { label = "Daily Word, Icon Guess, chess and the flight bar", keys = { "dailyword", "iconguess", "chess", "flight" } },
    { label = "Talents, training and level-up help", keys = { "talents", "trainingpanel", "levelup" } },
    { label = "Professions and the shopping list", keys = { "professionpanel", "profwindow", "shopping" } },
    { label = "Quick buttons and the minimap button", keys = { "launcher", "minimap" } },
    { label = "Vendor run, bag and gear warnings", keys = { "vendor", "warnings" } },
    { label = "Quests on autopilot", keys = { "quests" } },
}
local GUILD_KEYS = { "guild", "crafters", "layers" }

-- Starting points for the parts step.
local PRESETS = {
    { key = "casual", label = "Casual", note = "Games, Journal, guild and helpers" },
    { key = "everything", label = "Everything", note = "All of it, autopilot too" },
    { key = "look", label = "Just the look", note = "Only the UI pack and its minimap button" },
}
local function PresetWants(preset, key)
    if preset == "everything" then return true end
    if preset == "look" then return key == "minimap" end
    return key ~= "quests"
end

local PLAYS = {
    { key = "casual", label = "Casually", note = "Questing, games, the guild", preset = "casual" },
    { key = "group", label = "Dungeons and raids", note = "Planners, timers, meters", preset = "casual" },
    { key = "craft", label = "Crafting", note = "Professions first", preset = "casual" },
    { key = "all", label = "A bit of everything", note = "All of it", preset = "everything" },
}

---------------------------------------------------------------------------
-- What the steps change: chosen parts are kept here until Done, so Back
-- and Next never lose a choice.
---------------------------------------------------------------------------
local chosen, play, preset, startWanted

local function Wanted(key)
    local module = ns.modules[key]
    if not module then return nil end
    if chosen[key] ~= nil then return chosen[key] end
    return ns.ModuleWanted(module)
end

local function ApplyPreset(name)
    preset = name
    for _, group in ipairs(GROUPS) do
        for _, key in ipairs(group.keys) do
            if ns.modules[key] then chosen[key] = PresetWants(name, key) end
        end
    end
    for _, key in ipairs(GUILD_KEYS) do
        if ns.modules[key] then chosen[key] = name ~= "look" end
    end
end
Setup.ApplyPreset = ApplyPreset

local function GroupOn(group)
    local any, all = false, true
    for _, key in ipairs(group.keys) do
        local on = Wanted(key)
        if on ~= nil then
            any = true
            all = all and on
        end
    end
    return any and all
end

local function SetGroup(group, on)
    for _, key in ipairs(group.keys) do
        if ns.modules[key] then chosen[key] = on end
    end
end
Setup.SetGroup = SetGroup

-- Saves the chosen parts; returns whether any changed (so a reload is due).
function Setup.Save()
    local changed = false
    for key, on in pairs(chosen) do
        local module = ns.modules[key]
        if module and ns.ModuleWanted(module) ~= on then
            ns.db.modules[key] = on
            changed = true
        end
    end
    ns.db.setup = { done = ns.codeVersion, play = play, preset = preset }
    return changed
end

function Setup.Changes()
    local on, off = 0, 0
    for key, want in pairs(chosen) do
        local module = ns.modules[key]
        if module and startWanted[key] ~= want then
            if want then on = on + 1 else off = off + 1 end
        end
    end
    return on, off
end

---------------------------------------------------------------------------
-- The window.
---------------------------------------------------------------------------
local frame, content, stepButtons, pages, current = nil, nil, {}, {}, 1
local back, nextButton, counter

local function Choice(parent, width, height, label, note)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    b.bg = Style.Fill(b, "well")
    b.edges = Style.Border(b, "lineStrong")
    b.label = Style.Text(b, 13, "text", nil, true)
    b.label:SetPoint("TOPLEFT", 10, -9)
    b.label:SetText(label)
    b.note = Style.Text(b, 12, "muted")
    b.note:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -3)
    b.note:SetWidth(width - 20)
    b.note:SetJustifyH("LEFT")
    b.note:SetText(note or "")
    function b:SetPicked(on) Style.SetBorder(self.edges, on and "gold" or "lineStrong") end
    return b
end

local function Heading(page, title, lead)
    local h = Style.Text(page, 18, "text", nil, true)
    h:SetPoint("TOPLEFT", 0, 0)
    h:SetText(title)
    local p = Style.Text(page, 13, "muted")
    p:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
    p:SetWidth(WIDTH - SIDE - PAD * 2)
    p:SetJustifyH("LEFT")
    p:SetText(lead or "")
    return h, p
end

local function SwitchRow(parent, y, width, label, get, set)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, 28)
    row:SetPoint("TOPLEFT", 0, y)
    Style.Rule(row, "BOTTOM", "line")
    row.name = Style.Text(row, 13, "text")
    row.name:SetPoint("LEFT")
    row.name:SetText(label)
    row.switch = Style.Switch(row, function(on) set(on) end)
    row.switch:SetPoint("RIGHT")
    row:SetScript("OnClick", function() row.switch:Click() end)
    function row:Refresh() self.switch:SetOn(get()) end
    return row
end

local BUILD = {}
local innerW = WIDTH - SIDE - PAD * 2

BUILD.welcome = function(page)
    Heading(page, "Welcome to jsal.ui",
        "jsal.ui adds daily games for your guild, a journal of your character's story, planners for your road to 60 and a few easy helpers.")
    local p = Style.Text(page, 13, "text")
    p:SetPoint("TOPLEFT", 0, -90)
    p:SetWidth(innerW)
    p:SetJustifyH("LEFT")
    p:SetText("This setup takes a minute: pick what you want and skip what you don't. Nothing changes until the last step, and you can run it again any time from Settings or with /jsal setup.")
end

BUILD.you = function(page)
    local _, lead = Heading(page, "How do you play?", "")
    local tiles = {}
    local tileW = math.floor((innerW - 10) / 2)
    for i, p in ipairs(PLAYS) do
        local t = Choice(page, tileW, 56, p.label, p.note)
        t:SetPoint("TOPLEFT", ((i - 1) % 2) * (tileW + 10), -70 - math.floor((i - 1) / 2) * 66)
        t:SetScript("OnClick", function()
            play = p.key
            ApplyPreset(p.preset)
            for _, other in ipairs(tiles) do other:SetPicked(other == t) end
        end)
        t.key = p.key
        tiles[i] = t
    end
    page.Refresh = function()
        local className = UnitClass("player")
        lead:SetText(("You're a level %d %s. jsal.ui picks its parts to match how you play; you can change any of them on the next steps."):format(UnitLevel("player") or 0, className or ""))
        for _, t in ipairs(tiles) do t:SetPicked(t.key == play) end
    end
end

BUILD.look = function(page)
    local _, lead = Heading(page, "The look", "")
    local install = Style.Button(page, "Install the jsal.ui look", "primary", 220)
    install:SetPoint("TOPLEFT", 0, -110)
    local note = Style.Text(page, 13, "muted")
    note:SetPoint("TOPLEFT", install, "BOTTOMLEFT", 0, -12)
    note:SetWidth(innerW)
    note:SetJustifyH("LEFT")
    install:SetScript("OnClick", function()
        local ok, why = ns.Installer.Install()
        note:SetText(ok and "Installed. It takes over after the reload at the end of setup." or why)
        page.Refresh()
    end)
    page.Refresh = function()
        local state = ns.Installer.State()
        lead:SetText("jsal.ui's look is an EllesmereUI profile: bars, frames, minimap and damage meters in one dark, clean style. Your own EllesmereUI profiles stay as they are. " .. (ns.Installer.Message(state) or ""))
        install:SetShown(ns.Installer.CanInstall(state) and state ~= "installed")
        if state == "installed" then note:SetText("You're on the jsal.ui look.") end
        if not ns.Installer.CanInstall(state) then note:SetText("You can keep your own look: press Next.") end
    end
end

-- Other addons jsal.ui can set up to match; the rows show only what's
-- installed, and a profile not made yet says so.
local OTHERS = {
    { addon = "NaowhForever", label = "NaowhForever", note = "Its quality-of-life settings" },
    { addon = "BigWigs", label = "BigWigs", note = "Boss timers" },
    { addon = "Details", label = "Details", note = "Damage meter window" },
    { addon = "Plater", label = "Plater", note = "Nameplates" },
}

BUILD.addons = function(page)
    Heading(page, "Your other addons", "jsal.ui can set these up to match. Only the ones you have are listed.")
    local rows = {}
    local function Row(i)
        if rows[i] then return rows[i] end
        local r = CreateFrame("Frame", nil, page)
        r:SetSize(innerW, 46)
        r:SetPoint("TOPLEFT", 0, -64 - (i - 1) * 50)
        Style.Rule(r, "BOTTOM", "line")
        r.name = Style.Text(r, 14, "text", nil, true)
        r.name:SetPoint("TOPLEFT", 0, -6)
        r.note = Style.Text(r, 12, "muted")
        r.note:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
        r.tag = Style.Text(r, 12, "muted")
        r.tag:SetPoint("RIGHT")
        rows[i] = r
        return r
    end
    page.Refresh = function()
        for _, r in ipairs(rows) do r:Hide() end
        local i = 0
        local function Add(label, note, tag)
            i = i + 1
            local r = Row(i)
            r.name:SetText(label)
            r.note:SetText(note)
            r.tag:SetText(tag)
            r:Show()
        end
        local state = ns.Installer.State()
        Add("EllesmereUI", "Bars, frames, minimap and damage meters",
            state == "installed" and "|cff56944fSet up|r" or state == "missing" and "Not installed"
            or state == "noProfile" and "Coming soon" or "On the previous step")
        for _, o in ipairs(OTHERS) do
            if Compat.AddOnExists(o.addon) then Add(o.label, o.note, "Coming soon") end
        end
    end
end

BUILD.parts = function(page)
    Heading(page, "Which parts of jsal.ui?", "Start from a set, then change any switch. You can change them later in Settings.")
    local tileW = math.floor((innerW - 20) / 3)
    local tiles = {}
    local switches = {}
    local function RefreshSwitches() for _, s in ipairs(switches) do s:Refresh() end end
    for i, p in ipairs(PRESETS) do
        local t = Choice(page, tileW, 52, p.label, p.note)
        t:SetPoint("TOPLEFT", (i - 1) * (tileW + 10), -62)
        t:SetScript("OnClick", function()
            ApplyPreset(p.key)
            for _, other in ipairs(tiles) do other:SetPicked(other == t) end
            RefreshSwitches()
        end)
        t.key = p.key
        tiles[i] = t
    end
    local y = -128
    for _, group in ipairs(GROUPS) do
        local any = false
        for _, key in ipairs(group.keys) do any = any or ns.modules[key] ~= nil end
        if any then
            switches[#switches + 1] = SwitchRow(page, y, innerW, group.label, function() return GroupOn(group) end,
                function(on)
                    SetGroup(group, on)
                    preset = nil
                    for _, t in ipairs(tiles) do t:SetPicked(false) end
                end)
            y = y - 30
        end
    end
    page.Refresh = function()
        for _, t in ipairs(tiles) do t:SetPicked(t.key == preset) end
        RefreshSwitches()
    end
end

BUILD.guild = function(page)
    local _, lead = Heading(page, "Your guild", "")
    local rows = {
        SwitchRow(page, -96, innerW, "Guild tab: who has jsal.ui, today's scores, the Guild Word",
            function() return Wanted("guild") ~= false end, function(on) chosen.guild = on end),
        SwitchRow(page, -126, innerW, "Guild crafters: share your recipes, see who makes what",
            function() return Wanted("crafters") ~= false end, function(on) chosen.crafters = on end),
        SwitchRow(page, -156, innerW, "Layers: change layers by joining a guildmate",
            function() return Wanted("layers") ~= false end, function(on) chosen.layers = on end),
    }
    page.Refresh = function()
        if IsInGuild() then
            local count = 0
            for _ in pairs(ns.Guild and ns.Guild.Members and ns.Guild.Members() or {}) do count = count + 1 end
            lead:SetText(("jsal.ui works best with guildmates who have it too: %s. Messages between you travel out of sight, never in chat.")
                :format(count == 0 and "none heard from yet this session" or (count == 1 and "1 heard from this session" or (count .. " heard from this session"))))
        else
            lead:SetText("You're not in a guild. These parts wait until you join one; leave them on and they'll start then.")
        end
        for _, r in ipairs(rows) do r:Refresh() end
    end
end

BUILD.done = function(page)
    local _, lead = Heading(page, "All set", "")
    local reload = CreateFrame("Button", "jsalUISetupReload", page, "SecureActionButtonTemplate")
    reload:SetAttribute("type", "macro")
    reload:SetAttribute("macrotext", "/reload")
    reload:RegisterForClicks("AnyUp", "AnyDown")
    reload:SetSize(180, 30)
    reload:SetPoint("TOPLEFT", 0, -110)
    Style.Fill(reload, "gold")
    local label = Style.Text(reload, 13, "onGold", nil, true)
    label:SetPoint("CENTER")
    label:SetText("Reload and finish")
    reload:HookScript("OnClick", function() Setup.Save() end)
    page.Refresh = function()
        local on, off = Setup.Changes()
        if on + off == 0 then
            lead:SetText("Nothing to switch on or off. Press Finish to close, and open the dashboard any time with /jsal.")
            reload:Hide()
        else
            lead:SetText(("%d part%s switched on and %d off. Parts start and stop on a reload, so reload to finish; you can change them later in Settings.")
                :format(on, on == 1 and "" or "s", off))
            reload:Show()
        end
    end
end

local function Show(i)
    current = math.max(1, math.min(#STEPS, i))
    for n, step in ipairs(STEPS) do
        local page = pages[step.key]
        if n == current and not page then
            page = CreateFrame("Frame", nil, content)
            page:SetAllPoints()
            BUILD[step.key](page)
            pages[step.key] = page
        end
        if page then page:SetShown(n == current) end
        local b = stepButtons[n]
        b.bg:SetShown(n == current)
        b.mark:SetShown(n == current)
        b.num:SetText(n < current and "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t" or tostring(n))
        b.label:SetTextColor(Style.Color(n == current and "text" or "muted"))
    end
    local page = pages[STEPS[current].key]
    if page.Refresh then xpcall(page.Refresh, ns.Report) end
    back:SetShown(current > 1)
    counter:SetText(("Step %d of %d"):format(current, #STEPS))
    nextButton.label:SetText(current == #STEPS and "Finish" or (current == 1 and "Start" or "Next"))
end
Setup.Show = Show

local function Finish()
    Setup.Save()
    frame:Hide()
end

local function Build()
    frame = Style.Panel("jsalUISetup", WIDTH, HEIGHT, "Set up jsal.ui")
    frame:SetFrameStrata("DIALOG")
    -- Closing it early counts as seen, so it doesn't open again by itself.
    frame:HookScript("OnHide", function()
        ns.db.setup = ns.db.setup or { done = ns.codeVersion, skipped = true }
    end)
    local side = CreateFrame("Frame", nil, frame)
    side:SetPoint("TOPLEFT", 0, -32)
    side:SetPoint("BOTTOMLEFT")
    side:SetWidth(SIDE)
    Style.Fill(side, "titleBar")
    Style.Rule(side, "RIGHT", "line")
    for n, step in ipairs(STEPS) do
        local b = CreateFrame("Button", nil, side)
        b:SetSize(SIDE - 16, 30)
        b:SetPoint("TOPLEFT", 8, -14 - (n - 1) * 34)
        b.bg = Style.Fill(b, "well")
        b.mark = b:CreateTexture(nil, "ARTWORK")
        b.mark:SetColorTexture(Style.Color("gold"))
        b.mark:SetPoint("TOPLEFT")
        b.mark:SetPoint("BOTTOMLEFT")
        b.mark:SetWidth(2)
        b.num = Style.Text(b, 12, "muted", nil, true)
        b.num:SetPoint("LEFT", 12, 0)
        b.label = Style.Text(b, 13, "muted")
        b.label:SetPoint("LEFT", 34, 0)
        b.label:SetText(step.label)
        b:SetScript("OnClick", function() Show(n) end)
        stepButtons[n] = b
    end
    content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", SIDE + PAD, -32 - PAD)
    content:SetPoint("BOTTOMRIGHT", -PAD, 64)
    back = Style.Button(frame, "Back", "plain", 90)
    back:SetPoint("BOTTOMLEFT", SIDE + PAD, 18)
    back:SetScript("OnClick", function() Show(current - 1) end)
    nextButton = Style.Button(frame, "Next", "primary", 110)
    nextButton:SetPoint("BOTTOMRIGHT", -PAD, 18)
    nextButton:SetScript("OnClick", function()
        if current == #STEPS then Finish() else Show(current + 1) end
    end)
    counter = Style.Text(frame, 12, "muted")
    counter:SetPoint("BOTTOM", (SIDE) / 2, 26)
    local skip = Style.Text(frame, 12, "muted")
    skip:SetPoint("BOTTOMLEFT", 16, 26)
    skip:SetText("Esc closes setup")
end

function Setup.Open()
    if Compat.InCombat() then return ns.Print("Setup opens once combat ends.") end
    if not frame then Build() end
    chosen, preset = {}, (ns.db.setup and ns.db.setup.preset) or nil
    play = ns.db.setup and ns.db.setup.play or nil
    startWanted = {}
    for key, module in pairs(ns.modules) do startWanted[key] = ns.ModuleWanted(module) end
    frame:Show()
    Show(1)
end

ns.Command("setup", Setup.Open)

-- The secure Reload button can't be shown or hidden in combat, so setup
-- closes as a fight starts.
local combat = CreateFrame("Frame")
combat:RegisterEvent("PLAYER_REGEN_DISABLED")
combat:SetScript("OnEvent", function()
    if frame and frame:IsShown() then frame:Hide() end
end)

-- The first time jsal.ui runs, setup opens a few seconds after login,
-- once out of combat.
ns.OnLogin(function()
    if ns.db.setup then return end
    Compat.After(8, function()
        if ns.db.setup or Compat.InCombat() then return end
        xpcall(Setup.Open, ns.Report)
    end)
end)
