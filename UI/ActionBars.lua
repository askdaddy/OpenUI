-- 动作条 T1（#11）：主条（12 安全按钮 + 安全分页 1–6）+ 宠物条（10 安全按钮）。
-- 动作执行由 SecureActionButtonTemplate 属性驱动（保留原操作能力）；
-- 原生主条/宠物条隐藏仅在脱战应用（战斗中经 #6 PLAYER_REGEN_ENABLED 延后）。
-- 多动作条/姿态/载具/额外动作保持原生（T1 分期），OnDisable 全部恢复原生。

local _, ns = ...
local OpenUI = ns.OpenUI
local Theme = OpenUI.Theme

local MAIN_SLOTS = 12
local PET_SLOTS = 10
local BUTTON_SIZE = 36
local BUTTON_GAP = 2

local ActionBars = {}
local mainBar, petBar, nativeHider
local mainButtons, petButtons = {}, {}
local built = false
local eventsRegistered = false
local pendingNativeHide = false

local NATIVE_BARS = { "MainMenuBar", "PetActionBar" }

local PAGE_DRIVER = "[bonusbar:5] 6; [bonusbar:4] 5; [bonusbar:3] 4; [bonusbar:2] 3; "
    .. "[bonusbar:1] 2; [bar:1] 1; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; 1"

-- 安全环境片段：按页把 12 个子按钮的 action 属性指向 (page-1)*12+i（战斗中同样生效）。
local PAGE_SNIPPET = [[
    local page = tonumber(newstate) or 1
    for i = 1, 12 do
        local button = self:GetFrameRef("button" .. i)
        if button then
            button:SetAttribute("action", (page - 1) * 12 + i)
        end
    end
]]

local function skinButton(button)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(button)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    local count = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.openuiBg, button.openuiIcon, button.openuiCount = bg, icon, count
end

local function paintButtonBg(button)
    local bg = Theme.Get("color.surface-container-high")
    if type(bg) == "table" then
        button.openuiBg:SetColorTexture(bg[1], bg[2], bg[3], 1)
    end
end

local function refreshActionButton(button, slot)
    paintButtonBg(button)
    local texture
    if type(GetActionTexture) == "function" then texture = GetActionTexture(slot) end
    button.openuiIcon:SetTexture(texture)
    local count = 0
    if type(GetActionCount) == "function" then count = GetActionCount(slot) or 0 end
    button.openuiCount:SetText(count > 1 and tostring(count) or "")
end

local function refreshPetButton(button, slot)
    paintButtonBg(button)
    local texture, count
    if type(GetPetActionInfo) == "function" then
        local name, _, tex = GetPetActionInfo(slot)
        texture = tex
        if type(name) == "string" and type(_G[name]) == "number" then
            count = _G[name]
        end
    end
    button.openuiIcon:SetTexture(texture)
    button.openuiCount:SetText((type(count) == "number" and count > 1) and tostring(count) or "")
end

local function refreshMainIcons()
    if #mainButtons == 0 then return end
    local page = 1
    if type(GetActionBarPage) == "function" then page = GetActionBarPage() or 1 end
    for i = 1, MAIN_SLOTS do
        refreshActionButton(mainButtons[i], (page - 1) * MAIN_SLOTS + i)
    end
end

local function refreshPetIcons()
    for i = 1, PET_SLOTS do
        if petButtons[i] then refreshPetButton(petButtons[i], i) end
    end
end

local function refreshAll()
    refreshMainIcons()
    refreshPetIcons()
end

local function buildMainBar()
    mainBar = CreateFrame("Frame", "OpenUIActionBar", UIParent, "SecureHandlerStateTemplate")
    mainBar:SetSize(MAIN_SLOTS * (BUTTON_SIZE + BUTTON_GAP), BUTTON_SIZE)
    mainBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 24)
    for i = 1, MAIN_SLOTS do
        local button = CreateFrame("Button", nil, mainBar, "SecureActionButtonTemplate")
        button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        button:SetPoint("LEFT", mainBar, "LEFT", (i - 1) * (BUTTON_SIZE + BUTTON_GAP), 0)
        button:RegisterForClicks("AnyUp")
        button:SetAttribute("type", "action")
        button:SetAttribute("action", i)
        skinButton(button)
        mainBar:SetFrameRef("button" .. i, button)
        mainButtons[i] = button
    end
    mainBar:SetAttribute("_onstate-page", PAGE_SNIPPET)
    if type(RegisterStateDriver) == "function" then
        RegisterStateDriver(mainBar, "page", PAGE_DRIVER)
    end
