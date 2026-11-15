-- 媒体注册表与 LSM 可选桥接（#42）：OpenUI 前缀稳定媒体名，双向共享。
-- 不嵌入 LSM（D39 分发未定案）：LibStub/LSM 存在时桥接注册并暴露外部列表；不存在零影响。
-- 规则：只注册 "OpenUI:" 前缀；不改其他插件配置；不默认 SetGlobal；重复注册幂等覆盖。

local _, ns = ...
local OpenUI = ns.OpenUI
local Diagnose = OpenUI.Diagnose
local L = OpenUI.L

local Media = {}

local KINDS = {
    font = true, statusbar = true, background = true, border = true, sound = true,
}
local PREFIX = "OpenUI:"
local registry = {} -- kind -> { [name] = value }
local bridged = false

local function valid(kind, name, value)
    if type(kind) ~= "string" or not KINDS[kind] then return false end
    if type(name) ~= "string" or name:sub(1, #PREFIX) ~= PREFIX then return false end
    if type(value) ~= "string" then return false end
    return true
end

function Media.Register(kind, name, value)
    if not valid(kind, name, value) then
        Diagnose.Report("Media", L.MEDIA_INVALID:format(tostring(name)))
        return false
    end
    if not registry[kind] then registry[kind] = {} end
    registry[kind][name] = value
    -- 已桥接时同步注册到 LSM（重复注册幂等覆盖）
    local lsm = bridged and Media._LSM()
    if lsm and lsm.Register then lsm:Register(kind, name, value) end
    return true
end

function Media.Fetch(kind, name)
    return registry[kind] and registry[kind][name] or nil
end

function Media.List(kind)
    local list = {}
    for name in pairs(registry[kind] or {}) do
        list[#list + 1] = name
    end
    table.sort(list)
    return list
end

-- 运行时检测 LibSharedMedia-3.0（不强制存在）。
function Media._LSM()
    if type(LibStub) ~= "function" then return nil end
    local ok, lsm = pcall(LibStub, "LibSharedMedia-3.0", true)
    if ok and type(lsm) == "table" then return lsm end
    return nil
end

-- 桥接：注册全部内部媒体到 LSM（幂等）。
function Media.Bridge()
    local lsm = Media._LSM()
    if not lsm or type(lsm.Register) ~= "function" then return false end
    bridged = true
    for kind, entries in pairs(registry) do
        for name, value in pairs(entries) do
            lsm:Register(kind, name, value)
        end
    end
    return true
end

-- 外部媒体列表（无 LSM 返回 nil）。
function Media.External(kind)
    local lsm = Media._LSM()
    if not lsm or type(lsm.List) ~= "function" then return nil end
    local ok, list = pcall(lsm.List, lsm, kind)
    if ok and type(list) == "table" then return list end
    return nil
end

function Media.IsBridged() return bridged end

-- ==== #43：选择预览数据 / 配置标识化 / 缺失回退 ====

-- 选择器数据：内部 + 外部（去重合并；外部缺失时仅内部）。
function Media.Options(kind)
    local seen = {}
    local list = {}
    for _, name in ipairs(Media.List(kind)) do
        if not seen[name] then seen[name] = true; list[#list + 1] = name end
    end
    local external = Media.External(kind)
    if type(external) == "table" then
        for _, name in ipairs(external) do
            if not seen[name] then seen[name] = true; list[#list + 1] = name end
        end
    end
    table.sort(list)
    return list
end

-- 解析媒体名：internal / external / missing（缺失软报告并回退 fallbackName 的解析结果）。
function Media.Resolve(kind, name, fallbackName)
    if Media.Fetch(kind, name) then
        return { source = "internal", name = name, value = Media.Fetch(kind, name) }
    end
    local external = Media.External(kind)
    if type(external) == "table" then
        for _, candidate in ipairs(external) do
            if candidate == name then
                local lsm = Media._LSM()
                local value
                if lsm and type(lsm.Fetch) == "function" then
                    value = lsm:Fetch(kind, name)
                end
                return { source = "external", name = name, value = value }
            end
        end
    end
    Diagnose.Report("Media", L.MEDIA_MISSING:format(tostring(name)))
    if fallbackName and fallbackName ~= name then
        local fallback = Media.Resolve(kind, fallbackName, nil)
        fallback.fellBack = true
        return fallback
    end
    return { source = "missing", name = name, value = nil }
end

-- 配置标识化：仅存媒体名字符串（导出串不嵌入素材本体；非法输入拒绝）。
function Media.SetConfigName(configTable, key, kind, name)
    if type(configTable) ~= "table" or type(key) ~= "string"
        or type(name) ~= "string" or name == "" then
        Diagnose.Report("Media", L.MEDIA_INVALID:format(tostring(name)))
        return false
    end
    configTable[key] = name
    return true
end

OpenUI.Media = Media

OpenUI:RegisterModule("Media", {
    defaultEnabled = false,
    OnEnable = function()
        Media.Bridge()
    end,
    OnDisable = function() end,
})

-- 延迟加载：其他插件（含 LSM 宿主）加载后再尝试桥接。
OpenUI.Own("Media"):On("ADDON_LOADED", function()
    if not bridged then Media.Bridge() end
end)