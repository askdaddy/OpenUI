-- 主题系统（#3 T1 + #7 M3 Expressive）：M3 语义角色 + 七套 seed 配方配色 + 兼容别名。
-- 层次：palette/PRESET（纯数据，本地化无关）→ OpenUIDB.theme（用户全局定制，含 palette）
--   → moduleOverrides（模块运行时覆盖，不落库）。
-- 兼容：colors/GetColor 与生效值同对象同步（旧键为 M3 角色别名）；fonts/GetFont 静态旧视图。
-- 契约（spec A4）：模块只经只读 API 消费，不得改写返回的内部表。

local _, ns = ...
local OpenUI = ns.OpenUI
local L = OpenUI.L
local Diagnose = OpenUI.Diagnose

-- ==== 色彩引擎（纯 Lua，M3 角色配方；#7 design）====
local function hsl(h, s, l)
    h = (h % 360) / 360
    local function f(n)
        local k = (n + h * 12) % 12
        local a = s * math.min(l, 1 - l)
        local v = l - a * math.max(-1, math.min(k - 3, 9 - k, 1))
        return math.floor(v * 10000 + 0.5) / 10000
    end
    return { f(0), f(8), f(4), 1 }
end

-- 七套暗色配色 seed（#7 Q1 冻结：名称与默认）。
local PALETTES = {
    starblue = { h = 208, s = 0.62 },
    teal     = { h = 174, s = 0.45 },
    amber    = { h = 38,  s = 0.85 },
    amethyst = { h = 270, s = 0.55 },
    rose     = { h = 345, s = 0.55 },
    moss     = { h = 105, s = 0.35 },
    graphite = { h = 220, s = 0.06 },
}
local DEFAULT_PALETTE = "starblue"

-- 角色配方：相对 seed 的色相偏移/明度/饱和度系数；fixed* 为固定色相/饱和度角色。
local RECIPE = {
    ["surface"]                   = { l = 0.075, sf = 0.15 },
    ["surface-container-low"]     = { l = 0.10,  sf = 0.16 },
    ["surface-container"]         = { l = 0.125, sf = 0.17 },
    ["surface-container-high"]    = { l = 0.155, sf = 0.18 },
    ["surface-container-highest"] = { l = 0.185, sf = 0.19 },
    ["on-surface"]                = { l = 0.92,  sf = 0.05 },
    ["on-surface-variant"]        = { l = 0.68,  sf = 0.10 },
    ["outline"]                   = { l = 0.45,  sf = 0.15 },
    ["outline-variant"]           = { l = 0.28,  sf = 0.15 },
    ["primary"]                   = { l = 0.72,  sf = 0.85 },
    ["on-primary"]                = { l = 0.15,  sf = 0.30 },
    ["primary-container"]         = { l = 0.32,  sf = 0.60 },
    ["on-primary-container"]      = { l = 0.88,  sf = 0.40 },
    ["secondary"]                 = { dh = 30, l = 0.75, sf = 0.35 },
    ["tertiary"]                  = { dh = 60, l = 0.75, sf = 0.60 },
    ["error"]                     = { fixedH = 8, fixedS = 0.65, l = 0.70 },
    ["on-error"]                  = { fixedH = 8, fixedS = 0.50, l = 0.15 },
    ["error-container"]           = { fixedH = 8, fixedS = 0.70, l = 0.32 },
}

local function buildPalette(seed)
    local colors = {}
    for role, recipe in pairs(RECIPE) do
        local h = recipe.fixedH or (seed.h + (recipe.dh or 0))
        local s = recipe.fixedS or (seed.s * recipe.sf)
        colors[role] = hsl(h, s, recipe.l)
    end
    return colors
end

-- 旧 token -> M3 角色别名（#7 A4 迁移映射；单源：旧键解析为角色当前值）。
local COLOR_ALIASES = {
    ["color.bg"]      = "color.surface",
    ["color.panel"]   = "color.surface-container",
    ["color.border"]  = "color.outline-variant",
    ["color.text"]    = "color.on-surface",
    ["color.textDim"] = "color.on-surface-variant",
    ["color.accent"]  = "color.primary",
    ["color.warn"]    = "color.tertiary",
    ["color.danger"]  = "color.error",
}

