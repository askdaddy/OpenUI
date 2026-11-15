-- 特殊场景 T1（#31）：经 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号），关闭恢复。
-- 帧名按客户端常见命名，缺失零操作（守卫）；晚加载帧经 ADDON_LOADED 重应用。

local _, ns = ...
local OpenUI = ns.OpenUI

local M = {}
local registered = false

local FRAMES = { "VehicleSeatIndicator", "DurabilityFrame" }

local function reapply()
    OpenUI.Restyle.Apply("SpecialUI", FRAMES)
end

function M.OnEnable()
    reapply()
    if not registered then
        registered = true
        local own = OpenUI.Own("SpecialUI")
        own:On("ADDON_LOADED", reapply)
        own:On("PLAYER_ENTERING_WORLD", reapply)
    end
end

function M.OnDisable()
    registered = false
    OpenUI.Restyle.Restore("SpecialUI")
end

OpenUI.SpecialUI = M

OpenUI:RegisterModule("SpecialUI", {
    defaultEnabled = false,
    OnEnable = function() M.OnEnable() end,
    OnDisable = function() M.OnDisable() end,
})
