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