-- The Build Planner page: a class picker across the top and that class's
-- saved builds on the left, with ready-made leveling builds under them to
-- follow or copy. On the right, a build shows as its plan, level
-- by level, with what's taken and what's next; Edit opens the three trees,
-- where clicking talents in the order you'd take them builds the plan.
local _, ns = ...
local Style, Window, Tree, Compat = ns.Style, ns.Window, ns.TalentTree, ns.Compat

local LIST_W, GUTTER = 176, 18
local ICON, LABEL = 32, 13          -- a talent's icon, and its rank under it
local LEVELS = 80                   -- the editor's level-by-level section
local CLASSES_TOP = 32
local BODY_TOP = 74                 -- the builds list and the build's header
local MAIN_TOP = 140                -- the plan list, or the editor's trees
local STEP_H = 30                   -- one row of the plan list
local SOURCE_H = 22                 -- a suggested build's source line
local ROW_H = 46                    -- one build in the builds list

-- A small section heading with a count, a note on the right, and a rule.
local function Section(parent, width)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(width, 20)
    s.title = Style.Text(s, 11, "gold", nil, true)
    s.title:SetPoint("LEFT")
    s.count = Style.Text(s, 11, "muted", nil, true)
    s.count:SetPoint("LEFT", s.title, "RIGHT", 8, 0)
    s.note = Style.Text(s, 11, "muted")
    s.note:SetPoint("RIGHT")
    s.note:SetJustifyH("RIGHT")
    Style.Rule(s, "BOTTOM", "line")
    return s
end

local function Small(parent, label, kind, width)
    local b = Style.Button(parent, label, kind or "plain", width)
    b:SetHeight(24)
    return b
end

