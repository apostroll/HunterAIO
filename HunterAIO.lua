-- =============================================================
-- HunterAIO: Unified Hunter Suite for World of Warcraft 1.12.1
-- Modules: PetCare, SmartTrap, AutoShotTimer, RingMenu, Config GUI
-- =============================================================

BINDING_HEADER_HUNTERAIO_HEADER = "HunterAIO"
BINDING_NAME_HUNTERAIO_RING1 = "Open Ring 1 (Tracking)"
BINDING_NAME_HUNTERAIO_RING2 = "Open Ring 2 (Professions/Gathering)"
BINDING_NAME_HUNTERAIO_RING3 = "Open Ring 3 (Aspects/Utility)"
BINDING_NAME_HUNTERAIO_SMARTTRAP_FREEZING = "Smart Freezing Trap"
BINDING_NAME_HUNTERAIO_SMARTTRAP_FROST = "Smart Frost Trap"
BINDING_NAME_HUNTERAIO_SMARTTRAP_IMMOLATION = "Smart Immolation Trap"
BINDING_NAME_HUNTERAIO_SMARTTRAP_EXPLOSIVE = "Smart Explosive Trap"

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[HunterAIO]|r " .. msg)
    end
end

-- Hidden tooltip for scanning spell mana costs
local scanTooltip = CreateFrame("GameTooltip", "HunterAIOScanTooltip", UIParent, "GameTooltipTemplate")
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

-- Helper: Find spell in spellbook
local function FindSpellInBook(spellName)
    if not spellName then return nil end
    local highestID = nil
    local i = 1
    while true do
        local name = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        if string.lower(name) == string.lower(spellName) then
            highestID = i
        end
        i = i + 1
    end
    return highestID
end

-- Helper: Get spell mana cost from tooltip
local function GetSpellManaCost(spellID)
    if not spellID then return 0 end
    scanTooltip:ClearLines()
    scanTooltip:SetSpell(spellID, BOOKTYPE_SPELL)
    for j = 1, scanTooltip:NumLines() do
        local text = getglobal("HunterAIOScanTooltipTextLeft" .. j):GetText()
        if text then
            local _, _, mana = string.find(text, "(%d+) Mana")
            if mana then
                return tonumber(mana)
            end
        end
    end
    return 80
end

-- Helper: Check if spell is on cooldown (excluding global 1.5s GCD)
local function IsSpellOnCooldown(spellID)
    if not spellID then return false, 0 end
    local start, duration = GetSpellCooldown(spellID, BOOKTYPE_SPELL)
    if start and duration and duration > 1.5 then
        local remaining = (start + duration) - GetTime()
        if remaining > 0 then
            return true, remaining
        end
    end
    return false, 0
end

-- Helper: Get item description in container slot
local function GetSlotItemDescription(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    local _, count = GetContainerItemInfo(bag, slot)
    if link then
        if count and count > 1 then
            return link .. " (x" .. count .. ")"
        else
            return link
        end
    else
        return "|cffff5555Empty|r"
    end
end

-- =============================================================
-- MODULE 1: PetCare
-- =============================================================
local function IsPetEating()
    for i = 1, 16 do
        local buff = UnitBuff("pet", i)
        if buff and string.find(buff, "Ability_Hunter_BeastTraining") then
            return true
        end
    end
    return false
end

function PetCare(bag, slot)
    if not bag and HunterAIODB and HunterAIODB.petcare then bag = HunterAIODB.petcare.bag end
    if not slot and HunterAIODB and HunterAIODB.petcare then slot = HunterAIODB.petcare.slot end
    bag = tonumber(bag) or 0
    slot = tonumber(slot) or 1
    local cast = CastSpellByName

    if IsAltKeyDown() or UnitIsDead("pet") then
        cast("Revive Pet")
    elseif not UnitExists("pet") then
        cast("Call Pet")
    elseif UnitAffectingCombat("pet") or UnitAffectingCombat("player") then
        cast("Mend Pet")
    elseif GetPetHappiness() and GetPetHappiness() < 3 then
        if not IsPetEating() then
            cast("Feed Pet")
            PickupContainerItem(bag, slot)
        end
    else
        cast("Dismiss Pet")
    end
end

-- =============================================================
-- MODULE 2: SmartTrap
-- =============================================================
local function ParseTrapName(text)
    if not text then return nil end
    local s = string.lower(text)
    if string.find(s, "freez") then
        return "Freezing Trap"
    elseif string.find(s, "frost") then
        return "Frost Trap"
    elseif string.find(s, "immo") then
        return "Immolation Trap"
    elseif string.find(s, "explo") then
        return "Explosive Trap"
    end
    return nil
end

local function GetTrapSpellFromAction(action)
    if not HasAction(action) then return nil end
    local macroName = GetActionText(action)
    if not macroName then return nil end

    local numGlobal, numChar = GetNumMacros()
    for i = 1, numGlobal do
        local name, _, body = GetMacroInfo(i)
        if name == macroName and body then
            local trap = ParseTrapName(body)
            if trap then return trap end
        end
    end
    for i = 1, numChar do
        local name, _, body = GetMacroInfo(18 + i)
        if name == macroName and body then
            local trap = ParseTrapName(body)
            if trap then return trap end
        end
    end

    return ParseTrapName(macroName)
end

function SmartTrap(trapName)
    local _, playerClass = UnitClass("player")
    if playerClass ~= "HUNTER" then return end
    if not trapName or trapName == "" then return end

    local normalizedTrap = ParseTrapName(trapName)
    if not normalizedTrap then return end

    local trapID = FindSpellInBook(normalizedTrap)
    if not trapID then return end

    if not UnitAffectingCombat("player") then
        CastSpellByName(normalizedTrap)
    else
        local fdID = FindSpellInBook("Feign Death")
        if not fdID then return end
        if IsSpellOnCooldown(fdID) then return end
        if UnitMana("player") < GetSpellManaCost(fdID) then return end

        if UnitExists("pet") and not UnitIsDead("pet") then
            PetPassiveMode()
            PetFollow()
        end
        CastSpellByName("Feign Death")
        CastSpellByName(normalizedTrap)
    end
end

-- Action Bar Hooks for Cooldowns & Tooltips
local orig_ActionButton_UpdateCooldown = ActionButton_UpdateCooldown
function ActionButton_UpdateCooldown()
    orig_ActionButton_UpdateCooldown()
    local button = this
    if not button then return end
    local action = ActionButton_GetPagedID(button)
    if HasAction(action) and GetActionText(action) then
        local trapSpell = GetTrapSpellFromAction(action)
        if trapSpell then
            local spellID = FindSpellInBook(trapSpell)
            if spellID then
                local start, duration, enable = GetSpellCooldown(spellID, BOOKTYPE_SPELL)
                local cd = getglobal(button:GetName() .. "Cooldown")
                if cd then
                    CooldownFrame_SetTimer(cd, start, duration, enable)
                end
            end
        end
    end
end

local orig_ActionButton_Update = ActionButton_Update
function ActionButton_Update()
    orig_ActionButton_Update()
    local button = this
    if not button then return end
    local action = ActionButton_GetPagedID(button)
    if HasAction(action) and GetActionText(action) then
        local trapSpell = GetTrapSpellFromAction(action)
        if trapSpell then
            local spellID = FindSpellInBook(trapSpell)
            if spellID then
                local icon = getglobal(button:GetName() .. "Icon")
                local tex = GetSpellTexture(spellID, BOOKTYPE_SPELL)
                local curTex = GetActionTexture(action)
                if icon and tex and (not curTex or string.find(curTex, "INV_Misc_QuestionMark")) then
                    icon:SetTexture(tex)
                    icon:Show()
                end
            end
        end
    end
end

local orig_ActionButton_SetTooltip = ActionButton_SetTooltip
function ActionButton_SetTooltip()
    local button = this
    if not button then return end
    local action = ActionButton_GetPagedID(button)
    if HasAction(action) and GetActionText(action) then
        local trapSpell = GetTrapSpellFromAction(action)
        if trapSpell then
            local spellID = FindSpellInBook(trapSpell)
            if spellID then
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                GameTooltip:SetSpell(spellID, BOOKTYPE_SPELL)
                return
            end
        end
    end
    orig_ActionButton_SetTooltip()
end

local orig_ActionButton_UpdateUsable = ActionButton_UpdateUsable
function ActionButton_UpdateUsable()
    orig_ActionButton_UpdateUsable()
    local button = this
    if not button then return end
    local action = ActionButton_GetPagedID(button)
    if HasAction(action) and GetActionText(action) then
        local trapSpell = GetTrapSpellFromAction(action)
        if trapSpell then
            local icon = getglobal(button:GetName() .. "Icon")
            if icon then
                if UnitAffectingCombat("player") then
                    local fdID = FindSpellInBook("Feign Death")
                    local fdCooldown = fdID and IsSpellOnCooldown(fdID)
                    local noMana = fdID and (UnitMana("player") < GetSpellManaCost(fdID))
                    if not fdID or fdCooldown or noMana then
                        icon:SetVertexColor(0.4, 0.4, 0.4)
                    else
                        icon:SetVertexColor(1.0, 1.0, 1.0)
                    end
                else
                    icon:SetVertexColor(1.0, 1.0, 1.0)
                end
            end
        end
    end
end

-- =============================================================
-- MODULE 3: AutoShotTimer
-- =============================================================
local astLogBuffer = {}
local MAX_AST_LOGS = 1000

local function AST_Log(category, message)
    if not HunterAIODB or not HunterAIODB.ast or not HunterAIODB.ast.logging then return end

    local timestamp = string.format("%.3f", GetTime())
    local logLine = "[" .. timestamp .. "] " .. category .. ": " .. message
    
    table.insert(astLogBuffer, logLine)
    if table.getn(astLogBuffer) > MAX_AST_LOGS then
        table.remove(astLogBuffer, 1)
    end

    if HunterAIODB.ast.debug and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff88aaff[AST " .. timestamp .. "]|r |cffffd100" .. category .. ":|r " .. message)
    end
end

local astFrame = CreateFrame("Frame", "HunterAIO_ASTFrame", UIParent)
astFrame:SetWidth(200)
astFrame:SetHeight(16)
astFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
astFrame:SetMovable(true)
astFrame:EnableMouse(true)
astFrame:RegisterForDrag("LeftButton")

astFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 12, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
astFrame:SetBackdropColor(0, 0, 0, 0.8)
astFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.9)

