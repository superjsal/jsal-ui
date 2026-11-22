-- The Endgame page's two small parts below level 60: BUILD FOR 60 (the build that goes with your set, and the
-- levelling build you follow until then with how many of its 51 points are spent), and RAID NIGHT folded to
-- one line ("9 consumables for a Weave hunter's raid, about 21g 37s a night · Show ›"), which opens the card
-- as it is at 60 and folds it again, remembered per character.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local PAD = 16

-- Quiet gold words that light up under the pointer.
local function Link(parent, words, onClick)
    local b = CreateFrame("Button", nil, parent)
    b.text = Style.Text(b, 13, "gold", nil, true)
    b.text:SetPoint("RIGHT")
    function b:Say(w)
        self.text:SetText(w)
        self:SetSize(Style.Wide(self.text, #w * 7), 20)
    end
    b:Say(words)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(Style.Color("text")) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color("gold")) end)
    b:SetScript("OnClick", onClick)
    return b
end

-- BUILD FOR 60, `width` wide. Paint(level) returns its height.
function ns.EndgameBuild(parent, width)
    local card = CreateFrame("Frame", nil, parent)
    card:SetWidth(width)
    Style.Box(card, 6, "well", "cardLine")
    local title = Style.Text(card, 12, "gold", nil, true)
    title:SetPoint("TOPLEFT", PAD, -14)
    title:SetText("BUILD FOR 60")
    local open = Link(card, "Open Build", function()
        if card.build and ns.TalentTree then ns.TalentTree.Select(card.build.class, card.build) end
        Window.Open("build")
    end)
    open:SetPoint("TOPRIGHT", -PAD, -10)
    local rule = card:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(Style.Color("line"))
    rule:SetPoint("TOPLEFT", PAD, -38)
    rule:SetPoint("TOPRIGHT", -PAD, -38)
    rule:SetHeight(1)
    local name = Style.Text(card, 14, "text", nil, true)
    name:SetPoint("TOPLEFT", PAD, -50)
    name:SetWidth(width - 2 * PAD)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    local line = Style.Text(card, 12, "muted")
    line:SetPoint("TOPLEFT", PAD, -72)
    line:SetWidth(width - 2 * PAD)
    line:SetJustifyH("LEFT")

    function card.Paint(level)
        local Goal = ns.GearGoal
        local key = Goal and Goal.SetKey and Goal.SetKey()
        local build = key and ns.EndgameBuildFor and ns.EndgameBuildFor(key)
        card.build = build
        local own = false
        if Goal and Goal.Summary and Goal.running then
            local ok, s = pcall(Goal.Summary)
            own = ok and s and s.own or false
        end
        name:SetText(build and build.name or (own and "None goes with a set of your own" or "None goes with this set"))
        local followed = ns.TalentTree and ns.TalentTree.Active and ns.TalentTree.Active()
        local unspent = Compat.UnspentTalentPoints and Compat.UnspentTalentPoints() or 0
        local spent = math.max(0, math.min(51, (level or 1) - 9 - (tonumber(unspent) or 0)))
        local who = followed and followed ~= build and followed.name
        line:SetText(who and ("Until then you follow %s: %d of 51 points spent."):format(who, spent)
            or ("%d of 51 points spent."):format(spent))
        local plain = line:GetText() or ""
        local h = 72 + math.max(1, math.ceil(#plain * 6.2 / (width - 2 * PAD))) * 16 + 16
        card:SetHeight(h)
        return h
    end
    return card
end

-- What a night of the chosen list costs at the shopping list's prices, with how many are priced: the same
-- lines and prices the RAID NIGHT card shows.
function ns.EndgameNightOneNight()
    local RN = ns.RaidNight
    local lines = RN.Lines()
    local total, priced = 0, 0
    for _, l in ipairs(lines) do
        local price = ns.ItemPrices and ns.ItemPrices.Of(l.item)
        if price then
            total = total + price * l.per
            priced = priced + 1
        end
    end
    return #lines, total, priced
end

-- RAID NIGHT folded to a line, `width` wide; Show opens the card and Hide folds it. Paint() returns its height.
function ns.EndgameNightLine(parent, width, changed)
    local RN = ns.RaidNight
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(width, 52)
    Style.Box(bar, 6, "well", "cardLine")
    local title = Style.Text(bar, 12, "gold", nil, true)
    title:SetPoint("LEFT", PAD, 0)
    title:SetText("RAID NIGHT")
    local words = Style.Text(bar, 13, "secondary")
    words:SetPoint("LEFT", title, "RIGHT", 16, 0)
    words:SetJustifyH("LEFT")
    words:SetWordWrap(false)
    local show = Link(bar, "Show ›", function()
        local s = RN.Saved()
        s.open = (not s.open) or nil
        if changed then changed() end
    end)
    show:SetPoint("RIGHT", -PAD, 0)
    bar.words, bar.show = words, show

    function bar.Paint()
        local spec, list, setName = RN.Spec()
        local open = RN.Saved().open == true
        show:Say(open and "Hide ‹" or "Show ›")
        show:SetShown(list ~= nil)
        local room = width - 2 * PAD - Style.Wide(title, 80) - 16 - Style.Wide(show.text, 50) - 16
        words:SetWidth(room)
        if not list then
            words:SetText(("WoWSims gives no consumables for %s yet."):format(RN.SpecWords(spec)))
            return 52
        end
        local n, total, priced = ns.EndgameNightOneNight()
        local className = UnitClass("player")
        local whose = ("a %s%s's raid"):format(setName and (setName .. " ") or "", (className or "character"):lower())
        local cost = priced > 0 and (", about %s a night"):format(Compat.Money(ns.EndgameNightRounded(total))) or ""
        words:SetText(("%d consumables for %s%s"):format(n, whose, cost))
        return 52
    end
    return bar
end
