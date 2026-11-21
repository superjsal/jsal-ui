-- Every class's talents, from the game's own talent tables (TalentData.lua),
-- with your own class's learned ranks read live from the game, and the rules
-- a plan follows. Forever's talents are the classic three trees per class,
-- 7 rows by 4 columns, one point a level from 10 to 60.
local _, ns = ...
local Compat = ns.Compat

local Tree = {}
ns.TalentTree = Tree

Tree.MAX_POINTS = 51
Tree.FIRST_LEVEL = 10
Tree.PER_ROW = 5   -- points in a tree before its next row opens

function Tree.PlayerClass()
    local _, _, classID = UnitClass("player")
    return classID
end

-- A class's name and colour, from the game.
function Tree.ClassInfo(classID)
    local name, token = GetClassInfo(classID)
    local color = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    return name or "?", color
end

-- The classes that have talent trees, in the game's order.
function Tree.Classes()
    local list = {}
    for classID in pairs(ns.TalentData) do list[#list + 1] = classID end
    table.sort(list)
    return list
end

-- A class's trees: talents with their place, ranks, spell and what they
-- need. For your own class, each talent also carries the ranks you've
-- learned, and the data carries what's needed to learn more.
local function ReadNow(classID)
    local source = ns.TalentData[classID]
    if not source then return nil end
    local own = classID == Tree.PlayerClass()
    local configID = own and C_ClassTalents and C_ClassTalents.GetActiveConfigID() or nil
    local data = { classID = classID, own = own, configID = configID, trees = {}, nodes = {} }
    for i, t in ipairs(source) do
        local tree = { name = t.name, nodes = {}, rows = 7, cols = 4 }
        data.trees[i] = tree
        for _, talent in ipairs(t.talents) do
            local id, row, col, max, spellID, need, needRanks = unpack(talent)
            local name, icon = Compat.SpellInfo(spellID)
            local learned = 0
            if configID then
                local info = C_Traits.GetNodeInfo(configID, id)
                learned = info and (info.ranksPurchased or info.currentRank) or 0
            end
            data.nodes[id] = {
                id = id, tree = i, row = row, col = col, max = max, spellID = spellID,
                name = name or "?", icon = icon, learned = learned,
                need = need ~= 0 and need or nil, needRanks = needRanks,
            }
            table.insert(tree.nodes, id)
        end
    end
    return data
end

-- Home's cards, the menu's count, the talent helper and the Build Planner
-- each asked for the trees, so one click on the dashboard asked the game
-- about every talent four or five times. A class's trees are kept until
-- your talents, level or spells change. Your own aren't kept while the game
-- has no talent config to read them from yet, as just after logging in.
local kept = {}
function Tree.Read(classID)
    classID = classID or Tree.PlayerClass()
    local data = kept[classID]
    if data then return data end
    data = ReadNow(classID)
    if data and (data.configID or not data.own) then kept[classID] = data end
    return data
end

function Tree.Forget() kept = {} end

local forget = CreateFrame("Frame")
for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
    "TRAIT_CONFIG_LIST_UPDATED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "PLAYER_LEVEL_UP",
    "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED" }) do
    forget:RegisterEvent(event)
end
forget:SetScript("OnEvent", Tree.Forget)

-- The plan's rules, as the game applies them: a row opens after 5 points
-- per row above it in that tree, a talent with an arrow into it needs the
-- talent the arrow comes from at full rank, and 51 points in all.
function Tree.CanAdd(data, ranks, spent, count, id)
    local node = data.nodes[id]
    if not node then return false, "That talent isn't in this class's trees." end
    if count >= Tree.MAX_POINTS then return false, "All 51 points are planned." end
    if (ranks[id] or 0) >= node.max then return false, node.name .. " is already planned at full rank." end
    local need = node.row * Tree.PER_ROW
    if (spent[node.tree] or 0) < need then
        return false, ("%s needs %d points in %s first."):format(node.name, need, data.trees[node.tree].name)
    end
    local before = node.need and data.nodes[node.need]
    if before and (ranks[before.id] or 0) < node.needRanks then
        return false, ("%s needs %s at %d first."):format(node.name, before.name, node.needRanks)
    end
    return true
