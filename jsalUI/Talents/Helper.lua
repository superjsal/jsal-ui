-- The talent helper: when a talent point is waiting, a note names the next
-- talent in your active build. The note spends nothing: a press that spends a
-- point can't be taken back, and the note comes up unasked where a player may
-- already be clicking. The point is spent on the Build page, which it opens.
local _, ns = ...
local Style, Compat, Tree = ns.Style, ns.Compat, ns.TalentTree

local Helper = ns.NewModule("talents", {
    title = "Talent helper",
    note = "Names the next talent in your plan when a point comes in, and marks it in the talent window.",
    -- The one part that starts off: it speaks up about a player's talents unasked, so it waits to
    -- be switched on, in the welcome or in Settings.
    defaultOn = false,
})
ns.TalentHelper = Helper

local toast, text

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

local function Build()
    toast = CreateFrame("Frame", "jsalUITalentNote", UIParent)
    toast:SetSize(420, 96)
    toast:SetPoint("TOP", 0, -270)
    toast:SetFrameStrata("HIGH")
    toast:EnableMouse(true)
    toast:Hide()
    Style.Box(toast, 6, "window", "lineStrong")
    Style.Shadow(toast)
    Style.Opening(toast, 16)
    local mark = toast:CreateTexture(nil, "ARTWORK")
    mark:SetColorTexture(Style.Color("gold"))
    mark:SetPoint("TOPLEFT", 0, -6)
    mark:SetPoint("BOTTOMLEFT", 0, 6)
    mark:SetWidth(2)

    text = Style.Text(toast, 13, "text")
    text:SetPoint("TOPLEFT", 14, -12)
    text:SetWidth(392)
    local where = Style.Text(toast, 12, "muted")
    where:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -4)
    where:SetWidth(392)
    where:SetText("Learn it on your Build page.")

    local open = Style.Button(toast, "Open plan", "primary", 96)
    open:SetHeight(26)
    open:SetPoint("BOTTOMLEFT", 14, 12)
    open:SetScript("OnClick", function()
        toast:Hide()
        ns.Window.Open("build")
    end)
    local later = Style.Button(toast, "Not now", "plain", 86)
    later:SetHeight(26)
    later:SetPoint("LEFT", open, "RIGHT", 6, 0)
    later:SetScript("OnClick", function() toast:Hide() end)
end

local function Show()
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
