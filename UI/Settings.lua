-- 主控面板（#46）：模块分类总览 + 模块独立设置小窗。
-- 用户方向（2026-11-16）：所有模块分类显示在主控面板；每个模块的设置新开小窗。
-- 决策（推荐项）：总览三列磁贴（类目：基础/战斗界面/系统窗口/工具）；
-- 模块小窗单实例，含「启用」开关与模块专属控件（注册表可扩展）；搜索过滤磁贴。

local _, ns = ...
local OpenUI = ns.OpenUI
local L = OpenUI.L
local Theme = OpenUI.Theme
local Widgets = OpenUI.Widgets
local Locale = OpenUI.Locale

local Settings = {}

local WINDOW_W, WINDOW_H = 640, 520
local MODULE_W, MODULE_H = 400, 300
local TILE_W, TILE_H, TILE_GAP, TILE_COLS = 196, 26, 6, 3

local CATEGORY_ORDER = { "core", "combat", "panels", "tools" }
local CATEGORY_LABELS = {
    core = "SETTINGS_CAT_CORE",
    combat = "SETTINGS_CAT_COMBAT",
    panels = "SETTINGS_CAT_PANELS",
    tools = "SETTINGS_CAT_TOOLS",
}
local DEFAULT_CATEGORY = "panels"

local MODULE_CATEGORY = {
    Profile = "core", Theme = "core", Locale = "core", Settings = "core",
    Diagnostics = "core", Media = "core",
    ActionBars = "combat", Chat = "combat", UnitFrames = "combat", CastBars = "combat",
    Auras = "combat", Nameplates = "combat", MinimapUI = "combat",
    Tooltips = "panels", Bags = "panels", WorldMapUI = "panels", QuestUI = "panels",
    NPCUI = "panels", CharUI = "panels", SpellUI = "panels", PartyUI = "panels",
    SocialUI = "panels", TradeUI = "panels", ProfUI = "panels", AuctionUI = "panels",
    SystemUI = "panels", SpecialUI = "panels",
}
local MODULE_LABELS = {
    Profile = "SETTINGS_MOD_PROFILE",
    Theme = "SETTINGS_MOD_THEME",
    Locale = "SETTINGS_MOD_LOCALE",
    Settings = "SETTINGS_MOD_SETTINGS",
    Diagnostics = "SETTINGS_MOD_DIAGNOSTICS",
    Media = "SETTINGS_MOD_MEDIA",
    ActionBars = "SETTINGS_MOD_ACTIONBARS",
    Chat = "SETTINGS_MOD_CHAT",
    UnitFrames = "SETTINGS_MOD_UNITFRAMES",
    CastBars = "SETTINGS_MOD_CASTBARS",
    Auras = "SETTINGS_MOD_AURAS",
    Nameplates = "SETTINGS_MOD_NAMEPLATES",
    MinimapUI = "SETTINGS_MOD_MINIMAPUI",
    Tooltips = "SETTINGS_MOD_TOOLTIPS",
    Bags = "SETTINGS_MOD_BAGS",
    WorldMapUI = "SETTINGS_MOD_WORLDMAPUI",
    QuestUI = "SETTINGS_MOD_QUESTUI",
    NPCUI = "SETTINGS_MOD_NPCUI",
    CharUI = "SETTINGS_MOD_CHARUI",
    SpellUI = "SETTINGS_MOD_SPELLUI",
    PartyUI = "SETTINGS_MOD_PARTYUI",
    SocialUI = "SETTINGS_MOD_SOCIALUI",
    TradeUI = "SETTINGS_MOD_TRADEUI",
    ProfUI = "SETTINGS_MOD_PROFUI",
    AuctionUI = "SETTINGS_MOD_AUCTIONUI",
    SystemUI = "SETTINGS_MOD_SYSTEMUI",
    SpecialUI = "SETTINGS_MOD_SPECIALUI",
}

local frame, searchBox, noResultsText, hubHost
local hubTiles = {}        -- moduleName -> { button, category }
local categoryHeaders = {} -- categoryId -> FontString
local labelRefs = {}       -- { fs = FontString, update = fn }
local modulePanels = {}    -- moduleName -> { build = fn(host) }
local modWindow, modHost, modTitle
local currentModule

local function moduleLabel(moduleName)
    local key = MODULE_LABELS[moduleName]
    return key and L[key] or moduleName
end