end

-- Replays an order, keeping only the steps that are allowed at their turn,
-- and returns it with the planned ranks per talent and points per tree.
function Tree.Replay(data, order)
    local kept, ranks, spent = {}, {}, {}
    for _, id in ipairs(order) do
        if Tree.CanAdd(data, ranks, spent, #kept, id) then
            kept[#kept + 1] = id
            ranks[id] = (ranks[id] or 0) + 1
            local tree = data.nodes[id].tree
            spent[tree] = (spent[tree] or 0) + 1
        end
    end
    return kept, ranks, spent
end

-- The first step of the plan the character hasn't learned yet: the talent,
-- the rank it brings it to, and its place in the order.
function Tree.Next(data, order)
    local seen = {}
    for i, id in ipairs(order) do
        seen[id] = (seen[id] or 0) + 1
        local node = data.nodes[id]
        if node and node.learned < seen[id] then return id, seen[id], i end
    end
end

-- The loadout the game's own talent window has selected: a commit saves
-- into it too. None (the default loadout) commits the talents alone.
local function SavedLoadout(configID)
    local specs = C_SpecializationInfo
    local spec = specs and specs.GetSpecialization and specs.GetSpecialization() or (GetSpecialization and GetSpecialization())
    local specID = spec and ((specs and specs.GetSpecializationInfo and specs.GetSpecializationInfo(spec)) or (GetSpecializationInfo and GetSpecializationInfo(spec)))
    if not specID then return nil end
    local saved = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    local consts = Constants and Constants.TraitConsts
    if saved == configID or (consts and saved == consts.STARTER_BUILD_TRAIT_CONFIG_ID) then return nil end
    return saved
end

-- Spends several points at once, in the plan's order, and saves them in one
-- go. If the game refuses any of them, none are kept.
function Tree.LearnMany(data, ids)
    if not data.configID then return false, "Only your own class's talents can be learned." end
    if Compat.InCombat() then return false, "Talents can't change in combat." end
    for _, id in ipairs(ids) do
        if not C_Traits.PurchaseRank(data.configID, id) then
            C_Traits.RollbackConfig(data.configID)
            return false, ("The game won't let you learn %s yet."):format(data.nodes[id] and data.nodes[id].name or "that")
        end
    end
    if C_ClassTalents.CommitConfig(SavedLoadout(data.configID)) then return true end
    C_Traits.RollbackConfig(data.configID)
    return false, "The game didn't save them. Try again in a moment."
end

-- The level a step in the order is reached at: one point a level from 10.
-- The plan as the page lists it, from its steps (Tree.Steps). What's taken
-- folds into one line at the top (`open`: it's opened, and the taken steps
-- follow it); a step you're partway through is split into the ranks taken
-- and the ranks left, so the row that's next says which rank is; and where
-- the build moves to another tree there's a heading. `taken`: how many of
-- the plan's points are learned; `treeOf`: a talent's tree, by its id.
-- Rows are { fold = true, points, open } for the folded line,
-- { head = tree, points, first, last } for a heading (the run of steps in
-- that tree: its points, and the first and last point's place in the
-- plan), and a step { id, first, last, fromRank, toRank, done }.
function Tree.PlanRows(steps, taken, treeOf, open)
    local parts = {}
    for _, step in ipairs(steps) do
        if taken >= step.first and taken < step.last then
            local n = taken - step.first + 1
            parts[#parts + 1] = { id = step.id, first = step.first, last = taken, fromRank = step.fromRank,
                                  toRank = step.fromRank + n - 1, done = true }
            parts[#parts + 1] = { id = step.id, first = taken + 1, last = step.last, fromRank = step.fromRank + n,
                                  toRank = step.toRank, done = false }
        else
            parts[#parts + 1] = { id = step.id, first = step.first, last = step.last, fromRank = step.fromRank,
                                  toRank = step.toRank, done = step.last <= taken }
        end
    end
    local runs = {}
    for _, part in ipairs(parts) do
        local tree = treeOf(part.id)
        local run = runs[#runs]
        if not run or run.tree ~= tree then
            run = { tree = tree, points = 0, first = part.first }
            runs[#runs + 1] = run
        end
        run.points, run.last = run.points + (part.last - part.first + 1), part.last
        part.run = run
    end
    local rows, headed = {}, nil
    if taken > 0 then rows[1] = { fold = true, points = taken, open = open and true or false } end
    for _, part in ipairs(parts) do
        if open or not part.done then
            -- A build all in one tree needs no heading: its title names the tree.
            if #runs > 1 and part.run ~= headed then
                headed = part.run
                rows[#rows + 1] = { head = headed.tree, points = headed.points, first = headed.first, last = headed.last }
            end
            rows[#rows + 1] = part
        end
    end
    return rows
end

function Tree.Level(index)
    return Tree.FIRST_LEVEL + index - 1
end

-- The plan as a list of steps: back-to-back points in the same talent are
-- one step ("Levels 10-14, ranks 1-5"). Each step has its first and last
-- place in the order, the talent, and the ranks it goes from and to.
function Tree.Steps(order)
    local steps, seen = {}, {}
    for i, id in ipairs(order) do
        seen[id] = (seen[id] or 0) + 1
        local last = steps[#steps]
        if last and last.id == id then
            last.last, last.toRank = i, seen[id]
        else
            steps[#steps + 1] = { first = i, last = i, id = id, fromRank = seen[id], toRank = seen[id] }
        end
    end
    return steps
end

-- Share codes: "jsalui1:<class>:<talents>:<name>", one character per point,
-- each the talent's place in its class's list.
local CODE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function ClassOrder(classID)
    local list, index = {}, {}
    for _, tree in ipairs(ns.TalentData[classID] or {}) do
        for _, talent in ipairs(tree.talents) do
            list[#list + 1] = talent[1]
            index[talent[1]] = #list
        end
    end
    return list, index
end

function Tree.Encode(build)
    local _, index = ClassOrder(build.class)
    local chars = {}
    for _, id in ipairs(build.order or {}) do
        local n = index[id]
        if n and n <= #CODE then chars[#chars + 1] = CODE:sub(n, n) end
    end
    return ("jsalui1:%d:%s:%s"):format(build.class, table.concat(chars), build.name or "")
end

function Tree.Decode(text)
    if (text or ""):find("wowhead%.com") then return Tree.FromWowhead(text) end
    local classID, codes, name = strtrim(text or ""):match("^jsalui1:(%d+):([%w%+/]*):(.*)$")
    classID = tonumber(classID)
    if not classID or not ns.TalentData[classID] then return nil, "That isn't a jsal.ui build code or a Wowhead link." end
    local list = ClassOrder(classID)
    local order = {}
    for i = 1, #codes do
        local n = CODE:find(codes:sub(i, i), 1, true)
        if not n or not list[n] then return nil, "That build code is damaged." end
        order[#order + 1] = list[n]
    end
    name = strtrim(name or "")
    return { id = Tree.NewID(), class = classID, name = name ~= "" and name:sub(1, 24) or "Imported build", order = order }
end

-- Wowhead's Forever talent calculator links carry a whole build: after the
-- class, a fixed tag (Wowhead's own; it may change if Wowhead updates its
-- calculator), each tree's ranks as digits (trees joined by "-", trailing
-- zeros dropped), then "_t0", sometimes a flag or two ("_r95"), and after a
-- "/" the order: a tree's number (0 to 2) whenever the tree changes, then a
-- character per point for the talent's place, counted left to right, top
-- to bottom as in TalentData. Wowhead's calculator has two sets of
-- characters, one for a single point and one for "to full rank", taken
-- from its own code.
local WOWHEAD = "https://www.wowhead.com/forever/talent-calc/"
local WOWHEAD_TAG = "vkndmh"
local ONE_POINT = "abcdefghjkmnpqrstvwzxyilou468-~!"
local FULL_RANK = "ABCDEFGHJKMNPQRSTVWZXYILOU579_^."

local function Slug(classID)
    local _, token = GetClassInfo(classID)
    return token and token:lower() or nil
end

function Tree.WowheadLink(build)
    local slug = Slug(build.class)
    local source = ns.TalentData[build.class]
    if not (slug and source) then return nil end
    local place = {}   -- node -> tree, place in tree
    for t, tree in ipairs(source) do
        for i, talent in ipairs(tree.talents) do place[talent[1]] = { t, i } end
    end
    local ranks, order, current = {}, {}, nil
    for _, id in ipairs(build.order or {}) do
        local p = place[id]
        if p then
            ranks[p[1]] = ranks[p[1]] or {}
            ranks[p[1]][p[2]] = (ranks[p[1]][p[2]] or 0) + 1
            if current ~= p[1] then
                order[#order + 1] = tostring(p[1] - 1)
                current = p[1]
            end
            order[#order + 1] = ONE_POINT:sub(p[2], p[2])
        end
    end
    if #order == 0 then return WOWHEAD .. slug end
    local trees = {}
    for t, tree in ipairs(source) do
        local digits = {}
        for i = 1, #tree.talents do digits[i] = tostring((ranks[t] or {})[i] or 0) end
        trees[t] = (table.concat(digits):gsub("0+$", ""))
    end
    local joined = (table.concat(trees, "-"):gsub("%-+$", ""))
    return WOWHEAD .. slug .. "/" .. WOWHEAD_TAG .. joined .. "_t0/" .. table.concat(order)
end

-- Each tree's ranks from a link's digits, in TalentData's order, or nil if
-- they don't fit the trees.
local function WowheadRanks(source, digits)
    local ranks, t = {}, 0
    for part in (digits .. "-"):gmatch("([%d]*)%-") do
        t = t + 1
        local tree = source[t]
        if not tree or #part > #tree.talents then return nil end
        ranks[t] = {}
        for i, talent in ipairs(tree.talents) do
            local r = tonumber(part:sub(i, i)) or 0
            if r > talent[4] then return nil end
            ranks[t][i] = r
        end
    end
    for i = t + 1, #source do
        ranks[i] = {}
        for j = 1, #source[i].talents do ranks[i][j] = 0 end
    end
    return ranks
end

-- The order from a link's characters: each the talent at that place in its
-- tree, one point or to full rank. Nil if a character isn't a talent, or
-- the order doesn't end on the ranks the link gives.
local function WowheadOrder(source, ranks, letters)
    local order, taken, tree = {}, {}, 1
    for c in letters:gmatch(".") do
        if c == "0" or c == "1" or c == "2" then
            tree = tonumber(c) + 1
        else
            local one = ONE_POINT:find(c, 1, true)
            local full = FULL_RANK:find(c, 1, true)
            local talent = (one or full) and source[tree] and source[tree].talents[one or full]
            if not talent then return nil end
            local id, max = talent[1], talent[4]
            repeat
                order[#order + 1] = id
                taken[id] = (taken[id] or 0) + 1
            until not full or taken[id] >= max
        end
    end
    for t, data in ipairs(source) do
        for i, talent in ipairs(data.talents) do
            if (taken[talent[1]] or 0) ~= ranks[t][i] then return nil end
        end
    end
    return order
end

-- Reads a Wowhead link back into a build. Its tag is letters, or in older
-- links "v" and a version digit, so both readings are tried. A link without
-- the order part fills each tree top to bottom, which the plan's rules then
-- check.
function Tree.FromWowhead(text)
    local slug, rest = (text or ""):match("talent%-calc/(%a+)/(%S*)")
    if not slug then return nil end
    local classID
    for id in pairs(ns.TalentData) do
        if Slug(id) == slug:lower() then classID = id end
    end
    if not classID then return nil, "That Wowhead link isn't for a class jsal.ui knows." end
    local source = ns.TalentData[classID]
    local tag, digits, tail = rest:match("^(%a*)([%d%-]*)_t%d+(.*)$")
    if not tag then return nil, "That Wowhead link is damaged." end
    local letters = tail:match("/(%S+)$")
    local readings = { digits }
    if tag == "v" and digits:match("^%d") then readings[2] = digits:sub(2) end
    local order
    for _, reading in ipairs(readings) do
        local ranks = WowheadRanks(source, reading)
        if ranks and letters then
            order = WowheadOrder(source, ranks, letters)
        elseif ranks and not order then
            order = {}
            for t, data in ipairs(source) do
                for i, talent in ipairs(data.talents) do
                    for _ = 1, ranks[t][i] do order[#order + 1] = talent[1] end
                end
            end
        end
        if order and letters then break end
    end
    if not order then return nil, "That Wowhead link is from an older calculator or a different set of talents." end
    return { id = Tree.NewID(), class = classID, name = "Wowhead build", order = order }
end

function Tree.Add(build)
    local all = Tree.AllBuilds()
    all[#all + 1] = build
    ns.db.selectedBuild[build.class] = build.id
end

-- When talents change, whatever shows them repaints.
local listeners = {}
function Tree.OnChange(fn) listeners[#listeners + 1] = fn end

local watcher = CreateFrame("Frame")
for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "PLAYER_LEVEL_UP",
    "ACTIVE_TALENT_GROUP_CHANGED" }) do
    watcher:RegisterEvent(event)
end
local queued = false
watcher:SetScript("OnEvent", function()
    if queued then return end
    queued = true
    Compat.After(0.2, function()
        queued = false
        for _, fn in ipairs(listeners) do xpcall(fn, ns.Report) end
    end)
end)

-- Builds are saved for the whole account, so any character can plan any
-- class: each has an ID, a name, a class and an order. The build selected
-- for a class is remembered per class; for your own class, it's the one the
-- talent helper follows.
function Tree.AllBuilds()
    local all = type(ns.db.builds) == "table" and ns.db.builds or {}
    ns.db.builds = all
    ns.db.selectedBuild = type(ns.db.selectedBuild) == "table" and ns.db.selectedBuild or {}
    -- Builds from before they were account-wide move over once.
    local old = ns.char.builds
    if type(old) == "table" and type(old.list) == "table" then
        for _, b in ipairs(old.list) do
            if type(b.order) == "table" and #b.order > 0 then
                all[#all + 1] = { id = Tree.NewID(), name = b.name, class = Tree.PlayerClass(), order = b.order }
            end
        end
        ns.char.builds = nil
    end
    return all
end

function Tree.NewID()
    return ("%d-%d"):format(time(), math.random(100000, 999999))
end

function Tree.ClassBuilds(classID)
    local list = {}
    for _, build in ipairs(Tree.AllBuilds()) do
        if build.class == classID then list[#list + 1] = build end
    end
    return list
end

-- A new build is "Build N", N the lowest no build of the class's is named: after a delete the
-- count's next number could already be taken. A renamed one frees its number.
function Tree.NewBuild(classID)
    local all = Tree.AllBuilds()
    local taken = {}
    for _, b in ipairs(Tree.ClassBuilds(classID)) do taken[b.name or ""] = true end
    local n = 1
    while taken["Build " .. n] do n = n + 1 end
    local build = { id = Tree.NewID(), name = "Build " .. n, class = classID, order = {} }
    all[#all + 1] = build
    ns.db.selectedBuild[classID] = build.id
    return build
end

-- The ready-made leveling builds for a class, from SuggestedBuilds.lua. They
-- aren't saved with your builds, so they're never changed or deleted: Copy
-- makes one of your own from one.
function Tree.Suggested(classID)
    local list = {}
    for _, build in ipairs(ns.SuggestedBuilds or {}) do
        if build.class == classID then
            build.builtin = true
            list[#list + 1] = build
        end
    end
    return list
end

function Tree.Copy(build)
    local order = {}
    for i, id in ipairs(build.order or {}) do order[i] = id end
    local copy = { id = Tree.NewID(), class = build.class, name = ("Copy of " .. build.name):sub(1, 24), order = order }
    Tree.Add(copy)
    return copy
end

-- A class's build by its ID, your own or suggested.
local function Find(classID, id)
    if not id then return nil end
    for _, build in ipairs(Tree.ClassBuilds(classID)) do
        if build.id == id then return build end
    end
    for _, build in ipairs(Tree.Suggested(classID)) do
        if build.id == id then return build end
    end
end

-- The build selected for a class: the one last picked, or else your first
-- own build, or else the first suggested levelling one (a build for 60 is
-- only ever picked). A class with neither gets a new, empty build.
local function FirstLevelling(classID)
    for _, build in ipairs(Tree.Suggested(classID)) do
        if not build.raid then return build end
    end
end

function Tree.Selected(classID)
    -- Sets up the saved lists first: a player who has never made a build
    -- has none yet.
    Tree.AllBuilds()
    local build = Find(classID, ns.db.selectedBuild[classID])
        or Tree.ClassBuilds(classID)[1] or FirstLevelling(classID)
    if build then
        ns.db.selectedBuild[classID] = build.id
        return build
    end
    return Tree.NewBuild(classID)
end

function Tree.Select(classID, build)
    Tree.AllBuilds()
    ns.db.selectedBuild[classID] = build.id
end

-- With the deleted build chosen, the class shows the first build left: your own, else a
-- suggested levelling one, else its first build for 60. Tree.Selected alone would make a new
-- empty build for a class with only builds for 60.
function Tree.Delete(build)
    local all = Tree.AllBuilds()
    for i, b in ipairs(all) do
        if b == build then table.remove(all, i); break end
    end
    local classID = build.class
    if ns.db.selectedBuild[classID] == build.id then
        local left = Tree.ClassBuilds(classID)[1] or FirstLevelling(classID) or Tree.Suggested(classID)[1]
        ns.db.selectedBuild[classID] = left and left.id or nil
    end
end

-- Your talent group: 1, or 2 on your second spec where the game has dual spec.
function Tree.Group()
    local get = GetActiveTalentGroup or GetActiveSpecGroup
    local ok, group = pcall(get or function() return 1 end)
    return ok and tonumber(group) or 1
end

-- The build the talent helper follows, per character and per spec: the one you chose with
-- Follow this build. Your second spec follows its own once you choose one there, the first's
-- until then. With none chosen, the one selected the first time it's asked is kept as followed,
-- so looking at another build (a suggested one) doesn't make it the one followed: its title, the
-- helper, Home and the talent window's glow keep to the followed one.
function Tree.Follow(build)
    local group = Tree.Group()
    if group == 1 then
        ns.char.follow = build.id
    else
        ns.char.followSpec = type(ns.char.followSpec) == "table" and ns.char.followSpec or {}
        ns.char.followSpec[group] = build.id
    end
end

-- The build spec `group` follows, without choosing one for it: the spec you're on's is
-- Tree.Active(); your second spec's own, else the first's.
function Tree.Followed(group)
    if group == Tree.Group() then return Tree.Active() end
    local classID = Tree.PlayerClass()
    local own = group ~= 1 and type(ns.char.followSpec) == "table" and Find(classID, ns.char.followSpec[group])
    return own or Find(classID, ns.char.follow)
end

-- Whether you have a second spec to follow a build with.
function Tree.Dual()
    if Tree.Group() > 1 then return true end
    local ok, n = pcall(GetNumSpecGroups or function() return 1 end)
    return ok and (tonumber(n) or 1) > 1
end

function Tree.Active()
    local classID = Tree.PlayerClass()
    local group = Tree.Group()
    local own = group ~= 1 and type(ns.char.followSpec) == "table" and Find(classID, ns.char.followSpec[group])
    if own then return own end
    local followed = Find(classID, ns.char.follow)
    if followed then return followed end
    local selected = Tree.Selected(classID)
    if selected and selected.id and ns.char then ns.char.follow = selected.id end
    return selected
end
