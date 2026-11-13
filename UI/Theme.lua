-- 主题系统（#3 / design 方案 A）：扁平 token 注册表 + 三层解析。
-- 层次：PRESET（代码内纯数据，本地化无关）→ OpenUIDB.theme（用户全局定制）
--   → moduleOverrides（模块运行时覆盖，不落库）。
-- 兼容：colors/GetColor 与生效值同对象同步；fonts/GetFont 为静态旧视图。
-- 契约（spec A4）：模块只经只读 API 消费，不得改写返回的内部表。

local _, ns = ...
local OpenUI = ns.OpenUI
local L = OpenUI.L
local Diagnose = OpenUI.Diagnose

-- 预设注册表：token -> { value, kind, min, max }；默认值经用户确认冻结（#3 spec §6）。
local PRESET = {
    ["color.bg"]          = { value = { 0.09, 0.09, 0.11, 1 }, kind = "color" },
    ["color.panel"]       = { value = { 0.13, 0.13, 0.16, 1 }, kind = "color" },
    ["color.border"]      = { value = { 0.24, 0.24, 0.28, 1 }, kind = "color" },
    ["color.text"]        = { value = { 0.92, 0.92, 0.94, 1 }, kind = "color" },
    ["color.textDim"]     = { value = { 0.62, 0.62, 0.68, 1 }, kind = "color" },
    ["color.accent"]      = { value = { 0.20, 0.56, 0.85, 1 }, kind = "color" },
    ["color.warn"]        = { value = { 0.92, 0.60, 0.10, 1 }, kind = "color" },
    ["color.danger"]      = { value = { 0.85, 0.28, 0.28, 1 }, kind = "color" },
    ["opacity.panel"]     = { value = 0.95, kind = "number", min = 0, max = 1 },
    ["font.small"]        = { value = { file = nil, size = 11, flags = nil }, kind = "font" },
    ["font.normal"]       = { value = { file = nil, size = 13, flags = nil }, kind = "font" },
    ["font.header"]       = { value = { file = nil, size = 16, flags = nil }, kind = "font" },
    ["border.size"]       = { value = 1, kind = "number", min = 0, max = 10 },
    ["spacing.small"]     = { value = 4, kind = "number", min = 0, max = 64 },
    ["spacing.medium"]    = { value = 8, kind = "number", min = 0, max = 64 },
    ["spacing.large"]     = { value = 12, kind = "number", min = 0, max = 64 },
    ["size.cornerRadius"] = { value = 4, kind = "number", min = 0, max = 32 },
}

local function validColor(v)
    if type(v) ~= "table" or #v ~= 4 then return false end
    for i = 1, 4 do
        if type(v[i]) ~= "number" or v[i] < 0 or v[i] > 1 then return false end
    end
    return true
end

local function validFont(v)
    if type(v) ~= "table" then return false end
    if v.file ~= nil and type(v.file) ~= "string" then return false end
    if v.flags ~= nil and type(v.flags) ~= "string" then return false end
    return type(v.size) == "number" and v.size >= 6 and v.size <= 64
end

local function validate(token, value)
    local def = PRESET[token]
    if def == nil then return false end
    if def.kind == "color" then return validColor(value) end
    if def.kind == "font" then return validFont(value) end
    return type(value) == "number" and value >= def.min and value <= def.max
end

-- color/font 入参存副本，防调用方事后改表污染内部状态。
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = v end
    return out
end

local resolved = {}        -- token -> 全局生效值（预设 + OpenUIDB.theme 合法定制）
local moduleOverrides = {} -- 模块名 -> token -> 覆盖值（仅内存，不落库）

-- 旧视图：colors 与 resolved 同对象同步（保住既有恒等断言）；fonts 静态冻结。
local colors = {}
local fonts = {
    normal = "GameFontNormal",
    header = "GameFontNormalLarge",
}
local legacyKeys = {
    bg = "color.bg", panel = "color.panel", border = "color.border",
    text = "color.text", textDim = "color.textDim", accent = "color.accent",
    warn = "color.warn", danger = "color.danger",
}

local function rebuild()
    for token, def in pairs(PRESET) do
        local value = def.value
        local saved = _G.OpenUIDB and _G.OpenUIDB.theme and _G.OpenUIDB.theme[token]
        if saved ~= nil then
            if validate(token, saved) then
                value = saved
            else
                -- 软失败：非法/未知存量值跳过并报告，不删改用户数据。
                Diagnose.Report("Theme", L.THEME_INVALID:format(token))
            end
        end
        resolved[token] = copy(value)
    end
    for name, token in pairs(legacyKeys) do
        colors[name] = resolved[token]
    end
end

local Theme = {}

function Theme.Tokens()
    local list = {}
    for token in pairs(PRESET) do list[#list + 1] = token end
    table.sort(list)
    return list
end

-- 全局生效值；未知 token 返回 nil（兼容既有行为）。
function Theme.Get(token)
    return resolved[token]
end

-- 模块感知生效值：覆盖优先，回退全局。
function Theme.GetFor(moduleName, token)
    local overrides = moduleOverrides[moduleName]
    if overrides ~= nil then
        local value = overrides[token]
        if value ~= nil then return value end
    end
    return resolved[token]
end

-- 全局定制：校验 → 写 OpenUIDB.theme（持久化路径）→ 重建。
function Theme.Set(token, value)
    if not validate(token, value) then
        Diagnose.Report("Theme", L.THEME_INVALID:format(token))
        return false
    end
    if type(_G.OpenUIDB) ~= "table" then _G.OpenUIDB = {} end
    if type(_G.OpenUIDB.theme) ~= "table" then _G.OpenUIDB.theme = {} end
    _G.OpenUIDB.theme[token] = copy(value)
    rebuild()
    return true
end

-- 清除某 token 的全局定制，回预设。
function Theme.Reset(token)
    if PRESET[token] == nil then
        Diagnose.Report("Theme", L.THEME_INVALID:format(token))
        return false
    end
    if type(_G.OpenUIDB) == "table" and type(_G.OpenUIDB.theme) == "table" then
        _G.OpenUIDB.theme[token] = nil
    end
    rebuild()
    return true
end

-- 模块覆盖：仅内存，不写任何 SavedVariables。
function Theme.SetOverride(moduleName, token, value)
    if type(moduleName) ~= "string" or not validate(token, value) then
        Diagnose.Report("Theme", L.THEME_INVALID:format(token))
        return false
    end
    if moduleOverrides[moduleName] == nil then moduleOverrides[moduleName] = {} end
    moduleOverrides[moduleName][token] = copy(value)
    return true
end

-- 重置模块覆盖：token 为 nil 时清空该模块全部覆盖。
function Theme.ResetOverride(moduleName, token)
    local overrides = moduleOverrides[moduleName]
    if overrides == nil then return true end
    if token == nil then
        moduleOverrides[moduleName] = nil
    else
        overrides[token] = nil
    end
    return true
end

-- 旧接口兼容（既有黑盒测试基线）：GetColor 走同步视图，GetFont 走静态映射。
function Theme.GetColor(name)
    return colors[name]
end

function Theme.GetFont(name)
    return fonts[name]
end

Theme.colors = colors
Theme.fonts = fonts
OpenUI.Theme = Theme

-- ADDON_LOADED（默认已合并）后按 OpenUIDB.theme 重建；文件加载时先以预设值就绪。
OpenUI:RegisterModule("Theme", {
    OnInitialize = function()
        rebuild()
    end,
})

rebuild()
