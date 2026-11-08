-- The installer puts the jsal.ui look into EllesmereUI as a profile of its
-- own, through EllesmereUI's public import call. The player's other
-- EllesmereUI profiles are left as they are.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local Installer = {}
ns.Installer = Installer

local EUI = "EllesmereUI"
local FINISH = "Installed. Type /reload to switch to the jsal.ui look."
local SPEC_LOCKED ="The jsal.ui look is saved, but this spec is set to use another EllesmereUI profile. Pick jsal.ui on EllesmereUI's Profiles page to switch."

-- Where things stand, as one state the Install page and the Home card share.
function Installer.State()
    if not Compat.AddOnExists(EUI) then return "missing" end
    if not Compat.IsAddOnLoaded(EUI) then return "off" end
    if not (EllesmereUI and EllesmereUI.ImportProfileSilent) then return "old" end
    if ns.Profile.string == "" then return "noProfile" end
    local done = ns.db.installed
    if not done then return "ready" end
    if (done.version or 0) < ns.Profile.version then return "update" end
    return "installed"
end

local MESSAGES = {
    missing = "EllesmereUI isn't installed. The jsal.ui look is an EllesmereUI profile, so install EllesmereUI first (it's free on CurseForge and Wago), then /reload.",
    off = "EllesmereUI is installed but turned off. Turn it on in the AddOns list on the character screen.",
    old = "This EllesmereUI is too old for the installer. Update it, then /reload.",
    noProfile = "The jsal.ui look isn't in this version yet. Everything else in jsal.ui works without it.",
    ready = "Ready to install. This adds a profile called jsal.ui to EllesmereUI and switches to it, with Outfit, jsal.ui's font, in EllesmereUI and RestedXP Guides. Then you type /reload.",
    update = "A newer jsal.ui look is ready. Updating replaces the jsal.ui profile; your other profiles stay as they are.",
    installed = "Installed. You're on the latest jsal.ui look.",
}

function Installer.Message(state)
    return MESSAGES[state or Installer.State()]
end

function Installer.CanInstall(state)
    state = state or Installer.State()
    return state == "ready" or state == "update" or state == "installed"
end

-- Returns true and EllesmereUI's status, or false and a reason to show.
function Installer.Install()
    if Compat.InCombat() then
        return false, "You're in combat. Install once it ends."
    end
    local state = Installer.State()
    if not Installer.CanInstall(state) then
        return false, Installer.Message(state)
    end
    local first = not ns.db.installed
    local ran, ok, err, status = xpcall(function()
        return EllesmereUI.ImportProfileSilent({
            importString = ns.Profile.string,
            profileName = ns.Profile.name,
        })
    end, ns.Report)
    if not ran then
        return false, "EllesmereUI couldn't import the look. BugSack has the details."
    end
    if not ok then
        return false, "EllesmereUI couldn't import the look: " .. tostring(err)
    end
    ns.db.installed = {
        version = ns.Profile.version,
        at = Compat.ServerTime(),
        with = ns.version,
        specLocked = status == "spec_locked" or nil,
    }
    -- The look's font is Outfit, which the profile sets in EllesmereUI. A
    -- first install also turns on Outfit for RestedXP Guides; an update
    -- leaves that switch as the player last set it.
    if first then
        ns.SetOption("sharedFonts", "restedxp", true)
        if ns.SharedFonts and ns.SharedFonts.running then ns.SharedFonts.SetRestedXP(true) end
    end
    return true, status
end

-- While the look is available, jsal.ui runs the first-time setup, so
-- EllesmereUI's own first-install picker stays quiet.
ns.OnLoad(function()
    if ns.Profile.string ~= "" and EllesmereUI and EllesmereUI.RegisterExternalInstaller then
        EllesmereUI.RegisterExternalInstaller(ns.title)
    end
end)

-- One chat line per new look version, never a window in the player's face.
ns.OnLogin(function()
    local done = ns.db.installed
    if done and done.specLocked then
        done.specLocked = nil
        ns.Print(SPEC_LOCKED)
    end
    local state = Installer.State()
    local version = ns.Profile.version
    if (state == "ready" or state == "update") and not ns.db.nudged[version] then
        ns.db.nudged[version] = true
        if state == "update" then
            ns.Print("A newer jsal.ui look is ready: type /jsal install.")
        else
            ns.Print("The jsal.ui look is ready to install: type /jsal install.")
        end
    end
end)

local function EllesmereText(state)
    if state == "missing" then return "Not installed" end
    if state == "off" then return "Turned off" end
    local version = Compat.Metadata(EUI, "Version") or "unknown"
    if state == "old" then return "Version " .. version .. ", too old" end
    return "Version " .. version
end

local function LookText()
    if ns.Profile.string == "" then return "Not added yet" end
    local done = ns.db.installed
    local text = "Version " .. ns.Profile.version
    if done then
        text = text .. ", installed version " .. (done.version or 0)
    end
    return text
end

Window.Page("install", function(page)
    local lead = Style.Text(page, 13, "muted")
    lead:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    lead:SetWidth(Window.contentWidth)
    lead:SetText("The jsal.ui look is an EllesmereUI profile. Installing it takes one click and a reload.")

    local card = Style.Card(page, "Status")
    card:SetSize(Window.contentWidth, 88)
    card:SetPoint("TOPLEFT", lead, "BOTTOMLEFT", 0, -16)

    local function Row(top, label)
        local name = Style.Text(card, 13, "muted")
        name:SetPoint("TOPLEFT", 12, top)
        name:SetText(label)
        local value = Style.Text(card, 13, "text")
        value:SetPoint("TOPLEFT", 140, top)
        return value
    end
    local ellesmere = Row(-34, "EllesmereUI")
    local look = Row(-58, "jsal.ui look")

    local message = Style.Text(page, 13, "text")
    message:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -16)
    message:SetWidth(Window.contentWidth)

    local go = Style.Button(page, "Install the look", "primary", 200)
    go:SetPoint("TOPLEFT", message, "BOTTOMLEFT", 0, -16)
    local cancel = Style.Button(page, "Cancel", "plain", 100)
    cancel:SetPoint("LEFT", go, "RIGHT", 8, 0)

    -- The first click asks; the second installs. Addons can't reload the
    -- game on Forever, so the player finishes with /reload.
    local confirming, done = false, false

    local function Paint()
        local state = Installer.State()
        ellesmere:SetText(EllesmereText(state))
        look:SetText(LookText())
        message:SetText(done and FINISH or Installer.Message(state))
        go:SetEnabled(Installer.CanInstall(state) and not done)
        if confirming then
            go:SetLabel("Yes, install it")
        elseif state == "update" then
            go:SetLabel("Update the look")
        elseif state == "installed" then
            go:SetLabel("Reinstall the look")
        else
            go:SetLabel("Install the look")
        end
        cancel:SetShown(confirming)
    end

    go:SetScript("OnClick", function()
        if not confirming then
            confirming = true
            return Paint()
        end
        confirming = false
        local ok, result = Installer.Install()
        if not ok then
            Paint()
            message:SetText(result)
            return
        end
        done = true
        Paint()
        ns.Print(FINISH)
    end)

    cancel:SetScript("OnClick", function()
        confirming = false
        Paint()
    end)

    page.Refresh = function()
        confirming = false
        Paint()
    end
end)