local astBg = astFrame:CreateTexture(nil, "BACKGROUND")
astBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
astBg:SetPoint("TOPLEFT", astFrame, "TOPLEFT", 3, -3)
astBg:SetPoint("BOTTOMRIGHT", astFrame, "BOTTOMRIGHT", -3, 3)
astBg:SetVertexColor(0.08, 0.08, 0.08, 0.9)

local astLeftBar = astFrame:CreateTexture("HunterAIO_ASTLeftBar", "ARTWORK")
astLeftBar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
astLeftBar:SetPoint("RIGHT", astFrame, "CENTER", 0, 0)
astLeftBar:SetHeight(10)
astLeftBar:SetWidth(0.1)

local astRightBar = astFrame:CreateTexture("HunterAIO_ASTRightBar", "ARTWORK")
astRightBar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
astRightBar:SetPoint("LEFT", astFrame, "CENTER", 0, 0)
astRightBar:SetHeight(10)
astRightBar:SetWidth(0.1)

local astCenterLine = astFrame:CreateTexture(nil, "OVERLAY")
astCenterLine:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
astCenterLine:SetWidth(2)
astCenterLine:SetPoint("TOP", astFrame, "TOP", 0, -2)
astCenterLine:SetPoint("BOTTOM", astFrame, "BOTTOM", 0, 2)
astCenterLine:SetVertexColor(1.0, 1.0, 1.0, 0.4)

local astTextLeft = astFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
astTextLeft:SetPoint("LEFT", astFrame, "LEFT", 6, 0)
astTextLeft:SetText("Auto Shot")

local astTextRight = astFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
astTextRight:SetPoint("RIGHT", astFrame, "RIGHT", -6, 0)
astTextRight:SetText("")

astFrame:SetScript("OnDragStart", function()
    if not HunterAIODB or not HunterAIODB.ast or not HunterAIODB.ast.locked or IsShiftKeyDown() then
        this:StartMoving()
    end
end)

astFrame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    if not HunterAIODB then HunterAIODB = {} end
    if not HunterAIODB.ast then HunterAIODB.ast = {} end
    local point, _, relPoint, x, y = this:GetPoint()
    HunterAIODB.ast.point = point
    HunterAIODB.ast.relPoint = relPoint
    HunterAIODB.ast.x = x
    HunterAIODB.ast.y = y
end)

local astLastX, astLastY = nil, nil
local isPlayerMoving = false
local moveSampleTimer = 0

local function UpdateASTMovement(dt)
    moveSampleTimer = moveSampleTimer + dt
    if moveSampleTimer >= 0.04 then
        moveSampleTimer = 0
        local x, y = GetPlayerMapPosition("player")
        if x and y and (x ~= 0 or y ~= 0) then
            if astLastX and astLastY then
                local dx = x - astLastX
                local dy = y - astLastY
                if (dx * dx + dy * dy) > 0.000000001 then
                    if not isPlayerMoving then
                        AST_Log("MOVE", "Player Started Moving")
                    end
                    isPlayerMoving = true
                else
                    if isPlayerMoving then
                        AST_Log("MOVE", "Player Stopped Moving")
                    end
                    isPlayerMoving = false
                end
            end
            astLastX = x
            astLastY = y
        end
    end
    return isPlayerMoving
end

local astCycleStartTime = nil
local astCycleDuration = 2.8
local isAutoRepeating = false
local isASTTestMode = false
local isCastingSpecial = false
local isInitialShot = false
local AIM_DURATION = 0.5
local astLastPhase = nil

local function GetRangedWeaponSpeed()
    local speed = UnitRangedDamage("player")
    if speed and speed > 0 then
        return speed
    end
    return 2.8
end

local function StartInitialShot(reason)
    astCycleDuration = GetRangedWeaponSpeed()
    astCycleStartTime = GetTime()
    isInitialShot = true
    astLastPhase = "AIM"
    astLeftBar:Show()
    astRightBar:Show()
    astFrame:SetAlpha(1.0)
    astFrame:Show()
    AST_Log("TIMER", "StartInitialShot [" .. (reason or "Auto") .. "] -> Speed=" .. string.format("%.2f", astCycleDuration) .. "s (Starting with 0.50s Aim)")
end

local function StartReloadCycle(reason)
    astCycleDuration = isASTTestMode and 2.8 or GetRangedWeaponSpeed()
    astCycleStartTime = GetTime()
    isInitialShot = false
    astLastPhase = "RELOAD"
    astLeftBar:Show()
    astRightBar:Show()
    astFrame:SetAlpha(1.0)
    astFrame:Show()
    local reloadTime = math.max(0.01, astCycleDuration - AIM_DURATION)
    AST_Log("TIMER", "StartReloadCycle [" .. (reason or "Auto") .. "] -> Reload=" .. string.format("%.2f", reloadTime) .. "s")
end

local function StopShotCycle(reason)
    AST_Log("TIMER", "StopShotCycle [" .. (reason or "Auto") .. "]")
    astCycleStartTime = nil
    isInitialShot = false
    astLastPhase = nil
    astLeftBar:SetWidth(0.1)
    astRightBar:SetWidth(0.1)
    astLeftBar:Hide()
    astRightBar:Hide()
    astTextRight:SetText("")
    astTextLeft:SetText("Auto Shot")
    if not isAutoRepeating and not isASTTestMode then
        astFrame:SetAlpha(0.0)
    end
