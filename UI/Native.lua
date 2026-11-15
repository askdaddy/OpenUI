-- 原生帧隐藏/恢复共享助手（#13 提取，B1 各界面模块复用）。
-- 记录原 parent 并 reparent 到隐藏宿主；战斗中登记、PLAYER_REGEN_ENABLED 脱战应用；
-- 每模块独立记账，恢复幂等。

local _, ns = ...
local OpenUI = ns.OpenUI

local Native = {}
local hider
local records = {} -- 模块名 -> { [帧名] = { frame = 帧, parent = 原 parent } }
local pendingHide = {} -- 模块名 -> true（战斗中待应用）
local pendingRestore = {} -- 模块名 -> true
local listening = false

local function ensureHider()
    if hider then return hider end
    hider = CreateFrame("Frame", "OpenUINativeHider", UIParent)
    hider:Hide()
    return hider
end

local function startListening()
    if listening then return end
    listening = true
    OpenUI.Own("Native"):On("PLAYER_REGEN_ENABLED", function()
        for module in pairs(pendingHide) do
            Native.ApplyHide(module)
        end
        for module in pairs(pendingRestore) do
            Native.ApplyRestore(module)
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

-- 隐藏（脱战立即，战斗中登记脱战后应用）
function Native.Hide(module, names)
    local record = records[module]
    if not record then
        record = {}
        for _, entry in ipairs(namesToFrames(names)) do
            record[entry.name] = {
                frame = entry.frame,
                parent = (type(entry.frame.GetParent) == "function" and entry.frame:GetParent()) or nil,
            }
        end
        records[module] = record
    end
    if not OpenUI:CanModifyNow() then
        pendingHide[module] = true
        pendingRestore[module] = nil
        startListening()
        return false
    end
    return Native.ApplyHide(module)
end

function Native.ApplyHide(module)
    local record = records[module]
    if not record then return false end
    pendingHide[module] = nil
    if not OpenUI:CanModifyNow() then
        pendingHide[module] = true
        startListening()
        return false
    end
    local hiderFrame = ensureHider()
    for _, entry in pairs(record) do
        entry.frame:SetParent(hiderFrame)
        if entry.frame.Hide then entry.frame:Hide() end
    end
    return true
end

-- 恢复原 parent 并显示（脱战应用同上）
function Native.Restore(module)
    if not records[module] then return true end
    if not OpenUI:CanModifyNow() then
        pendingRestore[module] = true
        pendingHide[module] = nil
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
        startListening()
        return false
    end
    for _, entry in pairs(record) do
        entry.frame:SetParent(entry.parent or UIParent)
        if entry.frame.Show then entry.frame:Show() end
    end
    records[module] = nil
    return true
end

OpenUI.Native = Native