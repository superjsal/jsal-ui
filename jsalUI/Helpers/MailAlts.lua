-- Mail to your characters: beside the mailbox's Send tab, a short list of
-- your other characters (from the Journal's list of the account) and the
-- last few people you mailed. A click fills in the "To:" box and moves on
-- to the subject.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local MailAlts = ns.NewModule("mailalts", {
    title = "Mail to your characters",
    note = "Beside the mailbox: your other characters and recent recipients, one click to fill in who it's to.",
})
ns.MailAlts = MailAlts

local WIDTH, ROW_H, MAX_ALTS, MAX_RECENT = 180, 22, 12, 5

local function Recent()
    ns.db.mailRecent = type(ns.db.mailRecent) == "table" and ns.db.mailRecent or {}
    return ns.db.mailRecent
end

-- Your other characters, highest level first.
function MailAlts.Alts()
    local list, me = {}, Compat.MyName()
    for name, c in pairs(type(ns.db.characters) == "table" and ns.db.characters or {}) do
        if name ~= me and type(c) == "table" then list[#list + 1] = { name = name, level = c.level or 0 } end
    end
    table.sort(list, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        return a.name < b.name
    end)
    for i = MAX_ALTS + 1, #list do list[i] = nil end
    return list
end

-- Someone just mailed: they go to the top of Recent, unless they're yours.
function MailAlts.Mailed(name)
    name = strtrim(tostring(name or ""))
    if name == "" then return end
    local chars = type(ns.db.characters) == "table" and ns.db.characters or {}
    if chars[name] or name == Compat.MyName() then return end
    local list = Recent()
    for i = #list, 1, -1 do
        if list[i]:lower() == name:lower() then table.remove(list, i) end
    end
    table.insert(list, 1, name)
    for i = MAX_RECENT + 1, #list do list[i] = nil end
end

local panel, rows = nil, {}

local function Row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, panel)
    r:SetSize(WIDTH - 16, ROW_H)
    r.bg = Style.Fill(r, "well")
    r.bg:Hide()
    r.name = Style.Text(r, 12, "text")
    r.name:SetPoint("LEFT", 6, 0)
    r.name:SetWidth(WIDTH - 60)
    r.name:SetWordWrap(false)
    r.name:SetJustifyH("LEFT")
    r.note = Style.Text(r, 11, "muted")
    r.note:SetPoint("RIGHT", -6, 0)
    r:SetScript("OnEnter", function(self) self.bg:Show() end)
    r:SetScript("OnLeave", function(self) self.bg:Hide() end)
    r:SetScript("OnClick", function(self)
        if not SendMailNameEditBox then return end
        SendMailNameEditBox:SetText(self.value)
        if SendMailSubjectEditBox then SendMailSubjectEditBox:SetFocus() end
        MailAlts.Paint()
    end)
    rows[i] = r
    return r
end

local function Heading(text)
    local h = Style.Text(panel, 11, "gold", nil, true)
    h:SetText(text)
    return h
end

local altsHead, recentHead, empty
local function Build()
    panel = CreateFrame("Frame", "jsalUIMailAlts", SendMailFrame or UIParent)
    panel:SetWidth(WIDTH)
    Style.Fill(panel, "window")
    Style.Border(panel, "lineStrong")
    panel:SetPoint("TOPLEFT", MailFrame or UIParent, "TOPRIGHT", 6, -24)
    altsHead = Heading("YOUR CHARACTERS")
    recentHead = Heading("RECENT")
    empty = Style.Text(panel, 11, "muted")
    empty:SetWidth(WIDTH - 20)
    empty:SetJustifyH("LEFT")
    empty:SetText("Your other characters show here once you've logged in on each with jsal.ui.")
end

function MailAlts.Paint()
    if not panel then return end
    local to = SendMailNameEditBox and SendMailNameEditBox:GetText() or ""
    local y, i = -10, 0
    local function Add(value, note)
        i = i + 1
        local r = Row(i)
        r.value = value
        r.name:SetText(value)
        r.name:SetTextColor(Style.Color(value == to and "gold" or "text"))
        r.note:SetText(note or "")
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 8, y)
        r:Show()
        y = y - ROW_H
    end
    altsHead:ClearAllPoints()
    altsHead:SetPoint("TOPLEFT", 12, y)
    y = y - 18
    local alts = MailAlts.Alts()
    empty:SetShown(#alts == 0)
    if #alts == 0 then
        empty:ClearAllPoints()
        empty:SetPoint("TOPLEFT", 12, y)
        y = y - empty:GetStringHeight() - 6
    end
    for _, a in ipairs(alts) do Add(a.name, tostring(a.level)) end
    local recent = Recent()
    recentHead:SetShown(#recent > 0)
    if #recent > 0 then
        y = y - 8
        recentHead:ClearAllPoints()
        recentHead:SetPoint("TOPLEFT", 12, y)
        y = y - 18
        for _, name in ipairs(recent) do Add(name) end
    end
    for j = i + 1, #rows do rows[j]:Hide() end
    panel:SetHeight(-y + 10)
end

local hooked = false
local function Hook()
    if hooked or not SendMailFrame then return end
    hooked = true
    Build()
    SendMailFrame:HookScript("OnShow", function()
        if MailAlts.running then
            panel:Show()
            xpcall(MailAlts.Paint, ns.Report)
        end
    end)
    SendMailFrame:HookScript("OnHide", function() panel:Hide() end)
    if SendMailNameEditBox then
        SendMailNameEditBox:HookScript("OnTextChanged", function()
            if panel:IsShown() then xpcall(MailAlts.Paint, ns.Report) end
        end)
    end
    if SendMailFrame:IsShown() then panel:Show() MailAlts.Paint() else panel:Hide() end
end

function MailAlts:OnEnable()
    -- Who each sent letter went to, for Recent.
    if hooksecurefunc and SendMail then
        hooksecurefunc("SendMail", function(name) if MailAlts.running then MailAlts.Mailed(name) end end)
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("MAIL_SHOW")
    f:SetScript("OnEvent", function() xpcall(Hook, ns.Report) end)
    self.events = f
end

function MailAlts:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
    if panel then panel:Hide() end
end
