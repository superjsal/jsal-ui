-- Chess rules: the board, every legal move, check and mate, and the move
-- notation players read (Nf3, O-O, exd5). A game is kept as its moves in
-- the short form addon messages carry ("e2e4", "e7e8q") and replayed from the
-- start, so both players' boards can't drift apart.
--
-- Squares are numbered 1 to 64: a1 is 1, h1 is 8, a8 is 57. White's pieces
-- are capital letters (KQRBNP), Black's small (kqrbnp).
local _, ns = ...

local Rules = {}
ns.ChessRules = Rules

local FILES = "abcdefgh"

local function File(sq) return (sq - 1) % 8 + 1 end
local function Rank(sq) return math.floor((sq - 1) / 8) + 1 end
local function Square(file, rank)
    if file < 1 or file > 8 or rank < 1 or rank > 8 then return nil end
    return (rank - 1) * 8 + file
end
Rules.File, Rules.Rank, Rules.Square = File, Rank, Square

function Rules.Name(sq)
    return FILES:sub(File(sq), File(sq)) .. Rank(sq)
end

function Rules.Parse(name)
    local f, r = (name or ""):match("^([a-h])([1-8])$")
    if not f then return nil end
    return Square(FILES:find(f, 1, true), tonumber(r))
end

local function Side(piece)
    if not piece then return nil end
    return piece == piece:upper() and "w" or "b"
end
Rules.Side = Side

local function Other(side) return side == "w" and "b" or "w" end

