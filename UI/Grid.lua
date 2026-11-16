-- 布局网格（#52）：全屏网格覆盖层 + 中心轴线 + 可调尺寸 + 拖拽吸附定位。
-- 入口：/openui grid 切换；主控面板「布局网格」模块小窗（显示/尺寸/吸附）。
-- 吸附：Widgets.MakeDraggable 拖拽结束时按最近网格取整（网格显示时）。

local _, ns = ...
local OpenUI = ns.OpenUI
local Theme = OpenUI.Theme
local L = OpenUI.L
local Widgets = OpenUI.Widgets

local Grid = {}
local SIZES = { 32, 48, 64 }
local DEFAULT_SIZE = 48
local REST_ALPHA = 0.45
local fadeTarget, fadeTicker
local editActive = false

local frame
local segmentList = {}

local function activeConfig()
    if OpenUI.Profile and OpenUI.Profile.Config then
        local cfg = OpenUI.Profile.Config()
        if type(cfg) == "table" then return cfg end
    end
    if type(_G.OpenUIDB) ~= "table" then _G.OpenUIDB = {} end
    return _G.OpenUIDB
end

local function gridConfig()
    local cfg = activeConfig()
    if type(cfg.grid) ~= "table" then cfg.grid = {} end
    local g = cfg.grid
    if type(g.size) ~= "number" then g.size = DEFAULT_SIZE end
    if g.snap == nil then g.snap = true end
    if g.shown == nil then g.shown = false end
    return g
end

function Grid.GetSize()
    return gridConfig().size
end

function Grid.SetSize(size)
    if type(size) ~= "number" or size < 4 or size > 256 then return false end
    gridConfig().size = size
    Grid.Rebuild()
    return true
end

