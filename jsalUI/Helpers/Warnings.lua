-- Bags and gear warnings: one heads-up when your bags are nearly full or
-- your gear is close to breaking, and not again until it's sorted. In
-- combat, the warning waits until the fight is over.
local _, ns = ...
local Compat = ns.Compat

local Warnings = ns.NewModule("warnings", {
    title = "Bags and gear warnings",
    note = "A heads-up when bags are nearly full or gear is close to breaking.",
})

local BAGS_LOW, BAGS_OK = 2, 5
local GEAR_LOW, GEAR_OK = 0.2, 0.5
local bagsWarned, gearWarned = false, false

local function Warn(text)
    ns.AfterCombat(function()
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage(text, ns.Style.Color("gold"))
        end
        ns.Print(text)
    end)
end

-- Only plain bags count: a profession bag's space can't hold everything.
local function CheckBags()
    local free = 0
    for bag = 0, Compat.LAST_BAG do
        local slots, bagType = Compat.BagFree(bag)
        if (bagType or 0) == 0 then free = free + (slots or 0) end
    end
    if free <= BAGS_LOW and not bagsWarned then
        bagsWarned = true
        Warn(free == 0 and "Your bags are full." or ("Your bags are nearly full: %d slot%s left."):format(free, free == 1 and "" or "s"))
    elseif free >= BAGS_OK then
        bagsWarned = false
    end
end

local function CheckGear()
    local lowest
    for slot = 1, 18 do
        local current, maximum = GetInventoryItemDurability(slot)
        if current and maximum and maximum > 0 then
            local share = current / maximum
            if not lowest or share < lowest then lowest = share end
        end
    end
    if not lowest then return end
    if lowest <= GEAR_LOW and not gearWarned then
        gearWarned = true
        Warn(("Your gear is down to %d%%. Repair soon."):format(math.floor(lowest * 100)))
    elseif lowest >= GEAR_OK then
        gearWarned = false
    end
end

function Warnings:OnEnable()
    local events = CreateFrame("Frame")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    events:SetScript("OnEvent", ns.Safe(self, function(_, event)
        if not Warnings.running then return end
        if event == "BAG_UPDATE_DELAYED" then CheckBags() else CheckGear() end
    end))
    self.events = events
    Compat.After(5, ns.Safe(self, function()
        CheckBags()
        CheckGear()
    end))
end

function Warnings:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
end
