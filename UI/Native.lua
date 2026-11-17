-- 原生帧隐藏/恢复共享助手（#13 提取，#49 升级）。
-- 记录模块声明的帧名清单（含尚未加载的帧）；ADDON_LOADED / PLAYER_ENTERING_WORLD / 脱战
-- 自动重应用——延迟加载的原生帧出现即隐藏。每模块独立记账，恢复幂等。
-- OpenUI 模块开启时对应系统 UI 隐藏；关停只恢复自己的原生帧。

local _, ns = ...
local OpenUI = ns.OpenUI

local Native = {}
local hider
local records = {}        -- 模块名 -> { names = {…}, frames = { [帧名] = { frame, parent } } }
local pendingRestore = {} -- 模块名 -> true（战斗中待恢复）
local listening = false

local function ensureHider()
    if hider then return hider end
    hider = CreateFrame("Frame", "OpenUINativeHider", UIParent)
    hider:Hide()
    return hider
end

-- #70（ForeverUI 实证策略）：受保护帧 / EditMode 管理帧绝不 Hide 或换父——
-- 其 OnHide 会污染 Edit Mode 管理表（Forever 布局 pass 崩溃）。改为就地淡化 + 禁鼠标。
local function isProtectedOrManaged(frame)
    if frame.isManagedFrame == true then return true end
    if type(frame.IsProtected) == "function" then
        local ok, protected = pcall(function() return frame:IsProtected() end)
        if ok and protected then return true end
    end
    return false
end

local function concealFrame(entry)
    local frame = entry.frame
    if not frame then return end
    if entry.mode ~= "fade" then
        entry.mode = "fade"
        entry.alpha = (type(frame.GetAlpha) == "function" and frame:GetAlpha()) or 1
    end
    pcall(function() frame:SetAlpha(0.0001) end)
    if type(frame.EnableMouse) == "function" then pcall(frame.EnableMouse, frame, false) end
end

local function hideFrame(entry)
    if not entry.frame then return end
    if isProtectedOrManaged(entry.frame) then
        return concealFrame(entry)
    end
    entry.mode = "hidden"
    entry.frame:SetParent(ensureHider())
    if entry.frame.Hide then entry.frame:Hide() end
end

local function attachFrame(module, name)
    local record = records[module]
    if not record then return end
    local frame = _G[name]
    if not frame then return end
    local entry = record.frames[name]
    if not entry then
        entry = {
            frame = frame,
            parent = (type(frame.GetParent) == "function" and frame:GetParent()) or nil,
        }
        record.frames[name] = entry
    elseif entry.frame ~= frame then
        -- 全局帧被替换（重载/替换实现）：更新引用，保留原 parent
        entry.frame = frame
        entry.parent = (type(frame.GetParent) == "function" and frame:GetParent()) or entry.parent
    end
    if not OpenUI:CanModifyNow() then return end -- 战斗中不改变受保护父级
    hideFrame(entry)
end

-- 对全部已登记模块重新应用（新加载的原生帧补隐藏）
local function reapplyAll()
    if not OpenUI:CanModifyNow() then return end
    for module, record in pairs(records) do
        if not pendingRestore[module] then
            for _, name in ipairs(record.names) do
                attachFrame(module, name)
            end
        end
    end
end

local function startListening()
    if listening then return end
    listening = true
    local own = OpenUI.Own("Native")
    own:On("PLAYER_REGEN_ENABLED", function()
        for module in pairs(pendingRestore) do
            Native.ApplyRestore(module)
        end
        reapplyAll()
    end)
    own:On("ADDON_LOADED", function() reapplyAll() end)
    own:On("PLAYER_ENTERING_WORLD", function()
        reapplyAll()
        -- #57：暴雪 UI 在大厅初始化/重挂后可能重新显示动作条——登录后延迟重试
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
            for _, delay in ipairs({ 1, 3, 6 }) do
                C_Timer.After(delay, function()
                    if next(records) ~= nil then reapplyAll() end
                end)
            end
        end
    end)
end

local function namesToFrames(names)
    local list = {}
    for _, name in ipairs(names) do
        local frame = _G[name]
        if frame then list[#list + 1] = { name = name, frame = frame } end
    end
    return list
end

-- 隐藏（脱战立即；战斗中登记脱战后应用；未加载的帧保留名字，出帧即隐藏）
function Native.Hide(module, names)
    local record = records[module]
    if not record or record.restoring then
        record = { names = names or {}, frames = {} }
        records[module] = record
    else
        record.names = names or record.names
    end
    pendingRestore[module] = nil
    for _, entry in ipairs(namesToFrames(names or {})) do
        local existing = record.frames[entry.name]
        if not existing then
            record.frames[entry.name] = {
                frame = entry.frame,
                parent = (type(entry.frame.GetParent) == "function" and entry.frame:GetParent()) or nil,
            }
        elseif existing.frame ~= entry.frame then
            existing.frame = entry.frame
            existing.parent = (type(entry.frame.GetParent) == "function" and entry.frame:GetParent()) or existing.parent
        end
    end
    startListening()
    if not OpenUI:CanModifyNow() then
        return false -- 脱战回调里 reapplyAll 会补应用
    end
    for name in pairs(record.frames) do
        attachFrame(module, name)
    end
    return true
end

function Native.ApplyHide(module)
    local record = records[module]
    if not record then return false end
    return Native.Hide(module, record.names)
end

-- 恢复原 parent 并显示（脱战应用同上）
function Native.Restore(module)
    if not records[module] then return true end
    if not OpenUI:CanModifyNow() then
        pendingRestore[module] = true
        startListening()
        return false
    end
    return Native.ApplyRestore(module)
end

function Native.ApplyRestore(module)
    local record = records[module]
    if not record then return true end
    pendingRestore[module] = nil
    if not OpenUI:CanModifyNow() then
        pendingRestore[module] = true
        return false
    end
    for _, entry in pairs(record.frames) do
        if entry.frame then
            if entry.mode == "fade" then
                pcall(function()
                    entry.frame:SetAlpha(entry.alpha or 1)
                    if type(entry.frame.EnableMouse) == "function" then
                        entry.frame:EnableMouse(true)
                    end
                end)
            else
                pcall(function()
                    entry.frame:SetParent(entry.parent or UIParent)
                    if entry.frame.Show then entry.frame:Show() end
                end)
            end
        end
    end
    record.restoring = true
    records[module] = nil
    return true
end

-- 诊断（/openui probe）：各模块已登记/已隐藏帧清单 + 未找到的帧名（帧名不匹配诊断）
function Native.Snapshot()
    local list = {}
    for module, record in pairs(records) do
        local hidden, missing = {}, {}
        for _, name in ipairs(record.names or {}) do
            local entry = record.frames[name]
            if entry then
                hidden[#hidden + 1] = name .. (entry.mode == "fade" and "(fade)" or "(hidden)")
            else
                missing[#missing + 1] = name
            end
        end
        table.sort(hidden)
        table.sort(missing)
        local line = module .. ": hidden=[" .. table.concat(hidden, ",") .. "]"
        if #missing > 0 then
            line = line .. " missing=[" .. table.concat(missing, ",") .. "]"
        end
        list[#list + 1] = line
    end
    table.sort(list)
    return list
end

function Native.IsTracking(module)
    return records[module] ~= nil
end

OpenUI.Native = Native