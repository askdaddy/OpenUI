-- 光环 T1（#15）：玩家 Buff/Debuff 两行图标（图标/层数/剩余时间），主题描边。
-- 复用 OpenUI.Native 隐藏原生 BuffFrame（含临时附魔区），关闭恢复。
-- 目标光环、过滤/排序/施放者标记/点击取消（受保护）分期；UnitBuff/UnitDebuff 全守卫。

local _, ns = ...
local OpenUI = ns.OpenUI
local Theme = OpenUI.Theme
local Widgets = OpenUI.Widgets
local Native = OpenUI.Native

local Auras = {}

local ICON_SIZE, ICON_GAP, MAX_ICONS = 30, 4, 20
local built, eventsRegistered = false, false
local rows = {}
local ticker

local NATIVE_FRAMES = { "BuffFrame", "DebuffFrame" }

local function safe(fn, ...)
    if type(fn) == "function" then return fn(...) end
end

local function try(fn, fallback)
    return (OpenUI.Try and OpenUI.Try(fn, fallback)) or fallback
end

local function collect(kind)
    local query = kind == "Buff" and UnitBuff or UnitDebuff
    local list = {}
    if type(query) == "function" then
        pcall(function()
            for i = 1, 40 do
                local name, _, icon, stacks, _, duration, expiration = query("player", i)
                if not name then break end
                list[#list + 1] = {
                    icon = icon,
                    stacks = tonumber(stacks) or 0,
                    expiration = tonumber(expiration) or 0,
                }
            end
        end)
    end
    return list
end

local function buildRow(kind, point)
    local frame = CreateFrame("Frame", "OpenUI" .. kind .. "Row", UIParent)
    frame:SetSize(MAX_ICONS * (ICON_SIZE + ICON_GAP), ICON_SIZE)
    frame:SetPoint(point[1], UIParent, point[2], point[3], point[4])
    frame:Hide()
    Widgets.MakeDraggable(frame, "auras", kind, point)
    local borderColor = kind == "Buff" and "color.outline" or "color.error"
    local slots = {}
    for i = 1, MAX_ICONS do
        local button = CreateFrame("Button", nil, frame)
        button:SetSize(ICON_SIZE, ICON_SIZE)
        button:SetPoint("LEFT", frame, "LEFT", (i - 1) * (ICON_SIZE + ICON_GAP), 0)
        local border = button:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints(button)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        local count = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        local timeText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        timeText:SetPoint("TOP", button, "BOTTOM", 0, 0)
        local bc = Theme.Get(borderColor)
        border:SetColorTexture(bc[1], bc[2], bc[3], 0.9)
        slots[i] = { button = button, icon = icon, count = count, time = timeText, border = border }
    end
    rows[kind] = { frame = frame, slots = slots, list = {} }
end

local function build()
    if built then return end
    built = true
    buildRow("Buff", { "TOPRIGHT", "TOPRIGHT", -20, -8 })
    buildRow("Debuff", { "TOPRIGHT", "TOPRIGHT", -20, -44 })
end

local function formatRemain(seconds)
    if seconds >= 60 then
        return ("%dm"):format(math.floor(seconds / 60 + 0.5))
    end
    return ("%d"):format(math.floor(seconds + 0.5))
end

local function updateRow(kind)
    local row = rows[kind]
    if not row then return end
    local list = collect(kind)
    local now = (type(GetTime) == "function" and GetTime()) or 0
    for i = 1, MAX_ICONS do
        local slot = row.slots[i]
        local aura = list[i]
        if aura then
            -- Secret Values：图标/层数/时间任何一步抛错 → 该槽降级隐藏
            local ok = pcall(function()
                slot.icon:SetTexture(aura.icon)
                slot.count:SetText(aura.stacks > 1 and tostring(aura.stacks) or "")
                if aura.expiration > 0 then
                    slot.time:SetText(formatRemain(math.max(aura.expiration - now, 0)))
                else
                    slot.time:SetText("")
                end
            end)
            if ok then slot.button:Show() else slot.button:Hide() end
        else
            slot.button:Hide()
        end
    end
    if #list > 0 then row.frame:Show() else row.frame:Hide() end
    row.list = list
end

function Auras.UpdateAll()
    updateRow("Buff")
    updateRow("Debuff")
end

-- #50：配色切换后重绘槽位描边
function Auras.ApplyTheme()
    if not built then return end
    for kind, row in pairs(rows) do
        local token = kind == "Buff" and "color.outline" or "color.error"
        local color = Theme.Get(token)
        for _, slot in ipairs(row.slots) do
            if slot.border and color then
                slot.border:SetColorTexture(color[1], color[2], color[3], 0.8)
            end
        end
    end
end

if Theme.RegisterRefresh then Theme.RegisterRefresh(Auras.ApplyTheme) end

function Auras.OnEnable()
    build()
    if not eventsRegistered then
        eventsRegistered = true
        local own = OpenUI.Own("Auras")
        own:On("UNIT_AURA", function() Auras.UpdateAll() end)
        own:On("PLAYER_ENTERING_WORLD", function() Auras.UpdateAll() end)
        ticker = own:Every(0.5, function() Auras.UpdateAll() end)
    end
    Auras.UpdateAll()
    Native.Hide("Auras", NATIVE_FRAMES)
end

function Auras.OnDisable()
    eventsRegistered = false -- #6 Release 释放事件与定时器
    ticker = nil
    for _, row in pairs(rows) do
        row.frame:Hide()
    end
    Native.Restore("Auras")
end

Auras.Row = function(kind) return rows[kind] end

OpenUI.Auras = Auras

OpenUI:RegisterModule("Auras", {
    defaultEnabled = false,
    OnEnable = function() Auras.OnEnable() end,
    OnDisable = function() Auras.OnDisable() end,
})