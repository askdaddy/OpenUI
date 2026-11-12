-- 简体中文覆盖（D18）：仅当客户端语言为 zhCN 时覆写对应 key；
-- 未覆盖的 key 自动保留 enUS 基表值。

local _, ns = ...
local OpenUI = ns.OpenUI

if GetLocale() == "zhCN" then
    local L = OpenUI.L
    L.VERSION_LINE = "OpenUI %s 已加载。"
    L.MODULES_LINE = "模块：%s"
    L.NO_ERRORS = "暂无错误记录。"
    L.ERRORS_HEADER = "已记录错误（%d 条）："
    L.ERRORS_ITEM = "%d. %s"
    L.MODULE_DUPLICATE = "模块已注册："
    L.MODULE_INVALID = "无效模块名："
end
