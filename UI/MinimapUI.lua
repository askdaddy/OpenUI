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
    local x, y
    if type(GetPlayerMapPosition) == "function" then
        x, y = GetPlayerMapPosition("player")
    end
    if x and x > 0 then
        coords:SetText(("%.1f, %.1f"):format(x * 100, y * 100))
    else
        coords:SetText("")
    end
end

local function build()
    if built then return end
    local minimap = minimapFrame()
    if not minimap then return end
    built = true
    ring = CreateFrame("Frame", "OpenUIMinimapRing", UIParent)
    ring:SetSize(148, 148)
    ring:SetPoint("CENTER", minimap, "CENTER", 0, 0)
    local border = ring:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints(ring)
    local bc = Theme.Get("color.outline-variant")
    border:SetColorTexture(bc[1], bc[2], bc[3], 0.9)
    coords = Widgets.Text(ring, "", "label")
    coords:SetPoint("BOTTOM", ring, "BOTTOM", 0, -16)
    ring.openuiBorder = border
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