end

local function buildPetBar()
    petBar = CreateFrame("Frame", "OpenUIPetBar", UIParent)
    petBar:SetSize(PET_SLOTS * (BUTTON_SIZE + BUTTON_GAP), BUTTON_SIZE)
    petBar:SetPoint("BOTTOM", mainBar, "TOP", 0, BUTTON_GAP * 3)
    for i = 1, PET_SLOTS do
        local button = CreateFrame("Button", nil, petBar, "SecureActionButtonTemplate")
        button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        button:SetPoint("LEFT", petBar, "LEFT", (i - 1) * (BUTTON_SIZE + BUTTON_GAP), 0)
        button:RegisterForClicks("AnyUp")
        button:SetAttribute("type", "pet")
        button:SetAttribute("action", i)
        skinButton(button)
        petButtons[i] = button
    end
end

local function build()
    if built then return end
    built = true
    buildMainBar()
    buildPetBar()
end

local function hideNative()
    if not nativeHider then
        nativeHider = CreateFrame("Frame", "OpenUINativeHider", UIParent)
        nativeHider:Hide()
    end
    if not OpenUI:CanModifyNow() then
        pendingNativeHide = true -- 战斗中登记，脱战应用
        return
    end
    pendingNativeHide = false
    for _, name in ipairs(NATIVE_BARS) do
        local bar = _G[name]
        if bar then
            bar.openuiOriginalParent = bar.openuiOriginalParent or bar:GetParent()
            bar:SetParent(nativeHider)
            if bar.Hide then bar:Hide() end
        end
    end
end

local function restoreNative()
    for _, name in ipairs(NATIVE_BARS) do
        local bar = _G[name]
        if bar then
            bar:SetParent(bar.openuiOriginalParent or UIParent)
            bar.openuiOriginalParent = nil
            if bar.Show then bar:Show() end
        end
    end
end

local function registerEvents()
    if eventsRegistered then return end
    eventsRegistered = true
    local own = OpenUI.Own("ActionBars")
    own:On("PLAYER_ENTERING_WORLD", refreshAll)
    own:On("ACTIONBAR_SLOT_CHANGED", refreshAll)
    own:On("ACTIONBAR_UPDATE_STATE", refreshMainIcons)
    own:On("ACTIONBAR_PAGE_CHANGED", refreshMainIcons)
    own:On("PET_BAR_UPDATE", refreshPetIcons)
    own:On("PLAYER_REGEN_ENABLED", function()
        if pendingNativeHide then hideNative() end
    end)
end

function ActionBars.OnEnable()
    build()
    registerEvents()
    if mainBar then mainBar:Show() end
    if petBar then petBar:Show() end
    refreshAll()
    hideNative()
end

function ActionBars.OnDisable()
    eventsRegistered = false -- #6 Release 已移除名下事件；重建时重新登记
    pendingNativeHide = false
    if mainBar then mainBar:Hide() end
    if petBar then petBar:Hide() end
    restoreNative()
end

-- 导出给测试/诊断（只读用途）
ActionBars.MainBar = function() return mainBar end
ActionBars.PetBar = function() return petBar end
ActionBars.MainButtons = function() return mainButtons end
ActionBars.PetButtons = function() return petButtons end
ActionBars.PageDriver = PAGE_DRIVER

OpenUI.ActionBars = ActionBars

OpenUI:RegisterModule("ActionBars", {
    OnEnable = function()
        ActionBars.OnEnable()
    end,
    OnDisable = function()
        ActionBars.OnDisable()
    end,
})