end

local function UpdateASTDimensions()
    if not HunterAIODB or not HunterAIODB.ast then return end
    local w = HunterAIODB.ast.width or 200
    local h = HunterAIODB.ast.height or 16
    local s = HunterAIODB.ast.scale or 1.0

    astFrame:SetWidth(w)
    astFrame:SetHeight(h)
    astFrame:SetScale(s)

    local innerH = math.max(2, h - 6)
    astLeftBar:SetHeight(innerH)
    astRightBar:SetHeight(innerH)
end

astFrame:SetScript("OnUpdate", function()
    local dt = arg1 or 0.016
    local moving = not isASTTestMode and UpdateASTMovement(dt)

    if isCastingSpecial then return end

    if not astCycleStartTime then
        if isAutoRepeating then
            if moving then
                astTextLeft:SetText("|cffff5555Moving|r")
            else
                astTextLeft:SetText("Auto Shot (Ready)")
            end
        end
        return
    end

    local now = GetTime()
    local elapsed = now - astCycleStartTime
    local totalInnerW = math.max(0, astFrame:GetWidth() - 6)
    local halfW = totalInnerW / 2

    if isInitialShot then
        if moving then
            astCycleStartTime = now
            elapsed = 0
            astLeftBar:SetWidth(0.1)
            astRightBar:SetWidth(0.1)
            astLeftBar:Hide()
            astRightBar:Hide()
            astTextLeft:SetText("|cffff5555Moving|r")
            astTextRight:SetText("")
            return
        end

        if elapsed >= AIM_DURATION then
            StartReloadCycle("INITIAL_SHOT_FIRED")
            return
        end

        local p = elapsed / AIM_DURATION
        if p < 0 then p = 0 end
        if p > 1 then p = 1 end
        local currentW = math.max(0.1, p * halfW)

        astLeftBar:SetWidth(currentW)
        astRightBar:SetWidth(currentW)
        astLeftBar:Show()
        astRightBar:Show()
        astLeftBar:SetVertexColor(1.0, 0.15, 0.15, 0.95)
        astRightBar:SetVertexColor(1.0, 0.15, 0.15, 0.95)

        astTextLeft:SetText("|cffff3333Shoot|r")
        astTextRight:SetText(string.format("%.1fs", AIM_DURATION - elapsed))
        return
    end

    local reloadDuration = astCycleDuration - AIM_DURATION
    if reloadDuration <= 0 then reloadDuration = 0.001 end

    if elapsed < reloadDuration then
        if astLastPhase ~= "RELOAD" then
            astLastPhase = "RELOAD"
            AST_Log("TIMER", "Phase: RELOAD (Duration=" .. string.format("%.2f", reloadDuration) .. "s)")
        end

        local remainingRatio = 1.0 - (elapsed / reloadDuration)
        if remainingRatio < 0 then remainingRatio = 0 end
        if remainingRatio > 1 then remainingRatio = 1 end

        local currentW = math.max(0.1, remainingRatio * halfW)
        astLeftBar:SetWidth(currentW)
        astRightBar:SetWidth(currentW)

        if remainingRatio > 0.01 then
            astLeftBar:Show()
            astRightBar:Show()
        else
            astLeftBar:Hide()
            astRightBar:Hide()
        end

        local progress = 1.0 - remainingRatio
        local r, g, b
        if progress < 0.5 then
            local k = progress / 0.5
            r = 0.15 + (0.85 * k)
            g = 0.9
            b = 0.2 * (1.0 - k)
        else
            local k = (progress - 0.5) / 0.5
            r = 1.0
            g = 0.9 * (1.0 - k) + 0.3 * k
            b = 0.0
        end

        astLeftBar:SetVertexColor(r, g, b, 0.95)
        astRightBar:SetVertexColor(r, g, b, 0.95)
        astTextLeft:SetText("|cff33ff99Reload|r")
        astTextRight:SetText(string.format("%.1fs", reloadDuration - elapsed))

    else
        if moving then
            astCycleStartTime = now - reloadDuration
            astLeftBar:SetWidth(0.1)
            astRightBar:SetWidth(0.1)
            astLeftBar:Hide()
            astRightBar:Hide()
            astTextLeft:SetText("|cffff5555Moving|r")
            astTextRight:SetText("")
            return
        end

        if elapsed >= astCycleDuration then
            if isAutoRepeating or isASTTestMode then
                AST_Log("TIMER", "Cycle Complete (" .. string.format("%.2f", astCycleDuration) .. "s) -> Looping Next Reload")
                StartReloadCycle("CADENCE_LOOP")
                return
            else
                StopShotCycle("Finished")
                return
            end
        end

        if astLastPhase ~= "AIM" then
            astLastPhase = "AIM"
            AST_Log("TIMER", "Phase: AIM / DRAW (Hold Still! 0.50s)")
        end

        local aimElapsed = elapsed - reloadDuration
        local p = aimElapsed / AIM_DURATION
        if p < 0 then p = 0 end
        if p > 1 then p = 1 end

        local currentW = math.max(0.1, p * halfW)
        astLeftBar:SetWidth(currentW)
        astRightBar:SetWidth(currentW)
        astLeftBar:Show()
        astRightBar:Show()
        astLeftBar:SetVertexColor(1.0, 0.15, 0.15, 0.95)
        astRightBar:SetVertexColor(1.0, 0.15, 0.15, 0.95)

        astTextLeft:SetText("|cffff3333Shoot|r")
        astTextRight:SetText(string.format("%.1fs", AIM_DURATION - aimElapsed))
    end
end)

-- AST Log Viewer Window
local astLogWindow = CreateFrame("Frame", "HunterAIO_ASTLogWindow", UIParent)
astLogWindow:SetWidth(540)
astLogWindow:SetHeight(380)
astLogWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
astLogWindow:SetFrameStrata("DIALOG")
astLogWindow:SetMovable(true)
astLogWindow:EnableMouse(true)
astLogWindow:RegisterForDrag("LeftButton")
astLogWindow:SetScript("OnDragStart", function() this:StartMoving() end)
astLogWindow:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
astLogWindow:Hide()
tinsert(UISpecialFrames, "HunterAIO_ASTLogWindow")

astLogWindow:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})

local astLogTitle = astLogWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
astLogTitle:SetPoint("TOP", astLogWindow, "TOP", 0, -14)
astLogTitle:SetText("HunterAIO: AutoShot Event Log")

local astLogScroll = CreateFrame("ScrollFrame", "HunterAIO_ASTLogScroll", astLogWindow, "UIPanelScrollFrameTemplate")
astLogScroll:SetPoint("TOPLEFT", astLogWindow, "TOPLEFT", 16, -40)
astLogScroll:SetPoint("BOTTOMRIGHT", astLogWindow, "BOTTOMRIGHT", -36, 46)

local astLogEditBox = CreateFrame("EditBox", "HunterAIO_ASTLogEditBox", astLogScroll)
astLogEditBox:SetWidth(470)
astLogEditBox:SetMultiLine(true)
astLogEditBox:SetAutoFocus(false)
astLogEditBox:SetFontObject("GameFontHighlightSmall")
astLogEditBox:SetScript("OnEscapePressed", function() astLogWindow:Hide() end)
astLogScroll:SetScrollChild(astLogEditBox)

local astCloseBtn = CreateFrame("Button", nil, astLogWindow, "UIPanelButtonTemplate")
astCloseBtn:SetWidth(80)
astCloseBtn:SetHeight(22)
astCloseBtn:SetPoint("BOTTOMRIGHT", astLogWindow, "BOTTOMRIGHT", -16, 14)
astCloseBtn:SetText("Close")
astCloseBtn:SetScript("OnClick", function() astLogWindow:Hide() end)

