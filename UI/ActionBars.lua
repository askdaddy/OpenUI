-- 动作条 T1/T2（#11/#47）：主条（安全分页 1–6）+ bar2–bar6（固定槽 13–72）+ 宠物条。
-- 动作执行由 SecureActionButtonTemplate 属性驱动；原生条隐藏仅脱战应用（#6 意图队列）。
-- 每条独立显示开关与位置（Alt+左键或条体拖拽，脱战；持久化到生效配置档）。
-- OnDisable 全部恢复原生。

local _, ns = ...
local OpenUI = ns.OpenUI
local Theme = OpenUI.Theme

local SLOTS_PER_BAR = 12
local PET_SLOTS = 10
local BUTTON_SIZE = 36
local BUTTON_GAP = 2
local STEP = BUTTON_SIZE + BUTTON_GAP + 2

-- bar1 走安全分页（槽 1–12，页 2–6 由状态驱动映射到 13–72）；bar2–6 固定槽段。
local BAR_DEFS = {
    { key = "bar1", frame = "OpenUIActionBar", offset = 0, pageable = true, defaultShown = true },
    { key = "bar2", frame = "OpenUIBar2", offset = 12, defaultShown = false },
    { key = "bar3", frame = "OpenUIBar3", offset = 24, defaultShown = false },
    { key = "bar4", frame = "OpenUIBar4", offset = 36, defaultShown = false },
    { key = "bar5", frame = "OpenUIBar5", offset = 48, defaultShown = false },
    { key = "bar6", frame = "OpenUIBar6", offset = 60, defaultShown = false },
}

local ActionBars = {}
local bars = {} -- key -> { frame, buttons = {}, def }
local petBar
local petButtons = {}
local built = false
local eventsRegistered = false

local NATIVE_BARS = {
    "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight",
    "MultiBarLeft", "MultiBarRight", "MultiBar5", "MultiBar6", "MultiBar7",
    "PetActionBar",
}

local PAGE_DRIVER = "[bonusbar:5] 6; [bonusbar:4] 5; [bonusbar:3] 4; [bonusbar:2] 3; "
    .. "[bonusbar:1] 2; [bar:1] 1; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; 1"

local PAGE_SNIPPET = [[
    local page = tonumber(newstate) or 1
    for i = 1, 12 do
        local button = self:GetFrameRef("button" .. i)
        if button then
            button:SetAttribute("action", (page - 1) * 12 + i)
        end
    end
]]

-- 生效配置（Profile 语义；未加载时回退 legacy）
local function activeConfig()
    if OpenUI.Profile and OpenUI.Profile.Config then
        local cfg = OpenUI.Profile.Config()
        if type(cfg) == "table" then return cfg end
    end
    if type(_G.OpenUIDB) ~= "table" then _G.OpenUIDB = {} end
    return _G.OpenUIDB
end

local function barConfig(key)
    local cfg = activeConfig()
    if type(cfg.actionbars) ~= "table" then cfg.actionbars = {} end
    if type(cfg.actionbars[key]) ~= "table" then cfg.actionbars[key] = {} end
    return cfg.actionbars[key]
end

