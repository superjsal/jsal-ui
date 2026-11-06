-- Vendor run: at any vendor, repairs your gear with your own gold and sells
-- grey items, then says in chat what it spent and earned. Holding Shift as
-- the vendor opens skips it.
local _, ns = ...
local Compat = ns.Compat

local Vendor = ns.NewModule("vendor", {
    title = "Vendor run",
    note = "Repairs and sells grey items at any vendor. Hold Shift to skip.",
})

local POOR = Enum and Enum.ItemQuality and Enum.ItemQuality.Poor or 0
local BATCH = 10
local open = false

local function Repair()
    if not CanMerchantRepair() then return 0 end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or cost <= 0 or GetMoney() < cost then return 0 end
    RepairAllItems()
    return cost
end

local function Greys()
    local list = {}
    for bag = 0, Compat.LAST_BAG do
        for slot = 1, Compat.BagSize(bag) do
            local item = Compat.BagItem(bag, slot)
            if item and item.quality == POOR and not item.hasNoValue and not item.isLocked then
                local price = item.hyperlink and Compat.SellPrice(item.hyperlink) or 0
                list[#list + 1] = { bag = bag, slot = slot, value = (price or 0) * (item.stackCount or 1) }
            end
        end
    end
    return list
end

local function Report(repaired, sold, earned)
    local parts = {}
    if repaired > 0 then parts[#parts + 1] = "Repaired for " .. Compat.Money(repaired) .. "." end
    if sold > 0 then
        parts[#parts + 1] = ("Sold %d grey item%s for %s."):format(sold, sold == 1 and "" or "s", Compat.Money(earned))
    end
    if #parts > 0 then ns.Print(table.concat(parts, " ")) end
end

-- Sells a few at a time, a moment apart, and stops if the vendor closes.
local function Sell(list, start, repaired, earned)
    if not open then return Report(repaired, start - 1, earned) end
    local last = math.min(start + BATCH - 1, #list)
    for i = start, last do
        Compat.UseBagItem(list[i].bag, list[i].slot)
        earned = earned + list[i].value
    end
    if last < #list then
        Compat.After(0.3, function() Sell(list, last + 1, repaired, earned) end)
    else
        Report(repaired, #list, earned)
    end
end

function Vendor:OnEnable()
    local events = CreateFrame("Frame")
    events:RegisterEvent("MERCHANT_SHOW")
    events:RegisterEvent("MERCHANT_CLOSED")
    events:SetScript("OnEvent", ns.Safe(self, function(_, event)
        if event == "MERCHANT_CLOSED" then
            open = false
            return
        end
        open = true
        if not Vendor.running or IsShiftKeyDown() then return end
        local repaired = Repair()
        local list = Greys()
        if #list > 0 then
            Sell(list, 1, repaired, 0)
        else
            Report(repaired, 0, 0)
        end
    end))
    self.events = events
end

function Vendor:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
end
