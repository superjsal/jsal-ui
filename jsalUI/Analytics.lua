-- Usage counts: which parts of jsal.ui are switched on and how often the
-- games and shortcuts get used, through Wago's own analytics addon. Only
-- players who turned on data sharing in the Wago app send anything, and
-- what's sent is counts and on/off switches: never a name, guild or realm.
-- Without the Wago app every call here does nothing.
local addonName, ns = ...
local Compat = ns.Compat

local Analytics = ns.NewModule("analytics", {
    title = "Usage counts",
    note = "Anonymous counts of which parts get used, sent only if you turned on data sharing in the Wago app. Never names, guilds or realms.",
})

local wago

-- Signs in with Wago's analytics as soon as the settings are there, if
-- that addon is installed and this switch is on.
ns.OnLoad(function()
    local real = WagoAnalytics
    local id = Compat.Metadata(addonName, "X-Wago-ID")
    if not (ns.ModuleWanted(Analytics) and type(real) == "table" and real.Register and id and id ~= "") then return end
    local ok, handle = pcall(real.Register, real, id)
    if ok and type(handle) == "table" then wago = handle end
end)

-- Adds to a count, such as a game played or a button used.
function ns.Count(name, by)
    if wago and Analytics.running then pcall(wago.IncrementCounter, wago, name, by or 1) end
end

local function Switch(name, on)
    if wago then pcall(wago.Switch, wago, name, on and true or false) end
end

-- At login: which parts and options are on.
function Analytics:OnEnable()
    if not wago then return end
    for _, module in ipairs(ns.moduleOrder) do
        Switch("part." .. module.key, ns.ModuleWanted(module))
        for _, option in ipairs(module.options or {}) do
            Switch("option." .. module.key .. "." .. option.key, ns.OptionOn(module.key, option.key))
        end
    end
    Switch("with.EllesmereUI", Compat.IsAddOnLoaded("EllesmereUI"))
end