local function skinButton(button)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(button)
    local icon = button:CreateTexture(nil, "ARTWORK")
    -- #59：图标填满格子（无内缩），1px 描边绘制在其上方
    icon:SetAllPoints(button)
    local count = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    if type(count.SetShadowOffset) == "function" then
        count:SetShadowOffset(1, -1)
        if type(count.SetShadowColor) == "function" then count:SetShadowColor(0, 0, 0, 0.9) end
    end
    -- #56：图标外 1px 银灰描边（4 边）
    local border = Theme.Get("color.outline")
    if border then
        local edges = {}
        local function edge(x1, y1, x2, y2)
            local tex = button:CreateTexture(nil, "BORDER")
            tex:SetColorTexture(border[1], border[2], border[3], 0.8)
            tex:SetPoint("TOPLEFT", button, "TOPLEFT", x1, y1)
            tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", x2, y2)
            edges[#edges + 1] = tex
        end
        edge(0, 0, 0, -1)
        edge(0, 1, 0, 0)
        edge(0, 0, 1, 0)
        edge(-1, 0, 0, 0)
        button.openuiEdges = edges
    end
    button.openuiBg, button.openuiIcon, button.openuiCount = bg, icon, count
end

local function paintButtonBg(button)
    local bg = Theme.Get("color.surface-container-high")
    if type(bg) == "table" then
        button.openuiBg:SetColorTexture(bg[1], bg[2], bg[3], 1)
    end
end

local function actionTexture(slot)
    if type(GetActionTexture) == "function" then
        local tex = GetActionTexture(slot)
        if tex then return tex end
    end
    if type(C_ActionBar) == "table" and type(C_ActionBar.GetActionTexture) == "function" then
        return C_ActionBar.GetActionTexture(slot)
    end
    return nil
end

local function refreshActionButton(button, slot)
    paintButtonBg(button)
    local texture = actionTexture(slot)
    pcall(function() button.openuiIcon:SetTexture(texture) end)
    local countText = ""
    if type(GetActionCount) == "function" then
        local ok, text = pcall(function()
            local count = GetActionCount(slot) or 0
            return count > 1 and tostring(count) or ""
        end)
        if ok then countText = text end
    end
    button.openuiCount:SetText(countText)
end

local function refreshPetButton(button, slot)
    paintButtonBg(button)
    local ok = pcall(function()
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
    end)
    if not ok then
        pcall(function() button.openuiIcon:SetTexture(nil) end)
        button.openuiCount:SetText("")
    end
end

local function refreshMainIcons()
    local bar = bars.bar1
    if not bar or #bar.buttons == 0 then return end
    local page = 1
    if type(GetActionBarPage) == "function" then page = GetActionBarPage() or 1 end
    for i = 1, SLOTS_PER_BAR do
        refreshActionButton(bar.buttons[i], (page - 1) * SLOTS_PER_BAR + i)
    end
end

local function refreshFixedBars()
    for _, def in ipairs(BAR_DEFS) do
        if not def.pageable then
            local bar = bars[def.key]
            if bar then
                for i = 1, SLOTS_PER_BAR do
                    refreshActionButton(bar.buttons[i], def.offset + i)
                end
            end
        end
    end
end

local function refreshPetIcons()
    for i = 1, PET_SLOTS do
        if petButtons[i] then refreshPetButton(petButtons[i], i) end
    end
end

local function refreshAll()
    refreshMainIcons()
    refreshFixedBars()
    refreshPetIcons()
end

local function savePosition(key)
    local bar = bars[key]
    if not bar or type(bar.frame.GetLeft) ~= "function" then return end
    local cfg = barConfig(key)
    cfg.x = bar.frame:GetLeft()
    cfg.y = bar.frame:GetBottom()
end

local function restorePosition(key)
    local bar = bars[key]
    if not bar then return end
    local cfg = barConfig(key)
    if type(bar.frame.ClearAllPoints) == "function" then bar.frame:ClearAllPoints() end
    bar.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cfg.x or 0, cfg.y or 24)
end

local function attachDrag(frame, key, buttons)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if OpenUI:CanModifyNow() then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition(key)
    end)
    for _, button in ipairs(buttons) do
        if type(button.RegisterForDrag) == "function" then
            button:RegisterForDrag("LeftButton")
            button:SetScript("OnDragStart", function()
                local alt = type(IsAltKeyDown) == "function" and IsAltKeyDown()
                if alt and OpenUI:CanModifyNow() then frame:StartMoving() end
            end)
            button:SetScript("OnDragStop", function()
                frame:StopMovingOrSizing()
                savePosition(key)
            end)
        end
    end
end

local function buildBar(def)
    local frame
    if def.pageable then
        frame = CreateFrame("Frame", def.frame, UIParent, "SecureHandlerStateTemplate")
    else
        frame = CreateFrame("Frame", def.frame, UIParent)
    end
    frame:SetSize(SLOTS_PER_BAR * (BUTTON_SIZE + BUTTON_GAP), BUTTON_SIZE)
    local buttons = {}
    for i = 1, SLOTS_PER_BAR do
        local button = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
        button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        button:SetPoint("LEFT", frame, "LEFT", (i - 1) * (BUTTON_SIZE + BUTTON_GAP), 0)
        button:RegisterForClicks("AnyUp")
        button:SetAttribute("type", "action")
        button:SetAttribute("action", def.offset + i)
        skinButton(button)
        if def.pageable then
            frame:SetFrameRef("button" .. i, button)
        end
        buttons[i] = button
    end
    if def.pageable then
        frame:SetAttribute("_onstate-page", PAGE_SNIPPET)
        if type(RegisterStateDriver) == "function" then
            RegisterStateDriver(frame, "page", PAGE_DRIVER)
        end
    end
    attachDrag(frame, def.key, buttons)
    bars[def.key] = { frame = frame, buttons = buttons, def = def }
    restorePosition(def.key)
    return bars[def.key]
end

