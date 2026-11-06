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
function Tree.Read(classID)
    classID = classID or Tree.PlayerClass()
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

-- Spends a point on one of your own talents. A refused commit is rolled
-- back, so nothing is left half-learned.
function Tree.Learn(data, id)
    if not data.configID then return false, "Only your own class's talents can be learned." end
    if Compat.InCombat() then return false, "Talents can't change in combat." end
    if not C_Traits.PurchaseRank(data.configID, id) then
        return false, "The game won't let you learn that one yet."
    end
    if C_ClassTalents.CommitConfig(SavedLoadout(data.configID)) then return true end
    C_Traits.RollbackConfig(data.configID)
    return false, "The game didn't save it. Try again in a moment."
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
-- "/" the order: a tree's number whenever the tree changes, then a letter
-- per point, counted left to right, top to bottom (a capital takes it to
-- full rank). Links made here letter the talents by their place in
-- TalentData.
local WOWHEAD = "https://www.wowhead.com/forever/talent-calc/"
local WOWHEAD_TAG = "vkndmh"

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
            order[#order + 1] = string.char(96 + p[2])
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

-- The order from a link's letters. Wowhead's letters skip a few places that
-- TalentData doesn't have, so a letter isn't simply a talent's place; but
-- both count top to bottom, left to right, so the letters a tree uses,
-- sorted, are the talents the ranks give points to, in order. A capital
-- takes its talent to full rank. Nil if the letters and ranks disagree.
local function WowheadOrder(source, ranks, letters)
    local tokens, tree = {}, 1
    for c in letters:gmatch(".") do
        if c:match("%d") then tree = tonumber(c) + 1 else tokens[#tokens + 1] = { tree, c } end
    end
    local map = {}
    for t, data in ipairs(source) do
        local used, seen = {}, {}
        for _, token in ipairs(tokens) do
            local c = token[2]:lower()
            if token[1] == t and not seen[c] then seen[c] = true; used[#used + 1] = c end
        end
        table.sort(used)
        local ranked = {}
        for i, talent in ipairs(data.talents) do
            if ranks[t][i] > 0 then ranked[#ranked + 1] = talent end
        end
        if #used ~= #ranked then return nil end
        map[t] = {}
        for i, c in ipairs(used) do map[t][c] = ranked[i] end
    end
    local order, taken = {}, {}
    for _, token in ipairs(tokens) do
        local talent = map[token[1]] and map[token[1]][token[2]:lower()]
        if not talent then return nil end
        local id, max = talent[1], talent[4]
        repeat
            order[#order + 1] = id
            taken[id] = (taken[id] or 0) + 1
        until not token[2]:match("%u") or taken[id] >= max
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
    local letters = tail:match("/(%w+)$")
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
for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "PLAYER_LEVEL_UP" }) do
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

function Tree.NewBuild(classID)
    local all = Tree.AllBuilds()
    local count = #Tree.ClassBuilds(classID)
    local build = { id = Tree.NewID(), name = "Build " .. (count + 1), class = classID, order = {} }
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
-- own build, or else the first suggested one. A class with neither gets a
-- new, empty build.
function Tree.Selected(classID)
    local build = Find(classID, ns.db.selectedBuild[classID])
        or Tree.ClassBuilds(classID)[1] or Tree.Suggested(classID)[1]
    if build then
        ns.db.selectedBuild[classID] = build.id
        return build
    end
    return Tree.NewBuild(classID)
end

function Tree.Select(classID, build)
    ns.db.selectedBuild[classID] = build.id
end

function Tree.Delete(build)
    local all = Tree.AllBuilds()
    for i, b in ipairs(all) do
        if b == build then table.remove(all, i); break end
    end
    if ns.db.selectedBuild[build.class] == build.id then ns.db.selectedBuild[build.class] = nil end
end

-- The build the talent helper follows, per character: the one you chose
-- with Follow this build, or else the one selected for your class.
function Tree.Follow(build)
    ns.char.follow = build.id
end

function Tree.Active()
    local classID = Tree.PlayerClass()
    return Find(classID, ns.char.follow) or Tree.Selected(classID)
end
