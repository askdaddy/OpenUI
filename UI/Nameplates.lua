-- 名牌 T1（#16）：经 NAME_PLATE_CREATED / NAME_PLATE_UNIT_ADDED 对名牌应用主题外观。
-- 仅改纹理颜色/文本属性（非受保护）；结构不可识别时零操作零报错（守卫访问）。
-- 关闭模块停止应用新牌（已应用保持到刷新，已知限制）；连击点/资源/仇恨增强分期。

local _, ns = ...
local OpenUI = ns.OpenUI
local Theme = OpenUI.Theme

local Nameplates = {}
local eventsRegistered = false
local restyled = 0

local function safe(fn, ...)
    if type(fn) == "function" then return fn(...) end
end

local function setColor(texture, token)
    if type(texture) ~= "table" or type(texture.SetColorTexture) ~= "function" then return end
    local color = Theme.Get(token)
    if type(color) == "table" then
        texture:SetColorTexture(color[1], color[2], color[3], 1)
    end
end
Nameplates._setColor = setColor

local function reactionToken(unit)
    local ok, token = pcall(function()
        local reaction = UnitReaction(unit, "player")
        if reaction >= 5 then return "color.secondary" end
        if reaction == 4 then return "color.tertiary" end
        return "color.error"
    end)
    if ok and token then return token end
    return "color.secondary"
end

local function restylePlate(plate, unit)
    local unitFrame = type(plate) == "table" and plate.UnitFrame
    if type(unitFrame) ~= "table" then return false end
    local healthBar = unitFrame.healthBar or unitFrame.HealthBar
    if type(healthBar) == "table" then
        if type(healthBar.GetStatusBarTexture) == "function" then
            local texture = healthBar:GetStatusBarTexture()
            setColor(texture, reactionToken(unit))
        end
        if type(healthBar.SetStatusBarColor) == "function" then
            local color = Theme.Get(reactionToken(unit))
            healthBar:SetStatusBarColor(color[1], color[2], color[3], 1)
        end
    end
    local name = unitFrame.Name or unitFrame.name
    if type(name) == "table" then
        local label = Theme.Get("type.label")
        if type(label) == "table" and type(name.SetFont) == "function" then
            local file
            if type(name.GetFont) == "function" then
                file = name:GetFont()
            end
            if file then name:SetFont(file, label.size) end
        end
    end
    return true
end

function Nameplates.OnEnable()
    if eventsRegistered then return end
    eventsRegistered = true
    local own = OpenUI.Own("Nameplates")
    own:On("NAME_PLATE_CREATED", function(plate)
        if restylePlate(plate, plate.namePlateUnitToken or "target") then
            restyled = restyled + 1
        end
    end)
    own:On("NAME_PLATE_UNIT_ADDED", function(plate, unitToken)
        if restylePlate(plate, unitToken or "target") then
            restyled = restyled + 1
        end
    end)
end

function Nameplates.OnDisable()
    eventsRegistered = false -- #6 Release 释放事件；已应用外观不强制还原（已知限制）
end

Nameplates.RestyledCount = function() return restyled end
Nameplates.RestylePlate = function(plate, unit) return restylePlate(plate, unit) end

OpenUI.Nameplates = Nameplates

OpenUI:RegisterModule("Nameplates", {
    defaultEnabled = false,
    OnEnable = function() Nameplates.OnEnable() end,
    OnDisable = function() Nameplates.OnDisable() end,
})