local function buildPetBar()
    petBar = CreateFrame("Frame", "OpenUIPetBar", UIParent)
    petBar:SetSize(PET_SLOTS * (BUTTON_SIZE + BUTTON_GAP), BUTTON_SIZE)
    local mainFrame = bars.bar1 and bars.bar1.frame
    if mainFrame then
        petBar:SetPoint("BOTTOM", mainFrame, "TOP", 0, BUTTON_GAP * 3)
    else
        petBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 64)
    end
    -- #50：宠物条可拖（Alt+左键，含宠物按钮转发），位置持久化
    OpenUI.Widgets.MakeDraggable(petBar, "actionbars", "pet", nil)
    for i = 1, PET_SLOTS do
        local button = CreateFrame("Button", nil, petBar, "SecureActionButtonTemplate")
        button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        button:SetPoint("LEFT", petBar, "LEFT", (i - 1) * (BUTTON_SIZE + BUTTON_GAP), 0)
        button:RegisterForClicks("AnyUp")
        button:SetAttribute("type", "pet")
        button:SetAttribute("action", i)
        skinButton(button)
        if type(button.RegisterForDrag) == "function" then
            button:RegisterForDrag("LeftButton")
            button:SetScript("OnDragStart", function()
                local alt = type(IsAltKeyDown) == "function" and IsAltKeyDown()
                if alt and OpenUI:CanModifyNow() then petBar:StartMoving() end
            end)
            button:SetScript("OnDragStop", function()
                petBar:StopMovingOrSizing()
                if type(petBar.GetLeft) == "function" then
                    local cfg = barConfig("pet")
                    cfg.x = petBar:GetLeft()
                    cfg.y = petBar:GetBottom()
                end
            end)
        end
        petButtons[i] = button
    end
    local cfg = barConfig("pet")
    if cfg.x and cfg.y and type(petBar.ClearAllPoints) == "function" then
        petBar:ClearAllPoints()
        petBar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cfg.x, cfg.y)
    end
end

local function build()
    if built then return end
    built = true
    for _, def in ipairs(BAR_DEFS) do
        buildBar(def)
    end
    buildPetBar()
end

local function applyBarVisibility()
    for _, def in ipairs(BAR_DEFS) do
        local bar = bars[def.key]
        if bar then
            local cfg = barConfig(def.key)
            local shown = cfg.shown
            if shown == nil then shown = def.defaultShown end
            if shown then bar.frame:Show() else bar.frame:Hide() end
        end
    end
end


local function registerEvents()
    if eventsRegistered then return end
    eventsRegistered = true
    local own = OpenUI.Own("ActionBars")
    own:On("PLAYER_ENTERING_WORLD", refreshAll)
    own:On("ACTIONBAR_SLOT_CHANGED", refreshAll)
    own:On("ACTIONBAR_UPDATE_STATE", refreshAll)
    own:On("ACTIONBAR_PAGE_CHANGED", refreshAll)
    own:On("PET_BAR_UPDATE", refreshPetIcons)

end

-- 设置面板模块小窗：各 bar 显示开关（#47）
local function registerSettingsPanel()
    if type(OpenUI.Settings) ~= "table" or type(OpenUI.Settings.RegisterModulePanel) ~= "function" then
        return
    end
    OpenUI.Settings.RegisterModulePanel("ActionBars", {
        build = function(host)
            local L = OpenUI.L
            local Widgets = OpenUI.Widgets
            local y = -2
            for index, def in ipairs(BAR_DEFS) do
                local key = def.key
                local label = def.pageable and L.SETTINGS_BAR_MAIN or L.SETTINGS_BAR_N:format(index)
                local toggle = Widgets.Toggle(host, label,
                    function()
                        local cfg = barConfig(key)
                        local shown = cfg.shown
                        if shown == nil then shown = def.defaultShown end
                        return shown
                    end,
                    function(want)
                        barConfig(key).shown = want and true or false
                        applyBarVisibility()
                    end)
                toggle:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y)
                toggle:SetSize(220, 24)
                y = y - 28
            end
            local hint = Widgets.Text(host, L.SETTINGS_ACTIONBARS_HINT, "body")
            hint:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y - 4)
            hint:SetWidth(340)
        end,
    })
end

local function tryLoadBlizzardActionBar()
    if type(LoadAddOn) == "function" then
        pcall(LoadAddOn, "Blizzard_ActionBar")
    end
end

function ActionBars.OnEnable()
    build()
    registerEvents()
    tryLoadBlizzardActionBar()
    applyBarVisibility()
    if petBar then petBar:Show() end
    refreshAll()
    OpenUI.Native.Hide("ActionBars", NATIVE_BARS)
end

function ActionBars.OnDisable()
    eventsRegistered = false
    pendingNativeHide = false
    for _, def in ipairs(BAR_DEFS) do
        local bar = bars[def.key]
        if bar then bar.frame:Hide() end
    end
    if petBar then petBar:Hide() end
    OpenUI.Native.Restore("ActionBars")
end

-- 兼容 API（#11 测试与消费者）
ActionBars.MainBar = function() return bars.bar1 and bars.bar1.frame end
ActionBars.MainButtons = function() return bars.bar1 and bars.bar1.buttons or {} end
ActionBars.PetBar = function() return petBar end
ActionBars.PetButtons = function() return petButtons end
ActionBars.Bar = function(key) return bars[key] end
ActionBars.BarKeys = function()
    local list = {}
    for _, def in ipairs(BAR_DEFS) do list[#list + 1] = def.key end
    return list
end
ActionBars.PageDriver = PAGE_DRIVER

OpenUI.ActionBars = ActionBars

OpenUI:RegisterModule("ActionBars", {
    OnEnable = function() ActionBars.OnEnable() end,
    OnDisable = function() ActionBars.OnDisable() end,
})

registerSettingsPanel()