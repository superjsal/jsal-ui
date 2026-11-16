-- Pet feeding tile, for hunters: a small glowing tile beside the food
-- reminder while your pet is out and not happy, out of a fight. Pointing at
-- it opens a row of the food in your bags that your pet eats, highest level
-- first, and a click on one feeds it to your pet. It works like the food
-- reminder beside it: the tile itself only opens the row and drags.
--
-- Feeding is the Feed Pet spell cast on an item, which only the game's own
-- secure buttons may do: Forever's secure button casts the spell, then uses
-- the item its "target-bag" and "target-slot" name. Those buttons can't be
-- shown, hidden or changed in a fight, so the tile and its row hide as a
-- fight starts and come back once it ends. While the pet is eating (the Feed
-- Pet Effect on it) the tile waits, so a second click doesn't waste food.
-- What a pet eats comes from the game (C_PetInfo.CanPetEatItem), so no diet
-- table is kept here.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local PetFeed = ns.NewModule("petfeed", {
    title = "Pet feeding",
    -- A new box on the screen, so it starts off.
    defaultOn = false,
    note = "Hunters: a glowing tile beside the food reminder while your pet isn't happy. Point at it for the food in your bags your pet eats, and click one to feed your pet. Drag it anywhere.",
})
ns.PetFeed = PetFeed

local SIZE, ITEM, GAP, MAX = 36, 32, 4, 10
PetFeed.FEED_PET = 6991          -- Feed Pet, seen on Wowhead Forever
local FEED_PET_EFFECT = 1539      -- the buff on the pet while it eats
local ICON = 132165               -- Feed Pet's icon
local MOODS = { "Unhappy", "Content", "Happy" }

---------------------------------------------------------------------------
-- Your pet and your bags.
---------------------------------------------------------------------------

-- How happy your hunter pet is: 1 unhappy, 2 content, 3 happy; nil with no
-- hunter pet out.
function PetFeed.Mood()
    if not (UnitExists("pet") and HasPetUI) then return nil end
    local _, isHunterPet = HasPetUI()
    if not isHunterPet then return nil end
    return (C_PetInfo.GetPetHappiness())
end

-- Whether the pet is eating right now.
function PetFeed.Eating()
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not get then return false end
    for i = 1, 40 do
        local ok, aura = pcall(get, "pet", i, "HELPFUL")
        if not ok or not aura then break end
        -- A buff the game hides is skipped, never read.
        local name, spell = Compat.Plains(aura.name, aura.spellId)
        if spell == FEED_PET_EFFECT or name == "Feed Pet Effect" then return true end
    end
    return false
end

-- The food in your bags your pet eats, once per kind with where the first
-- of it is: highest level first (a pet likes food near its own level), then
-- the most you carry.
function PetFeed.Foods()
    local seen, list = {}, {}
    local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    for bag = 0, Compat.LAST_BAG do
        for slot = 1, Compat.BagSize(bag) do
            local item = Compat.BagItem(bag, slot)
            local id = item and item.itemID
            if id and not seen[id] and C_PetInfo.CanPetEatItem(id) then
                seen[id] = true
                local level = select(4, info(id)) or 0
                list[#list + 1] = { id = id, icon = item.iconFileID, bag = bag, slot = slot,
                                    count = Compat.ItemCount(id) or 1, level = level }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        if a.count ~= b.count then return a.count > b.count end
        return a.id < b.id
    end)
    for i = #list, MAX + 1, -1 do list[i] = nil end
    return list
end

-- Shown to a hunter who knows Feed Pet, with a living pet out that isn't
-- happy and isn't eating, while alive, out of a fight and off a flight.
function PetFeed.Wanted()
    if Compat.InCombat() then return false end
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return false end
    if IsPlayerSpell and not IsPlayerSpell(PetFeed.FEED_PET) then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
    if Compat.OnTaxi and Compat.OnTaxi() then return false end
    local mood = PetFeed.Mood()
    if not mood or mood >= 3 then return false end
    if UnitIsDead and UnitIsDead("pet") then return false end
    local ok, eating = pcall(PetFeed.Eating)
    return ok and not eating
end

---------------------------------------------------------------------------
-- The tile and its row.
---------------------------------------------------------------------------
local holder, tile, row, glow

local function Glow(frame)
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    local OUT, THICK = 3, 2
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetColorTexture(Style.Color("gold"))
        if side == "TOP" or side == "BOTTOM" then
            local y = side == "TOP" and OUT or -OUT
            t:SetPoint(side .. "LEFT", -OUT, y)
            t:SetPoint(side .. "RIGHT", OUT, y)
            t:SetHeight(THICK)
        else
            local x = side == "LEFT" and -OUT or OUT
            t:SetPoint("TOP" .. side, x, OUT)
            t:SetPoint("BOTTOM" .. side, x, -OUT)
            t:SetWidth(THICK)
        end
    end
    local pulse = overlay:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.3)
    fade:SetDuration(0.9)
    overlay.pulse = pulse
    return overlay
