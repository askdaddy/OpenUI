-- Locale 管理器（#4 / design 方案 A）：解析 OpenUIDB.locale 并在同一张 L 表上
-- 原地重建（表身份不变，消费者零改动、切换即时生效）。
-- 合法值：auto | enUS | zhCN（严格小写）；非法值软失败按 auto 兜底，不清洗用户数据。

local _, ns = ...
local OpenUI = ns.OpenUI

local L = OpenUI.L
local Diagnose = OpenUI.Diagnose

local VALID = { auto = true, enUS = true, zhCN = true }

local function resolve(setting)
    if setting == nil or setting == "auto" then
        return GetLocale() == "zhCN" and "zhCN" or "enUS"
    end
    return setting
end

-- 原地重建：清数据键（metatable 回退保留）→ enUS 基表 →（zhCN 时）覆盖表。
local function apply(setting)
    local locale = resolve(setting)
    for key in pairs(L) do
        L[key] = nil
    end
    for key, value in pairs(OpenUI.Locales.enUS) do
        L[key] = value
    end
    if locale == "zhCN" then
        for key, value in pairs(OpenUI.Locales.zhCN) do
            L[key] = value
        end
    end
    return locale
end

local Locale = {}

-- 生效配置（#9）：优先当前配置档（Profile）；未迁移/未加载时回退 legacy 顶层键。
local function activeConfig(create)
    if OpenUI.Profile and OpenUI.Profile.Config then
        local cfg = OpenUI.Profile.Config()
        if type(cfg) == "table" then return cfg end
    end
    local db = _G.OpenUIDB
    if type(db) == "table" then return db end
    if not create then return nil end
    _G.OpenUIDB = {}
    return _G.OpenUIDB
end

-- 当前设置（缺省 auto；DB 非法值读取按 auto 解释，报告见 OnInitialize/Set）。
function Locale.Get()
    local cfg = activeConfig(false)
    local setting = cfg and cfg.locale
    if setting ~= nil and not VALID[setting] then
        return "auto"
    end
    return setting or "auto"
end

-- 设置语言并即时生效：合法 → 写生效配置 + 重建 L；非法 → 软失败。
function Locale.Set(locale)
    if type(locale) ~= "string" or not VALID[locale] then
        Diagnose.Report("Locale", L.LOCALE_INVALID:format(tostring(locale)))
        return false
    end
    activeConfig(true).locale = locale
    apply(locale)
    -- 已打开的设置窗口文案即时刷新（#8；未加载时零影响）
    if OpenUI.Settings and OpenUI.Settings.Refresh then OpenUI.Settings.Refresh() end
    return true
end

OpenUI.Locale = Locale

OpenUI:RegisterModule("Locale", {
    OnInitialize = function()
        local setting = _G.OpenUIDB and _G.OpenUIDB.locale
        if setting ~= nil and not VALID[setting] then
            Diagnose.Report("Locale", L.LOCALE_INVALID:format(tostring(setting)))
        end
        apply(Locale.Get())
    end,
})

-- 初始态：按客户端语言应用一次（与历史行为一致；DB 手动选择在 OnInitialize 对齐）。
apply("auto")
