-- 共享外观重绘助手（#17 引入，B1 各界面票复用）：对命名原生帧应用主题
-- 背景/边框/字号并记录原值，Restore 逐项恢复；配色切换经 RefreshAll 原地换色。
-- 全部 setter 存在性守卫（客户端差异零崩溃）；仅改颜色/字体（非受保护操作）。

local _, ns = ...
local OpenUI = ns.OpenUI
local Theme = OpenUI.Theme

local Restyle = {}
local records = {} -- 模块名 -> { names = {...}, frames = { [帧] = 原值记录 } }

local function applyFrame(frame, record)
    local bg = Theme.Get("color.surface")
    if type(frame.SetBackdropColor) == "function" and bg then
        local alpha = Theme.Get("opacity.panel") or 1
        frame:SetBackdropColor(bg[1], bg[2], bg[3], alpha)
    end
    local border = Theme.Get("color.outline-variant")
    if type(frame.SetBackdropBorderColor) == "function" and border then
        frame:SetBackdropBorderColor(border[1], border[2], border[3], 1)
    end
    local body = Theme.Get("type.body")
    if type(frame.SetFont) == "function" and record.font and type(body) == "table" then
        frame:SetFont(record.font[1], body.size, record.font[3])
    end
end

-- 应用：names 中当前存在的帧（不存在跳过，后续 ADDON_LOADED 重应用时再取）
function Restyle.Apply(module, names)
    local entry = records[module]
    if not entry then
        entry = { names = names, frames = {} }
        records[module] = entry
    end
    for _, name in ipairs(names) do
        local frame = _G[name]
        if frame then
            local record = entry.frames[frame]
            if not record then
                record = {}
                if type(frame.GetBackdropColor) == "function" then
                    local r, g, b, a = frame:GetBackdropColor()
                    if r then record.bg = { r, g, b, a } end
                end
                if type(frame.GetBackdropBorderColor) == "function" then
                    local r, g, b, a = frame:GetBackdropBorderColor()
                    if r then record.border = { r, g, b, a } end
                end
                if type(frame.GetFont) == "function" then
                    local file, size, flags = frame:GetFont()
                    if file then record.font = { file, size, flags } end
                end
                entry.frames[frame] = record
            end
            applyFrame(frame, record)
        end
    end
end

-- 恢复：逐项还原记录原值并清除记账。
function Restyle.Restore(module)
    local entry = records[module]
    if not entry then return end
    for frame, record in pairs(entry.frames) do
        if record.bg and type(frame.SetBackdropColor) == "function" then
            frame:SetBackdropColor(record.bg[1], record.bg[2], record.bg[3], record.bg[4])
        end
        if record.border and type(frame.SetBackdropBorderColor) == "function" then
            frame:SetBackdropBorderColor(record.border[1], record.border[2], record.border[3], record.border[4])
        end
        if record.font and type(frame.SetFont) == "function" then
            frame:SetFont(record.font[1], record.font[2], record.font[3])
        end
    end
    records[module] = nil
end

-- 配色切换后全部模块重应用（Theme rebuild 钩子调用）。
function Restyle.RefreshAll()
    for _, entry in pairs(records) do
        for _, name in ipairs(entry.names) do
            local frame = _G[name]
            local record = frame and entry.frames[frame]
            if frame and record then applyFrame(frame, record) end
        end
    end
end

OpenUI.Restyle = Restyle