local astClearBtn = CreateFrame("Button", nil, astLogWindow, "UIPanelButtonTemplate")
astClearBtn:SetWidth(80)
astClearBtn:SetHeight(22)
astClearBtn:SetPoint("BOTTOMLEFT", astLogWindow, "BOTTOMLEFT", 16, 14)
clearBtn = astClearBtn
astClearBtn:SetText("Clear")
astClearBtn:SetScript("OnClick", function()
    astLogBuffer = {}
    astLogEditBox:SetText("")
    Print("AST Log buffer cleared.")
end)

local function ShowASTLogWindow()
    local fullText
    if table.getn(astLogBuffer) == 0 then
        if HunterAIODB and HunterAIODB.ast and HunterAIODB.ast.logging then
            fullText = "Logging is currently ENABLED, but no events have occurred yet.\nEngage in combat or Auto Shoot to generate logs."
        else
            fullText = "Logging is currently DISABLED.\n\nType /haio ast log on to begin recording events,\nthen type /haio ast dump to view and copy them here."
        end
    else
        local statusHeader = (HunterAIODB and HunterAIODB.ast and HunterAIODB.ast.logging) and "--- LOGGING ACTIVE ---" or "--- LOGGING INACTIVE ---"
        fullText = statusHeader .. "\n" .. table.concat(astLogBuffer, "\n")
    end
    astLogEditBox:SetText(fullText)
    astLogWindow:Show()
    astLogEditBox:SetFocus()
    astLogEditBox:HighlightText()
end

-- =============================================================
-- MODULE 4: RingMenu
-- =============================================================
local MAX_RING_SLOTS = 12
local currentRing = 1

local TRACKING_SPELLS = {
    "Track Beasts", "Track Humanoids", "Track Undead", "Track Hidden",
    "Track Elementals", "Track Demons", "Track Giants", "Track Dragonkin"
}

local GATHERING_SPELLS = {
    "Find Herbs", "Find Minerals", "Find Treasure", "Sense Undead", "Sense Demons"
}

local ASPECT_SPELLS = {
    "Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Cheetah",
    "Aspect of the Pack", "Aspect of the Wild", "Aspect of the Beast"
}

local ringMainFrame = CreateFrame("Frame", "HunterAIO_RingMainFrame", UIParent)
ringMainFrame:SetWidth(260)
ringMainFrame:SetHeight(260)
ringMainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
ringMainFrame:SetFrameStrata("HIGH")
ringMainFrame:EnableMouse(true)
ringMainFrame:Hide()
tinsert(UISpecialFrames, "HunterAIO_RingMainFrame")

local ringCenterDot = CreateFrame("Button", "HunterAIO_RingCenterDot", ringMainFrame)
ringCenterDot:SetWidth(15)
ringCenterDot:SetHeight(15)
ringCenterDot:SetPoint("CENTER", ringMainFrame, "CENTER", 0, 0)

local ringDotBg = ringCenterDot:CreateTexture(nil, "BACKGROUND")
ringDotBg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
ringDotBg:SetWidth(13)
ringDotBg:SetHeight(13)
ringDotBg:SetPoint("CENTER", ringCenterDot, "CENTER", 0, 0)
ringDotBg:SetVertexColor(0.12, 0.12, 0.12, 0.95)

local ringDotBorder = ringCenterDot:CreateTexture(nil, "OVERLAY")
ringDotBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
ringDotBorder:SetWidth(28)
ringDotBorder:SetHeight(28)
ringDotBorder:SetPoint("CENTER", ringCenterDot, "CENTER", 5, -5)

ringCenterDot:SetScript("OnClick", function()
    HunterAIO_RingMenu_Close()
end)

local ringButtons = {}

