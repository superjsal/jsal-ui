-- Outfit beyond jsal.ui's own windows. It goes on the shared font list other
-- addons build their font menus from (LibSharedMedia, which EllesmereUI and
-- many others carry), as "Outfit" and "Outfit SemiBold". With its switch on,
-- RestedXP Guides draws its guide in Outfit too.
local _, ns = ...
local Style = ns.Style

local SharedFonts = ns.NewModule("sharedFonts", {
    title = "Outfit in other addons",
    note = "Adds Outfit, jsal.ui's font, to the font lists of addons that share fonts, such as EllesmereUI.",
    options = {
        { key = "restedxp", title = "Use Outfit in RestedXP Guides", default = false,
          note = "The guide's steps and title in Outfit instead of the game's font." },
    },
})
ns.SharedFonts = SharedFonts

-- The shared list lives in a library another addon brings. jsal.ui loads
-- after EllesmereUI, so it's usually there already; failing that, it's
-- tried again at login, once every addon has loaded.
local shared = false
local function Share()
    if shared then return true end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not LSM then return false end
    LSM:Register("font", "Outfit", Style.font)
    LSM:Register("font", "Outfit SemiBold", Style.boldFont)
    shared = true
    return true
end
Share()

---------------------------------------------------------------------------
-- RestedXP Guides: each of its themes names the font its guide draws in,
-- and it reads the theme afresh each time it draws the guide. Its own fonts
-- are kept, so turning the switch off puts them back. A custom theme keeps
-- the font its player gave it.
---------------------------------------------------------------------------
local originals = setmetatable({}, { __mode = "k" })

local function Themes()
    local rxp = RXP
    local list = {}
    for _, set in ipairs({ rxp and rxp.themes, rxp and rxp.v2 and rxp.v2.themes }) do
        if type(set) == "table" then
            for _, theme in pairs(set) do
                if type(theme) == "table" and theme.name ~= "Custom" and theme.font then
                    list[#list + 1] = theme
                end
            end
        end
    end
    return list
end

function SharedFonts.SetRestedXP(on)
    local rxp = RXP
    if type(rxp) ~= "table" then return false end
    for _, theme in ipairs(Themes()) do
        if on then
            if originals[theme] == nil then originals[theme] = theme.font end
            theme.font = Style.font
        elseif originals[theme] then
            theme.font = originals[theme]
        end
    end
    -- Redraw the guide if it's already up, so the change shows at once.
    if rxp.font and type(rxp.RenderFrame) == "function" and rxp.RXPFrame then
        pcall(rxp.RenderFrame, true)
    end
    return true
end

function SharedFonts:OnEnable()
    Share()
    if ns.OptionOn("sharedFonts", "restedxp") then SharedFonts.SetRestedXP(true) end
end

function SharedFonts:OnOption(key, on)
    if key == "restedxp" then SharedFonts.SetRestedXP(on) end
end

function SharedFonts:OnDisable()
    SharedFonts.SetRestedXP(false)
end
