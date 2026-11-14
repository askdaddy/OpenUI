-- 诊断查看窗口（#10）：最近 50 条错误的可复制视图。
-- 错误队列与堆栈采集在 #1 Core.Diagnose；本文件只做展示/复制（多行 EditBox，选中 Ctrl+C）。
-- 不跨会话保留（错误属运行数据，不写 SavedVariables）。

local _, ns = ...
local OpenUI = ns.OpenUI
local L = OpenUI.L
local Widgets = OpenUI.Widgets

local Diagnostics = {}
local frame, editBox, titleLabel, hintLabel

local function formatErrors()
    local recorded = OpenUI.Diagnose.Errors()
    if #recorded == 0 then return L.NO_ERRORS end
    local lines = {}
    for i, err in ipairs(recorded) do
        lines[#lines + 1] = ("%d. %s"):format(i, err)
    end
    return table.concat(lines, "\n")
end

local function build()
    if frame then return end
    frame = Widgets.Panel(UIParent, { name = "OpenUIDiagnostics" })
    frame:SetSize(560, 360)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    titleLabel = Widgets.Text(frame, L.DIAG_TITLE, "headline")
    titleLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -12)

    local close = Widgets.Button(frame, L.SETTINGS_CLOSE)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -10)
    close:SetSize(72, 22)
    close:SetScript("OnClick", function() Diagnostics.Close() end)

    hintLabel = Widgets.Text(frame, L.DIAG_COPY_HINT, "label")
    hintLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -40)

    editBox = CreateFrame("EditBox", nil, frame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -58)
    editBox:SetSize(528, 286)
    editBox:SetText(formatErrors())

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "OpenUIDiagnostics")
    end
end

function Diagnostics.Open()
    build()
    editBox:SetText(formatErrors())
    frame:Show()
end

function Diagnostics.Close()
    if frame then frame:Hide() end
end

function Diagnostics.Refresh()
    if not frame then return end
    titleLabel:SetText(L.DIAG_TITLE)
    hintLabel:SetText(L.DIAG_COPY_HINT)
    editBox:SetText(formatErrors())
end

function Diagnostics.IsOpen()
    return frame ~= nil and frame:IsShown()
end

OpenUI.Diagnostics = Diagnostics

OpenUI:RegisterModule("Diagnostics", {
    OnEnable = function() end,
})