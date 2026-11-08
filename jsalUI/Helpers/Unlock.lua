-- jsal.ui's movable pieces in EllesmereUI's Unlock Mode, when EllesmereUI is
-- on: they get its grid, its snapping to the centre and to other pieces, and
-- its exact position fields, beside EllesmereUI's own. Each piece still drags
-- on its own without it. Registered through EllesmereUI's public call for
-- other addons' elements, a moment after login as its own parts do.
local _, ns = ...
local Compat = ns.Compat

local Unlock = {}
ns.Unlock = Unlock

local pieces = {}

-- A piece: key, label, frame() (the frame, or nil if it isn't built),
-- load() and save(point, relative, x, y) for its saved spot, and hidden()
-- for when it isn't in use.
function Unlock.Add(piece)
    pieces[piece.key] = piece
    if Unlock.registered then Unlock.Register() end
end

local function Element(piece)
    local function Apply()
        local frame = piece.frame()
        local at = piece.load()
        if frame and at and at[1] then
            frame:ClearAllPoints()
            frame:SetPoint(at[1], UIParent, at[2] or at[1], at[3] or 0, at[4] or 0)
        end
    end
    local element = {
        key = "jsalUI_" .. piece.key,
        label = piece.label,
        group = "jsal.ui",
        order = 900,
        noResize = true,
        isHidden = function() return piece.hidden and piece.hidden() or not piece.frame() end,
        getFrame = function() return piece.frame() end,
        getSize = function()
            local frame = piece.frame()
            if frame then return frame:GetWidth(), frame:GetHeight() end
            return 32, 32
        end,
        savePos = function(_, point, relative, x, y)
            if not point then return end
            piece.save(point, relative or point, x or 0, y or 0)
            if not EllesmereUI._unlockActive then Apply() end
        end,
        loadPos = function()
            local at = piece.load()
            if not (at and at[1]) then return nil end
            return { point = at[1], relPoint = at[2] or at[1], x = at[3] or 0, y = at[4] or 0 }
        end,
        clearPos = function() piece.save(nil) end,
        applyPos = Apply,
    }
    local make = EllesmereUI.MakeUnlockElement
    return make and make(element) or element
end

function Unlock.Register()
    if not (EllesmereUI and EllesmereUI.RegisterUnlockElements) then return false end
    local list = {}
    for _, piece in pairs(pieces) do list[#list + 1] = Element(piece) end
    if #list == 0 then return false end
    local ok = pcall(EllesmereUI.RegisterUnlockElements, EllesmereUI, list)
    Unlock.registered = ok
    return ok
end

ns.OnLogin(function()
    Compat.After(2, function() xpcall(Unlock.Register, ns.Report) end)
end)
