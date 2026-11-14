-- Quest tags: beside each quest in the tracker, its place in a chain ("1/4" is the first of four,
-- so skipping it loses the three after it; none when it stands alone) and about how many minutes
-- it's likely to take, green to red. Hovering them shows the reasons. For when you're ahead of
-- your guide and want to drop the slow quests that lead nowhere.
--
-- The minutes are the kills still needed times how long your fights last. A kill objective needs
-- what's left of it. An item that drops p of the time, n still needed, takes
-- (n + sqrt(n * (1 - p))) / p kills: the kills it takes on average, plus how far that usually
-- swings, so an unlucky run is counted, not a lucky one. A fight's length is a running average
-- of your own fights, solo and outside dungeons, from entering combat to leaving it.
--
-- Chains and drop chances come from pfQuest (QuestScoreData.lua); what's left comes from your
-- quest log as you go. The tags go left of whichever tracker shows: EllesmereUI's own, through
-- the hook it offers other addons, or the game's, so they take no room from the titles.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local QuestTags = ns.NewModule("questtags", {
    title = "Quest tags",
    -- Something new beside the tracker, so it starts off.
    defaultOn = false,
    note = "Beside each quest in your tracker: its place in a chain (1/4 is the first of four) and about how many minutes it will take, from how often its items drop and how long your fights last. Hover them for the details.",
})
ns.QuestTags = QuestTags

local DEFAULT_FIGHT = 20        -- seconds a fight is taken to last until you've had one
local WINDOW = 20               -- the average follows your last twenty or so fights
local SHORTEST, LONGEST = 2, 120
local GUESS = 3                 -- fewer fights than this, and the card says it's a guess
local HEIGHT, PAD = 17, 5       -- a pill's height, and the room inside it
local EDGE = 6                  -- between a pill and EllesmereUI's tracker
local GAP = 26                  -- left of a game tracker block, past its map button

---------------------------------------------------------------------------
-- The data: one line per quest, read when first asked for.
---------------------------------------------------------------------------
local parsed = {}

-- { step, chain, drops = { [item name] = chance 0..1 } }, or nil for a quest it doesn't know.
function QuestTags.Info(questID)
    local known = parsed[questID]
    if known ~= nil then return known or nil end
    local line = ns.QuestScoreData and ns.QuestScoreData[questID]
    if type(line) ~= "string" then
        parsed[questID] = false
        return nil
    end
    local info = { drops = {} }
    local chain, rest = line:match("^([^;]*)(.*)$")
    local step, of = chain:match("^(%d+),(%d+)$")
    if step then info.step, info.chain = tonumber(step), tonumber(of) end
    for name, chance, mark in rest:gmatch(";([^=;]+)=([%d%.]+)([wo]?)") do
        info.drops[name] = tonumber(chance) / 100
        -- "w": Wowhead Forever's chance from Forever's own kills; "o": from objects opened (chests,
        -- crates, plants), each opening counted like a fight; neither: pfQuest's (Classic's).
        if mark ~= "" then
            info.wowhead = info.wowhead or {}
            info.wowhead[name] = mark
        end
    end
    parsed[questID] = info
    return info
end

---------------------------------------------------------------------------
-- How long your fights last.
---------------------------------------------------------------------------
local function Fights()
    local saved = ns.char and ns.char.questFights
    if type(saved) ~= "table" or type(saved.average) ~= "number" or type(saved.count) ~= "number" then
        saved = { average = DEFAULT_FIGHT, count = 0 }
        if ns.char then ns.char.questFights = saved end
    end
    return saved
end

-- Seconds a fight takes, and how many fights that's from.
function QuestTags.FightSeconds()
    local f = Fights()
    return f.average, f.count
end

function QuestTags.AddFight(seconds)
    seconds = math.min(LONGEST, math.max(SHORTEST, seconds))
    local f = Fights()
    if f.count == 0 then
        f.average = seconds
    else
        f.average = f.average + (seconds - f.average) / math.min(f.count + 1, WINDOW)
    end
    f.count = math.min(f.count + 1, 999)
end

