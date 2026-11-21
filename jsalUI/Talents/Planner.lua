-- The Build Planner page: a class picker across the top and that class's
-- saved builds on the left, with ready-made leveling builds under them to
-- follow or copy. Beside them a build shows as its plan, level by level,
-- with what's taken and what's next, and at the plan's right the three
-- trees, small, with where its points go; Edit opens the three trees at
-- full size, where clicking talents in the order you'd take them builds
-- the plan.
local _, ns = ...
local Style, Window, Tree, Compat = ns.Style, ns.Window, ns.TalentTree, ns.Compat

local LIST_W, GUTTER = 196, 22
local ICON, LABEL = 32, 13          -- a talent's icon, and its rank under it
local LEVELS = 80                   -- the editor's level-by-level section
local CLASSES_TOP = 32
local BODY_TOP = 74                 -- the builds list and the build's header
local MAIN_TOP = 140                -- the plan list, or the editor's trees
local STEP_H = 30                   -- one row of the plan list
local COLS_H = 20                   -- the plan list's column headings
local NEXT_W = 340                    -- the card of your next point, beside the plan
local SOURCE_H = 22                 -- a suggested build's source line
local ROW_H = 46                    -- one build in the builds list

local function Small(parent, label, kind, width)
    local b = Style.Button(parent, label, kind or "plain", width)
    b:SetHeight(24)
    return b
end

