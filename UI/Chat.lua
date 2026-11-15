-- 聊天 T1（#12）：主题化原生聊天框架外观（背景/边框/字体字号 + 输入框背景）。
-- 不重建聊天引擎：消息、超链接、右键菜单、标签交互、滚动全部保留原生行为。
-- OnDisable 逐项恢复启用前原值；全部 setter 存在性守卫。
-- 分期（范围外）：自定义标签视觉、停靠/布局编辑、战斗日志独立窗、频道缩写等增强。

local _, ns = ...
local OpenUI = ns.OpenUI
local Theme = OpenUI.Theme

local Chat = {}
local originals = {} -- 帧 -> { bg = {r,g,b,a}, border = {r,g,b,a}, font = {file, size, flags} }
local eventsRegistered = false

local function targets()
    local list = {}
    local count = tonumber(NUM_CHAT_WINDOWS) or 0
    for i = 1, count do
        local cf = _G["ChatFrame" .. i]
        if cf then list[#list + 1] = cf end
    end
    local editBox = _G.ChatFrame1EditBox
    if editBox then list[#list + 1] = editBox end
    return list
end

local function snapshot(frame)
    local record = originals[frame]
    if record then return record end
    record = {}
    if frame.GetBackdropColor then
        local r, g, b, a = frame:GetBackdropColor()
        if r then record.bg = { r, g, b, a } end
    end
    if frame.GetBackdropBorderColor then
        local r, g, b, a = frame:GetBackdropBorderColor()
        if r then record.border = { r, g, b, a } end
    end
    if frame.GetFont then
        local file, size, flags = frame:GetFont()
        if file then record.font = { file, size, flags } end
    end
    originals[frame] = record
    return record
end

local function applyTo(frame)
    local bg = Theme.Get("color.surface")
    if frame.SetBackdropColor and bg then
        local alpha = Theme.Get("opacity.panel") or 1
        frame:SetBackdropColor(bg[1], bg[2], bg[3], alpha)
    end
    local border = Theme.Get("color.outline-variant")
    if frame.SetBackdropBorderColor and border then
        frame:SetBackdropBorderColor(border[1], border[2], border[3], 1)
    end
    local body = Theme.Get("type.body")
    if frame.SetFont and type(body) == "table" then
        local record = snapshot(frame)
        local file = record.font and record.font[1]
        if file then frame:SetFont(file, body.size, record.font[3]) end
    end
end

local function restoreFrame(frame)
    local record = originals[frame]
    if not record then return end
    if record.bg and frame.SetBackdropColor then
        frame:SetBackdropColor(record.bg[1], record.bg[2], record.bg[3], record.bg[4])
    end
    if record.border and frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(record.border[1], record.border[2], record.border[3], record.border[4])
    end
    if record.font and frame.SetFont then
        frame:SetFont(record.font[1], record.font[2], record.font[3])
    end
end

local function applyAll()
    for _, frame in ipairs(targets()) do
        snapshot(frame)
        applyTo(frame)
    end
end

-- 主题联动钩子：Theme rebuild 后调用（同 Widgets.Refresh 模式）。
function Chat.ApplyTheme()
    if next(originals) == nil then return end
    applyAll()
end

function Chat.OnEnable()
    if not eventsRegistered then
        eventsRegistered = true
        local own = OpenUI.Own("Chat")
        own:On("PLAYER_ENTERING_WORLD", function() Chat.ApplyTheme() end)
    end
    applyAll()
end

function Chat.OnDisable()
    eventsRegistered = false -- #6 Release 已移除名下事件
    for frame in pairs(originals) do
        restoreFrame(frame)
    end
    originals = {}
end

-- 供测试/诊断只读
Chat.Snapshot = function(frame) return originals[frame] end

OpenUI.Chat = Chat

OpenUI:RegisterModule("Chat", {
    OnEnable = function() Chat.OnEnable() end,
    OnDisable = function() Chat.OnDisable() end,
})