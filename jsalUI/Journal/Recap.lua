-- The session recap: a card of what this session added up to (time,
-- levels, kills, quests, gold, its moments), shown while the game counts
-- down a logout and on /jsal recap. When you're logging out away from an
-- inn or city, it says so, since rested XP builds four times faster there.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local Recap = {}
ns.Recap = Recap

local WIDTH, HEIGHT = 420, 272

local function Hours(seconds)
    seconds = math.floor(seconds or 0)
    local h, m = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
    if h > 0 then return ("%dh %02dm"):format(h, m) end
    return ("%dm"):format(m)
end

local function Coins(copper)
    copper = math.floor(copper or 0)
    local sign = copper < 0 and "-" or "+"
    copper = math.abs(copper)
    local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
    if g > 0 then return s > 0 and ("%s%dg %ds"):format(sign, g, s) or ("%s%dg"):format(sign, g) end
    if s > 0 then return c > 0 and ("%s%ds %dc"):format(sign, s, c) or ("%s%ds"):format(sign, s) end
    return ("%s%dc"):format(sign, c)
end

-- What this session added up to, from the Journal: a table the card and
-- the tests read.
function Recap.Summary()
    local J = ns.Journal
    local session = J and J.session
    if not session then return nil end
    local now, was = J.Book().stats, session.stats
    local function Delta(k) return (now[k] or 0) - (was[k] or 0) end
    local level = UnitLevel("player")
    local xp, xpMax = UnitXP("player"), UnitXPMax("player")
    local out = {
        seconds = GetTime() - session.clock,
        fromLevel = session.level, level = level,
        into = xpMax > 0 and math.floor(xp / xpMax * 100) or 0,
        wasInto = (session.xpMax or 0) > 0 and math.floor(session.xp / session.xpMax * 100) or 0,
        kills = Delta("foes"), quests = Delta("quests"), deaths = Delta("deaths"),
        net = Delta("earned") - Delta("spent"),
        resting = IsResting and IsResting() or false,
        moments = {},
    }
    local killers, kills, loot = {}, 0, nil
    for _, e in ipairs(J.Book().events) do
        if (e.t or 0) >= session.started then
            if e.k == "death" then killers[#killers + 1] = (e.s or ""):match("^Died to (.+)$")
            elseif e.k == "kill" or e.k == "boss" then kills = kills + 1
            elseif e.k == "loot" then loot = e.s end
        end
    end
    if out.deaths == 1 then
        out.moments[#out.moments + 1] = killers[1] and ("Died once, to " .. killers[1]) or "Died once"
    elseif out.deaths > 1 then
        out.moments[#out.moments + 1] = ("Died %d times"):format(out.deaths)
    end
    if kills > 0 then out.moments[#out.moments + 1] = kills == 1 and "A first kill" or (kills .. " first kills") end
    if loot then out.moments[#out.moments + 1] = loot end
    return out
end

local card, tiles, levelLine, moments, warning
local function Build()
    card = Style.Panel("jsalUIRecap", WIDTH, HEIGHT, "This session")
    -- Under the game's own boxes, so it never covers the logout box's Exit Now.
    card:SetFrameStrata("MEDIUM")
    levelLine = Style.Text(card, 14, "gold", nil, true)
    levelLine:SetPoint("TOPLEFT", 16, -46)
    levelLine:SetWidth(WIDTH - 32)
    levelLine:SetJustifyH("LEFT")
    tiles = {}
    local tileW = math.floor((WIDTH - 32 - 12) / 3)
    for i = 1, 3 do
        local t = CreateFrame("Frame", nil, card)
        t:SetSize(tileW, 54)
        t:SetPoint("TOPLEFT", 16 + (i - 1) * (tileW + 6), -74)
        Style.Fill(t, "well")
        Style.Border(t, "cardLine")
        t.n = Style.Text(t, 18, "gold", nil, true)
        t.n:SetPoint("TOPLEFT", 10, -8)
        t.label = Style.Text(t, 12, "text")
        t.label:SetPoint("TOPLEFT", t.n, "BOTTOMLEFT", 0, -3)
        tiles[i] = t
    end
    moments = Style.Text(card, 12, "muted")
    moments:SetPoint("TOPLEFT", 16, -140)
    moments:SetWidth(WIDTH - 32)
    moments:SetJustifyH("LEFT")
    warning = CreateFrame("Frame", nil, card)
    warning:SetSize(WIDTH - 32, 40)
    warning:SetPoint("TOPLEFT", 16, -178)
    Style.Fill(warning, "well")
    local edge = warning:CreateTexture(nil, "ARTWORK")
    edge:SetColorTexture(Style.Color("gold"))
    edge:SetPoint("TOPLEFT")
    edge:SetPoint("BOTTOMLEFT")
    edge:SetWidth(2)
    warning.text = Style.Text(warning, 12, "text")
    warning.text:SetPoint("LEFT", 12, 0)
    warning.text:SetWidth(WIDTH - 56)
    warning.text:SetJustifyH("LEFT")
    warning.text:SetText("You're not resting here: log out in an inn or city to earn rested XP four times faster.")
    local close = Style.Button(card, "Close", "plain", 90)
    close:SetPoint("BOTTOMRIGHT", -16, 14)
    close:SetScript("OnClick", function() card:Hide() end)
end

-- Just below the game's logout box while it shows, else near the top.
local function Place()
    if not card then return end
    local popup
    for _, which in ipairs({ "CAMP", "QUIT" }) do
        if StaticPopup_Visible then
            local name, frame = StaticPopup_Visible(which)
            popup = popup or frame or (name and _G[name])
        end
    end
    card:ClearAllPoints()
    if popup then
        card:SetPoint("TOP", popup, "BOTTOM", 0, -12)
    else
        card:SetPoint("TOP", 0, -140)
    end
end
Recap.Place = Place

function Recap.Show()
    local s = Recap.Summary()
    if not s then return ns.Print("The recap needs the Journal switched on in Settings.") end
    if not card then Build() end
    card.title:SetText("This session · " .. Hours(s.seconds))
    if s.level > s.fromLevel then
        levelLine:SetText(("Level %d → %d, and %d%% into %d"):format(s.fromLevel, s.level, s.into, s.level))
    elseif s.level >= 60 then
        levelLine:SetText("Level 60")
    else
        levelLine:SetText(("Level %d: %d%% → %d%%"):format(s.level, s.wasInto, s.into))
    end
    local data = { { tostring(s.kills), s.kills == 1 and "kill" or "kills" },
                   { tostring(s.quests), s.quests == 1 and "quest" or "quests" },
                   { s.net ~= 0 and Coins(s.net) or "0", "gold" } }
    for i, t in ipairs(tiles) do
        t.n:SetText(data[i][1])
        t.label:SetText(data[i][2])
    end
    tiles[3].n:SetTextColor(Style.Color(s.net < 0 and "text" or "gold"))
    moments:SetText(#s.moments > 0 and table.concat(s.moments, " · ") or "A quiet session.")
    local warn = not s.resting and s.level < 60
    warning:SetShown(warn)
    card:SetHeight(warn and HEIGHT or HEIGHT - 50)
    Place()
    card:Show()
    -- The logout box can appear a moment after the countdown starts.
    Compat.After(0.1, Place)
    return s
end

ns.Command("recap", function() Recap.Show() end)

-- The game's logout countdown starts: the card shows while it runs, and
-- goes if the logout is cancelled.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_CAMPING")
events:RegisterEvent("PLAYER_QUITING")
events:RegisterEvent("LOGOUT_CANCEL")
events:SetScript("OnEvent", function(_, event)
    if event == "LOGOUT_CANCEL" then
        if card then card:Hide() end
        return
    end
    local J = ns.Journal
    if not (J and J.running and ns.OptionOn("journal", "recap")) then return end
    xpcall(Recap.Show, ns.Report)
end)