Window.Page("build", function(page)
    local width, height = Window.contentWidth, Window.contentHeight
    local right = LIST_W + GUTTER
    local rightW = width - right
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

    local function Note(head, text)
        if status and GetTime() < statusUntil then
            head.note:SetText(status)
            head.note:SetTextColor(Style.Color("gold"))
        else
            head.note:SetText(text)
            head.note:SetTextColor(Style.Color("muted"))
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
        b.bg = Style.Fill(b, "well")
        b.edges = Style.Border(b, "cardLine")
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

    -- The builds list: your own builds, then the class's suggested ones.
    local listHead = Section(page, LIST_W)
    listHead:SetPoint("TOPLEFT", 0, -BODY_TOP)
    listHead.title:SetText("BUILDS")
    local ownEmpty = Style.Text(page, 11, "muted")
    ownEmpty:SetWidth(LIST_W - 12)
    ownEmpty:SetText("None yet. Start a new build, or copy a suggested one.")
    local suggestHead = Section(page, LIST_W)
    suggestHead.title:SetText("SUGGESTED")
    local rows = {}

    local function BuildRow()
        local row = CreateFrame("Button", nil, page)
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
        row:SetScript("OnClick", function(self)
            Tree.Select(classID, self.build)
            editing, status = false, nil
            Paint()
        end)
        return row
    end

    -- A build's line under its name: its main tree and points.
    local function Summary(b)
        if not data then return "" end
        local order, _, treePoints = Tree.Replay(data, b.order or {})
        local text = "No points yet"
        if #order > 0 then
            local best, most = 1, -1
            for i in ipairs(data.trees) do
                if (treePoints[i] or 0) > most then best, most = i, treePoints[i] or 0 end
            end
            text = ("%s, %d points"):format(data.trees[best].name, #order)
        end
        if data.own and Tree.Active() == b then text = text .. " · following" end
        return text
    end

    ---------------------------------------------------------------------------
    -- View mode: the build's header, its buttons, and the plan as a list.
    ---------------------------------------------------------------------------
    local view = CreateFrame("Frame", nil, page)
    view:SetPoint("TOPLEFT", right, -BODY_TOP)
    view:SetSize(rightW, height - BODY_TOP)
    local viewHead = Section(view, rightW)
    viewHead:SetPoint("TOPLEFT")

    -- Six buttons in one row; the widths add up to the column's width. A
    -- suggested build swaps Edit, Rename and Delete for Copy to my builds.
    local learn = Small(view, "Learn next points", "primary", 128)
    learn:SetPoint("TOPLEFT", 0, -30)
    local follow = Small(view, "Follow this build", "plain", 118)
    follow:SetPoint("LEFT", learn, "RIGHT", 6, 0)
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
    Style.Fill(nameBox, "well")
    Style.Border(nameBox, "gold")
    nameBox:Hide()
    local nameHint = Style.Text(view, 11, "muted")
    nameHint:SetPoint("LEFT", nameBox, "RIGHT", 10, 0)
    nameHint:SetText("Enter to save, Escape to cancel")
    nameHint:Hide()

    -- The plan list scrolls with the mouse wheel; a thin bar shows where.
    local scroll, list = Style.Scroller(view, rightW - 8, height - MAIN_TOP, nil, 7, STEP_H * 3)
    scroll:SetPoint("TOPLEFT", 0, -(MAIN_TOP - BODY_TOP))
    local empty = Style.Text(list, 13, "muted")
    empty:SetPoint("TOPLEFT", 10, -10)
    empty:SetWidth(rightW - 30)

    local stepRows = {}
    local function StepRow(i)
        local row = CreateFrame("Frame", nil, list)
        row:SetSize(rightW - 8, STEP_H)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * STEP_H)
        row.bg = Style.Fill(row, "well")
        row.levels = Style.Text(row, 12, "muted", nil, true)
        row.levels:SetPoint("LEFT", 10, 0)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(22, 22)
        row.icon:SetPoint("LEFT", 110, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.name = Style.Text(row, 13, "text")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.rank = Style.Text(row, 11, "muted")
        row.rank:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
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
        if data.own then
            Note(viewHead, ("%d of %d points taken"):format(taken, #kept))
        else
            Note(viewHead, ("%d points planned"):format(#kept))
        end

        local renaming = nameBox:IsShown()
        local builtin = build.builtin
        for _, b in ipairs({ learn, follow, edit, rename, export, delete, copy }) do b:SetShown(not renaming) end
        learn:SetShown(not renaming and data.own)
        follow:SetShown(not renaming and data.own)
        edit:SetShown(not renaming and not builtin)
        rename:SetShown(not renaming and not builtin)
        delete:SetShown(not renaming and not builtin)
        copy:SetShown(not renaming and builtin)
        -- Another class has nothing to learn or follow, so Edit (or Copy)
        -- leads the row.
        local first = builtin and copy or edit
        first:ClearAllPoints()
        if data.own then first:SetPoint("LEFT", follow, "RIGHT", 6, 0) else first:SetPoint("TOPLEFT", 0, -30) end
        export:ClearAllPoints()
        export:SetPoint("LEFT", builtin and copy or rename, "RIGHT", 6, 0)
        learn:SetEnabled(nextIndex ~= nil and waiting > 0)
        local following = data.own and Tree.Active() == build
        follow:SetLabel(following and "Following" or "Follow this build")
        follow:SetEnabled(not following)
        delete:SetEnabled(#Tree.ClassBuilds(classID) > 1 or #Tree.Suggested(classID) > 0)

        -- A suggested build says where it's from, above its plan.
        local shift = builtin and SOURCE_H or 0
        source:SetShown(builtin)
        source:SetText(builtin and ("Suggested, from |cffece6d6%s|r. Copy it to change anything."):format(build.source) or "")
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", 0, -(MAIN_TOP - BODY_TOP + shift))
        scroll:SetHeight(height - MAIN_TOP - shift)

        local steps = Tree.Steps(kept)
        empty:SetShown(#steps == 0)
        empty:SetText("Nothing planned yet. Edit opens the trees: click talents in the order you'd take them.")
        for i, step in ipairs(steps) do
            local row = stepRows[i] or StepRow(i)
            stepRows[i] = row
            local node = data.nodes[step.id]
            row.id = step.id
            local a, b = Tree.Level(step.first), Tree.Level(step.last)
            row.levels:SetText(a == b and ("Level %d"):format(a) or ("Levels %d-%d"):format(a, b))
            row.icon:SetTexture(node.icon)
            row.name:SetText(node.name)
            local ranksText = step.fromRank == step.toRank and tostring(step.toRank) or (step.fromRank .. "-" .. step.toRank)
            row.rank:SetText(("Rank %s of %d"):format(ranksText, node.max))
            row.bg:SetShown(i % 2 == 1)
            local done = data.own and step.last <= taken
            local isNext = nextIndex and step.first <= nextIndex and nextIndex <= step.last
            row:SetAlpha(done and 0.6 or 1)
            if done then
                row.state:SetText("Taken")
                row.state:SetTextColor(Style.Color("muted"))
            elseif isNext then
                row.state:SetText(waiting > 0 and "Next, learn it now" or "Next")
                row.state:SetTextColor(Style.Color("gold"))
            else
                row.state:SetText("")
            end
            row.levels:SetTextColor(Style.Color(isNext and "text" or "muted"))
            row:Show()
        end
        for i = #steps + 1, #stepRows do stepRows[i]:Hide() end
        list:SetHeight(math.max(1, #steps * STEP_H))
        scroll:UpdateScrollChildRect()
        scroll:Place()
    end

    ---------------------------------------------------------------------------
    -- Edit mode: the three trees and the plan's order.
    ---------------------------------------------------------------------------
    local editor = CreateFrame("Frame", nil, page)
    editor:SetPoint("TOPLEFT", right, -BODY_TOP)
    editor:SetSize(rightW, height - BODY_TOP)
    local editHead = Section(editor, rightW)
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

    local levelHead = Section(page, width)
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
                Style.Fill(chip, "well")
                chip.edges = Style.Border(chip, "cardLine")
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
        for _, b in ipairs(classButtons) do
            local on = b.classID == classID
            b.bg:SetShown(on)
            Style.SetBorder(b.edges, on and "gold" or "cardLine")
        end
        if not data then return end
        kept, ranks, spent = Tree.Replay(data, build.order or {})

        local builds, suggested = Tree.ClassBuilds(classID), Tree.Suggested(classID)
        listHead.count:SetText(#builds)
        suggestHead.count:SetText(#suggested)
        local used, y = 0, BODY_TOP + 24
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
        for i = used + 1, #rows do rows[i]:Hide() end

        view:SetShown(not editing)
        editor:SetShown(editing)
        levelHead:SetShown(editing)
        more:SetShown(editing)
        for _, chip in ipairs(chips) do if not editing then chip:Hide() end end
        title:SetText((editing and "Editing " or "") .. build.name .. "   |cff9a9688" .. Summary(build) .. "|r")
        if editing then PaintEditor() else PaintView() end
    end

    -- View-mode buttons.
    learn:SetScript("OnClick", function()
        local _, nextIndex = Progress()
        local waiting = Compat.UnspentTalentPoints()
        if not nextIndex or waiting <= 0 then return end
        local ids = {}
        for i = nextIndex, math.min(#kept, nextIndex + waiting - 1) do ids[#ids + 1] = kept[i] end
        local ok, why = Tree.LearnMany(data, ids)
        Say(ok and (("Learned %d point%s from the plan."):format(#ids, #ids == 1 and "" or "s")) or why)
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
        nameBox:SetText(build.name)
        nameBox:Show()
        nameHint:Show()
        nameBox:SetFocus()
        nameBox:HighlightText()
        Paint()
    end)
    local function EndRename(keep)
        local name = strtrim(nameBox:GetText())
        if keep and name ~= "" then build.name = name end
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

    -- Deleting asks once: the first click arms it for a few seconds.
    local armed = 0
    delete:SetScript("OnClick", function()
        if build.builtin or (#Tree.ClassBuilds(classID) <= 1 and #Tree.Suggested(classID) == 0) then return end
        if GetTime() > armed then
            armed = GetTime() + 3
            delete:SetLabel("Sure?")
            Compat.After(3, function() delete:SetLabel("Delete") end)
            return
        end
        armed = 0
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
end)
