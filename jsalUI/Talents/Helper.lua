-- The talent helper: when a talent point is waiting, a note names the next
-- talent in your active build, with a button to learn it. It only learns the
-- talent the plan says is next, never in combat, and only what the game allows.
local _, ns = ...
local Style, Compat, Tree = ns.Style, ns.Compat, ns.TalentTree

local Helper = ns.NewModule("talents", {
    title = "Talent helper",
    note = "Names the next talent in your plan when a point comes in, and marks it in the talent window.",
})
ns.TalentHelper = Helper

local toast, text, why, learn

-- The next step, when a point is waiting and the plan has one.
local function Pending()
    if Compat.UnspentTalentPoints() <= 0 then return nil end
    local data = Tree.Read()
    if not (data and data.configID) then return nil end
    local order = Tree.Replay(data, Tree.Active().order or {})
    local id, rank = Tree.Next(data, order)
    if not id then return nil end
    return data, data.nodes[id], rank
end

-- The level-up line leaves talent points to this note when it will show.
function Helper.Covers()
    if not Helper.running then return false end
    local ok, data = pcall(Pending)
    return ok and data ~= nil
end

local Show

local function Build()
    toast = CreateFrame("Frame", "jsalUITalentNote", UIParent)
    toast:SetSize(420, 96)
    toast:SetPoint("TOP", 0, -270)
    toast:SetFrameStrata("HIGH")
    toast:EnableMouse(true)
    toast:Hide()
    Style.Fill(toast, "window")
    Style.Border(toast, "lineStrong")
    local mark = toast:CreateTexture(nil, "ARTWORK")
    mark:SetColorTexture(Style.Color("gold"))
    mark:SetPoint("TOPLEFT")
    mark:SetPoint("BOTTOMLEFT")
    mark:SetWidth(2)

    text = Style.Text(toast, 13, "text")
    text:SetPoint("TOPLEFT", 14, -12)
    text:SetWidth(392)
    why = Style.Text(toast, 11, "gold")
    why:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -4)
    why:SetWidth(392)

    learn = Style.Button(toast, "Learn it", "primary", 90)
    learn:SetHeight(26)
    learn:SetPoint("BOTTOMLEFT", 14, 12)
    local open = Style.Button(toast, "Open plan", "plain", 96)
    open:SetHeight(26)
    open:SetPoint("LEFT", learn, "RIGHT", 6, 0)
    open:SetScript("OnClick", function()
        toast:Hide()
        ns.Window.Open("build")
    end)
    local later = Style.Button(toast, "Not now", "plain", 86)
    later:SetHeight(26)
    later:SetPoint("LEFT", open, "RIGHT", 6, 0)
    later:SetScript("OnClick", function() toast:Hide() end)

    learn:SetScript("OnClick", function()
        local data, node, rank = Pending()
        if not data then return toast:Hide() end
        local ok, reason = Tree.Learn(data, node.id)
        if not ok then
            why:SetText(reason)
            return
        end
        ns.Print(("Learned %s, rank %d of %d."):format(node.name, rank, node.max))
        -- The game updates the talents a moment later; then the next one shows.
        toast:Hide()
        Compat.After(0.5, function() Show() end)
    end)
end

Show = function()
    if not Helper.running or Compat.InCombat() then return end
    local data, node, rank = Pending()
    if not data then
        if toast then toast:Hide() end
        return
    end
    if not toast then Build() end
    local level = UnitLevel("player")
    text:SetText(("Level %d · next talent: |cffe3b04b%s|r, rank %d of %d  |cff9a9688(%s)|r"):format(
        level, node.name, rank, node.max, data.trees[node.tree].name))
    why:SetText("")
    toast:Show()
end

function Helper:OnEnable()
    -- The mark on the next talent inside the game's own talent window.
    ns.TalentGlow.Start()
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", ns.Safe(self, function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if toast then toast:Hide() end
        else
            -- The new point lands a moment after the level.
            Compat.After(2, function() ns.AfterCombat(Show) end)
        end
    end))
    Compat.After(6, ns.Safe(self, function() ns.AfterCombat(Show) end))
end

function Helper:OnDisable()
    if toast then toast:Hide() end
end
