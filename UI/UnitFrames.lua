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

local function try(fn, fallback)
    return (OpenUI.Try and OpenUI.Try(fn, fallback)) or fallback
end

local function classColor(unit)
    local ok, color = pcall(function()
        local class = UnitClass(unit)
        local colors = _G.RAID_CLASS_COLORS
        if class and type(colors) == "table" and type(colors[class]) == "table" then
            local c = colors[class]
            return { c.r or c[1], c.g or c[2], c.b or c[3], 1 }
        end
        return nil
    end)
    if ok and color then return color end
    local primary = Theme.Get("color.primary")
    return { primary[1], primary[2], primary[3], 1 }
end

local function reactionColor(unit)
    local reaction = try(function() return UnitReaction(unit, "player") end, nil)
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
    if color then
        -- #55：上亮下暗渐变填充（ElvUI gloss 等价，纯内置；不可用时降级纯色）
        if Widgets.GradientFill then
            Widgets.GradientFill(bar, color)
        else
            bar:SetColorTexture(color[1], color[2], color[3], 1)
        end
    end
    bar:SetSize((width or 208) * ratio, height or 10)
    bar.openuiRatio = ratio
end

local function buildUnitFrame(point, label)
    local frame = Widgets.Panel(UIParent, { name = label })
    frame:SetSize(220, 46)
    frame:SetPoint(point[1], UIParent, point[2], point[3], point[4])
    local name = Widgets.Text(frame, "", "label")
    name:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -4)
    local healthBg = frame:CreateTexture(nil, "BACKGROUND")
    healthBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -20)
    healthBg:SetSize(208, 10)
    local health = frame:CreateTexture(nil, "ARTWORK")
    health:SetPoint("TOPLEFT", healthBg, "TOPLEFT", 0, 0)
    health:SetSize(208, 10)
    local healthText = Widgets.Text(frame, "", "label")
    healthText:SetPoint("CENTER", healthBg, "CENTER", 0, 0)
    local powerBg = frame:CreateTexture(nil, "BACKGROUND")
    powerBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -36)
    powerBg:SetSize(208, 6)
    local power = frame:CreateTexture(nil, "ARTWORK")
    power:SetPoint("TOPLEFT", powerBg, "TOPLEFT", 0, 0)
    power:SetSize(208, 6)
    -- #56：条外 1px 暗描边（黑 ×0.7，参照效果图）
    local function barEdge(anchor, width, height)
        local tex = frame:CreateTexture(nil, "BORDER")
        tex:SetColorTexture(0, 0, 0, 0.7)
        tex:SetPoint("TOPLEFT", anchor, "TOPLEFT", -1, 1)
        tex:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 1, -1)
        return tex
    end
    local healthEdge = barEdge(healthBg)
    local powerEdge = barEdge(powerBg)
    return {
        frame = frame, name = name,
        health = health, healthBg = healthBg, healthText = healthText,
        power = power, powerBg = powerBg,
        healthEdge = healthEdge, powerEdge = powerEdge,
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
    local displayName = try(function()
        local name = UnitName(unit)
        if type(name) == "string" then return name end
        return ""
    end, "")
    pcall(function() parts.name:SetText(displayName or "") end)
    local hp = safe(UnitHealth, unit)
    local hpMax = safe(UnitHealthMax, unit)
    local pp = safe(UnitPower, unit)
    local ppMax = safe(UnitPowerMax, unit)
    -- Secret Values 兼容：除法/格式化可能抛错 → 降级为空条与空文本
    local healthRatio = try(function() return hpMax > 0 and hp / hpMax or 0 end, 0)
    local powerRatio = try(function() return ppMax > 0 and pp / ppMax or 0 end, 0)
    local healthText = try(function() return ("%d / %d"):format(hp, hpMax) end, "")
    setBar(parts.health, healthRatio, try(function() return colorFor(unit) end, nil), 208, 10)
    setBar(parts.power, powerRatio, Theme.Get("color.primary"), 208, 6)
    parts.healthText:SetText(healthText or "")
    parts.frame.openuiHealthRatio = healthRatio or 0
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
    player = buildUnitFrame({ "TOPLEFT", "TOPLEFT", 20, -24 }, "OpenUIPlayerFrame")
    target = buildUnitFrame({ "TOPLEFT", "TOPLEFT", 20, -76 }, "OpenUITargetFrame")
    playerFrame, targetFrame = player.frame, target.frame
    paintStatic(player)
    paintStatic(target)
    -- #50：统一 Alt+左键拖拽与位置持久化
    Widgets.MakeDraggable(playerFrame, "unitframes", "player", { "TOPLEFT", "TOPLEFT", 20, -24 })
    Widgets.MakeDraggable(targetFrame, "unitframes", "target", { "TOPLEFT", "TOPLEFT", 20, -76 })
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

-- #50：配色切换后重绘静态底纹与能量条颜色
function UnitFrames.ApplyTheme()
    if not built then return end
    for _, parts in ipairs({ player, target }) do
        if parts.frame then
            paintStatic(parts)
            local primary = Theme.Get("color.primary")
            if primary then
                if Widgets.GradientFill then
                    Widgets.GradientFill(parts.power, primary)
                else
                    parts.power:SetColorTexture(primary[1], primary[2], primary[3], 1)
                end
            end
        end
    end
end

if Theme.RegisterRefresh then Theme.RegisterRefresh(UnitFrames.ApplyTheme) end

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