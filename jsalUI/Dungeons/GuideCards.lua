-- The Dungeon guide's boss cards: each boss's loot worked out, and drawn on its card; and the Trash card.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

-- A boss's card: its heading, a line a piece, and the strip along its foot
-- for what isn't for you, with its small pictures.
local BOSS_H, ITEM_H, STRIP_H, SMALL = 36, 46, 40, 24
-- The Trash card's heading: its name with a quiet line under it.
local TRASH_H = 52
local METER_W = 52                 -- the bar under a piece's drop chance
-- A card's lines for what you can equip, at most: a piece you starred has its
-- line past them.
local LINES = 4
-- The tag after an item's name: its words and its tone. A better piece's
-- words are how much better it is; a worse one's (a piece you starred that
-- what you wear has passed), how much worse.
local TAGS = {
    better = { nil, "green" },
    worse = { nil, "red" },
    prof = { "your profession" },
}

ns.DungeonGuide = ns.DungeonGuide or {}

-- Made once, as the guide is built: puts the cards' own parts on `guide.B` (B.Row, B.TrashHead, B.Model,
-- B.Wide, B.Draw), their frames on `guide.bossList`.
function ns.DungeonGuide.Cards(guide, Kit)
    local ItemInfo, CantEquip, ForOthers, RED, RECIPE = Kit.ItemInfo, Kit.CantEquip, Kit.ForOthers, Kit.RED, Kit.RECIPE
    local D, B, right, bossList, bossRows, cardW, Spent = ns.Dungeons, guide.B, guide.right, guide.bossList,
        guide.bossRows, guide.cardW, guide.Spent

    local function BossRow(i)
        if bossRows[i] then return bossRows[i] end
        local b = CreateFrame("Frame", nil, bossList)
        b:SetSize(cardW, BOSS_H)
        Style.Box(b, 6, "well", "cardLine")
        -- Gold down its left, round with the card, when something here is
        -- for you.
        b.edge = Style.Edge(b, 6)
        b.head = CreateFrame("Frame", nil, b)
        b.head:SetPoint("TOPLEFT")
        b.head:SetPoint("TOPRIGHT")
        b.head:SetHeight(BOSS_H)
        Style.Rule(b.head, "BOTTOM", "line")
        b.number = Style.Text(b.head, 13, "gold", nil, true)
        b.number:SetPoint("LEFT", 14, 0)
        b.box = CreateFrame("Frame", nil, b.head)
        b.box:SetSize(16, 16)
        b.box:SetPoint("LEFT", 36, 0)
        -- A green square: its line would be the fill's own colour, inside the fill, so it's the fill alone.
        b.boxFill = Style.Fill(b.box, "wordGreen")
        -- The game's own check mark, in white.
        b.tick = b.box:CreateTexture(nil, "OVERLAY")
        b.tick:SetSize(16, 16)
        b.tick:SetPoint("CENTER", 1, 0)
        b.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        b.tick:SetDesaturated(true)
        b.tick:SetVertexColor(1, 1, 1)
        b.name = Style.Text(b.head, 14, "text", nil, true)
        b.name:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
        b.name:SetWidth(cardW - 190)
        b.name:SetJustifyH("LEFT")
        b.name:SetWordWrap(false)
        b.kills = Style.Text(b.head, 12, "muted")
        b.kills:SetPoint("RIGHT", -14, 0)
        b.none = Style.Text(b, 13, "muted")
        b.none:SetPoint("TOPLEFT", 14, -(BOSS_H + 14))
        b.none:SetWidth(cardW - 28)
        b.none:SetJustifyH("LEFT")
        -- Along the foot, round with the card: the rest it drops.
        b.strip = CreateFrame("Frame", nil, b)
        b.strip:SetPoint("BOTTOMLEFT", 1, 1)
        b.strip:SetPoint("BOTTOMRIGHT", -1, 1)
        Style.Cap(b.strip, 5, "titleBar", "BOTTOM")
        Style.Rule(b.strip, "TOP", "line")
        b.strip.label = Style.Text(b.strip, 10, "muted", nil, true)
        b.strip.label:SetPoint("TOPLEFT", 13, -13)
        b.items, b.smalls = {}, {}
        bossRows[i] = b
        return b
    end
    B.Row = BossRow

    -- The Trash card's heading: no number and no tick, its name and a quiet line under it.
    function B.TrashHead(card)
        card.boss = nil
        card.number:SetText("")
        card.box:Hide()
        card.kills:SetText("")
        card.head:SetHeight(TRASH_H)
        card.name:ClearAllPoints()
        card.name:SetPoint("TOPLEFT", card.head, "TOPLEFT", 14, -11)
        card.name:SetText("Trash")
        if not card.note then
            card.note = Style.Text(card.head, 12, "muted")
            card.note:SetPoint("TOPLEFT", 14, -31)
            card.note:SetText("From the dungeon's ordinary creatures")
        end
        card.note:Show()
    end

    -- The game's own tooltip for a piece, with what the card knows of it
    -- under: how often it's been seen to drop, and why it isn't for you.
    local function DropTip(self)
        if not self.item then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.item)
        for _, line in ipairs(self.more or {}) do GameTooltip:AddLine(line, 0.6, 0.59, 0.53, true) end
        GameTooltip:Show()
    end

    -- A colour's three numbers from its six letters.
    local function Hex3(hex)
        return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
    end

    -- A piece for you, a line across its boss's card: its picture in
    -- a line of its quality's colour, its name with a tag after it, what it
    -- is under the name, and at the right how often it drops over a bar
    -- that long.
    local function Item(card, i)
        if card.items[i] then return card.items[i] end
        local it = CreateFrame("Frame", nil, card)
        it:SetSize(cardW, ITEM_H)
        it.rule = Style.Rule(it, "TOP", "line")
        it.line = it:CreateTexture(nil, "BORDER")
        it.line:SetSize(32, 32)
        it.line:SetPoint("LEFT", 14, 0)
        it.icon = it:CreateTexture(nil, "ARTWORK")
        it.icon:SetPoint("TOPLEFT", it.line, "TOPLEFT", 1, -1)
        it.icon:SetPoint("BOTTOMRIGHT", it.line, "BOTTOMRIGHT", -1, 1)
        it.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        it.chance = Style.Text(it, 13, "text", nil, true)
        it.chance:SetPoint("TOPRIGHT", -14, -9)
        it.chance:SetJustifyH("RIGHT")
        it.track = it:CreateTexture(nil, "BORDER")
        it.track:SetColorTexture(Style.Color("window"))
        it.track:SetSize(METER_W, 4)
        it.track:SetPoint("BOTTOMRIGHT", -14, 11)
        it.fill = it:CreateTexture(nil, "ARTWORK")
        it.fill:SetColorTexture(Style.Color("gold"))
        it.fill:SetHeight(4)
        it.fill:SetPoint("LEFT", it.track, "LEFT", 0, 0)
        it.name = Style.Text(it, 14, "text")
        it.name:SetPoint("TOPLEFT", it.line, "TOPRIGHT", 12, 0)
        it.name:SetJustifyH("LEFT")
        it.name:SetWordWrap(false)
        -- How much better it is than what you wear, or worse.
        it.tag = Style.Tag(it, "", nil, true)
        it.tag:SetPoint("LEFT", it.name, "RIGHT", 8, 0)
        -- A piece you starred in your Gear plan has the plan's own star
        -- after its name (the game's yellow one), and its tag after that.
        it.star = it:CreateTexture(nil, "ARTWORK")
        it.star:SetSize(14, 14)
        it.star:SetPoint("LEFT", it.name, "RIGHT", 6, 0)
        it.star:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
        it.slot = Style.Text(it, 12, "muted")
        it.slot:SetPoint("BOTTOMLEFT", it.line, "BOTTOMRIGHT", 12, 0)
        it.slot:SetWidth(cardW - 58 - 14 - METER_W - 12)
        it.slot:SetJustifyH("LEFT")
        it.slot:SetWordWrap(false)
        it:EnableMouse(true)
        it:SetScript("OnEnter", function(self)
            DropTip(self)
            B.hover = self
            B.Glow()
        end)
        it:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            -- The piece asked for stays lit until the pointer has been on it and left.
            if B.lit == self then B.mark, B.lit, self.lit = nil, nil, nil end
            if B.hover == self then B.hover = nil end
            B.Glow()
        end)
        card.items[i] = it
        return it
    end

    -- A piece on the strip along its boss's card's foot: its picture, small
    -- and grey. Pointing at it says what it is, how often it drops, and why
    -- it isn't for you where that's so.
    local function Small(card, i)
        if card.smalls[i] then return card.smalls[i] end
        local s = CreateFrame("Frame", nil, card.strip)
        s:SetSize(SMALL, SMALL)
        s.line = Style.Fill(s, "lineStrong")
        s.icon = s:CreateTexture(nil, "ARTWORK")
        s.icon:SetPoint("TOPLEFT", 1, -1)
        s.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        s.icon:SetDesaturated(true)
        s:SetAlpha(0.55)
        s.away = true
        s:EnableMouse(true)
        s:SetScript("OnEnter", DropTip)
        s:SetScript("OnLeave", function() GameTooltip:Hide() end)
        card.smalls[i] = s
        return s
    end

    -- Puts an item's tag on, or takes it off; returns the room it takes.
    -- `words` are for a tag whose kind has none of its own.
    local function SetTag(it, kind, words)
        it.tagged = kind
        it.tag:SetShown(kind ~= nil)
        if not kind then return 0 end
        local t = TAGS[kind]
        it.tag:Tone(t[2])
        it.tag:Say(t[1] or words)
        return it.tag.wide + 8
    end

    -- How often a piece has been seen to drop, in words: in the guild's
    -- kills (the card's heading says how many those are), or by you.
    local function Seen(entry)
        if entry.guild then return ("dropped %d×"):format(entry.guild) end
        local seen = entry.item.seen or 0
        if seen > 0 then return seen > 1 and ("you've seen it %d×"):format(seen) or "you've seen it" end
        return nil
    end

    -- A boss's loot on its card: Wowhead's list with each item's drop
    -- chance, then anything you or the guild have seen it drop that the list
    -- doesn't have. Without Wowhead's chance, five or more guild kills give
    -- one. A line each for what's on your gear plan, then, LINES in all at
    -- most, for what's better than what you wear, the most first, then for
    -- what else you can equip, likeliest first: a starred piece always has
    -- its line. Everything else is a small picture on the strip along the
    -- card's foot: what you could use first, then what you can't equip,
    -- what's for other classes only and recipes for professions you don't
    -- have, each likeliest first. A piece the game hasn't sent yet waits on
    -- the strip: whether you can equip it isn't known.
    -- `keep` is a piece asked for from elsewhere: it has a line while it's
    -- asked for, and is put on the card if the list doesn't have it. Returns
    -- the card's height, how many pieces are for you (on your gear plan, or
    -- better than what you wear), how many it could tell that of, and the
    -- guild's kills.
    -- The Trash card's loot is `trash` (D.Trash's list): no boss, no drop chance, the creature named where it is.
    -- Worked out without a card, so a card's height is known before one is made: { lines, strip (each piece with
    -- its place on the strip, `x` and `y`), h (the card's height), forYou, sure, guildKills, none (no loot known) }.
    function B.Model(boss, encounter, keep, trash)
        local m = { lines = {}, strip = {}, forYou = 0, sure = 0, guildKills = 0, top = trash and TRASH_H or BOSS_H }
        local list, byId = {}, {}
        local function Add(id)
            if not byId[id] then
                byId[id] = { id = id, item = {} }
                list[#list + 1] = byId[id]
            end
            return byId[id]
        end
        for _, drop in ipairs(ns.DungeonLoot and ns.DungeonLoot[encounter] or {}) do
            Add(drop[1]).chance = drop[2]
        end
        for _, e in ipairs(trash or {}) do
            local entry = Add(e[1])
            entry.creature, entry.item.q = e[2], e[3]
        end
        for id, item in pairs(boss and D.Loot()[encounter or D.Key(boss)] or {}) do Add(id).item = item end
        local guild = encounter and ns.GuildLoot and ns.GuildLoot.On() and ns.GuildLoot.For(encounter)
        local guildKills = 0
        if guild then
            for id, n in pairs(guild.i or {}) do
                -- Until 0.3.52 guild loot couldn't read an item's quality from the game's newer
                -- links, and shared grey and white items with the rest. One only the guild has
                -- seen, that the game says is below uncommon, isn't shown; its count stays in the
                -- guild's list, which every copy still agrees on.
                local quality = not byId[id] and C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
                if type(quality) ~= "number" or quality >= 2 then
                    Add(id).guild = n
                    guildKills = math.max(guildKills, n)
                end
            end
            guildKills = math.max(guildKills, guild.k or 0)
            for _, entry in ipairs(list) do
                if entry.guild and not entry.chance and guildKills >= 5 then
                    entry.guessed = math.floor(entry.guild / guildKills * 100 + 0.5)
                end
            end
        end
        if keep then Add(keep) end
        table.sort(list, function(a, b)
            local ca, cb = a.chance or a.guessed or 0, b.chance or b.guessed or 0
            if ca ~= cb then return ca > cb end
            if (a.item.q or 0) ~= (b.item.q or 0) then return (a.item.q or 0) > (b.item.q or 0) end
            return a.id < b.id
        end)
        m.guildKills = guildKills
        if #list == 0 then
            m.none, m.h = true, BOSS_H + 62
            return m
        end
        local starredSet = ns.Gear and ns.Gear.Starred() or {}
        local trades = {}
        -- A recipe's kind is named in the client's language: your professions by the game's name too.
        for _, p in ipairs(ns.Professions and ns.Professions.Mine and ns.Professions.Mine() or {}) do
            trades[p.name or ""] = true
            if type(p.game) == "string" then trades[p.game] = true end
        end
        local mine, others, forYou, sure = {}, {}, 0, 0
        for k, entry in ipairs(list) do
            local _, _, _, _, _, _, subclass, _, equipLoc, _, classID, subclassID = ItemInfo(entry.id)
            entry.at, entry.known = k, classID ~= nil
            entry.starred = starredSet[entry.id] == true
            -- A piece on your gear plan is never put with what isn't for you.
            entry.cant = not entry.starred and CantEquip(classID, subclassID, equipLoc)
            entry.recipe = classID == RECIPE
            entry.prof = entry.recipe and trades[subclass or ""] == true
            -- For other classes only, by its own "Classes:" line.
            entry.classes = not entry.starred and not entry.recipe and ForOthers(entry.id) == true
            entry.better, entry.gain, entry.loss = nil, nil, nil
            if not entry.cant and not entry.classes and not entry.recipe and ns.Gear and ns.Gear.Better then
                local asked = debugprofilestop()
                local is, gain = ns.Gear.Better(entry.id, equipLoc, classID, subclassID)
                Spent("bosses: of which, the Gear plan's upgrade checks", asked)
                if is ~= nil then sure = sure + 1 end
                if is then
                    entry.better, entry.gain = true, gain
                elseif is == false and entry.starred and gain and gain < 0 then
                    -- Starred when it was an upgrade; what you wear has passed it.
                    entry.loss = gain
                end
            end
            entry.away = entry.cant or entry.classes or (entry.recipe and not entry.prof and not entry.starred)
            if entry.starred or entry.better then forYou = forYou + 1 end
            local to = entry.away and others or mine
            to[#to + 1] = entry
        end
        -- The lines: what you starred, as the list has them, then what's better, the most first, then what else
        -- you can equip, as the list has them (likeliest first), as many as there's room for. The rest goes on the
        -- strip, what you could use before what you can't.
        local lines, strip = m.lines, m.strip
        for _, entry in ipairs(mine) do if entry.starred then lines[#lines + 1] = entry end end
        local better = {}
        for _, entry in ipairs(mine) do if entry.better and not entry.starred then better[#better + 1] = entry end end
        table.sort(better, function(a, b)
            if (a.gain or 0) ~= (b.gain or 0) then return (a.gain or 0) > (b.gain or 0) end
            return a.at < b.at
        end)
        for _, entry in ipairs(better) do
            if #lines < LINES then lines[#lines + 1] = entry end
        end
        for _, entry in ipairs(lines) do entry.line = true end
        for _, entry in ipairs(mine) do
            if not entry.line and entry.known and #lines < LINES then
                lines[#lines + 1] = entry
                entry.line = true
            end
        end
        for _, entry in ipairs(mine) do if not entry.line then strip[#strip + 1] = entry end end
        for _, entry in ipairs(others) do strip[#strip + 1] = entry end
        -- The piece asked for is seen, on a line of its own.
        for k, entry in ipairs(strip) do
            if entry.id == keep then
                table.remove(strip, k)
                lines[#lines + 1] = entry
                break
            end
        end
        m.forYou, m.sure = forYou, sure
        m.h = m.top + #lines * ITEM_H
        -- The rest, small along the foot after its label: a second row of them when one won't hold them all.
        if #strip > 0 then
            m.label = ("ALSO DROPS %d"):format(#strip)
            local x0 = 13 + B.Wide(m.label) + 12
            local x, y = x0, 0
            for _, entry in ipairs(strip) do
                if x + SMALL > cardW - 14 then x, y = x0, y + SMALL + 4 end
                entry.x, entry.y = x, y
                x = x + SMALL + 4
            end
            m.stripH = STRIP_H + y
            m.h = m.h + m.stripH
        end
        return m
    end
    -- How wide the strip's label is drawn, by one line of text kept for it, measured once a label.
    B.widths = {}
    function B.Wide(text)
        if B.widths[text] then return B.widths[text] end
        if not B.measure then
            B.measure = Style.Text(right, 10, "muted", nil, true)
            B.measure:Hide()
        end
        B.measure:SetText(text)
        local w = B.measure.GetStringWidth and B.measure:GetStringWidth()
        if type(w) == "number" and w > 0 then
            B.widths[text] = w
            return w
        end
        return 70
    end

    -- A card's loot as B.Model worked it out, on its frame.
    local function PaintLoot(card, m)
        for _, it in ipairs(card.items) do it:Hide() end
        for _, s in ipairs(card.smalls) do s:Hide() end
        card.strip:Hide()
        card.edge:Hide()
        if m.none then
            card.none:SetText("No loot known yet. It's added when you or a guildmate with jsal.ui loots this boss.")
            card.none:Show()
            return
        end
        card.none:Hide()
        card.edge:SetShown(m.forYou > 0)
        local top = m.top
        for k, entry in ipairs(m.lines) do
            local it = Item(card, k)
            it:ClearAllPoints()
            it:SetPoint("TOPLEFT", 0, -(top + (k - 1) * ITEM_H))
            it.rule:SetShown(k > 1)
            it.item = entry.id
            local name, _, quality, _, req, _, subclass, _, equipLoc, texture, classID, subclassID = ItemInfo(entry.id)
            local q = quality or entry.item.q or 1
            -- After its name: the star when it's on your gear plan, then how
            -- much better it is than what you wear, or, for a starred piece
            -- that no longer is, how much worse.
            local kind, words = (entry.better and "better") or (entry.loss and "worse") or (entry.prof and "prof") or nil, "better"
            if entry.better and entry.gain then
                local pct = math.floor(entry.gain * 100 + 0.5)
                words = pct < 1 and "under 1%" or ("+" .. pct .. "%")
            elseif entry.loss then
                local pct = math.floor(-entry.loss * 100 + 0.5)
                words = pct < 1 and "a little worse" or ("-" .. pct .. "%")
            end
            local tagW = SetTag(it, kind, words)
            it.starred = entry.starred
            it.star:SetShown(entry.starred)
            it.tag:ClearAllPoints()
            it.tag:SetPoint("LEFT", entry.starred and it.star or it.name, "RIGHT", 8, 0)
            if entry.starred then tagW = tagW + 20 end
            it.name:SetWidth(0)
            it.name:SetText(("|cff%s%s|r"):format(Style.Quality(q), name or entry.item.n or "..."))
            it.line:SetColorTexture(Hex3(Style.Quality(q)))
            local room = cardW - 58 - 14 - METER_W - 12 - tagW
            local wide = it.name.GetStringWidth and it.name:GetStringWidth()
            if type(wide) ~= "number" or wide <= 0 or wide > room then it.name:SetWidth(room) end
            local slot = equipLoc and equipLoc ~= "" and _G[equipLoc] or nil
            local parts = {}
            -- Recipes and other things you don't wear have a blank slot name.
            if slot and slot ~= "" then parts[#parts + 1] = slot end
            -- Armour's Miscellaneous (a ring, a neck, a trinket) says nothing the slot doesn't: by its IDs, which every
            -- client language shares, and by the English word.
            local misc = (classID == 4 and subclassID == 0) or subclass == "Miscellaneous"
            if subclass and subclass ~= "" and subclass ~= slot and not misc then parts[#parts + 1] = subclass end
            -- On the Trash card, the creature it drops from.
            if entry.creature then parts[#parts + 1] = entry.creature end
            -- Too high for you yet: its level, in red.
            if req and req > (UnitLevel("player") or 1) then parts[#parts + 1] = ("%slevel %d|r"):format(RED, req) end
            it.slot:SetText(table.concat(parts, " · "))
            local chance = entry.chance or entry.guessed
            it.chance:SetText(chance and ("%d%%"):format(chance) or "")
            it.track:SetShown(chance ~= nil)
            it.fill:SetShown(chance ~= nil)
            if chance then it.fill:SetWidth(math.max(1, METER_W * math.min(100, chance) / 100)) end
            -- How often it's been seen is said when it's pointed at.
            it.seen = Seen(entry)
            -- And what its star and a red tag mean.
            local more = {}
            if it.seen then more[#more + 1] = (it.seen:gsub("^%l", string.upper)) .. "." end
            if entry.starred then more[#more + 1] = "Starred in your Gear plan." end
            if entry.loss then more[#more + 1] = "By your Gear plan's weights it's no longer better than what you wear." end
            it.more = #more > 0 and more or nil
            it.icon:SetTexture(texture or Compat.ItemIcon(entry.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            it:Show()
        end
        if #m.strip > 0 then
            local bar = card.strip
            bar.label:SetText(m.label)
            for k, entry in ipairs(m.strip) do
                local s = Small(card, k)
                s:ClearAllPoints()
                s:SetPoint("TOPLEFT", entry.x, -(8 + entry.y))
                s.item = entry.id
                local _, _, _, _, _, _, _, _, _, texture = ItemInfo(entry.id)
                s.icon:SetTexture(texture or Compat.ItemIcon(entry.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
                local chance, seen = entry.chance or entry.guessed, Seen(entry)
                s.more = {}
                if entry.cant then
                    s.more[1] = "Your class can't equip it."
                elseif entry.classes then
                    s.more[1] = "For other classes only."
                elseif entry.recipe then
                    s.more[1] = entry.prof and "A recipe for your profession." or "A recipe for a profession you don't have."
                end
                if chance then s.more[#s.more + 1] = ("Drops %d%% of the time."):format(chance) end
                if entry.creature then s.more[#s.more + 1] = ("Drops from %s."):format(entry.creature) end
                if seen then s.more[#s.more + 1] = (seen:gsub("^%l", string.upper)) .. "." end
                s:Show()
            end
            bar:SetHeight(m.stripH)
            bar:Show()
        end
    end

    -- A card on its frame: its heading, its loot, its place in the list.
    function B.Draw(card, m)
        local b = m.b
        if b then
            card.head:SetHeight(BOSS_H)
            if card.note then card.note:Hide() end
            card.boss = b[2]
            card.number:SetText(m.k)
            card.name:SetText(b[3] or b[2])
            card.box:SetShown(m.n > 0)
            -- Without a tick the name comes right after the number.
            card.name:ClearAllPoints()
            if m.n > 0 then
                card.name:SetPoint("LEFT", card.box, "RIGHT", 8, 0)
            else
                card.name:SetPoint("LEFT", card.head, "LEFT", 36, 0)
            end
            card.kills:SetText(m.kills)
        else
            B.TrashHead(card)
        end
        PaintLoot(card, m)
        card:SetHeight(m.h)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", m.left, -m.at)
        card.at, card.drawn = m.at, m
        card:Show()
    end
end