local function addLabelRef(fs, update)
    labelRefs[#labelRefs + 1] = { fs = fs, update = update }
    return fs
end

local function categoryOrderOf(name)
    return MODULE_CATEGORY[name] or DEFAULT_CATEGORY
end

function Settings.RegisterModulePanel(moduleName, def)
    assert(type(moduleName) == "string" and type(def) == "table" and type(def.build) == "function",
        "invalid module panel: " .. tostring(moduleName))
    modulePanels[moduleName] = def
end

-- ==== 模块小窗 ====
local function refreshTileStates()
    for name, tile in pairs(hubTiles) do
        local enabled = OpenUI:IsModuleEnabled(name)
        tile.button.themedLabel:SetText((enabled and "● " or "○ ") .. moduleLabel(name))
    end
end

local function buildModuleWindow()
    if modWindow then return end
    modWindow = Widgets.Panel(UIParent, { name = "OpenUIModuleSettings" })
    modWindow:SetSize(MODULE_W, MODULE_H)
    modWindow:SetPoint("LEFT", frame, "RIGHT", 10, 0)
    modWindow:SetMovable(true)
    modWindow:EnableMouse(true)
    modWindow:RegisterForDrag("LeftButton")
    modWindow:SetScript("OnDragStart", modWindow.StartMoving)
    modWindow:SetScript("OnDragStop", modWindow.StopMovingOrSizing)

    modTitle = Widgets.Text(modWindow, "", "headline")
    modTitle:SetPoint("TOPLEFT", modWindow, "TOPLEFT", 12, -10)
    addLabelRef(modTitle, function()
        modTitle:SetText(currentModule and moduleLabel(currentModule) or "")
    end)

    local close = Widgets.Button(modWindow, L.SETTINGS_CLOSE)
    close:SetPoint("TOPRIGHT", modWindow, "TOPRIGHT", -10, -8)
    close:SetSize(64, 22)
    close:SetScript("OnClick", function() Settings.CloseModule() end)
    addLabelRef(close.themedLabel, function() close.themedLabel:SetText(L.SETTINGS_CLOSE) end)

    local toggle = Widgets.Toggle(modWindow, "SETTINGS_MODULE_TOGGLE",
        function() return currentModule and OpenUI:IsModuleEnabled(currentModule) end,
        function(want)
            if not currentModule then return end
            if currentModule == "Core" then return end
            if want then
                OpenUI:EnableModule(currentModule)
            else
                OpenUI:DisableModule(currentModule)
            end
            refreshTileStates()
        end)
    toggle:SetPoint("TOPLEFT", modWindow, "TOPLEFT", 12, -44)
    toggle:SetSize(200, 24)

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "OpenUIModuleSettings")
    end
end

local function clearModuleHost()
    if modHost then
        modHost:Hide()
        modHost = nil
    end
end

local function buildModuleHost()
    modHost = CreateFrame("Frame", nil, modWindow)
    modHost:SetPoint("TOPLEFT", modWindow, "TOPLEFT", 12, -78)
    modHost:SetSize(MODULE_W - 24, MODULE_H - 90)
end

-- 内建模块面板（推荐项）
local function buildThemePanel(host)
    local names = { "starblue", "teal", "amber", "amethyst", "rose", "moss", "graphite" }
    local buttons = {}
    local function mark()
        local cur = Theme.GetPalette()
        for i, name in ipairs(names) do
            buttons[i].themedLabel:SetText(((name == cur) and "● " or "  ") .. name)
        end
    end
    for i, name in ipairs(names) do
        local btn = Widgets.Button(host, name)
        btn:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -(i - 1) * 28)
        btn:SetSize(180, 24)
        btn:SetScript("OnClick", function()
            Theme.SetPalette(name)
            mark()
        end)
        buttons[i] = btn
    end
    mark()
end

local function buildLocalePanel(host)
    local choices = { { id = "auto", labelKey = "SETTINGS_LOCALE_AUTO" },
                      { id = "enUS", label = "enUS" }, { id = "zhCN", label = "zhCN" } }
    local buttons = {}
    local function mark()
        local cur = Locale.Get()
        for i, choice in ipairs(choices) do
            local label = choice.label or L[choice.labelKey]
            buttons[i].themedLabel:SetText(((choice.id == cur) and "● " or "  ") .. label)
        end
    end
    for i, choice in ipairs(choices) do
        local btn = Widgets.Button(host, choice.label or L[choice.labelKey])
        btn:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -(i - 1) * 28)
        btn:SetSize(180, 24)
        btn:SetScript("OnClick", function()
            Locale.Set(choice.id)
            mark()
            Settings.Refresh()
        end)
        buttons[i] = btn
    end
    mark()