end

-- Points a secure button at a food: cast Feed Pet, then use the food in
-- that bag slot. Nil clears it. Never in a fight.
local function Aim(button, food)
    if food then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", PetFeed.FEED_PET)
        button:SetAttribute("target-bag", food.bag)
        button:SetAttribute("target-slot", food.slot)
    else
        button:SetAttribute("type", nil)
        button:SetAttribute("spell", nil)
        button:SetAttribute("target-bag", nil)
        button:SetAttribute("target-slot", nil)
    end
end
PetFeed.Aim = Aim

local function PetName()
    return Compat.Name("pet") or "your pet"
end

-- One food button: the game's secure button, so a click feeds it.
local function FoodButton(i)
    local b = row.items[i]
    if b then return b end
    b = CreateFrame("Button", "jsalUIPetFood" .. i, row, "SecureActionButtonTemplate")
    b:SetSize(ITEM, ITEM)
    -- Press and release both reach it, and the game acts on the one its
    -- "act on key down" setting picks. With the release alone, a click did
    -- nothing while that setting was on.
    b:RegisterForClicks("AnyUp", "AnyDown")
    Style.Fill(b, "well")
    b.edges = Style.Border(b, "lineStrong")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = Style.Text(b, 12, "text", "OVERLAY", true)
    b.count:SetPoint("BOTTOMRIGHT", -3, 3)
    b.count:SetJustifyH("RIGHT")
    b:SetScript("OnEnter", function(self)
        Style.SetBorder(self.edges, "gold")
        if self.food and GameTooltip.SetItemByID then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
            GameTooltip:SetItemByID(self.food)
            local mood = MOODS[PetFeed.Mood() or 0]
            if mood then GameTooltip:AddLine(("%s is %s."):format(PetName(), mood), 0.6, 0.59, 0.53) end
            GameTooltip:AddLine(("Click to feed it to %s."):format(PetName()), 0.6, 0.59, 0.53)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        Style.SetBorder(self.edges, "lineStrong")
        GameTooltip:Hide()
    end)
    row.items[i] = b
    return b
end

