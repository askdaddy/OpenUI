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
    -- 设置窗口（#8）
    SETTINGS_TITLE = "OpenUI 设置",
    SETTINGS_SEARCH = "搜索设置",
    SETTINGS_NO_RESULTS = "没有匹配的设置。",
    SETTINGS_PAGE_APPEARANCE = "外观",
    SETTINGS_PAGE_LANGUAGE = "语言",
    SETTINGS_PAGE_MODULES = "模块",
    SETTINGS_PAGE_ABOUT = "关于",
    SETTINGS_PALETTE = "配色",
    SETTINGS_LOCALE = "语言",
    SETTINGS_LOCALE_AUTO = "自动（跟随客户端）",
    SETTINGS_ON = "开",
    SETTINGS_OFF = "关",
    SETTINGS_HINT = "修改即时生效。",
    SETTINGS_CLOSE = "关闭",
    SETTINGS_ERRORS_COUNT = "已记录错误：%d 条",
    -- 主控面板（#46）
    SETTINGS_CAT_CORE = "基础",
    SETTINGS_CAT_COMBAT = "战斗界面",
    SETTINGS_CAT_PANELS = "系统窗口",
    SETTINGS_CAT_TOOLS = "工具",
    SETTINGS_MOD_PROFILE = "配置档",
    SETTINGS_MOD_THEME = "主题与控件",
    SETTINGS_MOD_LOCALE = "本地化",
    SETTINGS_MOD_SETTINGS = "设置",
    SETTINGS_MOD_DIAGNOSTICS = "诊断",
    SETTINGS_MOD_MEDIA = "媒体库",
    SETTINGS_MOD_ACTIONBARS = "动作条",
    SETTINGS_MOD_CHAT = "聊天",
    SETTINGS_MOD_UNITFRAMES = "单位框体",
    SETTINGS_MOD_CASTBARS = "施法条",
    SETTINGS_MOD_AURAS = "光环",
    SETTINGS_MOD_NAMEPLATES = "名牌",
    SETTINGS_MOD_MINIMAPUI = "小地图",
    SETTINGS_MOD_TOOLTIPS = "提示框",
    SETTINGS_MOD_BAGS = "背包与银行",
    SETTINGS_MOD_WORLDMAPUI = "世界地图",
    SETTINGS_MOD_QUESTUI = "任务",
    SETTINGS_MOD_NPCUI = "NPC 交互",
    SETTINGS_MOD_CHARUI = "角色与装备",
    SETTINGS_MOD_SPELLUI = "法术书与天赋",
    SETTINGS_MOD_PARTYUI = "队伍与团队",
    SETTINGS_MOD_SOCIALUI = "社交与组队",
    SETTINGS_MOD_TRADEUI = "交易与邮件",
    SETTINGS_MOD_PROFUI = "专业与成长",
    SETTINGS_MOD_AUCTIONUI = "拍卖行",
    SETTINGS_MOD_SYSTEMUI = "系统界面",
    SETTINGS_MOD_SPECIALUI = "特殊场景",
    SETTINGS_MODULE_TOGGLE = "启用",
    SETTINGS_MODULE_NO_OPTIONS = "暂无设置项，可在此启用或停用。",
    SETTINGS_DIAG_OPEN = "打开诊断窗口",
    SETTINGS_MEDIA_INFO = "使用 OpenUI: 前缀注册媒体；装有 LSM 时自动桥接。",
    SETTINGS_BAR_MAIN = "主条",
    SETTINGS_BAR_N = "动作条 %d",
    SETTINGS_ACTIONBARS_HINT = "Alt+左键拖动动作条（脱战）。",
    -- 诊断窗口（#10）
    DIAG_TITLE = "OpenUI 诊断",
    DIAG_COPY_HINT = "选中文本后按 Ctrl+C 复制。",
    MEDIA_INVALID = "无效的媒体注册已忽略：%s",
    MEDIA_MISSING = "媒体缺失，已回退：%s",
}
OpenUI.Locales.zhCN = zhCN

if GetLocale() == "zhCN" then
    local L = OpenUI.L
    for key, value in pairs(zhCN) do
        L[key] = value
    end
end
