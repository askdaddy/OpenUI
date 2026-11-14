-- 统一设置窗口（#8）：单帧 + 左侧竖排导航 + 搜索 + 页面注册表。
-- 用户裁决（2026-11-14）：Q1 左侧竖排 / Q2 裸 /openui 开窗+保留打印 /
-- Q3 搜索匹配页名+设置项 / Q4 全部选项即时生效（无应用/取消）。

local _, ns = ...
local OpenUI = ns.OpenUI
local L = OpenUI.L
local Theme = OpenUI.Theme
local Widgets = OpenUI.Widgets
local Locale = OpenUI.Locale

local Settings = {}
local pages, pageOrder = {}, {}
local frame, searchBox, noResultsText, contentHost
local navButtons = {} -- id -> { button = Button, label = FontString }
local pageFrames = {} -- id -> Frame
local pageRefreshers = {} -- id -> fn（locale 切换后按页重建文案）
local labelRefs = {}  -- { fs = FontString, update = fn }
local currentPage

function Settings.RegisterPage(id, def)
    assert(type(id) == "string" and id ~= "", "invalid settings page id")
    assert(type(def) == "table" and type(def.build) == "function", "invalid settings page: " .. id)
    if pages[id] then return end
    pages[id] = def
    pageOrder[#pageOrder + 1] = id
end

local function addLabel(parent, key, x, y)
    local fs = Widgets.Text(parent, L[key], "body")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    labelRefs[#labelRefs + 1] = { fs = fs, update = function() fs:SetText(L[key]) end }
    return fs
end

local function addCustomLabel(parent, text, role, x, y)
    local fs = Widgets.Text(parent, text, role)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    labelRefs[#labelRefs + 1] = { fs = fs, update = function() fs:SetText(text) end }
    return fs
end

local function markSelection(buttons, isSelected)
    for i = 1, #buttons do
        local btn = buttons[i]
        btn.themedLabel:SetText((isSelected(i) and "● " or "  ") .. btn.rawLabel)
    end
end

-- 页面构建器（内建 4 页；后续模块经 RegisterPage 扩展）
local function buildAppearance(parent)
    addLabel(parent, "SETTINGS_PALETTE", 0, -4)
    local names = { "starblue", "teal", "amber", "amethyst", "rose", "moss", "graphite" }
    local buttons = {}
    local function current()
        local cur = Theme.GetPalette()
        for i, name in ipairs(names) do
            if name == cur then return i end
        end
        return 1
    end
    for i, name in ipairs(names) do
        local btn = Widgets.Button(parent, name)
        btn.rawLabel = name
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -26 - (i - 1) * 26)
        btn:SetSize(150, 22)
        btn:SetScript("OnClick", function()
            Theme.SetPalette(name)
            markSelection(buttons, current)
        end)
        buttons[i] = btn
    end
    markSelection(buttons, current)
    local hint = Widgets.Text(parent, L.SETTINGS_HINT, "label")
    hint:SetPoint("TOPLEFT", parent, "TOPLEFT", 170, -26)
    labelRefs[#labelRefs + 1] = { fs = hint, update = function() hint:SetText(L.SETTINGS_HINT) end }
end

local function buildLanguage(parent)
    addLabel(parent, "SETTINGS_LOCALE", 0, -4)
    local choices = { { id = "auto", labelKey = "SETTINGS_LOCALE_AUTO" },
                      { id = "enUS", label = "enUS" }, { id = "zhCN", label = "zhCN" } }
    local buttons = {}
    local function current()
        local cur = Locale.Get()
        for i, choice in ipairs(choices) do
            if choice.id == cur then return i end
        end
        return 1
    end
    for i, choice in ipairs(choices) do
        local btn = Widgets.Button(parent, choice.label or L[choice.labelKey])
        btn.rawLabel = choice.label or L[choice.labelKey]
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -26 - (i - 1) * 26)
        btn:SetSize(150, 22)
        btn:SetScript("OnClick", function()
            Locale.Set(choice.id)
            markSelection(buttons, current)
        end)
        buttons[i] = btn
    end
    markSelection(buttons, current)
    pageRefreshers.language = function()
        for i, choice in ipairs(choices) do
            buttons[i].rawLabel = choice.label or L[choice.labelKey]
        end
        markSelection(buttons, current)
    end
end

local function buildModules(parent)
    local y = -4
    for _, module in ipairs(OpenUI.moduleOrder) do
        if module.name ~= "Core" then
            local name = module.name
            local toggle = Widgets.Toggle(parent, name,
                function() return OpenUI:IsModuleEnabled(name) end,
                function(want)
                    if want then
                        OpenUI:EnableModule(name)
                    else
                        OpenUI:DisableModule(name)
                    end
                end)
            toggle:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
            toggle:SetSize(220, 22)
            y = y - 26
        end
    end
end

local function buildAbout(parent)
    local versionLabel = addCustomLabel(parent, L.VERSION_LINE:format(OpenUI.version), "body", 0, -4)
    local names = {}
    for _, module in ipairs(OpenUI.moduleOrder) do
        names[#names + 1] = module.name
    end
    local modulesLabel = addCustomLabel(parent, L.MODULES_LINE:format(table.concat(names, ", ")), "body", 0, -28)
    local errorsLabel = addCustomLabel(parent, L.SETTINGS_ERRORS_COUNT:format(#OpenUI.Diagnose.Errors()), "body", 0, -52)
    pageRefreshers.about = function()
        versionLabel:SetText(L.VERSION_LINE:format(OpenUI.version))
        modulesLabel:SetText(L.MODULES_LINE:format(table.concat(names, ", ")))
        errorsLabel:SetText(L.SETTINGS_ERRORS_COUNT:format(#OpenUI.Diagnose.Errors()))
    end
end

Settings.RegisterPage("appearance", {
    labelKey = "SETTINGS_PAGE_APPEARANCE",
    keywords = { "SETTINGS_PALETTE" },
    build = buildAppearance,
})
Settings.RegisterPage("language", {
    labelKey = "SETTINGS_PAGE_LANGUAGE",
    keywords = { "SETTINGS_LOCALE", "SETTINGS_LOCALE_AUTO" },
    build = buildLanguage,
})
Settings.RegisterPage("modules", {
    labelKey = "SETTINGS_PAGE_MODULES",
    keywords = {},
    build = buildModules,
})
Settings.RegisterPage("about", {
    labelKey = "SETTINGS_PAGE_ABOUT",
    keywords = { "VERSION_LINE", "MODULES_LINE" },
    build = buildAbout,
})

local function ensurePage(id)
    local pf = pageFrames[id]
    if pf then return pf end
    pf = CreateFrame("Frame", nil, contentHost)
    pf:SetAllPoints(contentHost)
    pages[id].build(pf)
    pageFrames[id] = pf
    return pf
end

function Settings.ShowPage(id)
    if not pages[id] then return end
    for pid, pf in pairs(pageFrames) do
        if pid == id then pf:Show() else pf:Hide() end
    end
    local pf = ensurePage(id)
    pf:Show()
    if pageRefreshers[id] then pageRefreshers[id]() end
    currentPage = id
end

function Settings.ApplyFilter(query)
    query = (query or ""):lower()
    local any = false
    for _, id in ipairs(pageOrder) do
        local def = pages[id]
        local hit = query == ""
        if not hit then
            local label = (L[def.labelKey] or id):lower()
            if label:find(query, 1, true) then
                hit = true
            elseif def.keywords then
                for _, key in ipairs(def.keywords) do
                    if (L[key] or key):lower():find(query, 1, true) then
                        hit = true
                        break
                    end
                end
            end
        end
        local nav = navButtons[id]
        if nav then
            if hit then nav.button:Show() else nav.button:Hide() end
        end
        if hit then any = true end
    end
    if noResultsText then
        if (not any) and query ~= "" then noResultsText:Show() else noResultsText:Hide() end
    end
end

local function build()
    if frame then return end
    frame = Widgets.Panel(UIParent, { name = "OpenUISettings" })
    frame:SetSize(560, 380)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local title = Widgets.Text(frame, L.SETTINGS_TITLE, "headline")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -12)
    labelRefs[#labelRefs + 1] = { fs = title, update = function() title:SetText(L.SETTINGS_TITLE) end }

    local close = Widgets.Button(frame, L.SETTINGS_CLOSE)
    close.rawLabel = L.SETTINGS_CLOSE
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -10)
    close:SetSize(72, 22)
    close:SetScript("OnClick", function() Settings.Close() end)
    labelRefs[#labelRefs + 1] = { fs = close.themedLabel, update = function()
        close.themedLabel:SetText(L.SETTINGS_CLOSE)
    end }

    local searchLabel = Widgets.Text(frame, L.SETTINGS_SEARCH, "label")
    searchLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -46)
    labelRefs[#labelRefs + 1] = { fs = searchLabel, update = function() searchLabel:SetText(L.SETTINGS_SEARCH) end }
    searchBox = CreateFrame("EditBox", nil, frame)
    searchBox:SetAutoFocus(false)
    searchBox:SetText("")
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -64)
    searchBox:SetSize(140, 20)
    searchBox:SetScript("OnTextChanged", function(self)
        Settings.ApplyFilter(self:GetText())
    end)

    local y = -94
    for _, id in ipairs(pageOrder) do
        local btn = Widgets.Button(frame, L[pages[id].labelKey])
        btn.rawLabel = L[pages[id].labelKey]
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, y)
        btn:SetSize(140, 24)
        btn:SetScript("OnClick", function() Settings.ShowPage(id) end)
        navButtons[id] = { button = btn, label = btn.themedLabel }
        labelRefs[#labelRefs + 1] = { fs = btn.themedLabel, update = function()
            btn.themedLabel:SetText(L[pages[id].labelKey])
        end }
        y = y - 28
    end

    contentHost = CreateFrame("Frame", nil, frame)
    contentHost:SetPoint("TOPLEFT", frame, "TOPLEFT", 176, -94)
    contentHost:SetSize(368, 270)
    noResultsText = Widgets.Text(contentHost, L.SETTINGS_NO_RESULTS, "body")
    noResultsText:SetPoint("TOPLEFT", contentHost, "TOPLEFT", 0, 0)
    noResultsText:Hide()
    labelRefs[#labelRefs + 1] = { fs = noResultsText, update = function()
        noResultsText:SetText(L.SETTINGS_NO_RESULTS)
    end }

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "OpenUISettings")
    end
    Settings.ShowPage(pageOrder[1])
end

function Settings.Open()
    build()
    frame:Show()
end

function Settings.Close()
    if frame then frame:Hide() end
end

-- locale 切换后刷新窗口文案（由 Locale.Set 调用；未开窗时零成本）。
function Settings.Refresh()
    if not frame then return end
    for i = 1, #labelRefs do
        labelRefs[i].update()
    end
    if currentPage and pageRefreshers[currentPage] then pageRefreshers[currentPage]() end
    Widgets.Refresh()
end

function Settings.IsOpen()
    return frame ~= nil and frame:IsShown()
end

OpenUI.Settings = Settings