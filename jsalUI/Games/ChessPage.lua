-- The Chess page: on the left your record, your games (each saying whose
-- move it is), guildmates' games you can watch, and the guildmates online
-- with jsal.ui to challenge; on the right the board, what's happening, the
-- game's buttons and its moves. Click one of your pieces, then a marked
-- square, to move; a watched game is only to look at.
local addonName, ns = ...
local Style, Window, Rules = ns.Style, ns.Window, ns.ChessRules

local LIST_W, GUTTER = 176, 18
local BODY_TOP = 36
local SQ, COORD = 58, 14
local ROW_H, MATE_H = 46, 30
local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\Chess\\"

local COLOR_NAME = { w = "white", b = "black" }
local HOW_TEXT = {
    checkmate = "by checkmate", resigned = "by resignation", agreed = "by agreement",
    stalemate = "by stalemate", material = "with too few pieces to mate",
    fifty = "after fifty moves without a capture", repetition = "by repeating the position",
}

-- A small section heading with a count, a note on the right, and a rule.
local function Section(parent, width)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(width, 20)
    s.title = Style.Text(s, 11, "gold", nil, true)
    s.title:SetPoint("LEFT")
    s.count = Style.Text(s, 11, "muted", nil, true)
    s.count:SetPoint("LEFT", s.title, "RIGHT", 8, 0)
    s.note = Style.Text(s, 11, "muted")
    s.note:SetPoint("RIGHT")
    s.note:SetJustifyH("RIGHT")
    Style.Rule(s, "BOTTOM", "line")
    return s
end

local function Small(parent, label, kind, width, height)
    local b = Style.Button(parent, label, kind or "plain", width)
    b:SetHeight(height or 24)
    return b
end

-- "3-1", with draws as a third number when there are any.
local function Score(w, l, d)
    if w + l + d == 0 then return "new" end
    return d > 0 and ("%d-%d-%d"):format(w, l, d) or ("%d-%d"):format(w, l)
end