local KNIGHT = { { 1, 2 }, { 2, 1 }, { 2, -1 }, { 1, -2 }, { -1, -2 }, { -2, -1 }, { -2, 1 }, { -1, 2 } }
local KING = { { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { -1, -1 }, { 0, -1 }, { 1, -1 } }
local ROOK = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local BISHOP = { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

-- A position from Forsyth-Edwards notation, the usual way to write one.
function Rules.FromFEN(fen)
    local placement, turn, castle, ep, half, full = (fen or ""):match("^(%S+)%s+([wb])%s+(%S+)%s+(%S+)%s*(%d*)%s*(%d*)")
    if not placement then return nil end
    local board, rank, file = {}, 8, 1
    for c in placement:gmatch(".") do
        if c == "/" then
            rank, file = rank - 1, 1
        elseif c:match("%d") then
            file = file + tonumber(c)
        else
            board[Square(file, rank)] = c
            file = file + 1
        end
    end
    local rights = {}
    for c in castle:gmatch("[KQkq]") do rights[c] = true end
    return {
        board = board, turn = turn, castle = rights,
        ep = ep ~= "-" and Rules.Parse(ep) or nil,
        half = tonumber(half) or 0, full = tonumber(full) or 1,
    }
end

local START = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
function Rules.New() return Rules.FromFEN(START) end

-- Whether a side attacks a square.
local function Attacked(board, sq, by)
    local f, r = File(sq), Rank(sq)
    local up = by == "w" and 1 or -1
    local pawn, knight, king = by == "w" and "P" or "p", by == "w" and "N" or "n", by == "w" and "K" or "k"
    local queen, rook, bishop = by == "w" and "Q" or "q", by == "w" and "R" or "r", by == "w" and "B" or "b"
    for _, df in ipairs({ -1, 1 }) do
        local s = Square(f + df, r - up)
        if s and board[s] == pawn then return true end
    end
    for _, d in ipairs(KNIGHT) do
        local s = Square(f + d[1], r + d[2])
        if s and board[s] == knight then return true end
    end
    for _, d in ipairs(KING) do
        local s = Square(f + d[1], r + d[2])
        if s and board[s] == king then return true end
    end
    for _, set in ipairs({ { ROOK, rook }, { BISHOP, bishop } }) do
        for _, d in ipairs(set[1]) do
            local nf, nr = f + d[1], r + d[2]
            local s = Square(nf, nr)
            while s do
                local p = board[s]
                if p then
                    if p == set[2] or p == queen then return true end
                    break
                end
                nf, nr = nf + d[1], nr + d[2]
                s = Square(nf, nr)
            end
        end
    end
    return false
end

local function KingSquare(board, side)
    local king = side == "w" and "K" or "k"
    for sq = 1, 64 do
        if board[sq] == king then return sq end
    end
end

function Rules.InCheck(state, side)
    side = side or state.turn
    local k = KingSquare(state.board, side)
    return k ~= nil and Attacked(state.board, k, Other(side))
end

-- Every move the side to play could make, before checking it leaves its
-- own king safe. A move is { from, to, promo }.
local function Pseudo(state)
    local board, side, moves = state.board, state.turn, {}
    local function Add(from, to, promo) moves[#moves + 1] = { from = from, to = to, promo = promo } end
    for sq = 1, 64 do
        local p = board[sq]
        if p and Side(p) == side then
            local kind, f, r = p:lower(), File(sq), Rank(sq)
            if kind == "p" then
                local up = side == "w" and 1 or -1
                local last = side == "w" and 8 or 1
                local function Push(to)
                    if Rank(to) == last then
                        for _, promo in ipairs({ "q", "r", "b", "n" }) do Add(sq, to, promo) end
                    else
                        Add(sq, to)
                    end
                end
                local one = Square(f, r + up)
                if one and not board[one] then
                    Push(one)
                    local two = Square(f, r + 2 * up)
                    if r == (side == "w" and 2 or 7) and not board[two] then Add(sq, two) end
                end
                for _, df in ipairs({ -1, 1 }) do
                    local to = Square(f + df, r + up)
                    if to and ((board[to] and Side(board[to]) ~= side) or to == state.ep) then Push(to) end
                end
            elseif kind == "n" or kind == "k" then
                for _, d in ipairs(kind == "n" and KNIGHT or KING) do
                    local to = Square(f + d[1], r + d[2])
                    if to and Side(board[to]) ~= side then Add(sq, to) end
                end
                if kind == "k" then
                    -- Castling: the right is kept, the way is clear, and the
                    -- king doesn't start in, pass through or land in check.
                    local home, enemy = side == "w" and 1 or 8, Other(side)
                    local K, Q = side == "w" and "K" or "k", side == "w" and "Q" or "q"
                    local rookPiece = side == "w" and "R" or "r"
                    if sq == Square(5, home) and not Attacked(board, sq, enemy) then
                        if state.castle[K] and board[Square(8, home)] == rookPiece
                            and not board[Square(6, home)] and not board[Square(7, home)]
                            and not Attacked(board, Square(6, home), enemy) and not Attacked(board, Square(7, home), enemy) then
                            Add(sq, Square(7, home))
                        end
                        if state.castle[Q] and board[Square(1, home)] == rookPiece
                            and not board[Square(2, home)] and not board[Square(3, home)] and not board[Square(4, home)]
                            and not Attacked(board, Square(4, home), enemy) and not Attacked(board, Square(3, home), enemy) then
                            Add(sq, Square(3, home))
                        end
                    end
                end
            else
                local dirs = kind == "r" and ROOK or kind == "b" and BISHOP or nil
                local sets = dirs and { dirs } or { ROOK, BISHOP }
                for _, set in ipairs(sets) do
                    for _, d in ipairs(set) do
                        local nf, nr = f + d[1], r + d[2]
                        local to = Square(nf, nr)
                        while to do
                            if board[to] then
                                if Side(board[to]) ~= side then Add(sq, to) end
                                break
                            end
                            Add(sq, to)
                            nf, nr = nf + d[1], nr + d[2]
                            to = Square(nf, nr)
                        end
                    end
                end
            end
        end
    end
    return moves
end

-- The position after a move, as a new state; the old one is left as it was.
function Rules.Make(state, m)
    local board = {}
    for sq, p in pairs(state.board) do board[sq] = p end
    local piece = board[m.from]
    local kind, side = piece:lower(), Side(piece)
    local captured = board[m.to]
    board[m.from] = nil
    if kind == "p" and m.to == state.ep and not captured then
        -- En passant: the pawn taken sits beside, not on, the square moved to.
        board[Square(File(m.to), Rank(m.from))] = nil
        captured = side == "w" and "p" or "P"
    end
    board[m.to] = m.promo and (side == "w" and m.promo:upper() or m.promo) or piece
    if kind == "k" and math.abs(File(m.to) - File(m.from)) == 2 then
        local home = Rank(m.from)
        local fromFile, toFile = File(m.to) == 7 and 8 or 1, File(m.to) == 7 and 6 or 4
        board[Square(toFile, home)] = board[Square(fromFile, home)]
        board[Square(fromFile, home)] = nil
    end
    local castle = {}
    for k, v in pairs(state.castle) do castle[k] = v end
    if kind == "k" then
        if side == "w" then castle.K, castle.Q = nil, nil else castle.k, castle.q = nil, nil end
    end
    for _, sq in ipairs({ m.from, m.to }) do
        if sq == 1 then castle.Q = nil elseif sq == 8 then castle.K = nil
        elseif sq == 57 then castle.q = nil elseif sq == 64 then castle.k = nil end
    end
    local ep
    if kind == "p" and math.abs(Rank(m.to) - Rank(m.from)) == 2 then
        ep = Square(File(m.from), (Rank(m.from) + Rank(m.to)) / 2)
    end
    return {
        board = board, turn = Other(side), castle = castle, ep = ep,
        half = (kind == "p" or captured) and 0 or state.half + 1,
        full = state.full + (side == "b" and 1 or 0),
    }
end

-- The legal moves: those that don't leave the mover's own king in check.
function Rules.Legal(state)
    local legal = {}
    for _, m in ipairs(Pseudo(state)) do
        if not Rules.InCheck(Rules.Make(state, m), state.turn) then legal[#legal + 1] = m end
    end
    return legal
end

function Rules.UCI(m)
    return Rules.Name(m.from) .. Rules.Name(m.to) .. (m.promo or "")
end

-- A move written "e2e4" (or "e7e8q"), if it's legal here.
function Rules.FindMove(state, uci)
    for _, m in ipairs(Rules.Legal(state)) do
        if Rules.UCI(m) == uci then return m end
    end
end

-- The move as players write it: Nf3, exd5, O-O, e8=Q+, Qh7#.
function Rules.SAN(state, m)
    local piece = state.board[m.from]
    local kind = piece:lower()
    local text
    if kind == "k" and math.abs(File(m.to) - File(m.from)) == 2 then
        text = File(m.to) == 7 and "O-O" or "O-O-O"
    else
        local capture = state.board[m.to] ~= nil or (kind == "p" and m.to == state.ep)
        if kind == "p" then
            text = (capture and (FILES:sub(File(m.from), File(m.from)) .. "x") or "") .. Rules.Name(m.to)
            if m.promo then text = text .. "=" .. m.promo:upper() end
        else
            -- Another piece of the same kind that could go there too: say
            -- which one by its file, its rank, or both.
            local sameFile, sameRank, other = false, false, false
            for _, o in ipairs(Rules.Legal(state)) do
                if o.to == m.to and o.from ~= m.from and state.board[o.from] == piece then
                    other = true
                    if File(o.from) == File(m.from) then sameFile = true end
                    if Rank(o.from) == Rank(m.from) then sameRank = true end
                end
            end
            local from = ""
            if other then
                if not sameFile then from = FILES:sub(File(m.from), File(m.from))
                elseif not sameRank then from = tostring(Rank(m.from))
                else from = Rules.Name(m.from) end
            end
            text = kind:upper() .. from .. (capture and "x" or "") .. Rules.Name(m.to)
        end
    end
    local after = Rules.Make(state, m)
    if Rules.InCheck(after) then
        text = text .. (#Rules.Legal(after) == 0 and "#" or "+")
    end
    return text
end

-- Not enough left for either side to mate: kings alone, or a king and one
-- bishop or knight against a king.
local function Insufficient(board)
    local minor, other = 0, false
    for sq = 1, 64 do
        local p = board[sq] and board[sq]:lower()
        if p == "b" or p == "n" then minor = minor + 1
        elseif p and p ~= "k" then other = true end
    end
    return not other and minor <= 1
end

-- The same position: the same pieces, side to play, castling and en passant.
local function Key(state)
    local parts = {}
    for sq = 1, 64 do parts[sq] = state.board[sq] or "." end
    local castle = (state.castle.K and "K" or "") .. (state.castle.Q and "Q" or "") .. (state.castle.k and "k" or "") .. (state.castle.q and "q" or "")
    return table.concat(parts) .. state.turn .. castle .. (state.ep or "")
end

-- A game being played through: its position, each move as players write
-- it, and how often each position has come up. A game grows a move at a
-- time with Advance, so a new move doesn't replay the whole game.
function Rules.Start()
    local state = Rules.New()
    return { state = state, sans = {}, seen = { [Key(state)] = 1 }, count = 0 }
end

-- Plays one more move; false if it isn't legal here.
function Rules.Advance(run, uci)
    local m = Rules.FindMove(run.state, uci)
    if not m then return false end
    run.count = run.count + 1
    run.sans[run.count] = Rules.SAN(run.state, m)
    run.state = Rules.Make(run.state, m)
    local key = Key(run.state)
    run.seen[key] = (run.seen[key] or 0) + 1
    return true
end

-- How the game stands: "play", "checkmate", "stalemate", "material",
-- "fifty" or "repetition".
function Rules.Judge(run)
    local state = run.state
    if #Rules.Legal(state) == 0 then
        return Rules.InCheck(state) and "checkmate" or "stalemate"
    elseif Insufficient(state.board) then
        return "material"
    elseif state.half >= 100 then
        return "fifty"
    elseif (run.seen[Key(state)] or 0) >= 3 then
        return "repetition"
    end
    return "play"
end

-- Plays a game's moves from the start. Returns the position, each move as
-- players write it, and how the game stands. A move that isn't legal stops
-- it there and is reported by its place.
function Rules.Replay(moves)
    local run = Rules.Start()
    for i, uci in ipairs(moves or {}) do
        if not Rules.Advance(run, uci) then return run.state, run.sans, "play", i end
    end
    return run.state, run.sans, Rules.Judge(run)
end
