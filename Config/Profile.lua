-- 配置档（#9 T1）：账号级 OpenUIDB.profiles —— 5 共享槽 + 角色独立档 + 持续关联。
-- 关键证据（2026-11-14 本机客户端插件惯例核验）：## SavedVariables 为账号级，
-- 共享槽与角色关联表全账号可见，删除槽可为未登录角色保留副本（模块规范验收意向）。
-- 范围外（后续分期）：导入导出、槽命名/重置 UI、设置窗口配置档页。
-- 消费者契约：Theme/Locale/Core 经 Profile.Config() 读写生效配置；未加载本模块时回退 legacy 顶层键。

local _, ns = ...
local OpenUI = ns.OpenUI

local SLOT_COUNT = 5

local Profile = {}

local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = deepCopy(v) end
    return out
end

local function charKey()
    local name
    if type(UnitFullName) == "function" then
        name = UnitFullName("player")
    elseif type(UnitName) == "function" then
        name = UnitName("player")
    end
    if type(name) ~= "string" or name == "" then name = "Unknown" end
    local realm
    if type(GetRealmName) == "function" then realm = GetRealmName() end
    if type(realm) ~= "string" or realm == "" then realm = "Realm" end
    return name .. "-" .. realm
end
Profile.CharKey = charKey

-- 已迁移的存储；未迁移（或未初始化）返回 nil，消费者回退 legacy。
local function store()
    local d = _G.OpenUIDB
    if type(d) ~= "table" then return nil end
    local p = d.profiles
    if type(p) ~= "table" or p.migrated ~= true then return nil end
    return p
end

local function ensureStore()
    if type(_G.OpenUIDB) ~= "table" then _G.OpenUIDB = {} end
    local p = _G.OpenUIDB.profiles
    if type(p) ~= "table" then p = {}; _G.OpenUIDB.profiles = p end
    if type(p.slots) ~= "table" then p.slots = {} end
    if type(p.chars) ~= "table" then p.chars = {} end
    return p
end

local function record(name)
    local p = ensureStore()
    local key = name or charKey()
    local rec = p.chars[key]
    if type(rec) ~= "table" then
        rec = { mode = "independent", independent = {} }
        p.chars[key] = rec
    end
    if type(rec.independent) ~= "table" then rec.independent = {} end
    return rec, key
end

-- 首次初始化：顶层 legacy 配置深拷贝进当前角色独立档；legacy 键保留、不清洗。
local function migrate()
    local p = ensureStore()
    if p.migrated == true then return false end
    local d = _G.OpenUIDB
    local rec = record()
    rec.independent = {
        debug = d.debug,
        locale = d.locale,
        theme = deepCopy(d.theme) or {},
        modules = deepCopy(d.modules) or { enabled = {} },
    }
    p.migrated = true
    return true
end

-- 当前角色生效配置（活引用）：slot 模式为槽配置表本身（多角色同槽天然一致）。
function Profile.Config()
    local p = store()
    if not p then return nil end
    local rec = record()
    if rec.mode == "slot" then
        local slot = rec.slot and p.slots[rec.slot]
        if type(slot) == "table" and type(slot.config) == "table" then
            return slot.config
        end
        rec.mode = "independent" -- 槽失效（异常残留）回退独立档
        rec.slot = nil
    end
    return rec.independent
end

-- 任意角色（含离线记录）的生效配置。
function Profile.ConfigFor(name)
    local p = store()
    if not p then return nil end
    local rec = record(name)
    if rec.mode == "slot" then
        local slot = rec.slot and p.slots[rec.slot]
        if type(slot) == "table" and type(slot.config) == "table" then return slot.config end
    end
    return rec.independent
end

function Profile.GetCurrent()
    local rec = record()
    return { mode = rec.mode, slot = rec.slot }
end

-- 5 槽列表（index/name/used）。
function Profile.Slots()
    local p = store()
    local list = {}
    for i = 1, SLOT_COUNT do
        local slot = p and p.slots[i]
        list[i] = {
            index = i,
            name = type(slot) == "table" and slot.name or ("Slot " .. i),
            used = type(slot) == "table",
        }
    end
    return list
end

-- 使用共享槽（持续关联）：原独立档保留（D10）；槽不存在则创建。
function Profile.UseSlot(index)
    local p = store()
    if not p then return false end
    if type(index) ~= "number" or index < 1 or index > SLOT_COUNT or index % 1 ~= 0 then
        return false
    end
    if type(p.slots[index]) ~= "table" then
        p.slots[index] = { name = "Slot " .. index, config = {} }
    end
    if type(p.slots[index].config) ~= "table" then
        p.slots[index].config = {}
    end
    local rec = record()
    rec.mode = "slot"
    rec.slot = index
    return true
end

-- 解除关联（D10）：{ copy = true } 时复制槽当前配置为独立档；否则保留原独立档。
function Profile.UseIndependent(opts)
    local p = store()
    if not p then return false end
    local rec = record()
    if type(opts) == "table" and opts.copy and rec.mode == "slot" then
        local slot = rec.slot and p.slots[rec.slot]
        if type(slot) == "table" and type(slot.config) == "table" then
            rec.independent = deepCopy(slot.config)
        end
    end
    rec.mode = "independent"
    rec.slot = nil
    return true
end

-- 删除槽：全部关联角色（含未登录角色的记录）各留删除前副本并解除关联（D09）。
function Profile.DeleteSlot(index)
    local p = store()
    if not p then return false end
    local slot = p.slots[index]
    if type(slot) ~= "table" then return false end
    for _, rec in pairs(p.chars) do
        if rec.mode == "slot" and rec.slot == index then
            rec.independent = deepCopy(slot.config or {})
            rec.mode = "independent"
            rec.slot = nil
        end
    end
    p.slots[index] = nil
    return true
end

OpenUI.Profile = Profile

OpenUI:RegisterModule("Profile", {
    OnInitialize = function()
        migrate()
    end,
})