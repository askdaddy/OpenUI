-- 背包与银行 T1（#19）：经 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号），关闭恢复。
-- 帧名按客户端常见命名，缺失零操作（守卫）；晚加载帧经 ADDON_LOADED 重应用。

local _, ns = ...
local OpenUI = ns.OpenUI

local M = {}
local registered = false

local FRAMES = { "ContainerFrame1", "ContainerFrame2", "ContainerFrame3", "ContainerFrame4", "BankFrame" }

local function reapply()
    OpenUI.Restyle.Apply("Bags", FRAMES)
end

function M.OnEnable()
    reapply()
    if not registered then
        registered = true
        local own = OpenUI.Own("Bags")
        own:On("ADDON_LOADED", reapply)
        own:On("PLAYER_ENTERING_WORLD", reapply)
    end
end

function M.OnDisable()
    registered = false
    OpenUI.Restyle.Restore("Bags")
end

OpenUI.Bags = M

OpenUI:RegisterModule("Bags", {
    defaultEnabled = false,
    OnEnable = function() M.OnEnable() end,
    OnDisable = function() M.OnDisable() end,
})
