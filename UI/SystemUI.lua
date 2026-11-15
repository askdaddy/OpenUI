-- 系统界面 T1（#30）：经 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号），关闭恢复。
-- 帧名按客户端常见命名，缺失零操作（守卫）；晚加载帧经 ADDON_LOADED 重应用。

local _, ns = ...
local OpenUI = ns.OpenUI

local M = {}
local registered = false

local FRAMES = { "GameMenuFrame", "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" }

local function reapply()
    OpenUI.Restyle.Apply("SystemUI", FRAMES)
end

function M.OnEnable()
    reapply()
    if not registered then
        registered = true
        local own = OpenUI.Own("SystemUI")
        own:On("ADDON_LOADED", reapply)
        own:On("PLAYER_ENTERING_WORLD", reapply)
    end
end

function M.OnDisable()
    registered = false
    OpenUI.Restyle.Restore("SystemUI")
end

OpenUI.SystemUI = M

OpenUI:RegisterModule("SystemUI", {
    defaultEnabled = false,
    OnEnable = function() M.OnEnable() end,
    OnDisable = function() M.OnDisable() end,
})
