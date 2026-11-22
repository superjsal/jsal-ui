-- The Endgame page's right column: RAIDS over COOLDOWNS, every character's, from what
-- Journal\Lockouts.lua keeps. Each is a card with a gold heading, a note at its right and a
-- rule, then blocks of lines: a raid or a cooldown, and who. Each card is as tall as its lines,
-- within the room it's given; a block that doesn't fit becomes "And N more."
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local R = { PAD = 16, HEAD = 38, LINE = 22, BLOCK = 10, NAME = 84, PIP = 8, PIPS = 10, GAP = 16 }

local function ClassColor(classFile)
    local c = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
    return c and ("|cff%02x%02x%02x"):format(math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255)) or "|cffece6d6"
end

-- "Molten Core or Zul'Gurub", "A, B or C".
local function Either(list)
    if #list <= 1 then return list[1] or "" end
    return table.concat(list, ", ", 1, #list - 1) .. " or " .. list[#list]
end

-- The column, `width` wide, in `parent`. Paint(characters, x, top, room) draws both cards from
-- `top` down, in no more than `room` of height between them.
function ns.RaidCards(parent, width)
    local column = {}

    local function Card(heading)
        local k = CreateFrame("Frame", nil, parent)
        k:SetWidth(width)
        Style.Box(k, 6, "well", "cardLine")
        k.title = Style.Text(k, 12, "gold", nil, true)
        k.title:SetPoint("TOPLEFT", R.PAD, -12)
        k.title:SetText(heading:upper())
        k.note = Style.Text(k, 12, "muted", nil, true)
        k.note:SetPoint("TOPRIGHT", -R.PAD, -12)
        k.note:SetJustifyH("RIGHT")
        local rule = k:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(Style.Color("line"))
        rule:SetPoint("TOPLEFT", R.PAD, -R.HEAD)
        rule:SetPoint("TOPRIGHT", -R.PAD, -R.HEAD)
        rule:SetHeight(1)
        k.lines = {}
        return k
    end
    -- A line of a card, made the first time it's needed and kept: a block's title and its note
    -- at the right, or a name at the left with the free names after it, pips, the words at the
    -- right and a tick before them, or a muted note of a few lines.
    local function Line(k, i)
        local l = k.lines[i]
        if l then return l end
        l = { title = Style.Text(k, 14, "text", nil, true), small = Style.Text(k, 12, "muted"), left = Style.Text(k, 13, "text"),
              names = Style.Text(k, 13, "text"), right = Style.Text(k, 13, "text"), note = Style.Text(k, 12, "muted"), pips = {} }
        for _, fs in ipairs({ l.title, l.left, l.names }) do
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(false)
        end
        for _, fs in ipairs({ l.small, l.right }) do
            fs:SetJustifyH("RIGHT")
            fs:SetWordWrap(false)
        end
        l.note:SetJustifyH("LEFT")
        l.note:SetWidth(width - 2 * R.PAD)
        l.tick = k:CreateTexture(nil, "OVERLAY")
        l.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        l.tick:SetSize(16, 16)
        l.tick:SetDesaturated(true)
        l.tick:SetVertexColor(Style.Color("green"))
        l.tick:SetPoint("RIGHT", l.right, "LEFT", 0, 0)
        for p = 1, R.PIPS do
            local t = k:CreateTexture(nil, "ARTWORK")
            t:SetSize(6, 10)
            l.pips[p] = t
        end
        k.lines[i] = l
        return l
    end
    local function HideLine(l)
        for _, r in ipairs({ l.title, l.small, l.left, l.names, l.right, l.note, l.tick }) do r:Hide() end
        for _, t in ipairs(l.pips) do t:Hide() end
    end
    local raidsCard, cdsCard = Card("Raids"), Card("Cooldowns")
    cdsCard.foot = Style.Text(cdsCard, 12, "muted")
    cdsCard.foot:SetPoint("BOTTOMLEFT", R.PAD, 12)
    cdsCard.foot:SetWidth(width - 2 * R.PAD)
    cdsCard.foot:SetJustifyH("LEFT")
    cdsCard.foot:SetText("Each is as its character last saw it, counting down since.")
    column.raids, column.cooldowns = raidsCard, cdsCard

    -- A muted note of a few lines, as tall as its words.
    local function NoteHeight(text)
        local per = math.floor((width - 2 * R.PAD) / 6.2)
        return math.max(1, math.ceil(#text / per)) * 16
    end
    -- Names in their class's colour, as many as fit `room`, then "and N more".
    local function Names(fs, list, room)
        local shown = #list
        while true do
            local words = {}
            for i = 1, shown do words[i] = ClassColor(list[i].classFile) .. (list[i].name or "?") .. "|r" end
            local text = table.concat(words, "|cff9a9688, |r")
            if shown < #list then text = text .. ("|cff9a9688 and %d more|r"):format(#list - shown) end
            fs:SetText(text)
            local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if shown <= 1 or Style.Wide(fs, #plain * 6.5) <= room then return end
            shown = shown - 1
        end
    end

    -- The height a card's blocks and notes want, all of them, with `reserve` at its foot.
    local function Wanted(blocks, notes, reserve)
        local wanted = R.HEAD + 4
        for _, b in ipairs(blocks) do wanted = wanted + R.BLOCK + #b * R.LINE end
        for _, text in ipairs(notes) do wanted = wanted + R.BLOCK + NoteHeight(text) end
        return wanted + 12 + reserve
    end

    -- One "who" line: a name, the pips of a raid's bosses or a tick, and the words at the right.
    local function Who(k, l, row, nameW, mid)
        l.left:SetText(ClassColor(row.who.classFile) .. (row.who.name or "?") .. "|r")
        l.left:SetTextColor(Style.Color("text"))
        l.left:SetWidth(nameW - 8)
        l.right:SetText(row.right or "")
        l.right:SetTextColor(Style.Color(row.ready and "green" or "text"))
        l.tick:SetShown(row.ready == true)
        if row.of then
            local of = math.min(R.PIPS, row.of)
            for p, t in ipairs(l.pips) do
                t:ClearAllPoints()
                t:SetPoint("LEFT", k, "TOPLEFT", R.PAD + nameW + (p - 1) * R.PIP, mid)
                t:SetColorTexture(Style.Color(p <= row.done and "gold" or "lineStrong"))
                t:SetShown(p <= of)
            end
        end
        l.left:Show()
        l.right:Show()
    end

    -- Lays out a card's blocks from the top in `height`; a block that doesn't fit and the ones
    -- after it become "And N more."
    local function Fill(k, blocks, notes, height, reserve)
        local y, n, stopped = R.HEAD + 4, 0, nil
        local room = height - 12 - reserve
        -- The widest name on a "who" line sets where the pips start.
        local nameW = R.NAME
        for _, b in ipairs(blocks) do
            for _, row in ipairs(b) do
                if row.who then
                    local w = #(row.who.name or "") * 7.5 + 12
                    if w > nameW then nameW = math.min(130, w) end
                end
            end
        end
        -- What's left from each block on: when all of it fits, it all goes in; when not, a
        -- block goes in only with room after it for "And N more".
        local rest, after = {}, 0
        for _, text in ipairs(notes) do after = after + R.BLOCK + NoteHeight(text) end
        for bi = #blocks, 1, -1 do
            after = after + R.BLOCK + #blocks[bi] * R.LINE
            rest[bi] = after
        end
        for bi, b in ipairs(blocks) do
            local fitsAll = y + rest[bi] <= room
            if not fitsAll and bi > 1 and y + R.BLOCK + #b * R.LINE + R.BLOCK + 18 > room then
                stopped = #blocks - bi + 1
                break
            end
            y = y + R.BLOCK
            for _, row in ipairs(b) do
                n = n + 1
                local l = Line(k, n)
                HideLine(l)
                local mid = -(y + R.LINE / 2)
                l.left:ClearAllPoints()
                l.left:SetPoint("LEFT", k, "TOPLEFT", R.PAD, mid)
                l.right:ClearAllPoints()
                l.right:SetPoint("RIGHT", k, "TOPRIGHT", -R.PAD, mid)
                if row.title then
                    l.title:ClearAllPoints()
                    l.title:SetPoint("LEFT", k, "TOPLEFT", R.PAD, mid)
                    l.title:SetWidth(width - 2 * R.PAD - (row.note and 136 or 0))
                    l.title:SetText(row.title)
                    l.title:Show()
                    l.small:ClearAllPoints()
                    l.small:SetPoint("RIGHT", k, "TOPRIGHT", -R.PAD, mid)
                    l.small:SetText(row.note or "")
                    l.small:SetShown(row.note ~= nil)
                elseif row.free then
                    l.left:SetText("free")
                    l.left:SetTextColor(Style.Color("muted"))
                    l.left:SetWidth(nameW - 8)
                    l.names:ClearAllPoints()
                    l.names:SetPoint("LEFT", k, "TOPLEFT", R.PAD + nameW, mid)
                    l.names:SetWidth(width - 2 * R.PAD - nameW)
                    Names(l.names, row.free, width - 2 * R.PAD - nameW)
                    l.names:Show()
                    l.left:Show()
                else
                    Who(k, l, row, nameW, mid)
                end
                y = y + R.LINE
            end
        end
        local lines = {}
        if stopped then lines[#lines + 1] = ("And %d more."):format(stopped) end
        for _, text in ipairs(notes) do lines[#lines + 1] = text end
        for _, text in ipairs(lines) do
            local h = NoteHeight(text)
            if y + R.BLOCK + h > room then break end
            y = y + R.BLOCK
            n = n + 1
            local l = Line(k, n)
            HideLine(l)
            l.note:ClearAllPoints()
            l.note:SetPoint("TOPLEFT", k, "TOPLEFT", R.PAD, -(y + 2))
            l.note:SetText(text)
            l.note:Show()
            y = y + h
        end
        for i = n + 1, #k.lines do HideLine(k.lines[i]) end
    end

    -- RAIDS: a block a raid anyone is saved to; then the raids no one is.
    local function RaidBlocks(list, now)
        local L = ns.Lockouts
        local raids, nobody, sixties = L.Raids(list, now)
        local blocks, notes = {}, {}
        for _, r in ipairs(raids) do
            local b = { { title = r.name, note = ("resets %s · %s"):format(date("%a", r.ends), L.Left(r.ends - now)) } }
            for _, s in ipairs(r.saved) do
                b[#b + 1] = { who = s.c, done = s.done, of = s.of, right = ("%d |cff9a9688/ %d|r"):format(s.done, s.of) }
            end
            if #r.free > 0 then b[#b + 1] = { free = r.free } end
            blocks[#blocks + 1] = b
        end
        if #raids == 0 then
            notes[1] = "No one is saved to a raid. Once a character of yours is, the raid shows here with when it resets."
        elseif #nobody > 0 then
            notes[1] = ("No one is saved to %s."):format(Either(nobody))
        end
        return blocks, notes, sixties
    end

    -- COOLDOWNS: a block a cooldown, each character ready or the time left.
    local function CooldownBlocks(list, now)
        local L = ns.Lockouts
        local cds, ready = L.Cooldowns(list, now)
        local blocks, notes = {}, {}
        for _, cd in ipairs(cds) do
            local b = { { title = cd.name } }
            for _, row in ipairs(cd.rows) do
                b[#b + 1] = { who = row.c, ready = row.left == 0,
                              right = row.left == 0 and "ready" or (L.Left(row.left) .. " |cff9a9688left|r") }
            end
            blocks[#blocks + 1] = b
        end
        if #cds == 0 then
            local names = {}
            for _, cd in ipairs(ns.CooldownData or {}) do names[#names + 1] = cd.name end
            notes[1] = "None of your characters has a long cooldown yet: " .. Either(names):gsub(" or ", " and ")
                .. " show here once one does."
        end
        return blocks, notes, ready, #cds
    end

    -- `noRaids`: COOLDOWNS alone, at the top (below level 60, where raids aren't for you yet). Returns where
    -- the column ends.
    function column.Paint(list, x, top, room, noRaids)
        local now = Compat.ServerTime()
        local raidsH = -R.GAP
        raidsCard:SetShown(not noRaids)
        if not noRaids then
            local blocks, notes, sixties = RaidBlocks(list, now)
            raidsCard.note:SetText(sixties > 0 and ("your %d at 60"):format(sixties) or "")
            -- Raids take what they need, up to three fifths of the room.
            raidsH = math.floor(math.min(room * 0.6, Wanted(blocks, notes, 0)))
            raidsCard:SetHeight(raidsH)
            raidsCard:ClearAllPoints()
            raidsCard:SetPoint("TOPLEFT", x, -top)
            Fill(raidsCard, blocks, notes, raidsH, 0)
        end

        local cdBlocks, cdNotes, ready, count = CooldownBlocks(list, now)
        cdsCard.note:SetText(ready > 0 and ("%d ready"):format(ready) or "")
        cdsCard.note:SetTextColor(Style.Color("gold"))
        cdsCard.foot:SetShown(count > 0)
        local reserve = count > 0 and (NoteHeight(cdsCard.foot:GetText() or "") + 18) or 0
        local cdsH = math.floor(math.min(room - raidsH - R.GAP, Wanted(cdBlocks, cdNotes, reserve)))
        cdsCard:SetHeight(cdsH)
        cdsCard:ClearAllPoints()
        cdsCard:SetPoint("TOPLEFT", x, -(top + raidsH + R.GAP))
        Fill(cdsCard, cdBlocks, cdNotes, cdsH, reserve)
        return top + raidsH + R.GAP + cdsH
    end
    return column
end