-- Lays the food out in one row under the tile, centred on it.
local function FillRow()
    if Compat.InCombat() then return end
    local list = PetFeed.Foods()
    for i, food in ipairs(list) do
        local b = FoodButton(i)
        b.food = food.id
        Aim(b, food)
        b.icon:SetTexture(food.icon)
        b.count:SetText(food.count > 1 and food.count or "")
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", (i - 1) * (ITEM + GAP), 0)
        b:Show()
    end
    for i = #list + 1, #row.items do
        local b = row.items[i]
        b.food = nil
        Aim(b, nil)
        b:Hide()
    end
    row:SetSize(math.max(1, #list) * (ITEM + GAP) - GAP, ITEM)
    row.count = #list
end
PetFeed.FillRow = FillRow

local CloseRow

local function OpenRow()
    if Compat.InCombat() then return end
    -- One row at a time: the food reminder's sits in the same place, and
    -- the two lay over each other.
    if ns.FoodTile and ns.FoodTile.CloseRow then ns.FoodTile.CloseRow() end
    FillRow()
    if row.count == 0 then
        GameTooltip:SetOwner(tile, "ANCHOR_BOTTOM")
        GameTooltip:SetText(("%s is %s"):format(PetName(), MOODS[PetFeed.Mood() or 0] or "hungry"))
        GameTooltip:AddLine("No food it eats in your bags.", 0.6, 0.59, 0.53)
        GameTooltip:Show()
        return
    end
    row.away = 0
    row:Show()
end

function CloseRow()
    if row and row:IsShown() and not Compat.InCombat() then row:Hide() end
end
PetFeed.CloseRow = CloseRow

-- Its own spot once dragged; until then just right of the food reminder,
-- wherever that is.
local function Place()
    holder:ClearAllPoints()
    local at = ns.db and ns.db.petFeedAt
    if type(at) == "table" and at[1] then
        holder:SetPoint(at[1], UIParent, at[2], at[3], at[4])
        return
    end
    local food = ns.db and ns.db.foodTileAt
    if type(food) == "table" and food[1] then
        holder:SetPoint(food[1], UIParent, food[2], food[3] + SIZE + 8, food[4])
    else
        holder:SetPoint("CENTER", UIParent, "CENTER", SIZE + 8, -170)
    end
end

local function Build()
    holder = CreateFrame("Frame", "jsalUIPetFeedTile", UIParent)
    holder:SetSize(SIZE, SIZE)
    holder:SetFrameStrata("MEDIUM")
    holder:SetClampedToScreen(true)
    holder:SetMovable(true)
    -- A plain button, as the food reminder's is: it opens the row and
    -- drags, and never feeds. (It fed the first food on a click, but a
    -- click that acts as the button goes down fed on every drag too.)
    tile = CreateFrame("Button", "jsalUIPetFeedButton", holder)
    tile:SetAllPoints()
    tile:RegisterForDrag("LeftButton")
    tile:SetScript("OnDragStart", function()
        if Compat.InCombat() then return end
        holder:StartMoving()
    end)
    tile:SetScript("OnDragStop", function()
        holder:StopMovingOrSizing()
        local point, _, relative, x, y = holder:GetPoint(1)
        if ns.db then ns.db.petFeedAt = { point, relative, x, y } end
    end)
    tile.fill = Style.Fill(tile, "well")
    tile.edges = Style.Border(tile, "gold")
    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetTexture(ICON)
    tile.icon:SetPoint("TOPLEFT", 3, -3)
    tile.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    tile.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tile:SetScript("OnEnter", function(self)
        self.fill:SetColorTexture(Style.Color("wellHover"))
        OpenRow()
    end)
    tile:SetScript("OnLeave", function(self)
        self.fill:SetColorTexture(Style.Color("well"))
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    glow = Glow(tile)

    row = CreateFrame("Frame", "jsalUIPetFoodRow", UIParent)
    row:SetFrameStrata("DIALOG")
    row:SetClampedToScreen(true)
    row:SetPoint("TOP", holder, "BOTTOM", 0, -6)
    row.items = {}
    row.count = 0
    row:Hide()
    -- It stays while the pointer is on the tile or the row.
    row:SetScript("OnUpdate", function(self, elapsed)
        self.away = (holder:IsMouseOver() or self:IsMouseOver()) and 0 or (self.away or 0) + elapsed
        if self.away > 0.3 then CloseRow() end
    end)
    holder:Hide()
end

-- Shows or hides the tile for how your pet is now. Never in a fight: secure
-- buttons can't change then.
function PetFeed.Update()
    if not holder or Compat.InCombat() then return end
    if PetFeed.Wanted() then
        FillRow()
        if not holder:IsShown() then
            holder:Show()
            glow.pulse:Play()
        end
    else
        CloseRow()
        glow.pulse:Stop()
        holder:Hide()
    end
end

-- The events that name a unit, and whose: heard for that unit alone, where the game allows.
local UNIT = { UNIT_HAPPINESS = "pet", UNIT_AURA = "pet", UNIT_PET = "player" }

function PetFeed:OnEnable()
    -- Hunters only: for any other class nothing is built, and nothing listens (it heard
    -- every aura on everyone nearby, to find it wasn't a hunter's pet's).
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return end
    if not holder then Build() end
    Place()
    if ns.Unlock then
        ns.Unlock.Add({
            key = "PetFeed", label = "jsal.ui pet feeding",
            frame = function() return holder end,
            load = function() return ns.db and ns.db.petFeedAt end,
            save = function(point, relative, x, y)
                if not ns.db then return end
                ns.db.petFeedAt = point and { point, relative, x, y } or nil
                if not point then Place() end
            end,
        })
    end
    local events = self.events or CreateFrame("Frame")
    self.events = events
    for _, e in ipairs({ "UNIT_HAPPINESS", "UNIT_PET", "UNIT_AURA", "PET_UI_UPDATE", "BAG_UPDATE_DELAYED",
                         "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_DEAD",
                         "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_CONTROL_GAINED", "PLAYER_CONTROL_LOST" }) do
        if UNIT[e] and events.RegisterUnitEvent then
            events:RegisterUnitEvent(e, UNIT[e])
        else
            events:RegisterEvent(e)
        end
    end
    events:SetScript("OnEvent", ns.Safe(self, function(_, event, unit)
        unit = Compat.Plain(unit)
        if event == "UNIT_AURA" and unit ~= "pet" then return end
        -- The fight's lockdown starts after this event, so hide now.
        if event == "PLAYER_REGEN_DISABLED" then
            CloseRow()
            glow.pulse:Stop()
            holder:Hide()
            return
        end
        PetFeed.Update()
    end))
    PetFeed.Update()
end

function PetFeed:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
    if not holder then return end
    ns.AfterCombat(function()
        if row then row:Hide() end
        if holder then holder:Hide() end
    end)
end