Window.Page("chess", function(page)
    local Chess = ns.Chess
    local width, height = Window.contentWidth, Window.contentHeight
    local right = LIST_W + GUTTER
    local rightW = width - right
    local selectedID, from, promo
    local status, statusUntil = nil, 0
    local Paint

    local function Say(text)
        status, statusUntil = text, GetTime() + 5
        Paint()
    end

    local lead = Style.Text(page, 13, "muted")
    lead:SetPoint("TOPLEFT", 0, -4)
    lead:SetWidth(width)
    lead:SetText("Play guildmates who have jsal.ui. Moves wait for whoever's turn it is.")

    ---------------------------------------------------------------------------
    -- Left: the record, the games, the guildmates to challenge.
    ---------------------------------------------------------------------------
    local recordHead = Section(page, LIST_W)
    recordHead:SetPoint("TOPLEFT", 0, -BODY_TOP)
    recordHead.title:SetText("RECORD")
    local stats = {}
    for i, label in ipairs({ "Won", "Lost", "Drawn" }) do
        local x = (i - 1) * (LIST_W / 3)
        local n = Style.Text(page, 22, i == 1 and "gold" or "text", nil, true)
        n:SetPoint("TOPLEFT", x, -(BODY_TOP + 30))
        local l = Style.Text(page, 11, "muted")
        l:SetPoint("TOPLEFT", n, "BOTTOMLEFT", 0, -2)
        l:SetText(label)
        stats[i] = n
    end

    local gamesHead = Section(page, LIST_W)
    gamesHead:SetPoint("TOPLEFT", 0, -(BODY_TOP + 86))
    gamesHead.title:SetText("GAMES")
    local noGames = Style.Text(page, 11, "muted")
    noGames:SetWidth(LIST_W - 8)
    noGames:SetText("None yet. Challenge a guildmate below.")

    local rows, watchRows = {}, {}
    local function GameRow(i, pool)
        local row = CreateFrame("Button", nil, page)
        row:SetSize(LIST_W, ROW_H - 2)
        row.bg = Style.Fill(row, "well")
        row.mark = row:CreateTexture(nil, "ARTWORK")
        row.mark:SetColorTexture(Style.Color("gold"))
        row.mark:SetPoint("TOPLEFT")
        row.mark:SetPoint("BOTTOMLEFT")
        row.mark:SetWidth(2)
        row.name = Style.Text(row, 13, "text", nil, true)
        row.name:SetPoint("TOPLEFT", 12, -6)
        row.name:SetWidth(LIST_W - 20)
        row.name:SetWordWrap(false)
        row.sub = Style.Text(row, 11, "muted")
        row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
        row.sub:SetWidth(LIST_W - 20)
        row.sub:SetWordWrap(false)
        row:SetScript("OnClick", function(self)
            selectedID, from, promo, status = self.game.id, nil, nil, nil
            Paint()
        end)
        pool[i] = row
        return row
    end

    -- Guildmates' games being watched, a few at most.
    local MAX_WATCH = 3
    local watchHead = Section(page, LIST_W)
    watchHead.title:SetText("WATCHING")

    local mateHead = Section(page, LIST_W)
    mateHead.title:SetText("CHALLENGE")
    mateHead.note:SetText("online")
    local noMates = Style.Text(page, 11, "muted")
    noMates:SetWidth(LIST_W - 8)
    local mates = {}
    local function MateRow(i)
        local row = CreateFrame("Frame", nil, page)
        row:SetSize(LIST_W, MATE_H)
        row.dot = row:CreateTexture(nil, "ARTWORK")
        row.dot:SetTexture(MEDIA .. "dot")
        row.dot:SetSize(8, 8)
        row.dot:SetPoint("LEFT", 8, 0)
        row.dot:SetVertexColor(Style.Color("wordGreen"))
        row.play = Small(row, "Play", "plain", 44, 22)
        row.play:SetPoint("RIGHT")
        row.score = Style.Text(row, 11, "muted")
        row.score:SetPoint("RIGHT", row.play, "LEFT", -8, 0)
        row.score:SetJustifyH("RIGHT")
        row.name = Style.Text(row, 13, "text")
        row.name:SetPoint("LEFT", row.dot, "RIGHT", 8, 0)
        row.name:SetPoint("RIGHT", row.score, "LEFT", -6, 0)
        row.name:SetWordWrap(false)
        row.play:SetScript("OnClick", function(self)
            local game, why = Chess.Challenge(self.player.name, self.player.target)
            if game then
                selectedID, from, promo = game.id, nil, nil
                Say(("Challenge sent to %s."):format(self.player.name))
            else
                Say(why)
            end
        end)
        mates[i] = row
        return row
    end

    ---------------------------------------------------------------------------
    -- Right: the board and the game.
    ---------------------------------------------------------------------------
    local head = Section(page, rightW)
    head:SetPoint("TOPLEFT", right, -BODY_TOP)
    local empty = Style.Text(page, 13, "muted")
    empty:SetPoint("TOPLEFT", right, -(BODY_TOP + 32))
    empty:SetWidth(rightW)

    local board = CreateFrame("Frame", nil, page)
    board:SetSize(COORD + 8 * SQ, 8 * SQ + COORD)
    board:SetPoint("TOPLEFT", right, -(BODY_TOP + 30))
    local squares, rankLabels, fileLabels = {}, {}, {}
    local chosen = CreateFrame("Frame", nil, board)
    chosen:SetSize(SQ, SQ)
    chosen:SetFrameLevel(board:GetFrameLevel() + 5)
    Style.Border(chosen, "gold")
    -- A second line inside the first, so the picked square reads at a glance.
    local inner = CreateFrame("Frame", nil, chosen)
    inner:SetPoint("TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", -1, 1)
    Style.Border(inner, "gold")
    chosen:Hide()

    local OnSquare
    for i = 1, 8 do
        rankLabels[i] = Style.Text(board, 10, "muted")
        rankLabels[i]:SetPoint("CENTER", board, "TOPLEFT", COORD / 2, -(i - 0.5) * SQ)
        fileLabels[i] = Style.Text(board, 10, "muted")
        fileLabels[i]:SetPoint("CENTER", board, "TOPLEFT", COORD + (i - 0.5) * SQ, -(8 * SQ + COORD / 2))
        for j = 1, 8 do
            local b = CreateFrame("Button", nil, board)
            b:SetSize(SQ, SQ)
            b:SetPoint("TOPLEFT", COORD + (j - 1) * SQ, -(i - 1) * SQ)
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            local light = (i + j) % 2 == 0
            b.bg = b:CreateTexture(nil, "BACKGROUND")
            b.bg:SetAllPoints()
            if light then b.bg:SetColorTexture(0.29, 0.31, 0.36) else b.bg:SetColorTexture(0.19, 0.20, 0.24) end
            b.tint = b:CreateTexture(nil, "BORDER")
            b.tint:SetAllPoints()
            b.piece = b:CreateTexture(nil, "ARTWORK")
            b.piece:SetSize(SQ - 6, SQ - 6)
            b.piece:SetPoint("CENTER")
            b.mark = b:CreateTexture(nil, "OVERLAY")
            b.mark:SetPoint("CENTER")
            b:SetScript("OnClick", function(self, mouse) OnSquare(self.sq, mouse) end)
            squares[(i - 1) * 8 + j] = b
        end
    end

    local below = 8 * SQ + COORD + BODY_TOP + 30 + 12
    local stateText = Style.Text(page, 13, "text", nil, true)
    stateText:SetPoint("TOPLEFT", right, -(below + 4))
    stateText:SetWidth(rightW - 230)
    local primary = Small(page, "", "primary", 110)
    local second = Small(page, "", "plain", 90)
    second:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -below)
    primary:SetPoint("RIGHT", second, "LEFT", -6, 0)

    -- Promotion: the four pieces a pawn can become, picked by clicking.
    local promoButtons = {}
    for i, kind in ipairs({ "q", "r", "b", "n" }) do
        local b = CreateFrame("Button", nil, page)
        b:SetSize(30, 30)
        b:SetPoint("TOPLEFT", right + 100 + (i - 1) * 34, -(below - 2))
        Style.Fill(b, "well")
        Style.Border(b, "gold")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.kind = kind
        b:SetScript("OnClick", function(self)
            local game = Chess.Game(selectedID or "")
            if game and promo then
                Chess.Move(game, Rules.Name(promo.from) .. Rules.Name(promo.to) .. self.kind)
            end
            from, promo = nil, nil
            Paint()
        end)
        b:Hide()
        promoButtons[i] = b
    end

    local movesHead = Section(page, rightW)
    movesHead:SetPoint("TOPLEFT", right, -(below + 40))
    movesHead.title:SetText("MOVES")
    local movesText = Style.Text(page, 12, "text")
    movesText:SetPoint("TOPLEFT", movesHead, "BOTTOMLEFT", 0, -8)
    movesText:SetWidth(rightW)

    -- The resign button asks once: the first click arms it for a moment.
    local armed = 0

    ---------------------------------------------------------------------------
    -- Moving: click your piece, then where it goes. Right-click lets go.
    ---------------------------------------------------------------------------
    OnSquare = function(sq, mouse)
        local game = Chess.Game(selectedID or "")
        if not (game and Chess.MyTurn(game)) then return end
        if mouse == "RightButton" then
            from, promo = nil, nil
            return Paint()
        end
        local state = Chess.Position(game)
        if from then
            local options = {}
            for _, m in ipairs(Rules.Legal(state)) do
                if m.from == from and m.to == sq then options[#options + 1] = m end
            end
            if #options > 1 then
                promo = { from = from, to = sq }
                return Paint()
            elseif #options == 1 then
                Chess.Move(game, Rules.UCI(options[1]))
                from, promo = nil, nil
                return Paint()
            end
        end
        local piece = state.board[sq]
        from = (piece and Rules.Side(piece) == game.color and from ~= sq) and sq or nil
        promo = nil
        Paint()
    end

    ---------------------------------------------------------------------------
    -- Painting.
    ---------------------------------------------------------------------------
    local function PaintBoard(game)
        local state = Chess.Position(game)
        local flip = game.color == "b"
        local last = game.moves[#game.moves]
        local lastFrom, lastTo = last and Rules.Parse(last:sub(1, 2)), last and Rules.Parse(last:sub(3, 4))
        local targets = {}
        if from and Chess.MyTurn(game) then
            for _, m in ipairs(Rules.Legal(state)) do
                if m.from == from then targets[m.to] = true end
            end
        end
        local checked
        if Rules.InCheck(state) then
            local king = state.turn == "w" and "K" or "k"
            for sq = 1, 64 do if state.board[sq] == king then checked = sq end end
        end
        for i = 1, 8 do
            rankLabels[i]:SetText(flip and i or (9 - i))
            fileLabels[i]:SetText(("abcdefgh"):sub(flip and (9 - i) or i, flip and (9 - i) or i))
            for j = 1, 8 do
                local b = squares[(i - 1) * 8 + j]
                local sq = flip and Rules.Square(9 - j, i) or Rules.Square(j, 9 - i)
                b.sq = sq
                local piece = state.board[sq]
                if piece then
                    b.piece:SetTexture(MEDIA .. (Rules.Side(piece) .. piece:lower()))
                    b.piece:Show()
                else
                    b.piece:Hide()
                end
                if sq == checked then
                    b.tint:SetColorTexture(0.75, 0.25, 0.2, 0.45)
                    b.tint:Show()
                elseif sq == lastFrom or sq == lastTo then
                    b.tint:SetColorTexture(0.89, 0.69, 0.29, 0.18)
                    b.tint:Show()
                else
                    b.tint:Hide()
                end
                if targets[sq] then
                    local take = piece ~= nil
                    b.mark:SetTexture(MEDIA .. (take and "ring" or "dot"))
                    b.mark:SetSize(take and SQ - 4 or 16, take and SQ - 4 or 16)
                    b.mark:SetVertexColor(0.89, 0.69, 0.29, take and 0.7 or 0.6)
                    b.mark:Show()
                else
                    b.mark:Hide()
                end
                if sq == from then
                    chosen:ClearAllPoints()
                    chosen:SetPoint("TOPLEFT", b)
                end
            end
        end
        chosen:SetShown(from ~= nil)
    end

    local function MovesLine(game)
        local _, sans = Chess.Position(game)
        if #sans == 0 then return "No moves yet." end
        local first = math.max(1, #sans - 31)
        if first % 2 == 0 then first = first - 1 end
        local parts = first > 1 and { "…" } or {}
        for i = first, #sans do
            local text = sans[i]
            if i == #sans then text = "|cffe3b04b" .. text .. "|r" end
            if i % 2 == 1 then
                parts[#parts + 1] = ("|cff9a9688%d.|r %s"):format((i + 1) / 2, text)
            else
                parts[#parts + 1] = text
            end
        end
        return table.concat(parts, " ")
    end

    local function SetButton(b, label, enabled)
        b:SetShown(label ~= nil)
        if label then
            b:SetLabel(label)
            b:SetEnabled(enabled ~= false)
        end
    end

    local function PaintGame(game)
        local mine = Chess.MyTurn(game)
        head.title:SetText(game.opp:upper())
        local note = "you play " .. COLOR_NAME[game.color]
        if status and GetTime() < statusUntil then
            head.note:SetText(status)
            head.note:SetTextColor(Style.Color("gold"))
        else
            head.note:SetText(note)
            head.note:SetTextColor(Style.Color("muted"))
        end
        PaintBoard(game)
        movesText:SetText(MovesLine(game))
        for _, b in ipairs(promoButtons) do b:Hide() end
        stateText:SetTextColor(Style.Color("text"))

        if game.status == "asked" then
            stateText:SetText(("%s wants a game. You'd play %s."):format(game.opp, COLOR_NAME[game.color]))
            SetButton(primary, "Accept")
            SetButton(second, "Not now")
        elseif game.status == "invited" then
            stateText:SetText(("Waiting for %s to take the challenge."):format(game.opp))
            SetButton(primary, nil)
            SetButton(second, "Take back")
        elseif game.status == "over" then
            local result = game.result == "win" and "You won" or game.result == "loss" and "You lost" or "Drawn"
            stateText:SetText(result .. " " .. (HOW_TEXT[game.how] or "") .. ".")
            if game.result == "win" then stateText:SetTextColor(Style.Color("gold")) end
            SetButton(primary, "Rematch")
            SetButton(second, "Close")
        elseif promo then
            stateText:SetText("Promote to")
            local side = game.color
            for _, b in ipairs(promoButtons) do
                b.icon:SetTexture(MEDIA .. side .. b.kind)
                b:Show()
            end
            SetButton(primary, nil)
            SetButton(second, "Cancel")
        else
            local state = Chess.Position(game)
            local check = Rules.InCheck(state) and " · check" or ""
            if game.drawOffer == "them" then
                stateText:SetText(("%s offers a draw."):format(game.opp))
                SetButton(primary, "Accept draw")
            else
                stateText:SetText((mine and "Your move" or (game.opp .. "'s move")) .. check)
                if mine then stateText:SetTextColor(Style.Color("gold")) end
                SetButton(primary, game.drawOffer == "me" and "Draw offered" or "Offer draw", game.drawOffer ~= "me")
                primary:SetKind("plain")
            end
            SetButton(second, GetTime() < armed and "Sure?" or "Resign")
        end
        if game.status ~= "play" or promo or game.drawOffer == "them" then primary:SetKind("primary") end
    end

    -- A guildmates' game, to look at only: white at the bottom.
    local function PaintWatch(w)
        from, promo = nil, nil
        head.title:SetText((w.white .. " vs " .. w.black):upper())
        head.note:SetText("watching")
        head.note:SetTextColor(Style.Color("muted"))
        PaintBoard(w)
        movesText:SetText(MovesLine(w))
        for _, b in ipairs(promoButtons) do b:Hide() end
        stateText:SetTextColor(Style.Color("text"))
        if w.over then
            local who = w.winner == "w" and w.white or w.black
            stateText:SetText((w.winner == "d" and "Drawn" or (who .. " won")) .. " " .. (HOW_TEXT[w.how] or "") .. ".")
        else
            local state = Chess.Position(w)
            local check = Rules.InCheck(state) and " · check" or ""
            stateText:SetText(((#w.moves % 2 == 0) and w.white or w.black) .. "'s move" .. check)
        end
        SetButton(primary, nil)
        SetButton(second, "Stop watching")
    end

    Paint = function()
        if not Chess.running then
            for _, f in ipairs({ board, stateText, primary, second, movesHead, movesText, gamesHead, watchHead, mateHead, recordHead, noGames, noMates }) do f:Hide() end
            empty:SetText("Chess is turned off in Settings.")
            empty:Show()
            return
        end
        -- The record.
        local w, l, d = Chess.Totals()
        stats[1]:SetText(w)
        stats[2]:SetText(l)
        stats[3]:SetText(d)
        recordHead.note:SetText(("%d game%s"):format(w + l + d, w + l + d == 1 and "" or "s"))

        -- The games: your own, or one you're watching.
        local games, watching = Chess.Games(), Chess.Watching()
        local selected, seeing
        for _, g in ipairs(games) do if g.id == selectedID then selected = g end end
        for i, w in ipairs(watching) do if w.id == selectedID and i <= MAX_WATCH then seeing = w end end
        if not (selected or seeing) then selected, seeing = games[1], (not games[1]) and watching[1] or nil end
        selectedID = (selected or seeing) and (selected or seeing).id or nil
        gamesHead.count:SetText(#games)
        local y = BODY_TOP + 86 + 24
        noGames:SetShown(#games == 0)
        if #games == 0 then
            noGames:ClearAllPoints()
            noGames:SetPoint("TOPLEFT", 0, -(y + 2))
            y = y + 30
        end
        local openWith = {}
        for i, g in ipairs(games) do
            local row = rows[i] or GameRow(i, rows)
            row.game = g
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            y = y + ROW_H
            row.name:SetText(g.opp)
            local score = Score(Chess.Record(g.opp))
            local sub, gold
            if g.status == "asked" then sub, gold = "Wants a game", true
            elseif g.status == "invited" then sub = "Waiting for them"
            elseif g.status == "over" then sub = (g.result == "win" and "You won" or g.result == "loss" and "You lost" or "Drawn") .. " · " .. score
            elseif Chess.MyTurn(g) then sub, gold = "Your move · " .. score, true
            else sub = "Their move · " .. score end
            row.sub:SetText(sub)
            row.sub:SetTextColor(Style.Color(gold and "gold" or "muted"))
            local on = g == selected
            row.bg:SetShown(on)
            row.mark:SetShown(on)
            row.name:SetTextColor(Style.Color(on and "text" or "muted"))
            row:Show()
            if g.status ~= "over" then openWith[g.opp] = true end
        end
        for i = #games + 1, #rows do rows[i]:Hide() end

        -- Games you're watching: who's playing and where it's got to.
        local shownWatch = math.min(#watching, MAX_WATCH)
        watchHead:SetShown(shownWatch > 0)
        if shownWatch > 0 then
            y = y + 12
            watchHead:ClearAllPoints()
            watchHead:SetPoint("TOPLEFT", 0, -y)
            watchHead.count:SetText(#watching)
            y = y + 24
        end
        for i = 1, shownWatch do
            local wg = watching[i]
            local row = watchRows[i] or GameRow(i, watchRows)
            row.game = wg
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            y = y + ROW_H
            row.name:SetText(wg.white .. " vs " .. wg.black)
            local sub
            if wg.over then
                sub = wg.winner == "d" and "Drawn" or ((wg.winner == "w" and wg.white or wg.black) .. " won")
            else
                sub = ("Move %d · %s to move"):format(math.floor(#wg.moves / 2) + 1, #wg.moves % 2 == 0 and wg.white or wg.black)
            end
            row.sub:SetText(sub)
            row.sub:SetTextColor(Style.Color("muted"))
            local on = wg == seeing
            row.bg:SetShown(on)
            row.mark:SetShown(on)
            row.name:SetTextColor(Style.Color(on and "text" or "muted"))
            row:Show()
        end
        for i = shownWatch + 1, #watchRows do watchRows[i]:Hide() end

        -- Who to challenge: as many as fit, then a count of the rest.
        y = y + 12
        mateHead:ClearAllPoints()
        mateHead:SetPoint("TOPLEFT", 0, -y)
        mateHead:Show()
        y = y + 26
        local players = Chess.Players()
        mateHead.count:SetText(#players)
        local room = math.floor((height - y - 20) / MATE_H)
        local shown = math.min(#players, room)
        for i = 1, shown do
            local p = players[i]
            local row = mates[i] or MateRow(i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            y = y + MATE_H
            row.name:SetText(p.name)
            row.score:SetText(Score(Chess.Record(p.name)))
            row.play.player = p
            row.play:SetEnabled(not openWith[p.name])
            row.play:SetLabel(openWith[p.name] and "On" or "Play")
            row:Show()
        end
        for i = shown + 1, #mates do mates[i]:Hide() end
        noMates:ClearAllPoints()
        noMates:SetPoint("TOPLEFT", 0, -(y + 2))
        if #players == 0 then
            local guildOn = ns.Guild and ns.Guild.running
            noMates:SetText(guildOn and "No guildmates with jsal.ui online right now." or "Turn on the Guild tab in Settings to find players.")
            noMates:Show()
        elseif #players > shown then
            noMates:SetText(("And %d more online."):format(#players - shown))
            noMates:Show()
        else
            noMates:Hide()
        end
        recordHead:Show()
        gamesHead:Show()

        -- The game.
        local show = selected ~= nil or seeing ~= nil
        for _, f in ipairs({ board, stateText, movesHead, movesText }) do f:SetShown(show) end
        empty:SetShown(not show)
        if not show then
            head.title:SetText("NO GAME")
            head.note:SetText("")
            empty:SetText("Pick a guildmate under Challenge to start a game. They need jsal.ui and to be online to answer; after that, moves wait for whoever's turn it is. Guildmates' games show under Watching as they're played.")
            primary:Hide()
            second:Hide()
            for _, b in ipairs(promoButtons) do b:Hide() end
            return
        end
        if seeing then return PaintWatch(seeing) end
        PaintGame(selected)
    end

    -- The two buttons under the board do what the game's state calls for.
    primary:SetScript("OnClick", function()
        local game = Chess.Game(selectedID or "")
        if not game then return end
        if game.status == "asked" then
            Chess.Accept(game)
        elseif game.status == "over" then
            if not Chess.Online(game.opp) then return Say(game.opp .. " isn't online.") end
            local new, why = Chess.Challenge(game.opp, game.target)
            if new then selectedID = new.id else return Say(why) end
        elseif game.status == "play" then
            Chess.Draw(game)
            if game.status == "play" then Say("Draw offered.") end
        end
        Paint()
    end)
    second:SetScript("OnClick", function()
        local game = Chess.Game(selectedID or "")
        if not game then
            local w = Chess.Watched(selectedID)
            if w then
                Chess.StopWatching(w)
                selectedID = nil
                Paint()
            end
            return
        end
        if game.status == "asked" or game.status == "invited" then
            Chess.Decline(game)
            selectedID = nil
        elseif game.status == "over" then
            Chess.Close(game)
            selectedID = nil
        elseif promo then
            from, promo = nil, nil
        elseif GetTime() > armed then
            armed = GetTime() + 3
            ns.Compat.After(3, function() if page:IsVisible() then Paint() end end)
        else
            armed = 0
            Chess.Resign(game)
        end
        Paint()
    end)

    page.Refresh = Paint
    Chess.OnChange(function()
        if page:IsVisible() then Paint() end
    end)
end)
