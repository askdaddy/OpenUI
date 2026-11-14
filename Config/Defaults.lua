-- 配置最小挂点（spec C6）：OpenUIDB 默认表与深拷贝合并。
-- 已有用户值优先，缺失补默认；首次加载 OpenUIDB 为 nil。

local _, ns = ...
local OpenUI = ns.OpenUI

local defaults = {
    configVersion = 1,
    debug = false,
    locale = "auto", -- auto | enUS | zhCN（D18/#4）：跟随客户端或手动选择
    theme = {}, -- token -> 用户全局定制值（#3）；键集见 UI/Theme.lua PRESET
    modules = { enabled = {} }, -- 注册名 -> bool（#6）；缺省按 DEFAULT_ENABLED 组合
}

local function merge(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = merge(type(target[key]) == "table" and target[key] or {}, value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

OpenUI.Config = {
    defaults = defaults,
    MergeDefaults = function(db)
        return merge(db or {}, defaults)
    end,
}
