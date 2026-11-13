-- 英文为回退语言（D18）：骨架引用的全部文案 key 必须在此定义。
-- 未知 key 返回 key 本身，保证调用方永不抛错。

local _, ns = ...
local OpenUI = ns.OpenUI

local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})

L.VERSION_LINE = "OpenUI %s loaded."
L.MODULES_LINE = "Modules: %s"
L.NO_ERRORS = "No errors recorded."
L.ERRORS_HEADER = "Recorded errors (%d):"
L.ERRORS_ITEM = "%d. %s"
L.MODULE_DUPLICATE = "module already registered: "
L.MODULE_INVALID = "invalid module name: "
L.THEME_INVALID = "Invalid theme value ignored: %s"

OpenUI.L = L
