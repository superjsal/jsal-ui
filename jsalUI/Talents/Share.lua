-- The share window. Export shows a build as a Wowhead talent calculator link
-- (to open in a browser or paste anywhere) and as a short jsal.ui code (to
-- paste to a guildmate). Import takes either. Both are read as plain data,
-- never run.
local _, ns = ...
local Style, Tree = ns.Style, ns.TalentTree

local Share = {}
ns.TalentShare = Share

local WIDTH = 520
local frame, note, action, onImport
local fields = {}

-- A labelled one-line box that selects all its text when clicked.
local function Field(label, top)
    local f = {}
    f.label = Style.Text(frame, 12, "gold", nil, true)
    f.label:SetPoint("TOPLEFT", 16, top)
    f.label:SetText(label)
    f.well = CreateFrame("Frame", nil, frame)
    f.well:SetPoint("TOPLEFT", 16, top - 18)
    f.well:SetSize(WIDTH - 32, 28)
    Style.Fill(f.well, "well")
    Style.Border(f.well, "lineStrong")
    f.box = CreateFrame("EditBox", nil, f.well)
    f.box:SetPoint("TOPLEFT", 8, 0)
    f.box:SetPoint("BOTTOMRIGHT", -8, 0)
    f.box:SetAutoFocus(false)
    f.box:SetFont(Style.font, 12, "")
    f.box:SetTextColor(Style.Color("text"))
    f.box:SetScript("OnEscapePressed", function() frame:Hide() end)
    f.box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    f.well:EnableMouse(true)
    f.well:SetScript("OnMouseDown", function() f.box:SetFocus() end)
    return f
end

local function Build()
    frame = Style.Panel("jsalUIBuildCode", WIDTH, 230, "Build code")
    frame:SetFrameStrata("DIALOG")
    note = Style.Text(frame, 12, "muted")
    note:SetPoint("TOPLEFT", 16, -44)
    note:SetWidth(WIDTH - 32)
    fields.link = Field("WOWHEAD LINK", -72)
    fields.code = Field("JSAL.UI CODE", -126)

    action = Style.Button(frame, "Import", "primary", 110)
    action:SetPoint("BOTTOMRIGHT", -16, 14)
    local close = Style.Button(frame, "Close", "plain", 90)
    close:SetPoint("RIGHT", action, "LEFT", -6, 0)
    close:SetScript("OnClick", function() frame:Hide() end)
    action:SetScript("OnClick", function()
        local build, why = Tree.Decode(fields.code.box:GetText())
        if not build then
            note:SetText(why or "That isn't a jsal.ui build code or a Wowhead link.")
            note:SetTextColor(Style.Color("gold"))
            return
        end
        Tree.Add(build)
        frame:Hide()
        if onImport then onImport(build) end
    end)
end

function Share.Export(build)
    if not frame then Build() end
    frame.title:SetText("Export: " .. build.name)
    note:SetText("Click a box, then Ctrl+C to copy. The Wowhead link opens the build, in its order, in Wowhead's calculator.")
    note:SetTextColor(Style.Color("muted"))
    fields.link.label:Show()
    fields.link.well:Show()
    fields.link.box:SetText(Tree.WowheadLink(build) or "")
    fields.code.label:SetText("JSAL.UI CODE")
    fields.code.box:SetText(Tree.Encode(build))
    action:Hide()
    frame:Show()
    fields.link.box:SetFocus()
end

function Share.Import(callback)
    if not frame then Build() end
    onImport = callback
    frame.title:SetText("Import a build")
    note:SetText("Paste a jsal.ui build code or a Wowhead talent calculator link with Ctrl+V, then Import.")
    note:SetTextColor(Style.Color("muted"))
    fields.link.label:Hide()
    fields.link.well:Hide()
    fields.code.label:SetText("CODE OR LINK")
    fields.code.box:SetText("")
    action:Show()
    frame:Show()
    fields.code.box:SetFocus()
end