-- 非色彩预设注册表：token -> { value, kind, min, max }（#3 旧值 + #7 新增）。
local PRESET = {
    ["opacity.panel"] = { value = 0.95, kind = "number", min = 0, max = 1 },
    -- 旧字体角色（静态兼容值，语义保持）
    ["font.small"]    = { value = { file = nil, size = 11, flags = nil }, kind = "font" },
    ["font.normal"]   = { value = { file = nil, size = 13, flags = nil }, kind = "font" },
    ["font.header"]   = { value = { file = nil, size = 16, flags = nil }, kind = "font" },
    -- M3 排版角色（#7；file=nil 继承客户端默认字体）
    ["type.display"]   = { value = { file = nil, size = 24, flags = nil }, kind = "font" },
    ["type.headline"]  = { value = { file = nil, size = 20, flags = nil }, kind = "font" },
    ["type.title"]     = { value = { file = nil, size = 16, flags = nil }, kind = "font" },
    ["type.body"]      = { value = { file = nil, size = 13, flags = nil }, kind = "font" },
    ["type.label"]     = { value = { file = nil, size = 11, flags = nil }, kind = "font" },
    ["border.size"]   = { value = 1, kind = "number", min = 0, max = 10 },
    -- M3 形状等级（#7）
    ["shape.none"]    = { value = 0, kind = "number", min = 0, max = 999 },
    ["shape.sm"]      = { value = 4, kind = "number", min = 0, max = 999 },
    ["shape.md"]      = { value = 8, kind = "number", min = 0, max = 999 },
    ["shape.lg"]      = { value = 16, kind = "number", min = 0, max = 999 },
    ["shape.full"]    = { value = 999, kind = "number", min = 0, max = 999 },
    ["spacing.small"]  = { value = 4, kind = "number", min = 0, max = 64 },
    ["spacing.medium"] = { value = 8, kind = "number", min = 0, max = 64 },
    ["spacing.large"]  = { value = 12, kind = "number", min = 0, max = 64 },
    ["size.cornerRadius"] = { value = 4, kind = "number", min = 0, max = 32 },
    -- M3 状态层不透明度（#7；M3 官方口径）
    ["state.hover"]    = { value = 0.08, kind = "number", min = 0, max = 1 },
    ["state.pressed"]  = { value = 0.12, kind = "number", min = 0, max = 1 },
    ["state.focus"]    = { value = 0.10, kind = "number", min = 0, max = 1 },
    ["state.selected"] = { value = 0.12, kind = "number", min = 0, max = 1 },
    ["state.disabled"] = { value = 0.38, kind = "number", min = 0, max = 1 },
    -- 动效 token（#7；消费者模块按需实现动画，无动画引擎）
    ["motion.duration-short"]  = { value = 0.15, kind = "number", min = 0, max = 5 },
    ["motion.duration-medium"] = { value = 0.25, kind = "number", min = 0, max = 5 },
    ["motion.duration-long"]   = { value = 0.4, kind = "number", min = 0, max = 5 },
    ["motion.easing-standard"] = { value = "OUT_QUAD", kind = "string" },
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
    if token:sub(1, 6) == "color." then return validColor(value) end
    local def = PRESET[token]
    if def == nil then return false end
    if def.kind == "font" then return validFont(value) end
    if def.kind == "string" then return type(value) == "string" and value ~= "" end
    return type(value) == "number" and value >= def.min and value <= def.max
end

-- 存储副本，防调用方事后改表污染内部状态。
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = v end
    return out
end

local function colorTokenOf(token)
    if COLOR_ALIASES[token] then return COLOR_ALIASES[token] end
    if token:sub(1, 6) == "color." then return token end
    return nil
end

local resolved = {}        -- token -> 全局生效值（配色/预设 + OpenUIDB.theme 合法定制）
local moduleOverrides = {} -- 模块名 -> token -> 覆盖值（仅内存，不落库）

-- 旧视图：colors 与 resolved 同对象同步（保住既有恒等断言）；fonts 静态冻结。
local colors = {}
local fonts = {
    normal = "GameFontNormal",
    header = "GameFontNormalLarge",
}
local legacyColorNames = {
    bg = "color.bg", panel = "color.panel", border = "color.border",
    text = "color.text", textDim = "color.textDim", accent = "color.accent",
    warn = "color.warn", danger = "color.danger",
}

local function savedTheme()
    local db = _G.OpenUIDB
    return db and db.theme or nil
end

local function currentPaletteName()
    local saved = savedTheme() and savedTheme().palette
    if type(saved) == "string" and PALETTES[saved] then return saved end
    return DEFAULT_PALETTE
end

local function rebuild()
    local paletteColors = buildPalette(PALETTES[currentPaletteName()])
    local saved = savedTheme() or {}
    -- M3 色角色：配色生成值 -> DB 角色定制
    for role, value in pairs(paletteColors) do
        local token = "color." .. role
        local custom = saved[token]
        if custom ~= nil and validColor(custom) then
            value = custom
        elseif custom ~= nil then
            Diagnose.Report("Theme", L.THEME_INVALID:format(token))
        end
        resolved[token] = copy(value)
    end
    -- 旧别名：与角色同对象（单源）
    for alias, target in pairs(COLOR_ALIASES) do
        resolved[alias] = resolved[target]
    end
    -- 非色彩 token
    for token, def in pairs(PRESET) do
        local value = def.value
        local custom = saved[token]
        if custom ~= nil then
            if validate(token, custom) then
                value = custom
            else
                Diagnose.Report("Theme", L.THEME_INVALID:format(token))
            end
        end
        resolved[token] = copy(value)
    end
    for name, token in pairs(legacyColorNames) do
        colors[name] = resolved[token]
    end
    if OpenUI.Widgets then OpenUI.Widgets.Refresh() end
end

local Theme = {}

function Theme.Tokens()
    local list = {}
    for role in pairs(RECIPE) do list[#list + 1] = "color." .. role end
    for alias in pairs(COLOR_ALIASES) do list[#list + 1] = alias end
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

-- 全局定制：校验 → 写 OpenUIDB.theme（别名键写入目标角色）→ 重建。
function Theme.Set(token, value)
    if not validate(token, value) then
        Diagnose.Report("Theme", L.THEME_INVALID:format(tostring(token)))
        return false
    end
    local target = colorTokenOf(token) or token
    if type(_G.OpenUIDB) ~= "table" then _G.OpenUIDB = {} end
    if type(_G.OpenUIDB.theme) ~= "table" then _G.OpenUIDB.theme = {} end
    _G.OpenUIDB.theme[target] = copy(value)
    rebuild()
    return true
end

-- 清除定制，回预设（别名键同时清旧键与目标键）。
function Theme.Reset(token)
    if not (colorTokenOf(token) or PRESET[token]) then
        Diagnose.Report("Theme", L.THEME_INVALID:format(tostring(token)))
        return false
    end
    local theme = _G.OpenUIDB and _G.OpenUIDB.theme
    if type(theme) == "table" then
        theme[token] = nil
        local target = colorTokenOf(token)
        if target then theme[target] = nil end
    end
    rebuild()
    return true
end

-- 模块覆盖：仅内存，不写任何 SavedVariables。
function Theme.SetOverride(moduleName, token, value)
    if type(moduleName) ~= "string" or not validate(token, value) then
        Diagnose.Report("Theme", L.THEME_INVALID:format(tostring(token)))
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

-- ==== 配色切换（#7 Q1/Q3）====
function Theme.GetPalette()
    return currentPaletteName()
end

function Theme.SetPalette(name)
    if type(name) ~= "string" or not PALETTES[name] then
        Diagnose.Report("Theme", L.THEME_INVALID:format(tostring(name)))
        return false
    end
    if type(_G.OpenUIDB) ~= "table" then _G.OpenUIDB = {} end
    if type(_G.OpenUIDB.theme) ~= "table" then _G.OpenUIDB.theme = {} end
    _G.OpenUIDB.theme.palette = name
    rebuild()
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

-- 旧 token 定制迁移（#7 A4）：旧键值复制到 M3 角色键；旧键保留不清洗。
local function migrateLegacyCustomizations()
    local theme = _G.OpenUIDB and _G.OpenUIDB.theme
    if type(theme) ~= "table" then return end
    for alias, target in pairs(COLOR_ALIASES) do
        if theme[alias] ~= nil and theme[target] == nil then
            theme[target] = copy(theme[alias])
        end
    end
end

-- ADDON_LOADED（默认已合并）后迁移并重建；文件加载时先以默认配色就绪。
OpenUI:RegisterModule("Theme", {
    OnInitialize = function()
        migrateLegacyCustomizations()
        rebuild()
    end,
})

rebuild()