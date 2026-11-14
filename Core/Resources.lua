-- 模块资源调度器（#6 / design 方案 A）：共享事件帧按 owner 派发 + 定时器记账，
-- DisableModule 自动释放（Release 先于 OnDisable 回调）。
-- 契约（spec A3）：模块经 own:On/After/Every 持有的资源由核心跟踪；
-- 绕过本接口自建帧/定时器的资源不在跟踪范围（靠模块规范自律）。

local _, ns = ...
local OpenUI = ns.OpenUI

local registry = {} -- event -> { { module = 注册名, handler = fn }, ... }
local timers = {}   -- 注册名 -> { 句柄, ... }
local registered = {} -- event -> true（共享帧当前是否注册了该事件）

local frame = CreateFrame("Frame")

local function refreshRegistration(event)
    local entries = registry[event]
    local has = entries ~= nil and #entries > 0
    if has and not registered[event] then
        frame:RegisterEvent(event)
        registered[event] = true
    elseif not has and registered[event] then
        frame:UnregisterEvent(event)
        registered[event] = nil
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    local entries = registry[event]
    if not entries then return end
    -- 快照迭代：允许派发过程中增删登记
    local snapshot = {}
    for i = 1, #entries do snapshot[i] = entries[i] end
    for i = 1, #snapshot do
        local entry = snapshot[i]
        OpenUI.Run(entry.module .. "/" .. event, entry.handler, ...)
    end
end)

local Own = {}
Own.__index = Own

-- 登记事件监听：关闭模块时随 Release 自动移除。
function Own:On(event, handler)
    local entries = registry[event]
    if not entries then entries = {}; registry[event] = entries end
    entries[#entries + 1] = { module = self.name, handler = handler }
    refreshRegistration(event)
end

-- 一次性定时（可取消）：经 NewTicker 自取消实现，统一句柄模型。
function Own:After(seconds, func)
    local handle
    handle = C_Timer.NewTicker(seconds, function()
        handle:Cancel()
        func()
    end)
    return self:track(handle)
end

-- 周期定时（可取消）。
function Own:Every(interval, func)
    return self:track(C_Timer.NewTicker(interval, func))
end

function Own:track(handle)
    local list = timers[self.name]
    if not list then list = {}; timers[self.name] = list end
    list[#list + 1] = handle
    return handle
end

-- 获取模块资源上下文：local own = OpenUI.Own("MyModule")
function OpenUI.Own(name)
    return setmetatable({ name = name }, Own)
end

-- 释放模块名下全部资源（DisableModule 自动调用；幂等）。
function OpenUI.Release(name)
    for event, entries in pairs(registry) do
        local kept = {}
        for i = 1, #entries do
            if entries[i].module ~= name then kept[#kept + 1] = entries[i] end
        end
        registry[event] = kept
        refreshRegistration(event)
    end
    local list = timers[name]
    if list then
        for i = 1, #list do
            local handle = list[i]
            if type(handle) == "table" and type(handle.Cancel) == "function" then
                handle:Cancel()
            end
        end
        timers[name] = nil
    end
end

-- 战斗意图队列应用：核心自有事件（Core 不可禁用，监听常驻）。
OpenUI.Own("Core"):On("PLAYER_REGEN_ENABLED", function()
    OpenUI.ApplyPendingSwitches()
end)