for i = 1, MAX_RING_SLOTS do
    local btn = CreateFrame("Button", "HunterAIO_RingBtn" .. i, ringMainFrame)
    btn:SetWidth(32)
    btn:SetHeight(32)
    btn.slotIndex = i

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetWidth(18)
    bg:SetHeight(18)
    bg:SetPoint("CENTER", btn, "CENTER", 0, 0)
    bg:SetVertexColor(0.0, 0.0, 0.0, 0.9)
    btn.bg = bg

    local icon = btn:CreateTexture("HunterAIO_RingBtn" .. i .. "Icon", "BORDER")
    icon:SetWidth(16)
    icon:SetHeight(16)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    icon:SetTexCoord(0.14, 0.86, 0.14, 0.86)
    btn.icon = icon

    local cd = CreateFrame("Model", "HunterAIO_RingBtn" .. i .. "Cooldown", btn, "CooldownFrameTemplate")
    cd:SetWidth(16)
    cd:SetHeight(16)
    cd:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.cooldown = cd

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(50)
    border:SetHeight(50)
    border:SetPoint("CENTER", btn, "CENTER", 10, -10)
    btn.border = border

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    hl:SetWidth(24)
    hl:SetHeight(24)
    hl:SetPoint("CENTER", btn, "CENTER", 0, 0)
    hl:SetBlendMode("ADD")
    btn.highlight = hl

    btn:SetScript("OnMouseDown", function() this.icon:SetPoint("CENTER", this, "CENTER", 1, -1) end)
    btn:SetScript("OnMouseUp", function() this.icon:SetPoint("CENTER", this, "CENTER", 0, 0) end)
    btn:SetScript("OnClick", function() HunterAIO_RingMenu_OnButtonClick(this.slotIndex) end)
    btn:SetScript("OnEnter", function() HunterAIO_RingMenu_OnButtonEnter(this, this.slotIndex) end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ringButtons[i] = btn
end

local function LayoutRingButtons()
    local radius = (HunterAIODB and HunterAIODB.ringmenu and HunterAIODB.ringmenu.settings and HunterAIODB.ringmenu.settings.radius) or 90
    local btnSize = (HunterAIODB and HunterAIODB.ringmenu and HunterAIODB.ringmenu.settings and HunterAIODB.ringmenu.settings.buttonSize) or 45
    local scale = btnSize / 32

    local ringData = HunterAIODB.ringmenu.rings[currentRing]
    if not ringData or not ringData.slots then return end

    local totalButtons = 8
    for idx = 9, MAX_RING_SLOTS do
        if ringData.slots[idx] and ringData.slots[idx].name then
            totalButtons = MAX_RING_SLOTS
            break
        end
    end

    for i = 1, MAX_RING_SLOTS do
        local btn = ringButtons[i]
        btn:SetWidth(btnSize)
        btn:SetHeight(btnSize)
        btn.bg:SetWidth(18 * scale)
        btn.bg:SetHeight(18 * scale)
        btn.icon:SetWidth(16 * scale)
        btn.icon:SetHeight(16 * scale)
        btn.border:SetWidth(50 * scale)
        btn.border:SetHeight(50 * scale)
        btn.border:SetPoint("CENTER", btn, "CENTER", 10 * scale, -10 * scale)
        btn.cooldown:SetWidth(16 * scale)
        btn.cooldown:SetHeight(16 * scale)
        btn.highlight:SetWidth(24 * scale)
        btn.highlight:SetHeight(24 * scale)

        if i <= totalButtons then
            local angle = ((i - 1) / totalButtons) * (2 * math.pi) - (math.pi / 2)
            local x = radius * math.cos(angle)
            local y = -radius * math.sin(angle)
            btn:ClearAllPoints()
            btn:SetPoint("CENTER", ringMainFrame, "CENTER", x, y)
            btn:Show()
        else
            btn:Hide()
        end
    end
end

function HunterAIO_RingMenu_UpdateDisplay()
    if not HunterAIODB or not HunterAIODB.ringmenu or not HunterAIODB.ringmenu.rings then return end
    local ringData = HunterAIODB.ringmenu.rings[currentRing]
    if not ringData then return end

    LayoutRingButtons()

    for i = 1, MAX_RING_SLOTS do
        local btn = ringButtons[i]
        local icon = btn.icon
        local cd = btn.cooldown
        local slot = ringData.slots and ringData.slots[i]

        if slot and slot.name and slot.name ~= "" then
            local spellID = FindSpellInBook(slot.name)
            local tex = slot.icon
            if spellID then
                tex = GetSpellTexture(spellID, BOOKTYPE_SPELL)
                if cd then
                    local start, duration, enable = GetSpellCooldown(spellID, BOOKTYPE_SPELL)
                    CooldownFrame_SetTimer(cd, start, duration, enable)
                end
            elseif cd then
                cd:Hide()
            end
            if icon and tex then
                icon:SetTexture(tex)
                icon:SetTexCoord(0.14, 0.86, 0.14, 0.86)
                icon:Show()
            end
            btn.border:Show()
            btn.bg:Show()
            btn:SetAlpha(1.0)
            btn:Enable()
        else
            if icon then icon:Hide() end
            btn.border:Hide()
            btn.bg:Hide()
            btn:SetAlpha(0.0)
            btn:Disable()
            if cd then cd:Hide() end
        end
    end
end

function HunterAIO_RingMenu_OnButtonClick(slotIndex)
    local ringData = HunterAIODB.ringmenu.rings[currentRing]
    if not ringData then return end
    local slot = ringData.slots and ringData.slots[slotIndex]

    if slot and slot.name then
        if slot.type == "macro" then
            local numGlobal, numChar = GetNumMacros()
            for m = 1, (numGlobal + numChar) do
                local name, _, body = GetMacroInfo(m)
                if name == slot.name and body then
                    CastSpellByName(slot.name)
                    break
                end
            end
        else
            CastSpellByName(slot.name)
        end

        if HunterAIODB.ringmenu.settings.closeOnClick then
            HunterAIO_RingMenu_Close()
        end
    end
end

function HunterAIO_RingMenu_OnButtonEnter(btn, slotIndex)
    local ringData = HunterAIODB.ringmenu.rings[currentRing]
    if not ringData then return end
    local slot = ringData.slots and ringData.slots[slotIndex]

    if slot and slot.name then
        local spellID = FindSpellInBook(slot.name)
        if spellID then
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetSpell(spellID, BOOKTYPE_SPELL)
            GameTooltip:Show()
        else
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText(slot.name, 1, 1, 1)
            GameTooltip:Show()
        end
    end
end

function HunterAIO_RingMenu_Open(ringIndex)
    currentRing = ringIndex or 1
    if not HunterAIODB.ringmenu.rings[currentRing] then
        HunterAIODB.ringmenu.rings[currentRing] = { name = "Ring " .. currentRing, slots = {} }
    end

    if HunterAIODB.ringmenu.settings.openAtCursor then
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        ringMainFrame:ClearAllPoints()
        ringMainFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    else
        ringMainFrame:ClearAllPoints()
        ringMainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    HunterAIO_RingMenu_UpdateDisplay()
    ringMainFrame:Show()
    PlaySound("igSpellBookOpen")
end

function HunterAIO_RingMenu_Close()
    ringMainFrame:Hide()
    GameTooltip:Hide()
    PlaySound("igSpellBookClose")
end

function HunterAIO_RingMenu_Toggle(ringIndex)
    if ringMainFrame:IsVisible() and currentRing == (ringIndex or 1) then
        HunterAIO_RingMenu_Close()
    else
        HunterAIO_RingMenu_Open(ringIndex)
    end
end

function HunterAIO_RingMenu_OnKeyUp(ringIndex)
    if HunterAIODB.ringmenu.settings.holdToOpen and ringMainFrame:IsVisible() and currentRing == ringIndex then
        HunterAIO_RingMenu_Close()
    end
end

-- Global Aliases for Standalone Compatibility
RingMenu_Open = HunterAIO_RingMenu_Open
RingMenu_Close = HunterAIO_RingMenu_Close
RingMenu_Toggle = HunterAIO_RingMenu_Toggle
RingMenu_OnKeyUp = HunterAIO_RingMenu_OnKeyUp

function HunterAIO_PopulateSpells(ringIndex, spellList, ringName)
    if not HunterAIODB.ringmenu.rings[ringIndex] then
        HunterAIODB.ringmenu.rings[ringIndex] = { name = ringName, slots = {} }
    end
    HunterAIODB.ringmenu.rings[ringIndex].name = ringName
    HunterAIODB.ringmenu.rings[ringIndex].slots = {}

    local slot = 1
    for _, spellName in ipairs(spellList) do
        local id = FindSpellInBook(spellName)
        if id and slot <= MAX_RING_SLOTS then
            local icon = GetSpellTexture(id, BOOKTYPE_SPELL)
            HunterAIODB.ringmenu.rings[ringIndex].slots[slot] = {
                type = "spell",
                name = spellName,
                icon = icon or "Interface\\Icons\\Ability_Tracking"
            }
            slot = slot + 1
        end
    end
    Print("Populated |cffffd100" .. ringName .. "|r with " .. (slot - 1) .. " known spells.")
    HunterAIO_RingMenu_UpdateDisplay()
end

-- =============================================================
-- MODULE 5: Graphical Configuration Panel
-- =============================================================
local cfgFrame = CreateFrame("Frame", "HunterAIO_ConfigFrame", UIParent)
cfgFrame:SetWidth(560)
cfgFrame:SetHeight(460)
cfgFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
cfgFrame:SetFrameStrata("DIALOG")
cfgFrame:SetMovable(true)
cfgFrame:EnableMouse(true)
cfgFrame:RegisterForDrag("LeftButton")
cfgFrame:SetScript("OnDragStart", function() this:StartMoving() end)
cfgFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
cfgFrame:Hide()
tinsert(UISpecialFrames, "HunterAIO_ConfigFrame")

cfgFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})

local cfgTitle = cfgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
cfgTitle:SetPoint("TOP", cfgFrame, "TOP", 0, -14)
cfgTitle:SetText("HunterAIO Control Panel")

local cfgCloseBtn = CreateFrame("Button", nil, cfgFrame, "UIPanelCloseButton")
cfgCloseBtn:SetPoint("TOPRIGHT", cfgFrame, "TOPRIGHT", -8, -8)

local activeTab = 1
local tabPanels = {}
local tabButtons = {}

local TAB_NAMES = { "PetCare", "SmartTrap", "AutoShot", "RingMenu" }

for t = 1, 4 do
    local panel = CreateFrame("Frame", "HunterAIO_TabPanel" .. t, cfgFrame)
    panel:SetPoint("TOPLEFT", cfgFrame, "TOPLEFT", 20, -70)
    panel:SetPoint("BOTTOMRIGHT", cfgFrame, "BOTTOMRIGHT", -20, 20)
    panel:Hide()
    tabPanels[t] = panel

    local tbtn = CreateFrame("Button", "HunterAIO_TabBtn" .. t, cfgFrame, "UIPanelButtonTemplate")
    tbtn:SetWidth(110)
    tbtn:SetHeight(24)
    tbtn:SetPoint("TOPLEFT", cfgFrame, "TOPLEFT", 20 + (t - 1) * 120, -40)
    tbtn:SetText(TAB_NAMES[t])
    tbtn.tabIndex = t
    tbtn:SetScript("OnClick", function()
        HunterAIO_SelectTab(this.tabIndex)
    end)
    tabButtons[t] = tbtn
end

function HunterAIO_SelectTab(tabIndex)
    activeTab = tabIndex
    for t = 1, 4 do
        if t == tabIndex then
            tabPanels[t]:Show()
            tabButtons[t]:LockHighlight()
        else
            tabPanels[t]:Hide()
            tabButtons[t]:UnlockHighlight()
        end
    end
end

