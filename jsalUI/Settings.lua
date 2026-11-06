-- Settings: a switch for each part of jsal.ui. A change applies after a
-- reload, since modules start once, at login. Addons can't reload the game
-- themselves on Forever, so the page asks the player to type /reload.
local _, ns = ...
local Style, Window = ns.Style, ns.Window

local ROW_HEIGHT = 40

Window.Page("settings", function(page)
    local intro = Style.Text(page, 13, "muted")
    intro:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    intro:SetWidth(Window.contentWidth)
    intro:SetText("Turn parts of jsal.ui on or off. Changes apply after you type /reload.")

    -- Shown once a switch changes, until the reload.
    local pending = Style.Text(page, 13, "gold", nil, true)
    pending:SetText("Type /reload to apply your changes.")
    pending:Hide()

    local last, gap = intro, -14
    if #ns.moduleOrder == 0 then
        local none = Style.Text(page, 13, "text")
        none:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -14)
        none:SetWidth(Window.contentWidth)
        none:SetText("The games, the Guild tab and the planners will be listed here as they arrive.")
        last = none
    end

    local rows = {}
    for _, module in ipairs(ns.moduleOrder) do
        local row = CreateFrame("Frame", nil, page)
        row:SetSize(Window.contentWidth, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, gap)
        Style.Rule(row, "BOTTOM", "line")
        row.name = Style.Text(row, 13, "text")
        row.name:SetPoint("TOPLEFT", 0, -5)
        row.name:SetText(module.title)
        row.note = Style.Text(row, 11, "muted")
        row.note:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
        row.switch = Style.Switch(row, function(on)
            ns.db.modules[module.key] = on
            pending:SetShown(true)
        end)
        row.switch:SetPoint("RIGHT", 0, 0)
        row.module = module
        rows[#rows + 1] = row
        last, gap = row, 0
        -- The module's own options, indented under it. These apply at once.
        for _, option in ipairs(module.options or {}) do
            local sub = CreateFrame("Frame", nil, page)
            sub:SetSize(Window.contentWidth - 24, ROW_HEIGHT)
            sub:SetPoint("TOPLEFT", last, "BOTTOMLEFT", last == row and 24 or 0, 0)
            Style.Rule(sub, "BOTTOM", "line")
            sub.name = Style.Text(sub, 12, "text")
            sub.name:SetPoint("TOPLEFT", 0, -6)
            sub.name:SetText(option.title)
            sub.note = Style.Text(sub, 11, "muted")
            sub.note:SetPoint("TOPLEFT", sub.name, "BOTTOMLEFT", 0, -4)
            sub.note:SetText(option.note or "")
            sub.switch = Style.Switch(sub, function(on) ns.SetOption(module.key, option.key, on) end)
            sub.switch:SetPoint("RIGHT", 0, 0)
            sub.option, sub.moduleKey = option, module.key
            rows[#rows + 1] = sub
            last = sub
        end
        if last ~= row then
            -- The next module lines up with the page edge again.
            local spacer = CreateFrame("Frame", nil, page)
            spacer:SetSize(1, 1)
            spacer:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -(ROW_HEIGHT * #module.options) + 1)
            last = spacer
        end
    end
    pending:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -16)

    local footer = Style.Text(page, 11, "muted")
    footer:SetPoint("BOTTOMLEFT")
    footer:SetText("jsal.ui " .. ns.version .. ", free from jsal.io")

    page.Refresh = function()
        for _, row in ipairs(rows) do
            local module = row.module
            if row.option then
                row.switch:SetOn(ns.OptionOn(row.moduleKey, row.option.key))
            else
                row.switch:SetOn(ns.ModuleWanted(module))
                if module.failed then
                    row.note:SetText("Turned off after an error this session. BugSack has the details.")
                else
                    row.note:SetText(module.note or "")
                end
            end
        end
    end
end)
