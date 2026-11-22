-- The Endgame page's YOUR SET card, with a gold edge: where your pre-raid set stands, what to run
-- next for it, and the build for 60 you sim with. Below 60 it's your goal at 60: the set's pieces
-- as pictures, the first run for them and the level it opens at, and the levelling build you
-- follow until then. All of it from the Gear plan's own reading (GearGoal.Summary, the one Home at
-- 60's card reads) and the builds for 60 (SuggestedBuilds).
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local PAD, ICON, PIECES = 16, 24, 17
local MUTED = "|cff9a9688"

-- A game picture in a thin frame, its edge in the item's quality colour.
local function Icon(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.edges = Style.Lined(f, "lineStrong", "window")
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 1, -1)
    f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        if not self.item then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetItemByID(self.item)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function f:Item(id)
        self.item = id
        self.icon:SetTexture(Compat.ItemIcon(id))
        local e = ns.Gear and ns.Gear.Lookup and ns.Gear.Lookup(id)
        local hex = Style.Quality(e and e.quality or 1)
        local r, g, b = tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
        for _, edge in ipairs(self.edges) do
            if edge.SetColorTexture then edge:SetColorTexture(r, g, b) end
        end
    end
    return f
end

-- Quiet gold words that light up under the pointer.
local function Link(parent, words, onClick)
    local b = CreateFrame("Button", nil, parent)
    b.text = Style.Text(b, 13, "gold", nil, true)
    b.text:SetPoint("RIGHT")
    b.text:SetText(words)
    b:SetSize(Style.Wide(b.text, #words * 7), 20)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(Style.Color("text")) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color("gold")) end)
    b:SetScript("OnClick", onClick)
    return b
end

local function Caps(parent, words)
    local t = Style.Text(parent, 11, "muted", nil, true)
    t:SetText(words)
    return t
end

local function Rule(parent, y)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(Style.Color("line"))
    t:SetPoint("TOPLEFT", PAD, -y)
    t:SetPoint("TOPRIGHT", -PAD, -y)
    t:SetHeight(1)
    return t
end

-- The build for 60 WoWSims sims with a set of the At 60 view: the first that names it.
local function BuildFor(key)
    local classID = ns.TalentTree and ns.TalentTree.PlayerClass and ns.TalentTree.PlayerClass()
    for _, b in ipairs(ns.SuggestedBuilds or {}) do
        if b.raid and b.class == classID then
            for _, s in ipairs(b.sets or {}) do
                if s == key then return b end
            end
        end
    end
end
-- The BUILD FOR 60 card below 60 asks the same.
ns.EndgameBuildFor = BuildFor

-- A dungeon's level, from the dungeon guide, by its name.
local function LevelOf(name)
    for _, d in ipairs(ns.DungeonData or {}) do
        if d.name == name then return d.level end
    end
end

-- The words of a line that fit whole in `room`: the first of `list` that does.
local function Fits(text, list, room)
    for _, words in ipairs(list) do
        text:SetText(words)
        local plain = words:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        if Style.Wide(text, #plain * 6.5) <= room then return end
    end
end

-- The card, `width` wide. Paint() fills it and returns its height.
function ns.EndgameSet(parent, width)
    local card = CreateFrame("Frame", nil, parent)
    card:SetWidth(width)
    Style.Box(card, 6, "well", "cardLine")
    if Style.Edge then Style.Edge(card, 6, "gold") end
    local inner = width - 2 * PAD
    local title = Style.Text(card, 12, "gold", nil, true)
    title:SetPoint("TOPLEFT", PAD, -14)
    title:SetText("YOUR SET")
    local function OpenGoal()
        if ns.Gear then ns.Gear.openAt60 = true end
        Window.Open("gear")
    end
    local open = Link(card, "Open Gear plan", OpenGoal)
    open:SetPoint("TOPRIGHT", -PAD, -10)

    -- The top: at 60 the count and its pips; below, "Your goal at 60" and the set's pictures.
    local count = Style.Text(card, 26, "gold", nil, true)
    count:SetPoint("TOPLEFT", PAD, -40)
    local label = Style.Text(card, 15, "secondary")
    local goal = Style.Text(card, 18, "text", nil, true)
    goal:SetPoint("TOPLEFT", PAD, -42)
    goal:SetText("Your goal at 60")
    local pips, pieces = {}, {}
    for i = 1, PIECES do
        local t = card:CreateTexture(nil, "ARTWORK")
        t:SetSize(12, 12)
        t:SetPoint("TOPLEFT", PAD + (i - 1) * 16, -80)
        pips[i] = t
        local p = Icon(card, 15)
        p:SetPoint("TOPLEFT", PAD + (i - 1) * 17, -78)
        pieces[i] = p
    end
    local setLine = Style.Text(card, 12, "muted")
    setLine:SetPoint("TOPLEFT", PAD, -102)
    setLine:SetWidth(inner)
    setLine:SetWordWrap(false)
    setLine:SetJustifyH("LEFT")
    local off = Style.Text(card, 13, "muted")
    off:SetPoint("TOPLEFT", PAD, -44)
    off:SetWidth(inner)
    off:SetJustifyH("LEFT")

    -- NEXT (at 60) or FIRST STOP (below): a run's pieces, its name, and what it gives.
    local nextRule = Rule(card, 124)
    local nextHead = Caps(card, "NEXT")
    nextHead:SetPoint("TOPLEFT", PAD, -138)
    local runIcons = {}
    for i = 1, 4 do
        local f = Icon(card, ICON)
        f:SetPoint("TOPLEFT", PAD + (i - 1) * 28, -158)
        f:SetScript("OnMouseUp", OpenGoal)
        runIcons[i] = f
    end
    local runName = Style.Text(card, 14, "text", nil, true)
    runName:SetWordWrap(false)
    runName:SetJustifyH("LEFT")
    local runLine = Style.Text(card, 12, "muted")
    runLine:SetPoint("TOPLEFT", PAD, -190)
    runLine:SetWordWrap(false)
    runLine:SetJustifyH("LEFT")

    -- BUILD: the build for 60 you sim with your set, and Open Build.
    local buildRule = Rule(card, 214)
    local buildHead = Caps(card, "BUILD")
    buildHead:SetPoint("TOPLEFT", PAD, -228)
    local buildOpen = Link(card, "Open Build", function()
        if card.build and ns.TalentTree then ns.TalentTree.Select(card.build.class, card.build) end
        Window.Open("build")
    end)
    buildOpen:SetPoint("TOPRIGHT", -PAD, -224)
    local buildName = Style.Text(card, 14, "text", nil, true)
    buildName:SetPoint("TOPLEFT", PAD, -250)
    buildName:SetWidth(inner)
    buildName:SetWordWrap(false)
    buildName:SetJustifyH("LEFT")
    local buildLine = Style.Text(card, 12, "muted")
    buildLine:SetPoint("TOPLEFT", PAD, -272)
    buildLine:SetWidth(inner)
    buildLine:SetWordWrap(false)
    buildLine:SetJustifyH("LEFT")
    local sections = { nextRule, nextHead, runName, runLine, buildRule, buildHead, buildOpen, buildName, buildLine }

    local function PaintTop(s, at60)
        count:SetShown(at60 and not s.empty)
        label:SetShown(at60)
        goal:SetShown(not at60)
        local ids = (not at60 and ns.GearGoal.ChosenSet()) or {}
        local shownPiece = 0
        for i = 1, PIECES do
            pips[i]:SetShown(at60 and i <= s.of)
            pips[i]:SetColorTexture(Style.Color(i <= s.at and "gold" or "lineStrong"))
            local id = ids[i]
            if id and id > 0 then
                shownPiece = shownPiece + 1
                pieces[shownPiece]:Item(id)
            end
        end
        for i = 1, PIECES do pieces[i]:SetShown(not at60 and i <= shownPiece) end
        label:ClearAllPoints()
        if at60 and s.empty then
            label:SetPoint("TOPLEFT", PAD, -46)
            label:SetText("Your set has no pieces yet")
        else
            count:SetText(s.at)
            label:SetPoint("BOTTOMLEFT", count, "BOTTOMRIGHT", 8, 3)
            label:SetText(("of %d slot%s at your pre-BiS"):format(s.of, s.of == 1 and "" or "s"))
        end
        local name = s.own and s.name or ("WoWSims' " .. (s.name or "") .. " set")
        setLine:SetText(name .. ", before raids" .. (not at60 and shownPiece > 0 and (" · %d pieces"):format(shownPiece) or ""))
    end

    local function PaintRun(s, at60)
        nextHead:SetText(at60 and "NEXT" or "FIRST STOP")
        local run, piece = s.runs and s.runs[1], s.other and s.other[1]
        -- A run is only ever named for its pieces: one with none isn't shown.
        if run and #(run.pieces or {}) == 0 then run = nil end
        local done = s.of > 0 and s.at >= s.of
        local ids = {}
        if not (s.empty or done) then
            if run then
                for i, p in ipairs(run.pieces) do if i <= #runIcons then ids[i] = p.row.goal.id end end
            elseif piece then
                ids[1] = piece.goal.id
            end
        end
        for i, f in ipairs(runIcons) do
            f:SetShown(ids[i] ~= nil)
            if ids[i] then f:Item(ids[i]) end
        end
        runName:ClearAllPoints()
        runName:SetPoint("LEFT", card, "TOPLEFT", PAD + (#ids > 0 and (#ids * 28 + 6) or 0), -170)
        runName:SetWidth(inner - (#ids > 0 and (#ids * 28 + 6) or 0))
        runLine:SetWidth(inner)
        if s.empty then
            runName:SetText("")
            Fits(runLine, { "Choose its pieces in the Gear plan" }, inner)
        elseif done then
            runName:SetText("Your set is done")
            Fits(runLine, { "Raids open once there's raid loot" }, inner)
        elseif run then
            runName:SetText(run.name)
            local n = #run.pieces
            local pieceWords = ("%d piece%s for you"):format(n, n == 1 and "" or "s")
            local level = LevelOf(run.name)
            local extra = at60 and (run.any and (" · one in %d%% of runs"):format(math.max(1, math.floor(run.any * 100 + 0.5))) or "")
                or (level and (" · from level %d"):format(level) or "")
            Fits(runLine, { pieceWords .. extra, pieceWords }, inner)
        elseif piece then
            runName:SetText(piece.label)
            local from = ns.GearGoal.From(piece.goal.e)
            Fits(runLine, { from.text or "", "" }, inner)
        elseif (s.unknown or 0) > 0 then
            runName:SetText("")
            Fits(runLine, { ("%d piece%s with no known source yet"):format(s.unknown, s.unknown == 1 and "" or "s") }, inner)
        else
            runName:SetText("")
            runLine:SetText("")
        end
    end

    -- The build for 60 that goes with your set; Open Build opens the Build Planner on it, or as it is when none
    -- does. Below 60, the levelling build you follow until then.
    local function PaintBuild(at60, s)
        local Goal = ns.GearGoal
        local key, setName = Goal.SetKey()
        local build = key and BuildFor(key)
        card.build = build
        local followed = ns.TalentTree and ns.TalentTree.Active and ns.TalentTree.Active()
        local levelling = followed and followed ~= build and followed.name
        local untilThen = { levelling and ("Until then you follow " .. levelling) or "Until then, your levelling build", "Until then, your levelling build" }
        if not build then
            Fits(buildName, s.own and { "No build for 60 goes with a set of your own", "No build for 60 for a set of yours" }
                or { "No build for 60 goes with this set" }, inner)
            if at60 then buildLine:SetText("") else Fits(buildLine, untilThen, inner) end
            return
        end
        buildName:SetText(build.name .. ", a build for 60")
        if at60 then
            local words = s.own and ("Simmed with WoWSims' %s set, which yours began as"):format(setName or "")
                or ("Simmed with your %s set"):format(setName or "")
            Fits(buildLine, { words .. ((followed == build) and (MUTED .. " · you follow it|r") or ""), words,
                              s.own and ("Simmed with WoWSims' %s set"):format(setName or "") or "Simmed with your set" }, inner)
        else
            Fits(buildLine, untilThen, inner)
        end
    end

    function card.Paint()
        local Goal = ns.GearGoal
        local ok, s = pcall(function()
            if ns.Pretend then return ns.Pretend.GoalSummary() end
            return Goal and Goal.running and Goal.Summary and Goal.Summary()
        end)
        if not ok then ns.Report(s) end
        local at60 = (ns.Pretend and ns.Pretend.Level() or UnitLevel("player") or 0) >= (Goal and Goal.LEVEL or 60)
        local has = ok and s ~= nil
        off:SetShown(not has)
        open:SetShown(has)
        for _, r in ipairs(sections) do r:SetShown(has) end
        if not has then
            count:Hide() label:Hide() goal:Hide() setLine:Hide()
            for i = 1, PIECES do pips[i]:Hide() pieces[i]:Hide() end
            for _, f in ipairs(runIcons) do f:Hide() end
            off:SetText(not (Goal and Goal.running) and "The gear goal for 60 is switched off in Settings."
                or "WoWSims has no pre-raid set for your talent tree yet.")
            card:SetHeight(96)
            return 96
        end
        setLine:Show()
        PaintTop(s, at60)
        PaintRun(s, at60)
        PaintBuild(at60, s)
        card:SetHeight(300)
        return 300
    end
    return card
end
