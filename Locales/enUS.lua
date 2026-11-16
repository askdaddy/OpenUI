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
    -- 主控面板（#46）
    SETTINGS_CAT_CORE = "Core",
    SETTINGS_CAT_COMBAT = "Combat HUD",
    SETTINGS_CAT_PANELS = "Interface Windows",
    SETTINGS_CAT_TOOLS = "Tools",
    SETTINGS_MOD_PROFILE = "Profiles",
    SETTINGS_MOD_THEME = "Theme & Widgets",
    SETTINGS_MOD_LOCALE = "Localization",
    SETTINGS_MOD_SETTINGS = "Settings",
    SETTINGS_MOD_DIAGNOSTICS = "Diagnostics",
    SETTINGS_MOD_MEDIA = "Media Library",
    SETTINGS_MOD_ACTIONBARS = "Action Bars",
    SETTINGS_MOD_CHAT = "Chat",
    SETTINGS_MOD_UNITFRAMES = "Unit Frames",
    SETTINGS_MOD_CASTBARS = "Cast Bars",
    SETTINGS_MOD_AURAS = "Auras",
    SETTINGS_MOD_NAMEPLATES = "Nameplates",
    SETTINGS_MOD_MINIMAPUI = "Minimap",
    SETTINGS_MOD_TOOLTIPS = "Tooltips",
    SETTINGS_MOD_BAGS = "Bags & Bank",
    SETTINGS_MOD_WORLDMAPUI = "World Map",
    SETTINGS_MOD_QUESTUI = "Quests",
    SETTINGS_MOD_NPCUI = "NPC Interaction",
    SETTINGS_MOD_CHARUI = "Character",
    SETTINGS_MOD_SPELLUI = "Spellbook & Talents",
    SETTINGS_MOD_PARTYUI = "Party & Raid",
    SETTINGS_MOD_SOCIALUI = "Social",
    SETTINGS_MOD_TRADEUI = "Trade & Mail",
    SETTINGS_MOD_PROFUI = "Professions",
    SETTINGS_MOD_AUCTIONUI = "Auction House",
    SETTINGS_MOD_SYSTEMUI = "System UI",
    SETTINGS_MOD_SPECIALUI = "Special Scenes",
    SETTINGS_MODULE_TOGGLE = "Enabled",
    SETTINGS_MODULE_NO_OPTIONS = "No options yet. Enable or disable this module here.",
    SETTINGS_DIAG_OPEN = "Open diagnostics",
    SETTINGS_MEDIA_INFO = "Register media with the OpenUI: prefix; bridges to LSM when present.",
    SETTINGS_BAR_MAIN = "Main Bar",
    SETTINGS_BAR_N = "Bar %d",
    SETTINGS_ACTIONBARS_HINT = "Alt+Left drag to move bars (out of combat).",
    SETTINGS_MOD_GRID = "Layout Grid",
    SETTINGS_GRID_DISPLAY = "Show grid",
    SETTINGS_GRID_SNAP_LABEL = "Snap to grid",
    SETTINGS_GRID_SIZE_FMT = "Cell size: %d",
    SETTINGS_GRID_HINT = "Alt+Left drag elements; positions snap to the grid while it is shown.",
    GRID_TOGGLE_HINT = "Layout grid: %s",
    SETTINGS_EDIT_MODE = "Layout Edit",
    EDIT_MODE_HINT = "Layout edit mode: %s",
    SETTINGS_GRID_ON = "on",
    SETTINGS_GRID_OFF = "off",
    -- 诊断窗口（#10）
    DIAG_TITLE = "OpenUI Diagnostics",
    DIAG_COPY_HINT = "Select the text and press Ctrl+C to copy.",
    MEDIA_INVALID = "Invalid media registration ignored: %s",
    MEDIA_MISSING = "Media not found, falling back: %s",
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
