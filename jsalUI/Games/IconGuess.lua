-- Icon Guess: name the spell from its icon, four choices, ten icons a round.
-- The daily round is the same ten for everyone; practice rounds are random.
local _, ns = ...
local Style, Compat, Games = ns.Style, ns.Compat, ns.Games

local IconGuess = ns.NewModule("iconguess", {
    title = "Icon Guess",
    note = "Name the spell from its icon: a daily round and practice. /jsal icons",
})
ns.IconGuess = IconGuess

local ROUND, CHOICES = 10, 4

-- Every spell the game knows from the list, one per icon. The classes are
-- walked in a fixed order, so every player builds the same pool.
local pool, byClass
local function Pool()
    if pool then return pool end
    pool, byClass = {}, {}
    local classes = {}
    for class in pairs(ns.IconGuessData) do classes[#classes + 1] = class end
    table.sort(classes)
    local seenIcon = {}
    for _, class in ipairs(classes) do
        byClass[class] = {}
        for _, id in ipairs(ns.IconGuessData[class]) do
            local name, icon = Compat.SpellInfo(id)
            if name and icon and not seenIcon[icon] then
                seenIcon[icon] = true
                local entry = { id = id, name = name, icon = icon, class = class }
                pool[#pool + 1] = entry
                table.insert(byClass[class], entry)
            end
        end
    end
    return pool
end

-- A round: ten different spells, each with three wrong answers, from the
-- same class where it has enough, so the choices look alike.
local function NewRound(random)
    local all = Pool()
    local questions, used = {}, {}
    local tries = 0
    while #questions < ROUND and tries < 1000 do
        tries = tries + 1
        local answer = all[random(#all)]
        if not used[answer] then
            used[answer] = true
            local choices, names = { answer }, { [answer.name] = true }
            local same = byClass[answer.class]
            local picks = 0
            while #choices < CHOICES and picks < 300 do
                picks = picks + 1
                local source = (picks <= 100 and #same > CHOICES) and same or all
                local other = source[random(#source)]
                if not names[other.name] then
                    names[other.name] = true
                    choices[#choices + 1] = other
                end
            end
            for i = #choices, 2, -1 do
                local j = random(i)
                choices[i], choices[j] = choices[j], choices[i]
            end
            questions[#questions + 1] = { answer = answer, choices = choices }
        end
    end
    return questions
end

-- Each day's round is dealt from the day number plus one, so the rounds
-- run on from the first ones played.
local function DailyRound()
    return NewRound(Games.Random((Games.Today() + 1) * 7919 + 101))
end

-- Today's daily round, saved for the whole account, so closing the window
-- midway picks up where it stopped, and an alt can't replay it.
local function Daily()
    local today = Games.Today()
    local state = ns.db.icons
    if type(state) ~= "table" or state.day ~= today then
        state = { day = today, index = 1, score = 0, marks = {} }
        ns.db.icons = state
    end
    return state
end

function IconGuess.DailyDone()
    local state = ns.db.icons
    return type(state) == "table" and state.day == Games.Today() and state.done or false
end

function IconGuess.Result()
    if not IconGuess.DailyDone() then return nil end
    return ns.db.icons.day, tostring(ns.db.icons.score)
end

function IconGuess.Status()
    if not IconGuess.running then return "Turned off in Settings" end
    local state = Daily()
    if state.done then return ("%d of %d right"):format(state.score, ROUND) end
    if state.index > 1 then return ("In progress: icon %d of %d"):format(state.index, ROUND) end
    return ("#%d is ready"):format(state.day)
end

function IconGuess.Record()
    local best = ns.db.iconBest
    if not best then return "Icon Guess: no practice rounds yet." end
    return ("Icon Guess: best practice round %d of %d."):format(best, ROUND)
end

local frame, subtitle, iconHolder, iconTexture, buttons, endText, shareButton, practiceButton
local round, mode, index, score, marks, locked

local function ShareLine()
    local state = Daily()
    local row = {}
    for i, right in ipairs(state.marks) do row[i] = right and "{rt1}" or "{rt7}" end
    return ("Icon Guess #%d %d/%d %s"):format(state.day, state.score, ROUND, table.concat(row))
end

-- The window is shorter on the end screen, which has no choices to show.
local QUESTION_HEIGHT, END_HEIGHT = 440, 220

local function ShowEnd()
    frame:SetHeight(END_HEIGHT)
    iconHolder:Hide()
    for _, b in ipairs(buttons) do b:Hide() end
    endText:Show()
    practiceButton:Show()
    if mode == "daily" then
        subtitle:SetText(("Daily round #%d"):format(Daily().day))
        endText:SetText(("%d of %d right.\nA new round comes with the daily reset."):format(score, ROUND))
        shareButton:Show()
    else
        subtitle:SetText("Practice round")
        endText:SetText(("%d of %d right.\n%s"):format(score, ROUND, IconGuess.Record()))
        shareButton:Hide()
    end
end

local function ShowQuestion()
    local q = round[index]
    if not q then return ShowEnd() end
    locked = false
    endText:Hide()
    shareButton:Hide()
    practiceButton:Hide()
    frame:SetHeight(QUESTION_HEIGHT)
    iconHolder:Show()
    iconTexture:SetTexture(q.answer.icon)
    local label = mode == "daily" and ("Daily round #%d"):format(Daily().day) or "Practice round"
    subtitle:SetText(("%s · %d of %d · %d right"):format(label, index, ROUND, score))
    for i, b in ipairs(buttons) do
        local choice = q.choices[i]
        b:SetShown(choice ~= nil)
        if choice then
            b:SetLabel(choice.name)
            b:SetTone(nil)
            b:SetEnabled(true)
            b.choice = choice
        end
    end
end

local function Finish()
    if mode == "daily" then
        local state = Daily()
        state.done = true
        if ns.Guild then ns.Guild.Announce() end
        if ns.Flight then ns.Flight.Refresh() end
    else
        ns.db.iconBest = math.max(ns.db.iconBest or 0, score)
    end
    ns.Window.Refresh()
end

local function Pick(button)
    if locked then return end
    locked = true
    local q = round[index]
    local right = button.choice == q.answer
    if right then score = score + 1 end
    for _, b in ipairs(buttons) do
        if b.choice == q.answer then
            b:SetTone("right")
        elseif b == button then
            b:SetTone("wrong")
        end
    end
    index = index + 1
    if mode == "daily" then
        local state = Daily()
        state.index, state.score = index, score
        state.marks[#state.marks + 1] = right
    end
    if index > #round then Finish() end
    Compat.After(1, function()
        if frame:IsShown() then ShowQuestion() end
    end)
end

local function Build()
    frame = Style.Panel("jsalUIIconGuess", 360, 440, "Icon Guess")
    subtitle = Style.Text(frame, 11, "muted")
    subtitle:SetPoint("TOP", 0, -44)
    subtitle:SetJustifyH("CENTER")

    iconHolder = CreateFrame("Frame", nil, frame)
    iconHolder:SetSize(98, 98)
    iconHolder:SetPoint("TOP", 0, -68)
    Style.Border(iconHolder, "lineStrong")
    iconTexture = iconHolder:CreateTexture(nil, "ARTWORK")
    iconTexture:SetPoint("TOPLEFT", 1, -1)
    iconTexture:SetPoint("BOTTOMRIGHT", -1, 1)
    iconTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    buttons = {}
    for i = 1, CHOICES do
        local b = Style.Button(frame, "", "plain", 300)
        b:SetHeight(34)
        b:SetPoint("TOP", 0, -(186 + (i - 1) * 42))
        b:SetScript("OnClick", Pick)
        buttons[i] = b
    end

    -- The end screen takes the icon's place.
    endText = Style.Text(frame, 15, "text")
    endText:SetPoint("TOP", 0, -84)
    endText:SetWidth(320)
    endText:SetJustifyH("CENTER")
    endText:SetSpacing(6)

    shareButton = Style.Button(frame, "Share to guild", "primary", 150)
    shareButton:SetPoint("TOPRIGHT", frame, "TOP", -4, -164)
    shareButton:SetScript("OnClick", function()
        if not IsInGuild() then return ns.Print("Join a guild to share.") end
        Compat.SendChat(ShareLine(), "GUILD")
        shareButton:SetEnabled(false)
    end)
    practiceButton = Style.Button(frame, "Practice round", "plain", 150)
    practiceButton:SetPoint("TOPLEFT", frame, "TOP", 4, -164)
    practiceButton:SetScript("OnClick", function() IconGuess.Practice() end)
end

local function Start(newMode)
    if not IconGuess.running then
        return ns.Print("Icon Guess is turned off. /jsal settings turns it on.")
    end
    if Compat.InCombat() then
        return ns.Print("Icon Guess opens once combat ends.")
    end
    if #Pool() < CHOICES * 3 then
        return ns.Print("Icon Guess couldn't load its icons on this version of the game.")
    end
    if not frame then Build() end
    mode = newMode
    if mode == "daily" then
        local state = Daily()
        round, index, score = DailyRound(), state.index, state.score
        shareButton:SetEnabled(true)
    else
        round, index, score = NewRound(function(n) return math.random(n) end), 1, 0
    end
    ShowQuestion()
    frame:Show()
end

function IconGuess.Open() Start("daily") end
function IconGuess.Practice() Start("practice") end

function IconGuess:OnEnable()
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", ns.Safe(self, function()
        if frame then frame:Hide() end
    end))
end

ns.Command("icons", function() IconGuess.Open() end)