-- TAB 1: PetCare Controls
local p1 = tabPanels[1]
local p1Title = p1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
p1Title:SetPoint("TOPLEFT", p1, "TOPLEFT", 10, -10)
p1Title:SetText("PetCare: Smart Hunter Pet Maintenance")

local p1Desc = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
p1Desc:SetPoint("TOPLEFT", p1, "TOPLEFT", 10, -30)
p1Desc:SetText("1-Button Pet Management: Revives if dead, Calls if missing, Mends in combat,\nFeeds if unhappy (prevents food waste), and Dismisses if happy out of combat.")

local p1SlotLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
p1SlotLabel:SetPoint("TOPLEFT", p1, "TOPLEFT", 10, -80)
p1SlotLabel:SetText("Food Bag (0=Backpack, 1=Bag 1, 2, 3, 4):")

local p1BagEdit = CreateFrame("EditBox", "HunterAIO_PetBagEdit", p1, "InputBoxTemplate")
p1BagEdit:SetWidth(40)
p1BagEdit:SetHeight(20)
p1BagEdit:SetPoint("LEFT", p1SlotLabel, "RIGHT", 10, 0)
p1BagEdit:SetAutoFocus(false)
p1BagEdit:SetNumeric(true)
p1BagEdit:SetMaxLetters(1)

local p1SlotNumLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
p1SlotNumLabel:SetPoint("LEFT", p1BagEdit, "RIGHT", 20, 0)
p1SlotNumLabel:SetText("Slot (1-20):")

local p1SlotEdit = CreateFrame("EditBox", "HunterAIO_PetSlotEdit", p1, "InputBoxTemplate")
p1SlotEdit:SetWidth(40)
p1SlotEdit:SetHeight(20)
p1SlotEdit:SetPoint("LEFT", p1SlotNumLabel, "RIGHT", 10, 0)
p1SlotEdit:SetAutoFocus(false)
p1SlotEdit:SetNumeric(true)
p1SlotEdit:SetMaxLetters(2)

local p1FoodStatus = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
p1FoodStatus:SetPoint("TOPLEFT", p1, "TOPLEFT", 10, -120)
p1FoodStatus:SetText("Item in slot: ...")

local p1SaveBtn = CreateFrame("Button", nil, p1, "UIPanelButtonTemplate")
p1SaveBtn:SetWidth(120)
p1SaveBtn:SetHeight(24)
p1SaveBtn:SetPoint("TOPLEFT", p1, "TOPLEFT", 10, -160)
p1SaveBtn:SetText("Save Food Slot")
p1SaveBtn:SetScript("OnClick", function()
    local b = tonumber(p1BagEdit:GetText()) or 0
    local s = tonumber(p1SlotEdit:GetText()) or 1
    if b >= 0 and b <= 4 and s >= 1 and s <= 36 then
        HunterAIODB.petcare.bag = b
        HunterAIODB.petcare.slot = s
        local item = GetSlotItemDescription(b, s)
        p1FoodStatus:SetText("Item in slot: " .. item)
        Print("PetCare food slot saved to Bag " .. b .. ", Slot " .. s .. " (" .. item .. ")")
    else
        Print("Invalid bag (0-4) or slot (1-36).")
    end
end)

local p1TestBtn = CreateFrame("Button", nil, p1, "UIPanelButtonTemplate")
p1TestBtn:SetWidth(120)
p1TestBtn:SetHeight(24)
p1TestBtn:SetPoint("LEFT", p1SaveBtn, "RIGHT", 20, 0)
p1TestBtn:SetText("Run /petcare")
p1TestBtn:SetScript("OnClick", function()
    PetCare()
end)

-- TAB 2: SmartTrap Controls
local p2 = tabPanels[2]
local p2Title = p2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
p2Title:SetPoint("TOPLEFT", p2, "TOPLEFT", 10, -10)
p2Title:SetText("SmartTrap: In-Combat Feign Death + Trap Automation")

local p2Desc = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
p2Desc:SetPoint("TOPLEFT", p2, "TOPLEFT", 10, -35)
p2Desc:SetText("Automatically checks Feign Death readiness in combat, sets pet to passive\nand disengages pet to drop combat, casts Feign Death, and lays your trap.\nStandard Action Bar macro buttons will automatically show real cooldowns!")

local p2MacroTitle = p2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
p2MacroTitle:SetPoint("TOPLEFT", p2, "TOPLEFT", 10, -95)
p2MacroTitle:SetText("Macro Commands (Place on Action Bars with '?' Icon):")

local p2Macros = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
p2Macros:SetPoint("TOPLEFT", p2, "TOPLEFT", 20, -120)
p2Macros:SetText("/smarttrap freezing  - (or /haio trap freezing)\n/smarttrap frost     - (or /haio trap frost)\n/smarttrap immolation\n/smarttrap explosive")

local p2KeybindNote = p2:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
p2KeybindNote:SetPoint("TOPLEFT", p2, "TOPLEFT", 10, -200)
p2KeybindNote:SetText("Tip: You can also bind keys directly to traps under Game Menu -> Key Bindings -> HunterAIO.")

-- TAB 3: AutoShotTimer Controls
local p3 = tabPanels[3]
local p3Title = p3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
p3Title:SetPoint("TOPLEFT", p3, "TOPLEFT", 10, -10)
p3Title:SetText("AutoShotTimer: Ranged Weapon Swing & Stutter-Step Bar")

local p3WidthLabel = p3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
p3WidthLabel:SetPoint("TOPLEFT", p3, "TOPLEFT", 10, -40)
p3WidthLabel:SetText("Width (px):")

local p3WidthEdit = CreateFrame("EditBox", "HunterAIO_ASTWidthEdit", p3, "InputBoxTemplate")
p3WidthEdit:SetWidth(50)
p3WidthEdit:SetHeight(20)
p3WidthEdit:SetPoint("LEFT", p3WidthLabel, "RIGHT", 10, 0)
p3WidthEdit:SetAutoFocus(false)
p3WidthEdit:SetNumeric(true)

local p3HeightLabel = p3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
p3HeightLabel:SetPoint("LEFT", p3WidthEdit, "RIGHT", 20, 0)
p3HeightLabel:SetText("Height (px):")

local p3HeightEdit = CreateFrame("EditBox", "HunterAIO_ASTHeightEdit", p3, "InputBoxTemplate")
p3HeightEdit:SetWidth(40)
p3HeightEdit:SetHeight(20)
p3HeightEdit:SetPoint("LEFT", p3HeightLabel, "RIGHT", 10, 0)
p3HeightEdit:SetAutoFocus(false)
p3HeightEdit:SetNumeric(true)

local p3ApplyBtn = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
p3ApplyBtn:SetWidth(100)
p3ApplyBtn:SetHeight(22)
p3ApplyBtn:SetPoint("LEFT", p3HeightEdit, "RIGHT", 20, 0)
p3ApplyBtn:SetText("Apply Size")
p3ApplyBtn:SetScript("OnClick", function()
    local w = tonumber(p3WidthEdit:GetText()) or 200
    local h = tonumber(p3HeightEdit:GetText()) or 16
    HunterAIODB.ast.width = w
    HunterAIODB.ast.height = h
    UpdateASTDimensions()
    Print("AST dimensions set to " .. w .. "x" .. h .. "px.")
end)

local p3TestBtn = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
p3TestBtn:SetWidth(140)
p3TestBtn:SetHeight(24)
p3TestBtn:SetPoint("TOPLEFT", p3, "TOPLEFT", 10, -80)
p3TestBtn:SetText("Toggle Test Preview")
p3TestBtn:SetScript("OnClick", function()
    isASTTestMode = not isASTTestMode
    if isASTTestMode then
        astFrame:SetAlpha(1.0)
        astFrame:Show()
        StartReloadCycle("TEST_PREVIEW")
    else
        StopShotCycle("TEST_PREVIEW_OFF")
    end
end)