end

local function buildDiagnosticsPanel(host)
    local count = Widgets.Text(host, L.SETTINGS_ERRORS_COUNT:format(#OpenUI.Diagnose.Errors()), "body")
    count:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -4)
    addLabelRef(count, function()
        count:SetText(L.SETTINGS_ERRORS_COUNT:format(#OpenUI.Diagnose.Errors()))
    end)
    local open = Widgets.Button(host, L.SETTINGS_DIAG_OPEN)
    open:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -32)
    open:SetSize(180, 24)
    open:SetScript("OnClick", function()
        if OpenUI.Diagnostics then OpenUI.Diagnostics.Open() end
    end)
    addLabelRef(open.themedLabel, function() open.themedLabel:SetText(L.SETTINGS_DIAG_OPEN) end)
end

local function buildMediaPanel(host)
    local info = Widgets.Text(host, L.SETTINGS_MEDIA_INFO, "body")
    info:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -4)
    info:SetWidth(MODULE_W - 40)
    addLabelRef(info, function() info:SetText(L.SETTINGS_MEDIA_INFO) end)
end

local function buildSettingsPanel(host)
    local hint = Widgets.Text(host, L.SETTINGS_HINT, "body")
    hint:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -4)
    addLabelRef(hint, function() hint:SetText(L.SETTINGS_HINT) end)
end

Settings.RegisterModulePanel("Theme", { build = buildThemePanel })
Settings.RegisterModulePanel("Locale", { build = buildLocalePanel })
Settings.RegisterModulePanel("Diagnostics", { build = buildDiagnosticsPanel })
Settings.RegisterModulePanel("Media", { build = buildMediaPanel })
Settings.RegisterModulePanel("Settings", { build = buildSettingsPanel })

local function buildGenericPanel(host)
    local hint = Widgets.Text(host, L.SETTINGS_MODULE_NO_OPTIONS, "body")
    hint:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -4)
    hint:SetWidth(MODULE_W - 40)
    addLabelRef(hint, function() hint:SetText(L.SETTINGS_MODULE_NO_OPTIONS) end)
end

-- ==== 总览 ====
local function buildHub()
    local y = 0
    for _, category in ipairs(CATEGORY_ORDER) do
        local modules = {}
        for _, module in ipairs(OpenUI.moduleOrder) do
            if module.name ~= "Core" and categoryOrderOf(module.name) == category then
                modules[#modules + 1] = module.name
            end
        end
        if #modules > 0 then
            local header = Widgets.Text(hubHost, L[CATEGORY_LABELS[category]], "title")
            header:SetPoint("TOPLEFT", hubHost, "TOPLEFT", 0, y)
            addLabelRef(header, function() header:SetText(L[CATEGORY_LABELS[category]]) end)
            categoryHeaders[category] = header
            y = y - 30
            local col, row = 0, 0
            for _, name in ipairs(modules) do
                local btn = Widgets.Button(hubHost, moduleLabel(name))
                btn:SetPoint("TOPLEFT", hubHost, "TOPLEFT",
                    col * (TILE_W + TILE_GAP), y - row * (TILE_H + TILE_GAP))
                btn:SetSize(TILE_W, TILE_H)
                local captured = name
                btn:SetScript("OnClick", function() Settings.OpenModule(captured) end)
                hubTiles[name] = { button = btn, category = category }
                col = col + 1
                if col >= TILE_COLS then
                    col, row = 0, row + 1
                end
            end
            local usedRows = row + ((col > 0) and 1 or 0)
            y = y - usedRows * (TILE_H + TILE_GAP) - 8
        end
    end
end

local function build()
    if frame then return end
    frame = Widgets.Panel(UIParent, { name = "OpenUISettings" })
    frame:SetSize(WINDOW_W, WINDOW_H)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local title = Widgets.Text(frame, L.SETTINGS_TITLE, "headline")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -12)
    addLabelRef(title, function() title:SetText(L.SETTINGS_TITLE) end)

    local close = Widgets.Button(frame, L.SETTINGS_CLOSE)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -10)
    close:SetSize(72, 22)
    close:SetScript("OnClick", function() Settings.Close() end)
    addLabelRef(close.themedLabel, function() close.themedLabel:SetText(L.SETTINGS_CLOSE) end)

    local searchLabel = Widgets.Text(frame, L.SETTINGS_SEARCH, "label")
    searchLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -46)
    addLabelRef(searchLabel, function() searchLabel:SetText(L.SETTINGS_SEARCH) end)
    searchBox = CreateFrame("EditBox", nil, frame)
    searchBox:SetAutoFocus(false)
    searchBox:SetText("")
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -64)
    searchBox:SetSize(200, 20)
    if type(searchBox.SetFontObject) == "function" and type(GameFontHighlight) == "table" then
        searchBox:SetFontObject(GameFontHighlight)
    end
    local textColor = Theme.Get("color.on-surface")
    if type(searchBox.SetTextColor) == "function" and type(textColor) == "table" then
        searchBox:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
    end
    if type(searchBox.SetTextInsets) == "function" then
        searchBox:SetTextInsets(6, 6, 0, 0)
    end
    local searchBg = frame:CreateTexture(nil, "BACKGROUND")
    searchBg:SetPoint("TOPLEFT", searchBox, "TOPLEFT", -2, 2)
    searchBg:SetPoint("BOTTOMRIGHT", searchBox, "BOTTOMRIGHT", 2, -2)
    local sc = Theme.Get("color.surface-container-highest")
    searchBg:SetColorTexture(sc[1], sc[2], sc[3], 0.9)
    searchBox:SetScript("OnTextChanged", function(self)
        Settings.ApplyFilter(self:GetText())
    end)
    searchBox:SetScript("OnMouseDown", function(self)
        self:SetFocus()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    hubHost = CreateFrame("Frame", nil, frame)
    hubHost:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -94)
    hubHost:SetSize(WINDOW_W - 32, WINDOW_H - 112)
    noResultsText = Widgets.Text(hubHost, L.SETTINGS_NO_RESULTS, "body")
    noResultsText:SetPoint("TOPLEFT", hubHost, "TOPLEFT", 0, 0)
    noResultsText:Hide()
    addLabelRef(noResultsText, function() noResultsText:SetText(L.SETTINGS_NO_RESULTS) end)

    buildHub()
    refreshTileStates()

    buildModuleWindow()
    Settings.CloseModule()

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "OpenUISettings")
    end
