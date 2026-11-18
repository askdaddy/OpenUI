-- 主控面板 v2（#71）：滚动容器 + 卡片式磁贴 + 分区视觉层级。
-- 结构：固定页眉（标题/搜索/布局编辑/关闭 + 分隔线）→ 滚轮滚动的正文（类目分区 × 卡片磁贴）
--   → 固定页脚提示；模块小窗带标题带与主色强调条。
-- 滚动采用 examples/ForeverUI Config/GUI.lua 的纯 API 模式（ScrollFrame + SetScrollChild + OnMouseWheel，
-- 无模板依赖）；卡片边线用 Widgets.Edge（#69 配方）。

local _, ns = ...
local OpenUI = ns.OpenUI
local L = OpenUI.L
local Theme = OpenUI.Theme
local Widgets = OpenUI.Widgets
local Locale = OpenUI.Locale

local Settings = {}

local WINDOW_W, WINDOW_H = 700, 520
local MODULE_W, MODULE_H = 420, 330
local TILE_W, TILE_H, TILE_GAP, TILE_COLS = 150, 34, 10, 4
local HEADER_H = 62   -- 页眉高度（含分隔线）
local FOOTER_H = 30   -- 页脚高度
local SECTION_HEAD_H = 30
local SECTION_GAP = 18

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
    Diagnostics = "core", Media = "core", Grid = "core",
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
    Grid = "SETTINGS_MOD_GRID",
}

local frame, searchBox, noResultsText
local scrollFrame, scrollContent
local contentHeight = 0
local hubTiles = {}        -- moduleName -> { button, category, edges, bg, label, dot }
local categorySections = {} -- categoryId -> { frame, header, accent, count }
local labelRefs = {}       -- { fs, update }
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

-- ==== 卡片磁贴（#71）：边框 + 底色 + 左名右点 + 悬停主色边 ====
local function tilePaint(tile, hovered)
    local border = hovered and Theme.Get("color.primary") or Theme.Get("color.outline")
    local bg = hovered and Theme.Get("color.surface-container-highest")
        or Theme.Get("color.surface-container-high")
    if tile.bg and type(tile.bg.SetColorTexture) == "function" and bg then
        tile.bg:SetColorTexture(bg[1], bg[2], bg[3], 0.95)
    end
    for _, edge in ipairs(tile.edges or {}) do
        if type(edge.SetColorTexture) == "function" and border then
            edge:SetColorTexture(border[1], border[2], border[3], hovered and 1.0 or 0.85)
        end
    end
end

