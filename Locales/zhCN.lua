-- 简体中文覆盖（D18）：覆盖表无条件构建并存 OpenUI.Locales.zhCN（#4），
-- 供 Locale 管理器重建；保留 GetLocale 条件自应用作为兼容锚点
-- （Manager 未加载或直重载本文件时，行为与历史一致）。

local _, ns = ...
local OpenUI = ns.OpenUI

OpenUI.Locales = OpenUI.Locales or {}

local zhCN = {
    VERSION_LINE = "OpenUI %s 已加载。",
    MODULES_LINE = "模块：%s",
    NO_ERRORS = "暂无错误记录。",
    ERRORS_HEADER = "已记录错误（%d 条）：",
    ERRORS_ITEM = "%d. %s",
    MODULE_DUPLICATE = "模块已注册：",
    MODULE_INVALID = "无效模块名：",
    THEME_INVALID = "无效的主题值已忽略：%s",
    LOCALE_INVALID = "无效的语言设置已忽略：%s",
}
OpenUI.Locales.zhCN = zhCN

if GetLocale() == "zhCN" then
    local L = OpenUI.L
    for key, value in pairs(zhCN) do
        L[key] = value
    end
end