function Grid.CycleSize()
    local cur = Grid.GetSize()
    local idx = 1
    for i, value in ipairs(SIZES) do
        if value == cur then idx = i end
    end
    local nextSize = SIZES[idx % #SIZES + 1]
    Grid.SetSize(nextSize)
    return nextSize
end

function Grid.IsSnapEnabled()
    return gridConfig().snap and true or false
end

function Grid.SetSnap(value)
    gridConfig().snap = value and true or false
end

function Grid.ToggleSnap()
    local value = not Grid.IsSnapEnabled()
    Grid.SetSnap(value)
    return value
end

-- 最近网格取整（BOTTOMLEFT 坐标系原点）
function Grid.Snap(x, y)
    if not Grid.IsSnapEnabled() or type(x) ~= "number" or type(y) ~= "number" then
        return x, y
    end
    local size = Grid.GetSize()
    local function round(v)
        return math.floor(v / size + 0.5) * size
    end
    return round(x), round(y)
end

local function paintSegments()
    local border = Theme.Get("color.outline-variant")
    local accent = Theme.Get("color.primary")
    for _, seg in ipairs(segmentList) do
        if type(seg.tex.SetColorTexture) == "function" then
            if seg.center and accent then
                -- 中心轴高亮（参照 ElvUI 的红色中线思路，用主题主色）
                seg.tex:SetColorTexture(accent[1], accent[2], accent[3], 0.35)
            elseif border then
                seg.tex:SetColorTexture(border[1], border[2], border[3], 0.15)
            end
        end
    end
end

local function buildOverlay()
    if frame then return end
    frame = CreateFrame("Frame", "OpenUIGrid", UIParent)
    frame:SetAllPoints(UIParent)
    frame:Hide()
    if type(frame.EnableMouse) == "function" then frame:EnableMouse(false) end
    if type(frame.SetFrameStrata) == "function" then frame:SetFrameStrata("BACKGROUND") end
end

function Grid.Rebuild()
    buildOverlay()
    for _, seg in ipairs(segmentList) do
        if type(seg.tex.Hide) == "function" then seg.tex:Hide() end
    end
    segmentList = {}
    local w = (type(GetScreenWidth) == "function" and GetScreenWidth()) or 1024
    local h = (type(GetScreenHeight) == "function" and GetScreenHeight()) or 768
    local size = Grid.GetSize()
    local x = 0
    while x <= w do
        local tex = frame:CreateTexture(nil, "BACKGROUND")
        local width = math.abs(x - w / 2) < 1 and 2 or 1
        if type(tex.SetSize) == "function" then tex:SetSize(width, h) end
        tex:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
        segmentList[#segmentList + 1] = { tex = tex, center = width == 2 }
        x = x + size
    end
    local y = 0
    while y <= h do
        local tex = frame:CreateTexture(nil, "BACKGROUND")
        local height = math.abs(y - h / 2) < 1 and 2 or 1
        if type(tex.SetSize) == "function" then tex:SetSize(w, height) end
        tex:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)
        segmentList[#segmentList + 1] = { tex = tex, center = height == 2 }
        y = y + size
    end
    paintSegments()
    return #segmentList
end

function Grid.IsShown()
    return frame ~= nil and frame:IsShown()
end

-- 拖拽淡入淡出（参照 ElvUI Movers 的 UIFrameFadeIn/Out）
local function fadeTo(target)
    if not frame or type(frame.SetAlpha) ~= "function" then return end
    fadeTarget = target
    local own = OpenUI.Own("Grid")
    if fadeTicker then
        if type(fadeTicker.Cancel) == "function" then fadeTicker:Cancel() end
        fadeTicker = nil
    end
    local alpha = (type(frame.GetAlpha) == "function" and frame:GetAlpha()) or REST_ALPHA
    if math.abs(alpha - target) < 0.02 then
        frame:SetAlpha(target)
        return
    end
    fadeTicker = own:Every(0.05, function()
        local current = (type(frame.GetAlpha) == "function" and frame:GetAlpha()) or target
        local step = (target > current) and 0.15 or -0.15
        current = current + step
        if (target > alpha and current >= target) or (target <= alpha and current <= target) then
            frame:SetAlpha(target)
            if fadeTicker and type(fadeTicker.Cancel) == "function" then fadeTicker:Cancel() end
            fadeTicker = nil
        else
            frame:SetAlpha(current)
        end
    end)
end

function Grid.NotifyDragStart()
    if not Grid.IsShown() then return end
    fadeTo(1)
end

function Grid.NotifyDragEnd()
    if not Grid.IsShown() then return end
    fadeTo(editActive and 1 or REST_ALPHA)
end

function Grid.SetActiveEditing(value)
    editActive = value and true or false
    if not frame or not Grid.IsShown() then return end
    if type(frame.SetAlpha) == "function" then frame:SetAlpha(editActive and 1 or REST_ALPHA) end
end

function Grid.Show()
    buildOverlay()
    if #segmentList == 0 then Grid.Rebuild() end
    frame:Show()
    if type(frame.SetAlpha) == "function" then frame:SetAlpha(REST_ALPHA) end
    gridConfig().shown = true
end

function Grid.Hide()
    if frame then frame:Hide() end
    gridConfig().shown = false
end

function Grid.Toggle()
    if Grid.IsShown() then
        Grid.Hide()
    else
        Grid.Show()
    end
    return Grid.IsShown()
end

function Grid.SegmentCount()
    return #segmentList
end

-- 设置面板模块小窗
local function registerSettingsPanel()
    if type(OpenUI.Settings) ~= "table" or type(OpenUI.Settings.RegisterModulePanel) ~= "function" then
        return
    end
    OpenUI.Settings.RegisterModulePanel("Grid", {
        build = function(host)
            local y = -2
            local displayToggle = Widgets.Toggle(host, "SETTINGS_GRID_DISPLAY",
                function() return Grid.IsShown() end,
                function(want)
                    if want then Grid.Show() else Grid.Hide() end
                end)
            displayToggle:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y)
            displayToggle:SetSize(220, 24)
            y = y - 28

            local snapToggle = Widgets.Toggle(host, "SETTINGS_GRID_SNAP_LABEL",
                function() return Grid.IsSnapEnabled() end,
                function(want) Grid.SetSnap(want) end)
            snapToggle:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y)
            snapToggle:SetSize(220, 24)
            y = y - 28

            local sizeButton = Widgets.Button(host, L.SETTINGS_GRID_SIZE_FMT:format(Grid.GetSize()))
            sizeButton:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y)
            sizeButton:SetSize(180, 24)
            sizeButton:SetScript("OnClick", function()
                local size = Grid.CycleSize()
                sizeButton.themedLabel:SetText(L.SETTINGS_GRID_SIZE_FMT:format(size))
            end)
            y = y - 28

            local hint = Widgets.Text(host, L.SETTINGS_GRID_HINT, "body")
            hint:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y - 4)
            hint:SetWidth(340)
        end,
    })
end

function Grid.OnEnable()
    Grid.Rebuild()
    if gridConfig().shown then frame:Show() else frame:Hide() end
    if Theme.RegisterRefresh then Theme.RegisterRefresh(paintSegments) end
end

function Grid.OnDisable()
    if frame then frame:Hide() end
end

OpenUI.Grid = Grid

OpenUI:RegisterModule("Grid", {
    defaultEnabled = false,
    OnEnable = function() Grid.OnEnable() end,
    OnDisable = function() Grid.OnDisable() end,
})

registerSettingsPanel()