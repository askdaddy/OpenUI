-- OpenUI：面向 Forever 的现代扁平暗色界面替换框架（B0 骨架）。
-- 本文件建立全插件共享的命名空间；其余文件按 TOC 显式次序加载。

local ADDON_NAME, ns = ...

local function metadata(field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(ADDON_NAME, field)
    elseif GetAddOnMetadata then
        return GetAddOnMetadata(ADDON_NAME, field)
    end
end

local OpenUI = {
    name = ADDON_NAME,
    version = metadata("Version") or "2026.11.0-dev.1",
    modules = {},     -- 名称 -> 模块表
    moduleOrder = {}, -- 注册顺序，保证生命周期确定性
}
ns.OpenUI = OpenUI
-- 供命令行宏与外部访问的全局桥。
_G[ADDON_NAME] = OpenUI