---------------------------------------------------------------------------
-- What's left of a quest.
---------------------------------------------------------------------------
-- Kills likely needed for n items that drop p of the time (1 for a kill objective).
function QuestTags.Kills(n, p)
    if p >= 1 then return n end
    return (n + math.sqrt(n * (1 - p))) / p
end

-- The thing an objective names, from "Ghoul Fang: 1/10" or "1/10 Ghoul Fang".
local function Named(text)
    text = text or ""
    return text:match("^(.-):%s*%d+%s*/%s*%d+%s*$") or text:match("^%d+%s*/%s*%d+%s+(.+)$") or text
end

-- The item's drop chance, and whether it's Wowhead Forever's.
local function Chance(info, name)
    if not info then return nil end
    local found = info.drops[name] and name
    if not found then
        local lower = name:lower()
        for item in pairs(info.drops) do
            if item:lower() == lower then found = item end
        end
    end
    if found then return info.drops[found], info.wowhead and info.wowhead[found] or false end
end

-- Objective by objective, what's left: { name, left, chance (nil for a kill), kills (nil when
-- unknown) }; the kills in all; and the first item with no known drop chance, if any.
function QuestTags.Work(questID)
    local info = QuestTags.Info(questID)
    local objectives = C_QuestLog.GetQuestObjectives(questID)
    local rows, total, unknown = {}, 0, nil
    for _, o in ipairs(type(objectives) == "table" and objectives or {}) do
        local left = (o.numRequired or 0) - (o.numFulfilled or 0)
        if not o.finished and left > 0 and (o.type == "monster" or o.type == "item") then
            local name = Named(o.text)
            local row = { name = name, left = left }
            if o.type == "monster" then
                row.name = name:gsub("%s+slain$", "")
                row.kills = left
            else
                row.chance, row.wowhead = Chance(info, name)
                if row.chance then row.kills = QuestTags.Kills(left, row.chance) end
            end
            if row.kills then total = total + row.kills else unknown = unknown or name end
            rows[#rows + 1] = row
        end
    end
    return rows, total, unknown
end

-- The two tags: the chain's "k/n" (nil standing alone), and the minutes with their colour; then
-- the minutes as a number (nil when there's nothing to fight or a drop rate is unknown).
function QuestTags.Tags(questID)
    local info = QuestTags.Info(questID)
    local step = info and info.step and ("%d/%d"):format(info.step, info.chain) or nil
    local _, total, unknown = QuestTags.Work(questID)
    if unknown then return step, "?", "muted" end
    if total <= 0 then return step, "-", "muted" end
    local minutes = total * QuestTags.FightSeconds() / 60
    local colour = minutes < 4 and "green" or minutes < 9 and "gold" or "red"
    if minutes < 1 then return step, "<1m", colour, minutes end
    return step, ("%dm"):format(math.floor(minutes + 0.5)), colour, minutes
end

---------------------------------------------------------------------------
-- The card, on hovering the tags.
---------------------------------------------------------------------------
function QuestTags.ChainLine(questID)
    local info = QuestTags.Info(questID)
    if not info then return "Not in jsal.ui's quest data yet, so whether other quests follow it isn't known." end
    if not info.step then return "Not part of a chain: skipping it loses no other quests." end
    local after = info.chain - info.step
    if after <= 0 then
        return ("The last of a chain of %d: skipping it loses no other quests."):format(info.chain)
    end
    return ("Quest %d of a chain of %d: skipping it loses the %s after it."):format(info.step, info.chain,
        after == 1 and "one" or tostring(after))
end

local function Row(r)
    if not r.chance then
        if r.kills then return ("%d to kill"):format(r.left) end
        return ("%d left, drop rate unknown"):format(r.left)
    end
    local kills = math.max(1, math.floor(r.kills + 0.5))
    local per = ("%g"):format(math.floor(r.chance * 1000 + 0.5) / 10)
    if r.wowhead == "o" then
        return ("%d left, %s%% per opening: about %d opening%s"):format(r.left, per, kills, kills == 1 and "" or "s")
    end
    return ("%d left, %s%% drop: about %d kill%s"):format(r.left, per, kills, kills == 1 and "" or "s")
end

-- Where the card's drop chances came from, or nil when it shows none.
local function Sources(rows)
    local wowhead, classic
    for _, r in ipairs(rows) do
        if r.chance and r.wowhead then wowhead = true elseif r.chance then classic = true end
    end
    if wowhead and classic then return "Drop chances from Wowhead Forever and pfQuest (Classic's)" end
    if wowhead then return "Drop chances from what Wowhead Forever has seen drop" end
    if classic then return "Drop chances from pfQuest: Classic's, so a few may differ on Forever" end
end

local function Rgb(key) local r, g, b = Style.Color(key); return r, g, b end

-- A line in a colour, wrapped. Rgb's three numbers only all arrive when they come last in a
-- call, so a wrapped line can't take Rgb(key) followed by true.
local function Add(tip, text, key)
    local r, g, b = Style.Color(key)
    tip:AddLine(text, r, g, b, true)
end

function QuestTags.ShowCard(owner, questID)
    local tip = GameTooltip
    tip:SetOwner(owner, "ANCHOR_LEFT")
    tip:SetText(C_QuestLog.GetTitleForQuestID(questID) or "Quest", Rgb("text"))
    Add(tip, QuestTags.ChainLine(questID), "muted")
    local rows, total, unknown = QuestTags.Work(questID)
    local seconds, fights = QuestTags.FightSeconds()
    local _, _, colour, minutes = QuestTags.Tags(questID)
    tip:AddLine(" ")
    if unknown then
        Add(tip, ("Annoyance: unknown. How often %s drops isn't known."):format(unknown), "muted")
    elseif total <= 0 then
        Add(tip, C_QuestLog.IsComplete(questID) and "Ready to turn in." or "Nothing to fight for.", "muted")
    else
        local whole = math.max(1, math.floor(minutes + 0.5))
        Add(tip, ("Annoyance: about %s"):format(whole == 1 and "a minute" or (whole .. " minutes")), colour)
        local opens = false
        for _, r in ipairs(rows) do
            if r.wowhead == "o" then opens = true end
        end
        local count = math.max(1, math.floor(total + 0.5))
        Add(tip, ("About %d %s at %d seconds a fight, your average%s"):format(count,
            opens and "kills and openings" or (count == 1 and "kill" or "kills"), math.floor(seconds + 0.5),
            fights < GUESS and " (a guess until you've had a few fights)" or ""), "muted")
    end
    for _, r in ipairs(rows) do
        local lr, lg, lb = Rgb("secondary")
        local rr, rg, rb = Rgb("muted")
        tip:AddDoubleLine(r.name, Row(r), lr, lg, lb, rr, rg, rb)
    end
    local sources = Sources(rows)
    if sources then Add(tip, sources, "muted") end
    tip:Show()
end

---------------------------------------------------------------------------
-- The tags.
---------------------------------------------------------------------------
local function Line(parent)
    local text = Style.Text(parent, 12, "muted", nil, true, true)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    return text
end

-- One small dark pill: the chain's "k/n", then the minutes.
local function MakeTag(parent)
    local tag = CreateFrame("Frame", nil, parent)
    tag:SetSize(PAD * 2, HEIGHT)
    local fill = Style.Fill(tag, "window")
    fill:SetAlpha(0.88)
    Style.Border(tag, "lineStrong")
    tag.minutes = Line(tag)
    tag.minutes:SetPoint("RIGHT", tag, "RIGHT", -PAD, 0)
    tag.step = Line(tag)
    tag.step:SetPoint("LEFT", tag, "LEFT", PAD, 0)
    tag.step:SetTextColor(Style.Color("secondary"))
    tag:EnableMouse(true)
    tag:SetScript("OnEnter", ns.Safe(QuestTags, function(self)
        if self.questID then QuestTags.ShowCard(self, self.questID) end
    end))
    tag:SetScript("OnLeave", ns.Safe(QuestTags, function() GameTooltip:Hide() end))
    return tag
end
QuestTags.MakeTag = MakeTag

-- Nothing to fight leaves the minutes out; a quest that also stands alone gets no pill at all.
function QuestTags.Fill(tag, questID)
    local step, minutes, colour = QuestTags.Tags(questID)
    if minutes == "-" then minutes = nil end
    tag.questID = questID
    if not (step or minutes) then
        tag:Hide()
        return
    end
    tag.step:SetText(step or "")
    tag.minutes:SetText(minutes or "")
    tag.minutes:SetTextColor(Style.Color(colour))
    local width = PAD * 2
    if minutes then width = width + tag.minutes:GetStringWidth() end
    if step then width = width + tag.step:GetStringWidth() end
    if step and minutes then width = width + PAD end
    tag:SetWidth(math.max(HEIGHT + 4, math.floor(width + 0.5)))
    tag:Show()
end

-- EllesmereUI's own tracker: its hook runs for each quest title row on every redraw, with a slot
-- frame on the row. The tags go left of the tracker, outside its scrolling list, which hides
-- anything drawn outside it; so each pill is jsal.ui's own frame that follows its row, and fades
-- out while the row is scrolled out of sight or gone.
local function Corner(frame, edge)
    local v = edge == "left" and frame:GetLeft() or edge == "top" and frame:GetTop() or frame:GetBottom()
    return v and v * frame:GetEffectiveScale()
end

-- When EllesmereUI last drew its list: it hands each quest row to the hook within one frame, so a
-- pill not handed over then belongs to a row it has since given to something else (a zone heading).
local lastDrawn

function QuestTags.Follow(tag)
    local row, view = tag.row, tag.view
    local top, bottom, left = Corner(row, "top"), Corner(row, "bottom"), Corner(row, "left")
    local vtop, vbottom, vleft = Corner(view, "top"), Corner(view, "bottom"), Corner(view, "left")
    local seen = QuestTags.running and tag.drawn == lastDrawn and row:IsVisible()
        and top and vtop and top <= vtop + 1 and bottom >= vbottom - 1
    if seen then
        local x = math.floor((vleft - left) / tag:GetEffectiveScale() - EDGE + 0.5)
        if x ~= tag.x then
            tag.x = x
            tag:ClearAllPoints()
            tag:SetPoint("TOPRIGHT", row, "TOPLEFT", x, 1)
        end
    end
    if seen ~= tag.seen then
        tag.seen = seen
        tag:SetAlpha(seen and 1 or 0)
        tag:EnableMouse(seen and true or false)
    end
end

-- Every pill on EllesmereUI's tracker, so a redraw can settle them all at once.
local pills = {}

local function Settle()
    for _, tag in ipairs(pills) do QuestTags.Follow(tag) end
end

local function EllesmereRow(slot, questID)
    local tag = slot.jsalTag
    if not (QuestTags.running and type(questID) == "number") then
        if tag then tag:Hide() end
        return
    end
    if not tag then
        tag = MakeTag(UIParent)
        tag.row = slot:GetParent()
        -- The row is in the list's scrolling child; the scroll frame is what shows.
        tag.view = tag.row:GetParent():GetParent()
        local wait = 0
        tag:SetScript("OnUpdate", ns.Safe(QuestTags, function(self, elapsed)
            wait = wait + elapsed
            if wait < 0.1 then return end
            wait = 0
            QuestTags.Follow(self)
        end))
        slot.jsalTag = tag
        pills[#pills + 1] = tag
    end
    -- The first row of a redraw: once it's done (the next frame), every pill it didn't hand over
    -- fades at once, rather than at its next tenth-of-a-second look.
    local now = GetTime()
    if now ~= lastDrawn then
        lastDrawn = now
        C_Timer.After(0, ns.Safe(QuestTags, Settle))
    end
    tag.drawn = lastDrawn
    QuestTags.Fill(tag, questID)
    QuestTags.Follow(tag)
end

-- The game's tracker: each quest is a block keyed by its quest ID; its tags sit left of it.
local TRACKERS = { "QuestObjectiveTracker", "CampaignQuestObjectiveTracker" }
local blockTags = {}   -- [tracker] = { [block] = tag }

local function PaintTracker(tracker)
    local tags = blockTags[tracker] or {}
    blockTags[tracker] = tags
    local seen = {}
    if QuestTags.running and tracker.EnumerateActiveBlocks then
        tracker:EnumerateActiveBlocks(function(block)
            if type(block.id) ~= "number" or not block:IsShown() then return end
            local tag = tags[block] or MakeTag(block)
            tags[block] = tag
            tag:ClearAllPoints()
            tag:SetPoint("TOPRIGHT", block.HeaderText or block, "TOPLEFT", -GAP, 1)
            QuestTags.Fill(tag, block.id)
            -- EllesmereUI's own tracker hides this one (see-through, not hidden): no hovering it then.
            tag:EnableMouse(block:GetEffectiveAlpha() > 0.1)
            seen[block] = true
        end)
    end
    for block, tag in pairs(tags) do
        if not seen[block] then tag:Hide() end
    end
end

local hooked = {}
local function HookTrackers()
    for _, name in ipairs(TRACKERS) do
        local tracker = _G[name]
        if tracker and tracker.EndLayout and not hooked[name] then
            hooked[name] = true
            hooksecurefunc(tracker, "EndLayout", ns.Safe(QuestTags, PaintTracker))
        end
    end
end

-- Draws every tag again, on both trackers: after a fight changes the average.
function QuestTags.Refresh()
    for _, name in ipairs(TRACKERS) do
        if _G[name] and hooked[name] then PaintTracker(_G[name]) end
    end
    if EllesmereUI and EllesmereUI.RefreshQuestTrackerRows then EllesmereUI.RefreshQuestTrackerRows() end
end

---------------------------------------------------------------------------
-- Starting and stopping.
---------------------------------------------------------------------------
local started   -- when the fight began, or nil

local function OnEvent(_, event, addon)
    addon = Compat.Plain(addon)
    if event == "PLAYER_REGEN_DISABLED" then
        local inside = IsInInstance()
        started = not (inside or IsInGroup()) and GetTime() or nil
    elseif event == "PLAYER_REGEN_ENABLED" then
        if started then
            QuestTags.AddFight(GetTime() - started)
            started = nil
            QuestTags.Refresh()
        end
    elseif event == "ADDON_LOADED" and addon == "Blizzard_ObjectiveTracker" then
        HookTrackers()
    end
end

local registered
function QuestTags:OnEnable()
    local events = self.events or CreateFrame("Frame")
    self.events = events
    for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_LOADED" }) do
        events:RegisterEvent(e)
    end
    events:SetScript("OnEvent", ns.Safe(self, OnEvent))
    HookTrackers()
    if not registered and EllesmereUI and EllesmereUI.RegisterQuestTrackerRow then
        -- No room asked for beside the titles: the tags sit left of the tracker.
        registered = EllesmereUI.RegisterQuestTrackerRow("jsalUI", ns.Safe(self, EllesmereRow), 0)
    end
    -- Running is set once this returns; draw the tags just after.
    C_Timer.After(0, ns.Safe(self, QuestTags.Refresh))
end

function QuestTags:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
    started = nil
    C_Timer.After(0, function() pcall(QuestTags.Refresh) end)
end

-- /jsal questtags: what the tags see, for a bug report.
ns.Command("questtags", function()
    local seconds, fights = QuestTags.FightSeconds()
    ns.Print(("Quest tags: %s. Fights average %d seconds over %d. EllesmereUI's tracker: %s. The game's: %s.")
        :format(QuestTags.running and "on" or "off", math.floor(seconds + 0.5), fights,
        registered and "tagged" or "not in use", hooked.QuestObjectiveTracker and "tagged" or "not found"))
    for i = 1, C_QuestLog.GetNumQuestWatches() do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if questID then
            local step, minutes = QuestTags.Tags(questID)
            ns.Print(("  %s: %s %s"):format(C_QuestLog.GetTitleForQuestID(questID) or questID, step or "alone", minutes))
        end
    end
end)