Window.Page("build", function(page)
    local width, height = Window.fullWidth, Window.contentHeight
    local right = LIST_W + GUTTER
    local rightW = width - right
    -- The plan, with a card beside it of your next point and what it gives you. No small trees
    -- beside it (they were a lot of the page's pieces); Edit opens the trees.
    local planW = rightW - NEXT_W - GUTTER
    local treeW = (rightW - 24) / 3
    local classID = Tree.PlayerClass()
    local editing = false
    local data, build, kept, ranks, spent
    local status, statusUntil = nil, 0
    local Paint

    local function Save(order)
        build.order = order
        Paint()
    end

    local function Say(text)
        status, statusUntil = text, GetTime() + 5
        Paint()
    end

    -- `colorKey`: for a note that asks something of you (points to spend).
    local function Note(head, text, colorKey)
        if status and GetTime() < statusUntil then
            head.note:SetText(status)
            head.note:SetTextColor(Style.Color("gold"))
        else
            head.note:SetText(text)
            head.note:SetTextColor(Style.Color(colorKey or "muted"))
        end
    end

    -- The top: the build that's open, with its main tree and points.
    local title = Style.Text(page, 20, "text", nil, true)
    title:SetPoint("TOPLEFT", 0, -1)
    title:SetWidth(width - 220)
    title:SetWordWrap(false)

    -- Top right: bring in a build from a code, or start a new one.
    local newBuild = Small(page, "New build", "plain", 100)
    newBuild:SetPoint("TOPRIGHT", 0, 0)
    local import = Small(page, "Import", "plain", 80)
    import:SetPoint("RIGHT", newBuild, "LEFT", -6, 0)

    -- The class picker: one button per class, in its class colour.
    local classButtons = {}
    local classes = Tree.Classes()
    local classW = (width - (#classes - 1) * 6) / #classes
    for i, id in ipairs(classes) do
        local b = CreateFrame("Button", nil, page)
        b:SetSize(classW, 26)
        b:SetPoint("TOPLEFT", (i - 1) * (classW + 6), -CLASSES_TOP)
        b.box = Style.PillBox(b, "well", "cardLine")
        b.label = Style.Text(b, 12, "text", nil, true)
        b.label:SetPoint("CENTER")
        b.label:SetJustifyH("CENTER")
        local name, color = Tree.ClassInfo(id)
        b.label:SetText(name)
        if color then b.label:SetTextColor(color.r, color.g, color.b) end
        b.classID = id
        b:SetScript("OnClick", function()
            classID, editing, status = id, false, nil
            Paint()
        end)
        classButtons[i] = b
    end

    -- The builds list: your own builds, then the class's suggested ones, then its builds for 60.
    -- It scrolls with the wheel once it's longer than the page (a mage has seven ready-made).
    local listScroll, listBox = Style.Scroller(page, LIST_W, height - BODY_TOP, nil, 9, ROW_H)
    listScroll:SetPoint("TOPLEFT", 0, -BODY_TOP)
    local listHead = Style.Section(listBox, LIST_W)
    listHead:SetPoint("TOPLEFT", 0, 0)
    listHead.title:SetText("BUILDS")
    local ownEmpty = Style.Text(listBox, 11, "muted")
    ownEmpty:SetWidth(LIST_W - 12)
    ownEmpty:SetText("None yet. Start a new build, or copy a suggested one.")
    local suggestHead = Style.Section(listBox, LIST_W)
    suggestHead.title:SetText("SUGGESTED")
    -- Builds for 60: WoWSims Forever's own talents for each build it sims, under the levelling ones.
    local raidHead = Style.Section(listBox, LIST_W)
    raidHead.title:SetText("FOR 60 · WOWSIMS")
    local rows = {}

    -- The WoWSims build your At 60 set is, with At 60 on: a build for 60 simmed with it is YOUR SET.
    local function SetKey()
        local Goal = ns.GearGoal
        if not (Goal and Goal.SetKey and ns.ModuleWanted(Goal)) then return nil end
        return Goal.SetKey()
    end
    local function ForYourSet(b)
        local key = b.raid and SetKey()
        for _, s in ipairs(key and b.sets or {}) do
            if s == key then return true end
        end
        return false
    end

    local function BuildRow()
        local row = CreateFrame("Button", nil, listBox)
        row:SetSize(LIST_W, 44)
        row.bg = Style.Fill(row, "well")
        row.mark = row:CreateTexture(nil, "ARTWORK")
        row.mark:SetColorTexture(Style.Color("gold"))
        row.mark:SetPoint("TOPLEFT")
        row.mark:SetPoint("BOTTOMLEFT")
        row.mark:SetWidth(2)
        row.name = Style.Text(row, 13, "text", nil, true)
        row.name:SetPoint("TOPLEFT", 12, -6)
        row.name:SetWidth(LIST_W - 20)
        row.name:SetWordWrap(false)
        row.sub = Style.Text(row, 11, "muted")
        row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
        row.sub:SetWidth(LIST_W - 20)
        row.sub:SetWordWrap(false)
        -- The build you follow (on the spec you're on), yours or a suggested one: a gold tag after
        -- its name, or, where the name is too long for both, at the start of the line under it.
        row.tag = Style.Tag(row, "FOLLOWING", "gold", true)
        row.tag:Hide()
        row:SetScript("OnClick", function(self)
            Tree.Select(classID, self.build)
            editing, status = false, nil
            Paint()
        end)
        return row
    end

    -- A build's line under its name, and after it in the title: its main tree and points (`short`:
    -- just its points). Whether it's followed is the list's tag.
    local function Summary(b, short)
        if not data then return "" end
        local order, _, treePoints = Tree.Replay(data, b.order or {})
        local text = "No points yet"
        if #order > 0 then
            local best, most = 1, -1
            for i in ipairs(data.trees) do
                if (treePoints[i] or 0) > most then best, most = i, treePoints[i] or 0 end
            end
            text = short and ("%d points"):format(#order) or ("%s, %d points"):format(data.trees[best].name, #order)
        end
        return text
    end

    ---------------------------------------------------------------------------
    -- View mode: the build's header, its buttons, and the plan as a list.
    ---------------------------------------------------------------------------
    local view = CreateFrame("Frame", nil, page)
    view:SetPoint("TOPLEFT", right, -BODY_TOP)
    view:SetSize(rightW, height - BODY_TOP)
    local viewHead = Style.Section(view, rightW)
    viewHead:SetPoint("TOPLEFT")

    -- Five buttons in one row. A suggested build swaps Edit, Rename and Delete for Copy to my
    -- builds. (Learn is on the next point's card, when there's a point to spend.)
    local follow = Small(view, "Follow this build", "plain", 118)
    follow:SetPoint("TOPLEFT", 0, -30)
    local edit = Small(view, "Edit", "plain", 56)
    local rename = Small(view, "Rename", "plain", 70)
    local export = Small(view, "Export", "plain", 64)
    local delete = Small(view, "Delete", "plain", 64)
    local copy = Small(view, "Copy to my builds", "plain", 136)
    edit:SetPoint("LEFT", follow, "RIGHT", 6, 0)
    rename:SetPoint("LEFT", edit, "RIGHT", 6, 0)
    delete:SetPoint("LEFT", export, "RIGHT", 6, 0)
    local source = Style.Text(view, 11, "muted")
    source:SetPoint("TOPLEFT", 0, -64)
    source:SetWidth(rightW)
    source:SetWordWrap(false)

    local nameBox = CreateFrame("EditBox", nil, view)
    nameBox:SetSize(220, 24)
    nameBox:SetPoint("TOPLEFT", 0, -30)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(24)
    nameBox:SetFont(Style.font, 12, "")
    nameBox:SetTextColor(Style.Color("text"))
    nameBox:SetTextInsets(8, 8, 0, 0)
    Style.Box(nameBox, 5, "well", "gold")
    nameBox:Hide()
    local nameHint = Style.Text(view, 11, "muted")
    nameHint:SetPoint("LEFT", nameBox, "RIGHT", 10, 0)
    nameHint:SetText("Enter to save, Escape to cancel")
    nameHint:Hide()

    -- The plan's column headings: the level is said once here, where every
    -- row began "Level" or "Levels".
    local cols = CreateFrame("Frame", nil, view)
    cols:SetSize(planW - 8, COLS_H)
    for _, label in ipairs({ { "LEVEL", 10 }, { "TALENT", 76 } }) do
        local t = Style.Text(cols, 10, "muted", nil, true)
        t:SetPoint("TOPLEFT", label[2], 0)
        t:SetText(label[1])
    end
    Style.Rule(cols, "BOTTOM", "lineStrong")

    -- Your next point: its picture in a gold line, its name, its tree and which rank, the level it
    -- comes at, and what it does, in the game's own words. For another class's build, its first.
    -- It goes by three steps: the next point; READY TO LEARN with Learn at its foot when there's a
    -- point to spend; LEARNED, green, when you take it (with the game's quest-done chime when it
    -- happens with the page open), until the page closes or the next point is ready.
    local nextCard = CreateFrame("Frame", nil, view)
    nextCard:SetWidth(NEXT_W)
    nextCard.box = Style.Box(nextCard, 6, "well", "gold")
    nextCard.title = Style.Text(nextCard, 11, "gold", nil, true)
    nextCard.title:SetPoint("TOPLEFT", 16, -14)
    nextCard.level = Style.Text(nextCard, 11, "muted")
    nextCard.level:SetPoint("TOPRIGHT", -16, -14)
    nextCard.level:SetJustifyH("RIGHT")
    local iconFrame = CreateFrame("Frame", nil, nextCard)
    iconFrame:SetSize(40, 40)
    iconFrame:SetPoint("TOPLEFT", 16, -38)
    iconFrame.line = Style.Lined(iconFrame, "gold")
    nextCard.icon = iconFrame:CreateTexture(nil, "ARTWORK")
    nextCard.icon:SetPoint("TOPLEFT", 1, -1)
    nextCard.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    nextCard.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    nextCard.name = Style.Text(nextCard, 17, "text", nil, true)
    nextCard.name:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 12, 0)
    nextCard.name:SetWidth(NEXT_W - 16 - 40 - 12 - 16)
    nextCard.name:SetJustifyH("LEFT")
    nextCard.name:SetWordWrap(false)
    nextCard.sub = Style.Text(nextCard, 12, "muted")
    nextCard.sub:SetPoint("TOPLEFT", nextCard.name, "BOTTOMLEFT", 0, -6)
    nextCard.text = Style.Text(nextCard, 13, "secondary")
    nextCard.text:SetPoint("TOPLEFT", 16, -94)
    nextCard.text:SetWidth(NEXT_W - 32)
    nextCard.text:SetJustifyH("LEFT")
    nextCard.text:SetWordWrap(true)
    nextCard.foot = CreateFrame("Frame", nil, nextCard)
    nextCard.foot:SetSize(NEXT_W, 44)
    Style.Rule(nextCard.foot, "TOP", "line")
    nextCard.footText = Style.Text(nextCard.foot, 13, "muted")
    nextCard.footText:SetPoint("LEFT", 16, 0)
    nextCard.footText:SetWidth(NEXT_W - 32 - 96)
    nextCard.footText:SetJustifyH("LEFT")
    local learn = Style.Button(nextCard.foot, "Learn", "primary", 84)
    learn:SetHeight(26)
    learn:SetPoint("RIGHT", -14, 0)
    -- On a build you don't follow, Follow this build in Learn's place: Learn is only ever for the
    -- build you follow, on the spec you're on.
    local cardFollow = Style.Button(nextCard.foot, "Follow this build", "plain", 124)
    cardFollow:SetHeight(26)
    cardFollow:SetPoint("RIGHT", -14, 0)
    nextCard.foot:Hide()

    -- Learn asks first: a box of each point it would spend, in order, where they go (which spec,
    -- by which plan), with Learn and Cancel. Nothing is spent until Learn there.
    local ask = CreateFrame("Frame", nil, view)
    ask:SetSize(NEXT_W, 160)
    ask:SetFrameStrata("DIALOG")
    ask:EnableMouse(true)
    Style.Box(ask, 8, "titleBar", "lineStrong")
    ask.title = Style.Text(ask, 15, "text", nil, true)
    ask.title:SetPoint("TOPLEFT", 18, -16)
    ask.where = Style.Text(ask, 12, "muted")
    ask.where:SetPoint("TOPLEFT", ask.title, "BOTTOMLEFT", 0, -5)
    ask.where:SetWidth(NEXT_W - 36)
    ask.where:SetJustifyH("LEFT")
    ask.list = Style.Text(ask, 13, "text")
    ask.list:SetPoint("TOPLEFT", ask.where, "BOTTOMLEFT", 0, -10)
    ask.list:SetWidth(NEXT_W - 36)
    ask.list:SetJustifyH("LEFT")
    ask.go = Style.Button(ask, "Learn", "primary", 84)
    ask.go:SetHeight(26)
    ask.go:SetPoint("BOTTOMRIGHT", -16, 14)
    ask.cancel = Style.Button(ask, "Cancel", "plain", 84)
    ask.cancel:SetHeight(26)
    ask.cancel:SetPoint("RIGHT", ask.go, "LEFT", -8, 0)
    ask:Hide()
    -- What was taken when the card last showed, and the point just learned since (shown green
    -- until the page closes); `open` while the page has been showing since then. A respec only
    -- lowers what was taken; a switch to your other spec starts afresh, learning nothing.
    local learned = {}
    view:HookScript("OnHide", function() learned.fresh, learned.open, ask.ids = nil, false, nil; ask:Hide() end)
    -- What a spell does can come a moment after it's first asked for: asked once more then.
    local askedAgain = {}

    -- The plan list scrolls with the mouse wheel; a thin bar shows where.
    local scroll, list = Style.Scroller(view, planW - 8, height - MAIN_TOP - COLS_H, nil, 7, STEP_H * 3)
    scroll:SetPoint("TOPLEFT", 0, -(MAIN_TOP - BODY_TOP + COLS_H))
    local empty = Style.Text(list, 13, "muted")
    empty:SetPoint("TOPLEFT", 10, -10)
    empty:SetWidth(planW - 30)

    -- What the plan's list is made of besides its steps: the line the
    -- taken points fold into, and a heading where the build changes tree.
    local V = { heads = {}, HEAD_H = 30, FOLD_H = 30 }
    V.fold = CreateFrame("Button", nil, list)
    V.fold:SetSize(planW - 8, V.FOLD_H)
    V.fold.sign = Style.Text(V.fold, 14, "gold", nil, true)
    V.fold.sign:SetPoint("LEFT", 10, 0)
    V.fold.text = Style.Text(V.fold, 12, "muted")
    V.fold.text:SetPoint("LEFT", 28, 0)
    Style.Hover(V.fold)
    V.fold:Hide()
    function V.Head(i)
        if V.heads[i] then return V.heads[i] end
        local h = CreateFrame("Frame", nil, list)
        h:SetSize(planW - 8, V.HEAD_H)
        Style.Rule(h, "BOTTOM", "lineStrong")
        h.title = Style.Text(h, 11, "gold", nil, true)
        h.title:SetPoint("BOTTOMLEFT", 10, 6)
        h.note = Style.Text(h, 11, "muted")
        h.note:SetPoint("BOTTOMRIGHT", -10, 6)
        h.note:SetJustifyH("RIGHT")
        V.heads[i] = h
        return h
    end

    local stepRows = {}
    local function StepRow()
        local row = CreateFrame("Frame", nil, list)
        row:SetSize(planW - 8, STEP_H)
        row.bg = Style.Fill(row, "well")
        row.levels = Style.Text(row, 12, "muted", nil, true)
        row.levels:SetPoint("LEFT", 10, 0)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(22, 22)
        row.icon:SetPoint("LEFT", 76, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.name = Style.Text(row, 13, "text")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        -- Its ranks as ticks: the ones taken before this line dim, the ones
        -- this line takes gold.
        row.pips = Style.Pips(row)
        row.pips:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
        row.state = Style.Text(row, 12, "muted", nil, true)
        row.state:SetPoint("RIGHT", -10, 0)
        row.state:SetJustifyH("RIGHT")
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            local node = data and data.nodes[self.id]
            if not (node and node.spellID) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(node.spellID)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        Style.Hover(row)
        return row
    end

    -- Which plan points the character has already learned, and the next one.
    local function Progress()
        if not data.own then return 0, nil end
        local _, _, nextIndex = Tree.Next(data, kept)
        return (nextIndex or (#kept + 1)) - 1, nextIndex
    end

    local function PaintView()
        viewHead.title:SetText("THE PLAN, LEVEL BY LEVEL")
        local taken, nextIndex = Progress()
        local waiting = data.own and Compat.UnspentTalentPoints() or 0
        -- Where the build stands, in a line: what's taken, and what's next
        -- (in gold when there are points to spend now).
        if not data.own then
            Note(viewHead, ("%d points planned"):format(#kept))
        elseif not nextIndex then
            Note(viewHead, #kept > 0 and ("all %d points taken"):format(#kept) or "")
        elseif waiting > 0 then
            Note(viewHead, ("%d of %d points taken  ·  %d to spend now"):format(taken, #kept, waiting), "gold")
        else
            Note(viewHead, ("%d of %d points taken  ·  next at level %d"):format(taken, #kept, Tree.Level(nextIndex)))
        end

        local renaming = nameBox:IsShown()
        local builtin = build.builtin
        -- Only the buttons that do something now. Learn next points is
        -- there, in gold, when there are points to spend; Follow this build
        -- when you aren't following it (the build's title says when you
        -- are). They were both there always, greyed out, ahead of the rest.
        local following = data.own and Tree.Active() == build
        follow:SetShown(not renaming and data.own and not following)
        follow:SetLabel("Follow this build")
        follow:SetEnabled(true)
        edit:SetShown(not renaming and not builtin)
        rename:SetShown(not renaming and not builtin)
        copy:SetShown(not renaming and builtin)
        export:SetShown(not renaming)
        delete:SetShown(not renaming and not builtin)
        -- Side by side from the left, whichever are showing.
        local before
        for _, b in ipairs({ follow, edit, rename, copy, export, delete }) do
            if b:IsShown() then
                b:ClearAllPoints()
                if before then b:SetPoint("LEFT", before, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 0, -30) end
                before = b
            end
        end
        delete:SetEnabled(#Tree.ClassBuilds(classID) > 1 or #Tree.Suggested(classID) > 0)
        -- "Sure?" is asked of one build: with another showing, the button reads Delete again.
        if delete.armedFor ~= build then
            delete.armedFor = nil
            delete:SetLabel("Delete")
        end

        -- A suggested build says where it's from, above its plan.
        local shift = builtin and SOURCE_H or 0
        source:SetShown(builtin)
        source:SetText(builtin and (build.raid and ("For 60, from |cffece6d6%s|r: the talents it sims %s with. Copy it to change anything."):format(build.source, build.name)
            or ("Suggested, from |cffece6d6%s|r. Copy it to change anything."):format(build.source)) or "")
        cols:ClearAllPoints()
        cols:SetPoint("TOPLEFT", 0, -(MAIN_TOP - BODY_TOP + shift))
        nextCard:ClearAllPoints()
        nextCard:SetPoint("TOPLEFT", planW + GUTTER, -(MAIN_TOP - BODY_TOP + shift))
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", 0, -(MAIN_TOP - BODY_TOP + shift + COLS_H))
        scroll:SetHeight(height - MAIN_TOP - shift - COLS_H)

        local steps = Tree.Steps(kept)
        empty:SetShown(#steps == 0)
        cols:SetShown(#steps > 0)
        empty:SetText("Nothing planned yet. Edit opens the trees: click talents in the order you'd take them.")
        -- The list: what's taken folded into a line that opens, so the plan
        -- starts at what's next; a heading where the build moves to another
        -- tree; and a step you're partway through split, so the row that's
        -- next names the rank that is.
        -- The card: your next point, or a build's first for another class. A point learned since
        -- the card last showed is LEARNED, unless another is ready to learn.
        -- Points spent that the plan you follow doesn't have where you are in it ("off the plan"):
        -- no Learn. Another build isn't yours to be off: it says which you follow.
        local spent = 0
        for _, n in pairs(data.own and data.nodes or {}) do spent = spent + (tonumber(n.learned) or 0) end
        local off = data.own and following and nextIndex and spent > taken and (spent - taken) or 0
        local ready = data.own and following and nextIndex ~= nil and waiting > 0 and off == 0
        if not ready then ask:Hide() end
        local group = Tree.Group and Tree.Group() or 1
        if data.own and learned.build == build and learned.group == group and learned.taken and taken > learned.taken then
            learned.fresh, learned.many = taken, taken - learned.taken
            if learned.open and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_QUEST_LIST_COMPLETE or 878, "SFX") end
        end
        if learned.build ~= build or ready or (learned.fresh and taken < learned.fresh) then learned.fresh = nil end
        learned.build, learned.group, learned.taken, learned.open = build, group, data.own and taken or nil, true
        local fresh = data.own and learned.fresh
        -- A build for 60, on your own class: A BUILD FOR 60 while you don't follow it, and RESPEC
        -- FIRST (gold, not OFF THE PLAN) while you follow it with points it doesn't have.
        local forSixty = build.raid and data.own and not fresh and (not following or off > 0)
        local nextAt = fresh or (data.own and nextIndex or (#kept > 0 and 1 or nil))
        if forSixty then nextAt = #kept > 0 and 1 or nil end
        local nextID = nextAt and kept[nextAt]
        local node = nextID and data.nodes[nextID]
        nextCard:SetShown(node ~= nil)
        if node then
            local rank = 0
            for k = 1, nextAt do if kept[k] == nextID then rank = rank + 1 end end
            local tone = fresh and "green" or (off > 0 and not forSixty) and "red" or "gold"
            Style.SetBorder({ nextCard.box.line }, tone)
            Style.SetBorder(iconFrame.line, tone)
            nextCard.title:SetTextColor(Style.Color(tone))
            -- Yours only for the build you follow; one you're looking at says it's that build's.
            nextCard.title:SetText(fresh and (learned.many > 1 and ("LEARNED %d POINTS"):format(learned.many) or "LEARNED")
                or off > 0 and "OFF THE PLAN"
                or ready and "READY TO LEARN"
                or not data.own and "THE BUILD'S FIRST POINT" or (following and "YOUR NEXT POINT" or "THIS BUILD'S NEXT POINT"))
            nextCard.level:SetText(ready and "now" or ("level %d"):format(Tree.Level(nextAt)))
            nextCard.icon:SetTexture(node.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            nextCard.name:SetText(node.name or "")
            local tree = data.trees[node.tree]
            nextCard.sub:SetText((tree and tree.name or "") .. "  ·  "
                .. (node.max == 1 and "1 rank" or ("rank %d of %d"):format(rank, node.max)))
            local describe = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
            local says = node.spellID and describe and describe(node.spellID) or ""
            if says == "" and node.spellID and not askedAgain[node.spellID] then
                askedAgain[node.spellID] = true
                if C_Spell and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(node.spellID) end
                Compat.After(1, function() if view:IsVisible() then Paint() end end)
            end
            nextCard.text:SetText(says)
            local tall = Style.Wide and nextCard.text.GetStringHeight and nextCard.text:GetStringHeight() or 0
            if forSixty then
                -- The build's name and where its points go, then what following it takes.
                nextCard.title:SetText(following and "RESPEC FIRST" or "A BUILD FOR 60")
                nextCard.level:SetText("WoWSims")
                nextCard.name:SetText(build.name or "")
                local Goal = ns.GearGoal
                local setName = ForYourSet(build) and Goal and select(2, Goal.SetKey())
                nextCard.sub:SetText(setName and ("The talents WoWSims sims your %s set with"):format(setName)
                    or ("WoWSims Forever's %s talents"):format(build.spec or ""))
                local _, _, treePoints = Tree.Replay(data, build.order or {})
                local split = {}
                for i, t in ipairs(data.trees) do split[#split + 1] = ("%d %s"):format(treePoints[i] or 0, t.name or "") end
                local className = UnitClass("player") or ""
                local how = following and ("%d of your points are where this build doesn't have them. Reset your talents at a %s trainer: then Learn %d puts every point where this build has them.")
                        :format(off, className:lower(), #kept)
                    or spent > 0 and ("Your %d points are in other talents. Follow this build, reset your talents at a %s trainer, and Learn %d puts them all where this build has them.")
                        :format(spent, className:lower(), #kept)
                    or ("Follow this build, and Learn puts your points where it has them.")
                nextCard.text:SetText(table.concat(split, "  ·  ") .. "\n\n" .. how)
                tall = nextCard.text.GetStringHeight and nextCard.text:GetStringHeight() or 0
            end
            local h = 94 + (type(tall) == "number" and tall or 0) + 18
            -- Its foot: Learn, with how many points there are to spend; or, learned, what's next.
            local after = fresh and nextIndex
            local afterID = after and kept[after]
            local afterNode = afterID and data.nodes[afterID]
            local other = data.own and not following and not fresh and (off == 0 or forSixty)
            nextCard.foot:SetShown((ready or fresh or (off > 0 and not forSixty) or other) and true or false)
            learn:SetShown(ready and true or false)
            cardFollow:SetShown(other and true or false)
            nextCard.footText:SetWidth(NEXT_W - 32 - (ready and 96 or other and 136 or 0))
            nextCard.footText:SetTextColor(Style.Color((off > 0 and not forSixty) and "red" or "muted"))
            if forSixty and other then
                nextCard.footText:SetText("From WoWSims Forever")
            elseif off > 0 then
                nextCard.footText:SetText(("%d of your points %s off this plan, so Learn is off. Respec, or follow a build that has them.")
                    :format(off, off == 1 and "is" or "are"))
            elseif other then
                local followed = Tree.Active()
                nextCard.footText:SetText(followed and followed ~= build and ("You follow |cffe8e4d8%s|r, not this build."):format(followed.name or "")
                    or "You don't follow this build.")
            elseif ready then
                local n = math.min(waiting, #kept - nextIndex + 1)
                learn:SetLabel(n > 1 and ("Learn %d"):format(n) or "Learn")
                nextCard.footText:SetText(("%d point%s to spend"):format(waiting, waiting == 1 and "" or "s"))
            elseif fresh then
                local afterRank = 0
                for k = 1, after or 0 do if kept[k] == afterID then afterRank = afterRank + 1 end end
                nextCard.footText:SetText(afterNode and ("Next: |cffe3b04b%s|r rank %d, at level %d"):format(afterNode.name or "", afterRank, Tree.Level(after))
                    or "Every point of the plan is taken.")
            end
            if nextCard.foot:IsShown() then
                local words = nextCard.footText.GetStringHeight and nextCard.footText:GetStringHeight() or 0
                local footH = math.max(44, (type(words) == "number" and words or 0) + 22)
                nextCard.foot:SetHeight(footH)
                nextCard.foot:ClearAllPoints()
                nextCard.foot:SetPoint("TOPLEFT", 0, -(h - 6))
                h = h - 6 + footH
            end
            nextCard:SetHeight(h)
        end

        local rows = Tree.PlanRows(steps, taken, function(id) return data.nodes[id].tree end, V.open)
        local y, used, heads = 0, 0, 0
        V.fold:Hide()
        for _, step in ipairs(rows) do
            if step.fold then
                V.fold:ClearAllPoints()
                V.fold:SetPoint("TOPLEFT", 0, -y)
                V.fold.sign:SetText(step.open and "–" or "+")
                V.fold.text:SetText(("%d point%s taken, level%s %s"):format(step.points, step.points == 1 and "" or "s",
                    step.points == 1 and "" or "s",
                    step.points == 1 and tostring(Tree.Level(1)) or (Tree.Level(1) .. "–" .. Tree.Level(step.points))))
                V.fold:SetScript("OnClick", function()
                    V.open = not V.open
                    Paint()
                end)
                V.fold:Show()
                y = y + V.FOLD_H
            elseif step.head then
                heads = heads + 1
                local h = V.Head(heads)
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", 0, -y)
                h.title:SetText((data.trees[step.head] and data.trees[step.head].name or "Talents"):upper())
                h.note:SetText(("%d point%s  ·  levels %d–%d"):format(step.points, step.points == 1 and "" or "s",
                    Tree.Level(step.first), Tree.Level(step.last)))
                h:Show()
                y = y + V.HEAD_H
            else
                used = used + 1
                local row = stepRows[used] or StepRow()
                stepRows[used] = row
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y)
                local node = data.nodes[step.id]
                row.id = step.id
                local a, b = Tree.Level(step.first), Tree.Level(step.last)
                row.levels:SetText(a == b and tostring(a) or ("%d–%d"):format(a, b))
                row.icon:SetTexture(node.icon)
                row.name:SetText(node.name)
                row.pips:SetShown(node.max > 1)
                row.pips:Set(step.fromRank - 1, node.max, step.toRank - step.fromRank + 1)
                row.bg:SetShown(used % 2 == 1)
                local isNext = nextIndex and step.first <= nextIndex and nextIndex <= step.last
                row:SetAlpha(step.done and 0.6 or 1)
                if step.done then
                    row.state:SetText("taken")
                    row.state:SetTextColor(Style.Color("muted"))
                elseif isNext then
                    row.state:SetText(waiting > 0 and "next: learn it now" or "next")
                    row.state:SetTextColor(Style.Color("gold"))
                else
                    row.state:SetText("")
                end
                row.levels:SetTextColor(Style.Color(isNext and "text" or "muted"))
                row:Show()
                y = y + STEP_H
            end
        end
        for i = used + 1, #stepRows do stepRows[i]:Hide() end
        for i = heads + 1, #V.heads do V.heads[i]:Hide() end
        list:SetHeight(math.max(1, y))
        scroll:UpdateScrollChildRect()
        scroll:Place()
    end

    ---------------------------------------------------------------------------
    -- Edit mode: the three trees and the plan's order.
    ---------------------------------------------------------------------------
    local editor = CreateFrame("Frame", nil, page)
    editor:SetPoint("TOPLEFT", right, -BODY_TOP)
    editor:SetSize(rightW, height - BODY_TOP)
    local editHead = Style.Section(editor, rightW)
    editHead:SetPoint("TOPLEFT")
    local undo = Small(editor, "Undo", "plain", 72)
    undo:SetPoint("TOPLEFT", 0, -30)
    local clear = Small(editor, "Clear", "plain", 72)
    clear:SetPoint("LEFT", undo, "RIGHT", 6, 0)
    local done = Small(editor, "Done", "primary", 80)
    done:SetPoint("LEFT", clear, "RIGHT", 6, 0)
    local hint = Style.Text(editor, 11, "muted")
    hint:SetPoint("LEFT", done, "RIGHT", 12, 0)
    hint:SetText("Click: add a rank · Right-click: take one off")

    local area = CreateFrame("Frame", nil, editor)
    area:SetPoint("TOPLEFT", 0, -(MAIN_TOP - BODY_TOP))
    area:SetSize(rightW, height - MAIN_TOP - LEVELS)
    local columns, buttons, lines = {}, {}, {}

    local levelHead = Style.Section(page, width)
    levelHead:SetPoint("TOPLEFT", 0, -(height - LEVELS + 6))
    levelHead.title:SetText("LEVEL BY LEVEL")
    levelHead.note:SetText("The order the points are taken in")
    local chips, more = {}, Style.Text(page, 11, "muted")

    local function TalentButton()
        local b = CreateFrame("Button", nil, area)
        b:SetSize(ICON, ICON)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 1, -1)
        b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.edges = Style.Border(b, "lineStrong")
        b.rank = Style.Text(b, 10, "muted", nil, true)
        b.rank:SetPoint("TOP", b, "BOTTOM", 0, -2)
        b.rank:SetJustifyH("CENTER")
        b:SetScript("OnEnter", function(self)
            local node = data and data.nodes[self.nodeID]
            if not node then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if node.spellID then GameTooltip:SetSpellByID(node.spellID) else GameTooltip:SetText(node.name) end
            GameTooltip:AddLine(" ")
            local text = ("Planned %d of %d"):format(ranks[node.id] or 0, node.max)
            if data.own then text = text .. (" · learned %d"):format(node.learned) end
            GameTooltip:AddLine(text, 0.89, 0.69, 0.29)
            GameTooltip:AddLine("Click: add a rank · Right-click: take one off", 0.6, 0.59, 0.53)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self, mouse)
            local id = self.nodeID
            if mouse == "RightButton" then
                local order = {}
                for i, v in ipairs(kept) do order[i] = v end
                for i = #order, 1, -1 do
                    if order[i] == id then
                        table.remove(order, i)
                        -- Anything that leaned on that rank comes off too.
                        local after = Tree.Replay(data, order)
                        Save(after)
                        if #after < #order then Say("Talents that needed it came off as well.") end
                        return
                    end
                end
                return
            end
            local ok, why = Tree.CanAdd(data, ranks, spent, #kept, id)
            if not ok then return Say(why) end
            local order = {}
            for i, v in ipairs(kept) do order[i] = v end
            order[#order + 1] = id
            Save(order)
        end)
        return b
    end

    local function Layout()
        for _, b in ipairs(buttons) do b:Hide() end
        for _, line in ipairs(lines) do line:Hide() end
        local gridH = area:GetHeight() - 28 - ICON - LABEL
        local rowStep = math.min(56, gridH / 6)
        local used, place = 0, {}
        for i, t in ipairs(data.trees) do
            local col = columns[i]
            if not col then
                col = CreateFrame("Frame", nil, area)
                col.name = Style.Text(col, 14, "text", nil, true)
                col.name:SetPoint("TOPLEFT", 0, 0)
                col.points = Style.Text(col, 14, "gold", nil, true)
                col.points:SetPoint("LEFT", col.name, "RIGHT", 8, 0)
                columns[i] = col
            end
            col:ClearAllPoints()
            col:SetPoint("TOPLEFT", (i - 1) * (treeW + 12), 0)
            col:SetSize(treeW, area:GetHeight())
            col.name:SetText(t.name)
            col:Show()
            local colStep = (treeW - ICON - 8) / 3
            for _, id in ipairs(t.nodes) do
                used = used + 1
                local b = buttons[used] or TalentButton()
                buttons[used] = b
                b:SetParent(col)
                b:ClearAllPoints()
                local node = data.nodes[id]
                b:SetPoint("TOPLEFT", node.col * colStep, -(28 + node.row * rowStep))
                b.nodeID = id
                b.icon:SetTexture(node.icon)
                b:Show()
                place[id] = b
            end
        end
        for i = #data.trees + 1, #columns do columns[i]:Hide() end
        -- The arrows between talents, as lines under the icons.
        local linked = 0
        for id, node in pairs(data.nodes) do
            local from, to = node.need and place[node.need], place[id]
            if from and to then
                linked = linked + 1
                local line = lines[linked]
                if not line then
                    line = area:CreateLine(nil, "ARTWORK")
                    line:SetThickness(2)
                    lines[linked] = line
                end
                line:SetParent(columns[node.tree])
                if data.nodes[node.need].row == node.row then
                    line:SetStartPoint("RIGHT", from)
                    line:SetEndPoint("LEFT", to)
                else
                    line:SetStartPoint("BOTTOM", from, 0, -LABEL)
                    line:SetEndPoint("TOP", to)
                end
                line.from, line.needRanks = node.need, node.needRanks
                line:Show()
            end
        end
    end

    local function PaintLevels()
        for _, chip in ipairs(chips) do chip:Hide() end
        more:SetText("")
        levelHead.count:SetText(#kept)
        if #kept == 0 then
            more:ClearAllPoints()
            more:SetPoint("TOPLEFT", levelHead, "BOTTOMLEFT", 0, -10)
            more:SetText("Nothing planned yet: click talents in the order you'd take them.")
            return
        end
        -- Your own class starts at your next point; others from the start.
        local _, nextIndex = Progress()
        local start = data.own and (nextIndex or #kept) or 1
        local seen = {}
        for i = 1, start - 1 do seen[kept[i]] = (seen[kept[i]] or 0) + 1 end
        local x, line = 0, 0
        for i = start, #kept do
            local id = kept[i]
            seen[id] = (seen[id] or 0) + 1
            local index = i - start + 1
            local chip = chips[index]
            if not chip then
                chip = CreateFrame("Frame", nil, page)
                chip:SetHeight(22)
                chip.edges = { Style.Box(chip, 5, "well", "cardLine").line }
                chip.level = Style.Text(chip, 11, "muted", nil, true)
                chip.level:SetPoint("LEFT", 6, 0)
                chip.text = Style.Text(chip, 11, "text")
                chip.text:SetPoint("LEFT", chip.level, "RIGHT", 5, 0)
                chips[index] = chip
            end
            chip.level:SetText(Tree.Level(i))
            chip.text:SetText(("%s %d"):format(data.nodes[id].name, seen[id]))
            local w = chip.level:GetStringWidth() + chip.text:GetStringWidth() + 17
            if x + w > width - 80 then
                if line == 1 then
                    more:ClearAllPoints()
                    more:SetPoint("TOPLEFT", levelHead, "BOTTOMLEFT", x + 4, -14 - line * 26)
                    more:SetText(("+%d more"):format(#kept - i + 1))
                    break
                end
                line, x = line + 1, 0
            end
            chip:SetWidth(w)
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", levelHead, "BOTTOMLEFT", x, -8 - line * 26)
            Style.SetBorder(chip.edges, i == nextIndex and "gold" or "cardLine")
            chip:Show()
            x = x + w + 4
        end
    end

    local function PaintEditor()
        editHead.title:SetText("EDITING " .. build.name:upper())
        local reach = #kept > 0 and (", up to level " .. Tree.Level(#kept)) or ""
        Note(editHead, ("%d of %d points%s. Click talents in the order you take them."):format(#kept, Tree.MAX_POINTS, reach))
        Layout()
        for i, col in ipairs(columns) do
            if data.trees[i] then col.points:SetText(spent[i] or 0) end
        end
        for _, b in ipairs(buttons) do
            if b:IsShown() then
                local node = data.nodes[b.nodeID]
                local planned = ranks[b.nodeID] or 0
                local open = planned > 0 or Tree.CanAdd(data, ranks, spent, #kept, b.nodeID)
                b.icon:SetDesaturated(not open)
                b.icon:SetAlpha(open and 1 or 0.5)
                Style.SetBorder(b.edges, planned > 0 and "gold" or "lineStrong")
                b.rank:SetText(planned .. "/" .. node.max)
                b.rank:SetTextColor(Style.Color(planned > 0 and "gold" or "muted"))
            end
        end
        for _, line in ipairs(lines) do
            if line:IsShown() then
                local reached = (ranks[line.from] or 0) >= line.needRanks
                line:SetColorTexture(Style.Color(reached and "gold" or "lineStrong"))
            end
        end
        undo:SetEnabled(#kept > 0)
        clear:SetEnabled(#kept > 0)
        PaintLevels()
    end

    Paint = function()
        data = Tree.Read(classID)
        build = Tree.Selected(classID)
        -- The rename box is for the build it was opened on: with another build or class
        -- picked it closes, nothing saved. (Left open, Enter named whichever build was
        -- showing by then.)
        if nameBox:IsShown() and nameBox.forBuild ~= build then
            nameBox.forBuild = nil
            nameBox:ClearFocus()
            nameBox:Hide()
            nameHint:Hide()
        end
        for _, b in ipairs(classButtons) do
            -- The class in hand: a dim gold fill in a gold line, as a chosen pill has.
            local on = b.classID == classID
            b.box:Paint(on and "needFill" or "well", on and "gold" or "cardLine")
        end
        if not data then return end
        kept, ranks, spent = Tree.Replay(data, build.order or {})

        local builds, suggested, raid = Tree.ClassBuilds(classID), {}, {}
        for _, b in ipairs(Tree.Suggested(classID)) do
            local list = b.raid and raid or suggested
            list[#list + 1] = b
        end
        listHead.count:SetText(#builds)
        suggestHead.count:SetText(#suggested)
        raidHead.count:SetText(#raid)
        local used, y = 0, 24
        local function Place(b)
            used = used + 1
            rows[used] = rows[used] or BuildRow()
            local row = rows[used]
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            y = y + ROW_H
            row.build = b
            row.name:SetText(b.name)
            row.sub:SetText(Summary(b))
            -- Which specs follow it: FOLLOWING with one spec; with dual spec SPEC 1, SPEC 2 or
            -- SPEC 1 & 2, gold where the spec you're on is one, grey where it's only your other.
            local followed, ours = false, false
            if data and data.own then
                if Tree.Dual and Tree.Dual() then
                    local specs, here = {}, Tree.Group()
                    for g = 1, 2 do
                        if Tree.Followed(g) == b then
                            specs[#specs + 1] = tostring(g)
                            if g == here then ours = true end
                        end
                    end
                    if #specs > 0 then
                        followed = true
                        row.tag:Say("SPEC " .. table.concat(specs, " & "))
                    end
                elseif Tree.Active() == b then
                    followed, ours = true, true
                    row.tag:Say("FOLLOWING")
                end
            end
            -- Not followed, a build for 60 simmed with your At 60 set says so, in grey.
            if not followed and ForYourSet(b) then
                followed = true
                row.tag:Say("YOUR SET")
            end
            row.tag:Tone(ours and "gold" or "plain")
            row.tag:SetShown(followed)
            row.tag:ClearAllPoints()
            row.sub:ClearAllPoints()
            row.name:SetWidth(LIST_W - 20)
            local beside = followed and Style.Wide(row.name, #(b.name or "") * 7.5) + 6 + row.tag.wide <= LIST_W - 20
            if followed and not beside then
                -- Beside the tag, just its points: the tree's name was cut off there.
                row.sub:SetText(Summary(b, true))
                row.tag:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
                row.sub:SetPoint("LEFT", row.tag, "RIGHT", 6, 0)
                row.sub:SetWidth(LIST_W - 20 - row.tag.wide - 6)
            else
                if followed then row.name:SetWidth(Style.Wide(row.name, #(b.name or "") * 7.5)) end
                row.tag:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
                row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
                row.sub:SetWidth(LIST_W - 20)
            end
            local selected = b == build
            row.bg:SetShown(selected)
            row.mark:SetShown(selected)
            row.name:SetTextColor(Style.Color(selected and "text" or "secondary"))
            row:Show()
        end
        for _, b in ipairs(builds) do Place(b) end
        ownEmpty:SetShown(#builds == 0)
        if #builds == 0 then
            ownEmpty:ClearAllPoints()
            ownEmpty:SetPoint("TOPLEFT", 0, -(y + 2))
            y = y + 36
        end
        suggestHead:SetShown(#suggested > 0)
        suggestHead:ClearAllPoints()
        suggestHead:SetPoint("TOPLEFT", 0, -(y + 12))
        y = y + 36
        for _, b in ipairs(suggested) do Place(b) end
        raidHead:SetShown(#raid > 0)
        raidHead:ClearAllPoints()
        raidHead:SetPoint("TOPLEFT", 0, -(y + 12))
        if #raid > 0 then y = y + 36 end
        for _, b in ipairs(raid) do Place(b) end
        for i = used + 1, #rows do rows[i]:Hide() end
        listBox:SetHeight(math.max(1, y))
        -- Another class's list starts at its top.
        if listScroll.forClass ~= classID then
            listScroll.forClass = classID
            listScroll:SetVerticalScroll(0)
        end
        listScroll:UpdateScrollChildRect()
        listScroll:Place()

        view:SetShown(not editing)
        editor:SetShown(editing)
        levelHead:SetShown(editing)
        more:SetShown(editing)
        for _, chip in ipairs(chips) do if not editing then chip:Hide() end end
        title:SetText((editing and "Editing " or "") .. build.name .. "   |cff9a9688" .. Summary(build) .. "|r")
        if editing then PaintEditor() else PaintView() end
    end

    -- View-mode buttons.
    -- The points Learn would spend now, in the plan's order, and each one's rank; nil when it
    -- mustn't: not the build you follow, nothing to spend, or points spent off the plan.
    local function ToLearn()
        local taken, nextIndex = Progress()
        local waiting = Compat.UnspentTalentPoints()
        if not (data.own and nextIndex and waiting > 0 and Tree.Active() == build) then return nil end
        local spent = 0
        for _, n in pairs(data.nodes) do spent = spent + (tonumber(n.learned) or 0) end
        if spent > taken then return nil end
        local ids, lines = {}, {}
        for i = nextIndex, math.min(#kept, nextIndex + waiting - 1) do
            local rank = 0
            for k = 1, i do if kept[k] == kept[i] then rank = rank + 1 end end
            local node = data.nodes[kept[i]]
            ids[#ids + 1] = kept[i]
            if #lines < 8 then
                lines[#lines + 1] = ("%d.  %s  |cff9a9688%s|r"):format(#ids, node and node.name or "?",
                    node and node.max == 1 and "" or ("rank " .. rank))
            end
        end
        if #ids > 8 then lines[#lines + 1] = ("|cff9a9688and %d more|r"):format(#ids - 8) end
        return ids, lines, nextIndex .. ":" .. table.concat(ids, ",")
    end
    learn:SetScript("OnClick", function()
        local ids, lines, key = ToLearn()
        if not ids then return end
        local group = Tree.Group and Tree.Group() or 1
        local dual = group > 1 or (GetNumSpecGroups and (tonumber(GetNumSpecGroups()) or 1) > 1)
        ask.title:SetText(("Learn %d point%s?"):format(#ids, #ids == 1 and "" or "s"))
        ask.where:SetText(("Into %s, by the plan %s."):format(not dual and "your talents"
            or (group == 1 and "your first spec" or "your second spec"), build.name or ""))
        ask.list:SetText(table.concat(lines, "\n"))
        ask.ids = key
        local tall = ask.list.GetStringHeight and ask.list:GetStringHeight() or 0
        ask:SetHeight(16 + 20 + 22 + (type(tall) == "number" and tall or #lines * 18) + 16 + 26 + 16)
        ask:ClearAllPoints()
        ask:SetPoint("TOPLEFT", nextCard, "BOTTOMLEFT", 0, -8)
        ask:Show()
    end)
    ask.cancel:SetScript("OnClick", function() ask.ids = nil; ask:Hide() end)
    -- Learn in the box spends only what it listed: if anything changed since, it says so instead.
    ask.go:SetScript("OnClick", function()
        local ids, _, key = ToLearn()
        local listed = ask.ids
        ask.ids = nil
        ask:Hide()
        if not ids or key ~= listed then
            Say("Your talents changed since. Look at the plan again before learning.")
            return
        end
        local ok, why = Tree.LearnMany(data, ids)
        Say(ok and (("Learned %d point%s from the plan."):format(#ids, #ids == 1 and "" or "s")) or why)
    end)
    cardFollow:SetScript("OnClick", function()
        Tree.Follow(build)
        Say("The talent helper now follows " .. build.name .. ".")
    end)
    follow:SetScript("OnClick", function()
        Tree.Follow(build)
        Say("The talent helper now follows " .. build.name .. ".")
    end)
    edit:SetScript("OnClick", function()
        if build.builtin then return end
        editing, status = true, nil
        Paint()
    end)
    rename:SetScript("OnClick", function()
        nameBox.forBuild = build
        nameBox:SetText(build.name)
        nameBox:Show()
        nameHint:Show()
        nameBox:SetFocus()
        nameBox:HighlightText()
        Paint()
    end)
    local function EndRename(keep)
        local name = strtrim(nameBox:GetText())
        if keep and name ~= "" and nameBox.forBuild == build then build.name = name end
        nameBox.forBuild = nil
        nameBox:ClearFocus()
        nameBox:Hide()
        nameHint:Hide()
        Paint()
    end
    nameBox:SetScript("OnEnterPressed", function() EndRename(true) end)
    nameBox:SetScript("OnEscapePressed", function() EndRename(false) end)
    export:SetScript("OnClick", function() ns.TalentShare.Export(build) end)
    copy:SetScript("OnClick", function()
        local mine = Tree.Copy(build)
        Say("Copied to your builds as " .. mine.name .. ". Edit it as you like.")
    end)

    -- Deleting asks once: the first click arms it for a few seconds, for the build it was
    -- clicked on (kept on the button, where the page's painting can see it). It was armed for
    -- the page: "Sure?" on one build, another picked in those seconds, and one click deleted that.
    delete:SetScript("OnClick", function()
        if build.builtin or (#Tree.ClassBuilds(classID) <= 1 and #Tree.Suggested(classID) == 0) then return end
        if delete.armedFor ~= build or GetTime() > (delete.armedTill or 0) then
            delete.armedFor, delete.armedTill = build, GetTime() + 3
            delete:SetLabel("Sure?")
            Compat.After(3, function()
                if GetTime() >= (delete.armedTill or 0) then
                    delete.armedFor = nil
                    delete:SetLabel("Delete")
                end
            end)
            return
        end
        delete.armedFor, delete.armedTill = nil, nil
        delete:SetLabel("Delete")
        Tree.Delete(build)
        Paint()
    end)

    -- Edit-mode buttons.
    undo:SetScript("OnClick", function()
        local order = {}
        for i = 1, #kept - 1 do order[i] = kept[i] end
        Save(order)
    end)
    clear:SetScript("OnClick", function() Save({}) end)
    done:SetScript("OnClick", function()
        editing, status = false, nil
        Paint()
    end)

    newBuild:SetScript("OnClick", function()
        Tree.NewBuild(classID)
        editing, status = true, nil
        Paint()
    end)
    import:SetScript("OnClick", function()
        ns.TalentShare.Import(function(added)
            classID, editing = added.class, false
            Say("Imported " .. added.name .. ".")
        end)
    end)

    page.Refresh = Paint
    Tree.OnChange(function()
        if page:IsVisible() then Paint() end
    end)
end, nil, true)