end

-- ==== 公共 API ====
function Settings.OpenModule(moduleName)
    if not OpenUI.modules[moduleName] then return end
    build()
    currentModule = moduleName
    clearModuleHost()
    buildModuleHost()
    local panel = modulePanels[moduleName]
    if panel then
        panel.build(modHost)
    else
        buildGenericPanel(modHost)
    end
    modTitle:SetText(moduleLabel(moduleName))
    modWindow:Show()
    Widgets.Refresh()
end

function Settings.CloseModule()
    if modWindow then modWindow:Hide() end
    currentModule = nil
end

function Settings.Open()
    build()
    frame:Show()
    refreshTileStates()
end

function Settings.Close()
    Settings.CloseModule()
    if frame then frame:Hide() end
end

function Settings.IsOpen()
    return frame ~= nil and frame:IsShown()
end

function Settings.ApplyFilter(query)
    query = (query or ""):lower()
    local any = false
    local perCategory = {}
    for name, tile in pairs(hubTiles) do
        local hit = query == ""
        if not hit then
            if moduleLabel(name):lower():find(query, 1, true) then
                hit = true
            else
                local catLabel = L[CATEGORY_LABELS[categoryOrderOf(name)]] or ""
                if catLabel:lower():find(query, 1, true) then hit = true end
            end
        end
        if hit then
            tile.button:Show()
            any = true
            perCategory[tile.category] = true
        else
            tile.button:Hide()
        end
    end
    for category, header in pairs(categoryHeaders) do
        if perCategory[category] then header:Show() else header:Hide() end
    end
    if noResultsText then
        if (not any) and query ~= "" then noResultsText:Show() else noResultsText:Hide() end
    end
end

function Settings.Refresh()
    if not frame then return end
    for i = 1, #labelRefs do
        labelRefs[i].update()
    end
    refreshTileStates()
    if currentModule and modWindow and modWindow:IsShown() then
        modTitle:SetText(moduleLabel(currentModule))
    end
    Widgets.Refresh()
end

Settings.IsModuleWindowShown = function()
    return modWindow ~= nil and modWindow:IsShown()
end
Settings.CurrentModule = function() return currentModule end
Settings.Tile = function(name) return hubTiles[name] end

OpenUI.Settings = Settings

OpenUI:RegisterModule("Settings", {})