local function buildTile(parent, name, category)
    local tile = CreateFrame("Button", nil, parent)
    tile:SetSize(TILE_W, TILE_H)

    local bg = tile:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints(tile)

    local label = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", tile, "LEFT", 10, 0)
    if type(label.SetJustifyH) == "function" then label:SetJustifyH("LEFT") end
    if type(label.SetShadowOffset) == "function" then
        label:SetShadowOffset(1, -1)
        if type(label.SetShadowColor) == "function" then label:SetShadowColor(0, 0, 0, 0.9) end
    end
    label:SetText(moduleLabel(name))

    local dot = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dot:SetPoint("RIGHT", tile, "RIGHT", -10, 0)
    dot:SetText("○")

    local edges = {}
    if Widgets.Edge then
        local border = Theme.Get("color.outline")
        for _, side in ipairs({ "top", "bottom", "left", "right" }) do
            local e = Widgets.Edge(tile, side, border, 0.85)
            if e then edges[#edges + 1] = e end
        end
    end

    local entry = {
        button = tile, category = category, edges = edges, bg = bg,
        label = label, dot = dot,
    }
    tile.themedLabel = label -- 兼容既有测试/检索

    tile:SetScript("OnEnter", function() tilePaint(entry, true) end)
    tile:SetScript("OnLeave", function() tilePaint(entry, false) end)
    tile:SetScript("OnClick", function() Settings.OpenModule(name) end)

    tilePaint(entry, false)
    return entry
end

local function refreshTileStates()
    for name, tile in pairs(hubTiles) do
        local enabled = OpenUI:IsModuleEnabled(name)
        tile.label:SetText(moduleLabel(name))
        local state = enabled and "●" or "○"
        local color = enabled and Theme.Get("color.primary") or Theme.Get("color.outline")
        tile.dot:SetText(state)
        if type(tile.dot.SetTextColor) == "function" and color then
            tile.dot:SetTextColor(color[1], color[2], color[3], 1)
        end
        tile.label:SetAlpha(enabled and 1.0 or 0.55)
    end
end

-- ==== 模块小窗（#71：标题带 + 主色强调条 + 方形关闭钮） ====
local function buildModuleWindow()
    if modWindow then return end
    modWindow = Widgets.Panel(UIParent, { name = "OpenUIModuleSettings" })
    modWindow:SetSize(MODULE_W, MODULE_H)
    modWindow:SetPoint("LEFT", frame, "RIGHT", 12, 0)
    modWindow:SetMovable(true)
    modWindow:EnableMouse(true)
    modWindow:RegisterForDrag("LeftButton")
    modWindow:SetScript("OnDragStart", modWindow.StartMoving)
    modWindow:SetScript("OnDragStop", modWindow.StopMovingOrSizing)

    -- 标题带：深色底 + 左侧 3px 主色条
    local barBg = modWindow:CreateTexture(nil, "BACKGROUND", nil, -8)
    barBg:SetPoint("TOPLEFT", modWindow, "TOPLEFT", 0, 0)
    barBg:SetPoint("TOPRIGHT", modWindow, "TOPRIGHT", 0, 0)
    if type(barBg.SetHeight) == "function" then barBg:SetHeight(38) end
    local barColor = Theme.Get("color.surface-container-highest")
    if barColor then barBg:SetColorTexture(barColor[1], barColor[2], barColor[3], 0.95) end

    local accent = modWindow:CreateTexture(nil, "OVERLAY", nil, 7)
    accent:SetPoint("TOPLEFT", modWindow, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", barBg, "BOTTOMLEFT", 0, 0)
    if type(accent.SetWidth) == "function" then accent:SetWidth(3) end
    local primary = Theme.Get("color.primary")
    if primary then accent:SetColorTexture(primary[1], primary[2], primary[3], 1) end

    modTitle = modWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    modTitle:SetPoint("LEFT", accent, "RIGHT", 10, 0)
    if type(modTitle.SetJustifyH) == "function" then modTitle:SetJustifyH("LEFT") end
    if type(modTitle.SetShadowOffset) == "function" then
        modTitle:SetShadowOffset(1, -1)
        if type(modTitle.SetShadowColor) == "function" then
            modTitle:SetShadowColor(0, 0, 0, 0.9)
        end
    end
    addLabelRef(modTitle, function()
        modTitle:SetText(currentModule and moduleLabel(currentModule) or "")
    end)

    -- 方形关闭钮（×）
    local closeBtn = CreateFrame("Button", nil, modWindow)
    closeBtn:SetSize(26, 26)
    closeBtn:SetPoint("TOPRIGHT", modWindow, "TOPRIGHT", -8, -6)
    local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND", nil, -8)
    closeBg:SetAllPoints(closeBtn)
    local cbColor = Theme.Get("color.surface-container-high")
    if cbColor then closeBg:SetColorTexture(cbColor[1], cbColor[2], cbColor[3], 0.95) end
    if Widgets.Edge then
        local border = Theme.Get("color.outline")
        for _, side in ipairs({ "top", "bottom", "left", "right" }) do
            Widgets.Edge(closeBtn, side, border, 0.85)
        end
    end
    local closeLabel = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    closeLabel:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    closeLabel:SetText("×")
    closeBtn:SetScript("OnClick", function() Settings.CloseModule() end)
    closeBtn.themedLabel = closeLabel

    -- 底部分隔线
    if Widgets.Edge then
        Widgets.Edge(modWindow, "top", Theme.Get("color.outline"), 0.6, barBg)
    end

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
    toggle:SetPoint("TOPLEFT", modWindow, "TOPLEFT", 14, -46)
    toggle:SetSize(210, 24)

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
    modHost:SetPoint("TOPLEFT", modWindow, "TOPLEFT", 14, -80)
    modHost:SetSize(MODULE_W - 28, MODULE_H - 94)
end

-- ==== 内建模块面板 ====
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
        btn:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -(i - 1) * 30)
        btn:SetSize(190, 26)
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
        btn:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -(i - 1) * 30)
        btn:SetSize(190, 26)
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
    open:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -34)
    open:SetSize(190, 26)
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

