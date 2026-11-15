-- 任务 T1（#21）：经 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号），关闭恢复。
-- 帧名按客户端常见命名，缺失零操作（守卫）；晚加载帧经 ADDON_LOADED 重应用。

local _, ns = ...
local OpenUI = ns.OpenUI

local M = {}
local registered = false

local FRAMES = { "QuestLogFrame", "QuestLogDetailFrame", "WatchFrame" }

local function reapply()
    OpenUI.Restyle.Apply("QuestUI", FRAMES)
end

function M.OnEnable()
    reapply()
    if not registered then
        registered = true
        local own = OpenUI.Own("QuestUI")
        own:On("ADDON_LOADED", reapply)
        own:On("PLAYER_ENTERING_WORLD", reapply)
    end
end

function M.OnDisable()
    registered = false
    OpenUI.Restyle.Restore("QuestUI")
end

OpenUI.QuestUI = M

OpenUI:RegisterModule("QuestUI", {
    defaultEnabled = false,
    OnEnable = function() M.OnEnable() end,
    OnDisable = function() M.OnDisable() end,
})
