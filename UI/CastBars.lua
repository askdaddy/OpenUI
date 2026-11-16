-- 施法条 T1（#14）：玩家/目标施法条（名称/进度/剩余秒；引导反向进度），主题化。
-- 复用 OpenUI.Native 隐藏原生 CastingBarFrame/TargetFrameSpellBar，关闭恢复。
-- 焦点/宠物施法条分期保持原生；读取 UnitCastingInfo/UnitChannelInfo 全守卫。

local _, ns = ...
local OpenUI = ns.OpenUI
local Theme = OpenUI.Theme
local Widgets = OpenUI.Widgets
local Native = OpenUI.Native

local CastBars = {}
local built, eventsRegistered = false, false
local player = {}
local target = {}
local ticker

local NATIVE_FRAMES = { "PlayerCastingBarFrame", "CastingBarFrame", "TargetFrameSpellBar" }
local BAR_WIDTH, BAR_HEIGHT = 240, 14

local function safe(fn, ...)
    if type(fn) == "function" then return fn(...) end
end

local function try(fn, fallback)
    return (OpenUI.Try and OpenUI.Try(fn, fallback)) or fallback
end

local function castInfo(unit)
    -- 返回 name, startTime, endTime, isChannel（无施法 nil）
    local name, _, _, startTime, endTime = safe(UnitCastingInfo, unit)
    local isChannel = false
    if not name then
        name, _, _, startTime, endTime = safe(UnitChannelInfo, unit)
        if name then isChannel = true end
    end
    if not name or not startTime or not endTime then return nil end
    -- Secret Values：毫秒→秒换算可能抛错 → 时间未知，仅显示名称
    local startSec = try(function() return startTime / 1000 end, nil)
    local endSec = try(function() return endTime / 1000 end, nil)
    return name, startSec, endSec, isChannel
end

local function updateUnit(parts, unit)
    local name, startTime, endTime, isChannel = castInfo(unit)
    local now = (type(GetTime) == "function" and GetTime()) or 0
    if not name then
        if parts.shownCast then parts.frame:Hide() end
        parts.shownCast = false
        return
    end
    parts.shownCast = true
    parts.frame:Show()
    parts.name:SetText(name .. (isChannel and " (引导)" or ""))
    if not startTime or not endTime then
        -- 时间不可用（secret）：静态半条 + 无秒数
        parts.bar:SetSize(BAR_WIDTH * 0.5, BAR_HEIGHT)
        parts.bar.openuiRatio = 0.5
        parts.text:SetText("")
        return
    end
    local progress = try(function()
        local total = math.max(endTime - startTime, 0.001)
        local elapsed = math.max(0, math.min(now - startTime, total))
        local ratio = elapsed / total
        if isChannel then ratio = 1 - ratio end
        return ratio
    end, nil)
    if not progress then
        parts.bar:SetSize(BAR_WIDTH * 0.5, BAR_HEIGHT)
        parts.bar.openuiRatio = 0.5
        parts.text:SetText("")
        return
    end
    parts.bar:SetSize(BAR_WIDTH * progress, BAR_HEIGHT)
    parts.bar.openuiRatio = progress
    parts.text:SetText(try(function() return ("%.1fs"):format(endTime - now) end, ""))
end

function CastBars.UpdatePlayer() if player.frame then updateUnit(player, "player") end end
function CastBars.UpdateTarget() if target.frame then updateUnit(target, "target") end end
function CastBars.UpdateAll()
    CastBars.UpdatePlayer()
    CastBars.UpdateTarget()
end

local function buildUnit(point, name)
    local frame = Widgets.Panel(UIParent, { name = name })
    frame:SetSize(BAR_WIDTH + 8, 34)
    frame:SetPoint(point[1], UIParent, point[2], point[3], point[4])
    frame:Hide()
    local label = Widgets.Text(frame, "", "label")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -2)
    local track = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    track:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -16)
    track:SetSize(BAR_WIDTH, BAR_HEIGHT)
    local bar = frame:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    bar:SetSize(0, BAR_HEIGHT)
    local text = Widgets.Text(frame, "", "label")
    text:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -16)
    -- #56/#69：进度条 1px 暗描边（四边正确边线）
    local barEdge = {}
    if OpenUI.Widgets and OpenUI.Widgets.Edge then
        local dark = { 0, 0, 0 }
        for _, side in ipairs({ "top", "bottom", "left", "right" }) do
            local t = OpenUI.Widgets.Edge(track, side, dark, 0.7)
            if t then barEdge[#barEdge + 1] = t end
        end
    end
    return { frame = frame, name = label, track = track, bar = bar, text = text, barEdge = barEdge, shownCast = false }
end

local function build()
    if built then return end
    built = true
    player = buildUnit({ "TOPLEFT", "TOPLEFT", 20, -140 }, "OpenUIPlayerCastBar")
    target = buildUnit({ "TOPLEFT", "TOPLEFT", 20, -180 }, "OpenUITargetCastBar")
    local function paint(parts)
        local track = Theme.Get("color.surface-container-highest")
        parts.track:SetColorTexture(track[1], track[2], track[3], 1)
        local primary = Theme.Get("color.primary")
        if Widgets.GradientFill then
            Widgets.GradientFill(parts.bar, primary)
        else
            parts.bar:SetColorTexture(primary[1], primary[2], primary[3], 1)
        end
    end
    paint(player)
    paint(target)
    CastBars._paint = paint
    -- #50：统一拖拽 + 主题刷新
    Widgets.MakeDraggable(player.frame, "castbars", "player", { "TOPLEFT", "TOPLEFT", 20, -140 })
    Widgets.MakeDraggable(target.frame, "castbars", "target", { "TOPLEFT", "TOPLEFT", 20, -180 })
    if Theme.RegisterRefresh then
        Theme.RegisterRefresh(function()
            if built then
                paint(player)
                paint(target)
            end
        end)
    end
end

function CastBars.OnEnable()
    build()
    if not eventsRegistered then
        eventsRegistered = true
        local own = OpenUI.Own("CastBars")
        for _, event in ipairs({
            "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_INTERRUPTED",
            "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
            "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
            "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
        }) do
            own:On(event, function() CastBars.UpdateAll() end)
        end
        ticker = own:Every(0.1, function() CastBars.UpdateAll() end)
    end
    Native.Hide("CastBars", NATIVE_FRAMES)
end

function CastBars.OnDisable()
    eventsRegistered = false -- #6 Release 释放事件与定时器
    ticker = nil
    if player.frame then player.frame:Hide() end
    if target.frame then target.frame:Hide() end
    Native.Restore("CastBars")
end

CastBars.Player = function() return player end
CastBars.Target = function() return target end

OpenUI.CastBars = CastBars

OpenUI:RegisterModule("CastBars", {
    defaultEnabled = false,
    OnEnable = function() CastBars.OnEnable() end,
    OnDisable = function() CastBars.OnDisable() end,
})