-- ==== 总览正文（滚动内容：类目分区 × 卡片磁贴） ====
local function buildHub()
    local y = 0
    local contentW = WINDOW_W - 32
    for _, category in ipairs(CATEGORY_ORDER) do
        local modules = {}
        for _, module in ipairs(OpenUI.moduleOrder) do
            if module.name ~= "Core" and categoryOrderOf(module.name) == category then
                modules[#modules + 1] = module.name
            end
        end
        if #modules > 0 then
            -- 分区容器（独立 Frame，便于整段隐藏）
            local section = CreateFrame("Frame", nil, scrollContent)
            section:SetSize(contentW, SECTION_HEAD_H)

            -- 主色竖条 + 类目标题 + 计数
            local accent = section:CreateTexture(nil, "OVERLAY", nil, 7)
            accent:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -2)
            if type(accent.SetWidth) == "function" then accent:SetWidth(3) end
            if type(accent.SetHeight) == "function" then accent:SetHeight(16) end
            local primary = Theme.Get("color.primary")
            if primary then accent:SetColorTexture(primary[1], primary[2], primary[3], 1) end

            local header = section:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            header:SetPoint("LEFT", accent, "RIGHT", 8, 0)
            if type(header.SetJustifyH) == "function" then header:SetJustifyH("LEFT") end
            if type(header.SetShadowOffset) == "function" then
                header:SetShadowOffset(1, -1)
                if type(header.SetShadowColor) == "function" then
                    header:SetShadowColor(0, 0, 0, 0.9)
                end
            end
            header:SetText(L[CATEGORY_LABELS[category]])
            addLabelRef(header, function() header:SetText(L[CATEGORY_LABELS[category]]) end)

            local count = section:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            count:SetPoint("LEFT", header, "RIGHT", 8, 0)
            count:SetText(tostring(#modules))

            -- 磁贴网格
            local col, row = 0, 0
            local rows = 0
            for _, name in ipairs(modules) do
                local tile = buildTile(section, name, category)
                tile.button:SetPoint("TOPLEFT", section, "TOPLEFT",
                    col * (TILE_W + TILE_GAP), -SECTION_HEAD_H - row * (TILE_H + TILE_GAP))
                hubTiles[name] = tile
                col = col + 1
                if col >= TILE_COLS then
                    col, row = 0, row + 1
                end
            end
            rows = row + ((col > 0) and 1 or 0)

            local sectionH = SECTION_HEAD_H + rows * (TILE_H + TILE_GAP)
            section:SetSize(contentW, sectionH)
            section:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, y)
            categorySections[category] = { frame = section, header = header, accent = accent }
            y = y - sectionH - SECTION_GAP
        end
    end
    contentHeight = -y
    scrollContent:SetSize(contentW, math.max(contentHeight, 10))
    if type(scrollFrame.SetScrollChild) == "function" then
        scrollFrame:SetScrollChild(scrollContent)
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

    -- ==== 页眉（固定） ====
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
    if type(title.SetJustifyH) == "function" then title:SetJustifyH("LEFT") end
    if type(title.SetShadowOffset) == "function" then
        title:SetShadowOffset(1, -1)
        if type(title.SetShadowColor) == "function" then title:SetShadowColor(0, 0, 0, 0.9) end
    end
    title:SetText(L.SETTINGS_TITLE)
    addLabelRef(title, function() title:SetText(L.SETTINGS_TITLE) end)

    local close = Widgets.Button(frame, L.SETTINGS_CLOSE)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -10)
    close:SetSize(72, 24)
    close:SetScript("OnClick", function() Settings.Close() end)
    addLabelRef(close.themedLabel, function() close.themedLabel:SetText(L.SETTINGS_CLOSE) end)

    local editButton = Widgets.Button(frame, L.SETTINGS_EDIT_MODE)
    editButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -96, -10)
    editButton:SetSize(96, 24)
    editButton:SetScript("OnClick", function()
        if OpenUI.EditMode then
            OpenUI.EditMode.Toggle()
            editButton.themedLabel:SetText(
                (OpenUI.EditMode.IsActive() and "● " or "") .. L.SETTINGS_EDIT_MODE)
        end
    end)
    addLabelRef(editButton.themedLabel, function()
        local marker = (OpenUI.EditMode and OpenUI.EditMode.IsActive()) and "● " or ""
        editButton.themedLabel:SetText(marker .. L.SETTINGS_EDIT_MODE)
    end)

    -- 搜索框（带底与边）
    searchBox = CreateFrame("EditBox", nil, frame)
    searchBox:SetAutoFocus(false)
    searchBox:SetText("")
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 230, -12)
    searchBox:SetSize(280, 24)
    if type(searchBox.SetFontObject) == "function" and type(GameFontHighlight) == "table" then
        searchBox:SetFontObject(GameFontHighlight)
    end
    local textColor = Theme.Get("color.on-surface")
    if type(searchBox.SetTextColor) == "function" and type(textColor) == "table" then
        searchBox:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
    end
    if type(searchBox.SetTextInsets) == "function" then
        searchBox:SetTextInsets(8, 8, 0, 0)
    end
    local searchBg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    searchBg:SetPoint("TOPLEFT", searchBox, "TOPLEFT", -2, 2)
    searchBg:SetPoint("BOTTOMRIGHT", searchBox, "BOTTOMRIGHT", 2, -2)
    local sc = Theme.Get("color.surface-container-high")
    if sc then searchBg:SetColorTexture(sc[1], sc[2], sc[3], 0.95) end
    if Widgets.Edge then
        local border = Theme.Get("color.outline")
        for _, side in ipairs({ "top", "bottom", "left", "right" }) do
            Widgets.Edge(searchBox, side, border, 0.85, searchBox)
        end
    end
    searchBox:SetScript("OnTextChanged", function(self)
        Settings.ApplyFilter(self:GetText())
    end)
    searchBox:SetScript("OnMouseDown", function(self) self:SetFocus() end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- 页眉分隔线
    local divider = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -HEADER_H)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -HEADER_H)
    if type(divider.SetHeight) == "function" then divider:SetHeight(1) end
    local outline = Theme.Get("color.outline")
    if outline then divider:SetColorTexture(outline[1], outline[2], outline[3], 0.6) end

    -- ==== 正文（滚动） ====
    scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -(HEADER_H + 8))
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, FOOTER_H)
    if type(scrollFrame.EnableMouseWheel) == "function" then
        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(self, delta)
            local range = (type(self.GetVerticalScrollRange) == "function"
                and self:GetVerticalScrollRange()) or 0
            local current = (type(self.GetVerticalScroll) == "function"
                and self:GetVerticalScroll()) or 0
            local target = current - delta * 40
            if type(self.SetVerticalScroll) == "function" then
                self:SetVerticalScroll(math.max(0, math.min(range, target)))
            end
        end)
    end
    scrollContent = CreateFrame("Frame", nil, scrollFrame)

    noResultsText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    noResultsText:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -(HEADER_H + 16))
    noResultsText:SetText(L.SETTINGS_NO_RESULTS)
    noResultsText:Hide()
    addLabelRef(noResultsText, function() noResultsText:SetText(L.SETTINGS_NO_RESULTS) end)

    -- ==== 页脚（固定） ====
    local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 10)
    footer:SetText(L.SETTINGS_HINT)
    addLabelRef(footer, function() footer:SetText(L.SETTINGS_HINT) end)

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
    for category, section in pairs(categorySections) do
        if perCategory[category] or query == "" then
            section.frame:Show()
        else
            section.frame:Hide()
        end
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
Settings.ContentHeight = function() return contentHeight end

OpenUI.Settings = Settings

OpenUI:RegisterModule("Settings", {})