local p3LockBtn = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
p3LockBtn:SetWidth(140)
p3LockBtn:SetHeight(24)
p3LockBtn:SetPoint("LEFT", p3TestBtn, "RIGHT", 15, 0)
p3LockBtn:SetText("Toggle Lock Position")
p3LockBtn:SetScript("OnClick", function()
    HunterAIODB.ast.locked = not HunterAIODB.ast.locked
    Print("Bar position " .. (HunterAIODB.ast.locked and "Locked" or "Unlocked (Drag to move)"))
end)

local p3ResetBtn = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
p3ResetBtn:SetWidth(120)
p3ResetBtn:SetHeight(24)
p3ResetBtn:SetPoint("LEFT", p3LockBtn, "RIGHT", 15, 0)
p3ResetBtn:SetText("Reset Position")
p3ResetBtn:SetScript("OnClick", function()
    astFrame:ClearAllPoints()
    astFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
    HunterAIODB.ast.point = "CENTER"
    HunterAIODB.ast.relPoint = "CENTER"
    HunterAIODB.ast.x = 0
    HunterAIODB.ast.y = -160
    Print("AST position reset to center.")
end)

local p3LogToggleBtn = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
p3LogToggleBtn:SetWidth(140)
p3LogToggleBtn:SetHeight(24)
p3LogToggleBtn:SetPoint("TOPLEFT", p3, "TOPLEFT", 10, -120)
p3LogToggleBtn:SetText("Toggle Event Log")
p3LogToggleBtn:SetScript("OnClick", function()
    HunterAIODB.ast.logging = not HunterAIODB.ast.logging
    Print("Event logging " .. (HunterAIODB.ast.logging and "Enabled" or "Disabled (0 overhead)"))
end)

local p3ViewLogBtn = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
p3ViewLogBtn:SetWidth(140)
p3ViewLogBtn:SetHeight(24)
p3ViewLogBtn:SetPoint("LEFT", p3LogToggleBtn, "RIGHT", 15, 0)
p3ViewLogBtn:SetText("View Log Window")
p3ViewLogBtn:SetScript("OnClick", function()
    ShowASTLogWindow()
end)

-- TAB 4: RingMenu Controls
local p4 = tabPanels[4]
local p4Title = p4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
p4Title:SetPoint("TOPLEFT", p4, "TOPLEFT", 10, -10)
p4Title:SetText("RingMenu: Circular Popup Action Bars")

local p4KeyInfo = p4:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
p4KeyInfo:SetPoint("TOPLEFT", p4, "TOPLEFT", 10, -35)
p4KeyInfo:SetText("Default Keybind: |cffffd100CTRL-D|r opens Ring 1 (Hunter Tracking).\nChange keybind anytime: |cffffd100/ringmenu bind <key>|r or in Key Bindings.")

local p4PopTrackBtn = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
p4PopTrackBtn:SetWidth(150)
p4PopTrackBtn:SetHeight(24)
p4PopTrackBtn:SetPoint("TOPLEFT", p4, "TOPLEFT", 10, -75)
p4PopTrackBtn:SetText("Populate Tracking (R1)")
p4PopTrackBtn:SetScript("OnClick", function()
    HunterAIO_PopulateSpells(1, TRACKING_SPELLS, "Hunter Tracking")
end)

local p4PopGatherBtn = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
p4PopGatherBtn:SetWidth(150)
p4PopGatherBtn:SetHeight(24)
p4PopGatherBtn:SetPoint("LEFT", p4PopTrackBtn, "RIGHT", 10, 0)
p4PopGatherBtn:SetText("Populate Gathering (R2)")
p4PopGatherBtn:SetScript("OnClick", function()
    HunterAIO_PopulateSpells(2, GATHERING_SPELLS, "Gathering")
end)

local p4PopAspectBtn = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
p4PopAspectBtn:SetWidth(150)
p4PopAspectBtn:SetHeight(24)
p4PopAspectBtn:SetPoint("LEFT", p4PopGatherBtn, "RIGHT", 10, 0)
p4PopAspectBtn:SetText("Populate Aspects (R3)")
p4PopAspectBtn:SetScript("OnClick", function()
    HunterAIO_PopulateSpells(3, ASPECT_SPELLS, "Aspects")
end)

local p4OpenR1 = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
p4OpenR1:SetWidth(110)
p4OpenR1:SetHeight(24)
p4OpenR1:SetPoint("TOPLEFT", p4, "TOPLEFT", 10, -115)
p4OpenR1:SetText("Open Ring 1")
p4OpenR1:SetScript("OnClick", function() HunterAIO_RingMenu_Toggle(1) end)

local p4OpenR2 = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
p4OpenR2:SetWidth(110)
p4OpenR2:SetHeight(24)
p4OpenR2:SetPoint("LEFT", p4OpenR1, "RIGHT", 10, 0)
p4OpenR2:SetText("Open Ring 2")
p4OpenR2:SetScript("OnClick", function() HunterAIO_RingMenu_Toggle(2) end)

local p4OpenR3 = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
p4OpenR3:SetWidth(110)
p4OpenR3:SetHeight(24)
p4OpenR3:SetPoint("LEFT", p4OpenR2, "RIGHT", 10, 0)
p4OpenR3:SetText("Open Ring 3")
p4OpenR3:SetScript("OnClick", function() HunterAIO_RingMenu_Toggle(3) end)

function HunterAIO_OpenConfig()
    if not HunterAIODB then return end
    p1BagEdit:SetText(tostring(HunterAIODB.petcare.bag or 0))
    p1SlotEdit:SetText(tostring(HunterAIODB.petcare.slot or 1))
    p1FoodStatus:SetText("Item in slot: " .. GetSlotItemDescription(HunterAIODB.petcare.bag or 0, HunterAIODB.petcare.slot or 1))

    p3WidthEdit:SetText(tostring(HunterAIODB.ast.width or 200))
    p3HeightEdit:SetText(tostring(HunterAIODB.ast.height or 16))

    HunterAIO_SelectTab(activeTab or 1)
    cfgFrame:Show()
end

-- =============================================================
-- Global Event Router & Initialization
-- =============================================================
local aioEventFrame = CreateFrame("Frame")
aioEventFrame:RegisterEvent("VARIABLES_LOADED")
aioEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
aioEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
aioEventFrame:RegisterEvent("START_AUTOREPEAT_SPELL")
aioEventFrame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
aioEventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
aioEventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
aioEventFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
aioEventFrame:RegisterEvent("SPELLCAST_START")
aioEventFrame:RegisterEvent("SPELLCAST_STOP")
aioEventFrame:RegisterEvent("SPELLCAST_INTERRUPTED")
aioEventFrame:RegisterEvent("PLAYER_LEAVE_COMBAT")
aioEventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
aioEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
aioEventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
aioEventFrame:RegisterEvent("SPELLS_CHANGED")
aioEventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
aioEventFrame:RegisterEvent("UI_ERROR_MESSAGE")

aioEventFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if not HunterAIODB then
            HunterAIODB = {
                petcare = { bag = 0, slot = 1 },
                ast = {
                    locked = false,
                    logging = false,
                    debug = false,
                    width = 200,
                    height = 16,
                    scale = 1.0,
                    point = "CENTER",
                    relPoint = "CENTER",
                    x = 0,
                    y = -160
                },
                ringmenu = {
                    settings = {
                        radius = 90,
                        buttonSize = 45,
                        closeOnClick = true,
                        openAtCursor = true,
                        holdToOpen = false,
                    },
                    rings = {
                        [1] = { name = "Hunter Tracking", slots = {} },
                        [2] = { name = "Professions & Gathering", slots = {} },
                        [3] = { name = "Aspects & Utility", slots = {} }
                    }
                }
            }

            local _, playerClass = UnitClass("player")
            if playerClass == "HUNTER" then
                HunterAIO_PopulateSpells(1, TRACKING_SPELLS, "Hunter Tracking")
                HunterAIO_PopulateSpells(2, GATHERING_SPELLS, "Gathering")
                HunterAIO_PopulateSpells(3, ASPECT_SPELLS, "Aspects")
            end
        end

        if not HunterAIODB.ringmenu.settings.buttonSize or HunterAIODB.ringmenu.settings.buttonSize == 32 or HunterAIODB.ringmenu.settings.buttonSize == 36 then
            HunterAIODB.ringmenu.settings.buttonSize = 45
        end
        if not HunterAIODB.ringmenu.settings.radius or HunterAIODB.ringmenu.settings.radius == 85 then
            HunterAIODB.ringmenu.settings.radius = 90
        end

        UpdateASTDimensions()
        astFrame:ClearAllPoints()
        astFrame:SetPoint(HunterAIODB.ast.point or "CENTER", UIParent, HunterAIODB.ast.relPoint or "CENTER", HunterAIODB.ast.x or 0, HunterAIODB.ast.y or -160)
        astFrame:SetAlpha(0.0)
        SetMapToCurrentZone()

    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        SetMapToCurrentZone()

    elseif event == "START_AUTOREPEAT_SPELL" then
        AST_Log("EVENT", "START_AUTOREPEAT_SPELL")
        isAutoRepeating = true
        if not astCycleStartTime then
            StartInitialShot("START_AUTOREPEAT")
        end

    elseif event == "STOP_AUTOREPEAT_SPELL" then
        AST_Log("EVENT", "STOP_AUTOREPEAT_SPELL")
        isAutoRepeating = false
        StopShotCycle("STOP_AUTOREPEAT")

    elseif event == "ITEM_LOCK_CHANGED" then
        AST_Log("EVENT", "ITEM_LOCK_CHANGED (Ammo Consumed / Shot Fired)")
        if isAutoRepeating and not isInitialShot then
            local now = GetTime()
            if astCycleStartTime then
                local elapsed = now - astCycleStartTime
                if elapsed >= (astCycleDuration - 0.4) and elapsed <= (astCycleDuration + 0.4) then
                    StartReloadCycle("ITEM_LOCK_SYNC")
                end
            end
        end

    elseif event == "UNIT_INVENTORY_CHANGED" then
        local spd = GetRangedWeaponSpeed()
        AST_Log("EVENT", "UNIT_INVENTORY_CHANGED (WeaponSpeed=" .. string.format("%.2f", spd) .. "s)")

    elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        AST_Log("EVENT", "CHAT_MSG_SPELL_SELF_DAMAGE: " .. (arg1 or ""))
        if arg1 and string.find(arg1, "Auto Shot") then
            if not astCycleStartTime and isAutoRepeating then
                StartReloadCycle("SELF_DAMAGE_SYNC")
            end
        end

    elseif event == "SPELLCAST_START" then
        AST_Log("EVENT", "SPELLCAST_START: " .. (arg1 or "") .. " (" .. (arg2 or 0) .. "ms)")
        if arg1 and string.find(arg1, "Aimed Shot") then
            isCastingSpecial = true
            astFrame:SetAlpha(0.0)
        end

    elseif event == "SPELLCAST_STOP" or event == "SPELLCAST_INTERRUPTED" then
        if isCastingSpecial then
            isCastingSpecial = false
            if isAutoRepeating then
                StartReloadCycle("SPECIAL_FINISH")
            end
        end

    elseif event == "PLAYER_LEAVE_COMBAT" then
        if not isAutoRepeating then
            StopShotCycle("LEAVE_COMBAT")
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        isAutoRepeating = false
        StopShotCycle("LEFT_COMBAT")

    elseif event == "PLAYER_TARGET_CHANGED" then
        if not UnitExists("target") or UnitIsDead("target") then
            if not isAutoRepeating then
                StopShotCycle("TARGET_DEAD_OR_CLEARED")
            end
        end

    elseif event == "SPELLS_CHANGED" or event == "SPELL_UPDATE_COOLDOWN" then
        if ringMainFrame:IsVisible() then
            HunterAIO_RingMenu_UpdateDisplay()
        end

    elseif event == "UI_ERROR_MESSAGE" then
        AST_Log("EVENT", "UI_ERROR_MESSAGE: " .. (arg1 or ""))
        if arg1 and (string.find(arg1, "moving") or string.find(arg1, "Moving")) then
            isPlayerMoving = true
        end
    end
end)

-- =============================================================
-- Slash Command Handlers & Aliases
-- =============================================================
local function ShowGlobalHelp()
    Print("HunterAIO Commands:")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/haio|r - Open GUI Control Panel")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/haio pet|r (or |cffffd100/petcare|r) - Run Smart PetCare")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/haio trap <name>|r (or |cffffd100/smarttrap <name>|r) - Run SmartTrap")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/haio ring <1-3>|r (or |cffffd100/ringmenu|r) - Open RingMenu")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100/haio ast ...|r (or |cffffd100/ast ...|r) - AutoShotTimer options")
end

SLASH_HUNTERAIO1 = "/haio"
SLASH_HUNTERAIO2 = "/hunteraio"
SlashCmdList["HUNTERAIO"] = function(msg)
    msg = msg and string.gsub(msg, "^%s*(.-)%s*$", "%1") or ""
    local lower = string.lower(msg)

    if lower == "" or lower == "gui" or lower == "menu" or lower == "config" then
        HunterAIO_OpenConfig()
        return
    end

    if lower == "help" or lower == "?" then
        ShowGlobalHelp()
        return
    end

    if lower == "pet" or lower == "petcare" then
        PetCare()
        return
    end

    local _, _, trCmd = string.find(lower, "^trap%s+(.+)$")
    if trCmd then
        SmartTrap(trCmd)
        return
    end

    local _, _, rCmd = string.find(lower, "^ring%s*(%d*)$")
    if rCmd then
        HunterAIO_RingMenu_Toggle(tonumber(rCmd) or 1)
        return
    end

    ShowGlobalHelp()
end

-- Backward Compatibility Aliases for Macros
SLASH_PETCARE1 = "/petcare"
SlashCmdList["PETCARE"] = function(msg)
    PetCare()
end

SLASH_SMARTTRAP1 = "/smarttrap"
SLASH_SMARTTRAP2 = "/strap"
SlashCmdList["SMARTTRAP"] = function(msg)
    SmartTrap(msg)
end

SLASH_RINGMENU1 = "/ringmenu"
SLASH_RINGMENU2 = "/radial"
SlashCmdList["RINGMENU"] = function(msg)
    msg = msg and string.gsub(msg, "^%s*(.-)%s*$", "%1") or ""
    local _, _, r = string.find(string.lower(msg), "^open%s*(%d*)$")
    if r then
        HunterAIO_RingMenu_Toggle(tonumber(r) or 1)
    else
        HunterAIO_RingMenu_Toggle(1)
    end
end

SLASH_AST1 = "/ast"
SLASH_AST2 = "/autoshot"
SlashCmdList["AST"] = function(msg)
    msg = msg and string.gsub(msg, "^%s*(.-)%s*$", "%1") or ""
    local lower = string.lower(msg)
    if lower == "test" then
        isASTTestMode = not isASTTestMode
        if isASTTestMode then
            astFrame:SetAlpha(1.0)
            astFrame:Show()
            StartReloadCycle("TEST_PREVIEW")
        else
            StopShotCycle("TEST_PREVIEW_OFF")
        end
    elseif lower == "dump" or lower == "log show" then
        ShowASTLogWindow()
    elseif lower == "log on" then
        HunterAIODB.ast.logging = true
        Print("AST logging enabled.")
    elseif lower == "log off" then
        HunterAIODB.ast.logging = false
        Print("AST logging disabled.")
    else
        HunterAIO_OpenConfig()
        HunterAIO_SelectTab(3)
    end
end
