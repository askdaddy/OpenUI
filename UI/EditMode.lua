-- 布局编辑模式（#54）：类似原生 Edit Mode —— 网格自动显示、全部可移动组件显示并可**直接拖放**
-- （无需 Alt），每个组件带高亮边框；退出恢复模块启停与网格原状态。位置仍即时持久化。

local _, ns = ...
local OpenUI = ns.OpenUI
local Theme = OpenUI.Theme
local L = OpenUI.L

local EditMode = {}
local active = false
local records

-- 拥有可移动组件的模块（编辑模式下临时启用，便于摆放）
local SECTION_MODULES = { "UnitFrames", "CastBars", "Auras", "ActionBars" }

local function highlightFrame(frame)
    local overlay = frame.openuiEditHighlight
    if not overlay then
        overlay = CreateFrame("Frame", nil, frame)
        overlay:SetAllPoints(frame)
        if type(overlay.SetFrameLevel) == "function" and type(frame.GetFrameLevel) == "function" then
            pcall(function() overlay:SetFrameLevel(frame:GetFrameLevel() + 5) end)
        end
        local primary = Theme.Get("color.primary")
        local function edge(x1, y1, x2, y2)
            local tex = overlay:CreateTexture(nil, "OVERLAY")
            if primary then tex:SetColorTexture(primary[1], primary[2], primary[3], 0.9) end
            tex:SetPoint("TOPLEFT", overlay, "TOPLEFT", x1, y1)
            tex:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", x2, y2)
            return tex
        end
        edge(0, 0, 0, -2)
        edge(0, 2, 0, 0)
        edge(0, 0, 2, 0)
        edge(-2, 0, 0, 0)
        frame.openuiEditHighlight = overlay
    end
    overlay:Show()
end

local function clearHighlights()
    for _, mover in ipairs(OpenUI.Widgets.Movers()) do
        local overlay = mover.frame and mover.frame.openuiEditHighlight
        if overlay then overlay:Hide() end
    end
end

function EditMode.IsActive()
    return active
end

function EditMode.Enter()
    if active then return true end
    active = true
    records = { modules = {}, gridWasShown = OpenUI.Grid and OpenUI.Grid.IsShown() }
    if OpenUI.Grid then
        OpenUI.Grid.Show()
        if OpenUI.Grid.SetActiveEditing then OpenUI.Grid.SetActiveEditing(true) end
    end
    for _, name in ipairs(SECTION_MODULES) do
        if OpenUI.modules[name] then
            local wasEnabled = OpenUI:IsModuleEnabled(name)
            records.modules[name] = wasEnabled
            if not wasEnabled then
                OpenUI:EnableModule(name)
            end
        end
    end
    for _, mover in ipairs(OpenUI.Widgets.Movers()) do
        if mover.frame then
            pcall(function() mover.frame:Show() end)
            highlightFrame(mover.frame)
        end
    end
    return true
end

function EditMode.Exit()
    if not active then return true end
    active = false
    clearHighlights()
    if records then
        for name, wasEnabled in pairs(records.modules) do
            if not wasEnabled then OpenUI:DisableModule(name) end
        end
        if OpenUI.Grid then
            if OpenUI.Grid.SetActiveEditing then OpenUI.Grid.SetActiveEditing(false) end
            if not records.gridWasShown then OpenUI.Grid.Hide() end
        end
    end
    records = nil
    return true
end

function EditMode.Toggle()
    if active then
        EditMode.Exit()
    else
        EditMode.Enter()
    end
    return active
end

OpenUI.EditMode = EditMode
