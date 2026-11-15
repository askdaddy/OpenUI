-- 单位框体 T1（#13）：玩家/目标框体（名称/生命条+数值/能量条），主题化；
-- 原生 PlayerFrame/TargetFrame 经 OpenUI.Native 隐藏（脱战应用），关闭恢复。
-- 纯展示（T1 不含框体点击选中：受保护交互后续票补）；队友/焦点/ToT/宠物分期保持原生。

local _, ns = ...
local OpenUI = ns.OpenUI
local Theme = OpenUI.Theme
local Widgets = OpenUI.Widgets
local Native = OpenUI.Native

local UnitFrames = {}
local built, eventsRegistered = false, false
local playerFrame, targetFrame
local player = {}
local target = {}

local NATIVE_FRAMES = { "PlayerFrame", "TargetFrame" }

local function safe(fn, ...)
    if type(fn) == "function" then return fn(...) end
end

local function classColor(unit)
    local class = safe(UnitClass, unit)
    local colors = _G.RAID_CLASS_COLORS
    if class and type(colors) == "table" and type(colors[class]) == "table" then
        local c = colors[class]
        return { c.r or c[1], c.g or c[2], c.b or c[3], 1 }
    end
    local primary = Theme.Get("color.primary")
    return { primary[1], primary[2], primary[3], 1 }
end

local function reactionColor(unit)
    local reaction = safe(UnitReaction, unit, "player")
    if type(reaction) == "number" then
        if reaction >= 5 then
            return { 0.29, 0.74, 0.45, 1 }
        elseif reaction == 4 then
            return { 0.85, 0.80, 0.45, 1 }
        end
        return { 0.78, 0.26, 0.26, 1 }
    end
    local secondary = Theme.Get("color.secondary")
    return { secondary[1], secondary[2], secondary[3], 1 }
end

local function setBar(bar, ratio, color, width, height)
    ratio = math.max(0, math.min(1, ratio or 0))
    if color then bar:SetColorTexture(color[1], color[2], color[3], 1) end
    bar:SetSize((width or 208) * ratio, height or 10)
    bar.openuiRatio = ratio
end

local function buildUnitFrame(anchor, label)
    local frame = Widgets.Panel(UIParent, { name = label })
    frame:SetSize(220, 46)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, anchor)
    local name = Widgets.Text(frame, "", "label")
    name:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -4)
    local healthBg = frame:CreateTexture(nil, "BACKGROUND")
    healthBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -20)
    healthBg:SetSize(208, 10)
    local health = frame:CreateTexture(nil, "ARTWORK")
    health:SetPoint("TOPLEFT", healthBg, "TOPLEFT", 0, 0)
    health:SetSize(208, 10)
    local healthText = Widgets.Text(frame, "", "label")
    healthText:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -32)
    local powerBg = frame:CreateTexture(nil, "BACKGROUND")
    powerBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -36)
    powerBg:SetSize(208, 6)
    local power = frame:CreateTexture(nil, "ARTWORK")
    power:SetPoint("TOPLEFT", powerBg, "TOPLEFT", 0, 0)
    power:SetSize(208, 6)
    return {
        frame = frame, name = name,
        health = health, healthBg = healthBg, healthText = healthText,
        power = power, powerBg = powerBg,
    }
end

local function paintStatic(parts)
    local track = Theme.Get("color.surface-container-highest")
    parts.healthBg:SetColorTexture(track[1], track[2], track[3], 1)
    parts.powerBg:SetColorTexture(track[1], track[2], track[3], 1)
end

local function updateUnit(parts, unit, colorFor)
    local exists = safe(UnitExists, unit)
    if not exists then
        parts.name:SetText("")
        parts.healthText:SetText("")
        setBar(parts.health, 0, nil, 208, 10)
        setBar(parts.power, 0, nil, 208, 6)
        return
    end
    local name = safe(UnitName, unit)
    parts.name:SetText(type(name) == "string" and name or "")
    local hp, hpMax = safe(UnitHealth, unit) or 0, safe(UnitHealthMax, unit) or 1
    local pp, ppMax = safe(UnitPower, unit) or 0, safe(UnitPowerMax, unit) or 1
    setBar(parts.health, hpMax > 0 and hp / hpMax or 0, colorFor(unit), 208, 10)
    setBar(parts.power, ppMax > 0 and pp / ppMax or 0, Theme.Get("color.primary"), 208, 6)
    parts.healthText:SetText(("%d / %d"):format(hp, hpMax))
    parts.frame.openuiHealthRatio = hpMax > 0 and hp / hpMax or 0
end

function UnitFrames.UpdatePlayer()
    if player.frame then updateUnit(player, "player", classColor) end
end

function UnitFrames.UpdateTarget()
    if target.frame then updateUnit(target, "target", reactionColor) end
end

local function build()
    if built then return end
    built = true
    player = buildUnitFrame(120, "OpenUIPlayerFrame")
    target = buildUnitFrame(60, "OpenUITargetFrame")
    playerFrame, targetFrame = player.frame, target.frame
    paintStatic(player)
    paintStatic(target)
end

function UnitFrames.OnEnable()
    build()
    if not eventsRegistered then
        eventsRegistered = true
        local own = OpenUI.Own("UnitFrames")
        own:On("PLAYER_ENTERING_WORLD", function() UnitFrames.UpdateAll() end)
        for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE",
                                 "UNIT_NAME_UPDATE", "UNIT_FACTION" }) do
            own:On(event, function() UnitFrames.UpdateAll() end)
        end
        own:On("PLAYER_TARGET_CHANGED", function() UnitFrames.UpdateTarget() end)
    end
    playerFrame:Show()
    targetFrame:Show()
    UnitFrames.UpdateAll()
    Native.Hide("UnitFrames", NATIVE_FRAMES)
end

function UnitFrames.UpdateAll()
    UnitFrames.UpdatePlayer()
    UnitFrames.UpdateTarget()
end

function UnitFrames.OnDisable()
    eventsRegistered = false
    if playerFrame then playerFrame:Hide() end
    if targetFrame then targetFrame:Hide() end
    Native.Restore("UnitFrames")
end

UnitFrames.Player = function() return player end
UnitFrames.Target = function() return target end

OpenUI.UnitFrames = UnitFrames

OpenUI:RegisterModule("UnitFrames", {
    defaultEnabled = false,
    OnEnable = function() UnitFrames.OnEnable() end,
    OnDisable = function() UnitFrames.OnDisable() end,
})