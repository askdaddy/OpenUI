-- 小地图 T1（#17）：主题化边框环 + 坐标显示（1s 刷新），原生小地图功能全保留。
-- 同时引入共享外观重绘助手 UI/Restyle.lua（B1 后续界面票复用）。

local _, ns = ...
local OpenUI = ns.OpenUI
local Theme = OpenUI.Theme
local Widgets = OpenUI.Widgets
local Restyle = OpenUI.Restyle

local MinimapUI = {}
local built, eventsRegistered = false, false
local ring, coords
local ticker

local function safe(fn, ...)
    if type(fn) == "function" then return fn(...) end
end

local function minimapFrame()
    return _G.Minimap
end

local function updateCoords()
    if not coords then return end
    if type(GetPlayerMapPosition) ~= "function" then
        coords:SetText("")
        return
    end
    local ok, text = pcall(function()
        local x, y = GetPlayerMapPosition("player")
        if x and x > 0 then
            return ("%.1f, %.1f"):format(x * 100, y * 100)
        end
        return ""
    end)
    coords:SetText(ok and text or "")
end

local SEGMENTS = 36

local function build()
    if built then return end
    local minimap = minimapFrame()
    if not minimap then return end
    built = true
    ring = CreateFrame("Frame", "OpenUIMinimapRing", UIParent)
    ring:SetSize(148, 148)
    ring:SetPoint("CENTER", minimap, "CENTER", 0, 0)
    -- 圆形点环（36 段沿圆周）：方框描边在圆形小地图上会显示成"小方块"，弃用。
    local bc = Theme.Get("color.outline-variant")
    local radius = 70
    ring.openuiSegments = {}
    for i = 1, SEGMENTS do
        local angle = (i - 1) / SEGMENTS * math.pi * 2
        local seg = ring:CreateTexture(nil, "ARTWORK")
        seg:SetSize(2, 6)
        seg:SetPoint("CENTER", ring, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
        if type(seg.SetRotation) == "function" then
            seg:SetRotation(angle)
        end
        seg:SetColorTexture(bc[1], bc[2], bc[3], 0.55)
        ring.openuiSegments[i] = seg
    end
    coords = Widgets.Text(ring, "", "label")
    coords:SetPoint("BOTTOM", ring, "BOTTOM", 0, -16)
end

function MinimapUI.OnEnable()
    build()
    if ring then ring:Show() end
    if not eventsRegistered then
        eventsRegistered = true
        local own = OpenUI.Own("MinimapUI")
        own:On("PLAYER_ENTERING_WORLD", function() updateCoords() end)
        own:On("ZONE_CHANGED_NEW_AREA", function() updateCoords() end)
        ticker = own:Every(1, updateCoords)
    end
    updateCoords()
end

function MinimapUI.OnDisable()
    eventsRegistered = false -- #6 Release 释放事件与定时器
    ticker = nil
    if ring then ring:Hide() end
end

MinimapUI.Ring = function() return ring end
MinimapUI.UpdateCoords = updateCoords

OpenUI.MinimapUI = MinimapUI

OpenUI:RegisterModule("MinimapUI", {
    defaultEnabled = false,
    OnEnable = function() MinimapUI.OnEnable() end,
    OnDisable = function() MinimapUI.OnDisable() end,
})