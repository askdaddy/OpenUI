-- 英文为回退语言（D18）：全部文案 key 必须在此定义；未知 key 返回 key 本身。
-- enUS 数据表存 OpenUI.Locales.enUS（#4），与 L 分离：
-- Locale 管理器以数据表为源在 L 上原地重建（同引用会被 wipe 误清空）。

local _, ns = ...
local OpenUI = ns.OpenUI

OpenUI.Locales = OpenUI.Locales or {}

local enUS = {
    VERSION_LINE = "OpenUI %s loaded.",
    MODULES_LINE = "Modules: %s",
    NO_ERRORS = "No errors recorded.",
    ERRORS_HEADER = "Recorded errors (%d):",
    ERRORS_ITEM = "%d. %s",
    MODULE_DUPLICATE = "module already registered: ",
    MODULE_INVALID = "invalid module name: ",
    THEME_INVALID = "Invalid theme value ignored: %s",
    LOCALE_INVALID = "Invalid locale ignored: %s",
    -- 设置窗口（#8）
    SETTINGS_TITLE = "OpenUI Settings",
    SETTINGS_SEARCH = "Search settings",
    SETTINGS_NO_RESULTS = "No matching settings.",
    SETTINGS_PAGE_APPEARANCE = "Appearance",
    SETTINGS_PAGE_LANGUAGE = "Language",
    SETTINGS_PAGE_MODULES = "Modules",
    SETTINGS_PAGE_ABOUT = "About",
    SETTINGS_PALETTE = "Palette",
    SETTINGS_LOCALE = "Language",
    SETTINGS_LOCALE_AUTO = "Auto (client)",
    SETTINGS_ON = "On",
    SETTINGS_OFF = "Off",
    SETTINGS_HINT = "Changes apply immediately.",
    SETTINGS_CLOSE = "Close",
    SETTINGS_ERRORS_COUNT = "Recorded errors: %d",
}
OpenUI.Locales.enUS = enUS

local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
for key, value in pairs(enUS) do
    L[key] = value
end
OpenUI.L = L
