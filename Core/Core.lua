-- 核心最小实现（spec C5/C7）：模块注册表 + 三段生命周期 + 错误隔离。
-- #6 增量：启停配置驱动生命周期筛选、Enable/Disable 状态机、战斗中意图队列。
-- OnDisable 的契约是"恢复原生界面"；骨架不含界面模块，契约先行。

local _, ns = ...
local OpenUI = ns.OpenUI
local L = OpenUI.L

-- 诊断挂点：有界错误队列，供 /openui errors 输出。
local errors = {}
local MAX_ERRORS = 50

local Diagnose = {}
function Diagnose.Report(owner, message)
    errors[#errors + 1] = tostring(owner) .. ": " .. tostring(message)
    if #errors > MAX_ERRORS then table.remove(errors, 1) end
end
function Diagnose.Errors()
    return errors
end
OpenUI.Diagnose = Diagnose

local function traceback(err)
    return tostring(err) .. "\n" .. (debugstack and debugstack(2) or "")
end

-- 隔离执行：单个回调失败只记录，不中断其余模块（验收 7.2）。
local function Run(owner, func, ...)
    local ok, result = xpcall(func, traceback, ...)
    if not ok then Diagnose.Report(owner, result) end
    return ok, result
end
OpenUI.Run = Run

function OpenUI:RegisterModule(name, defs)
    assert(type(name) == "string" and name ~= "", L.MODULE_INVALID .. tostring(name))
    assert(self.modules[name] == nil, L.MODULE_DUPLICATE .. name)
    local module = defs or {}
    module.name = name
    self.modules[name] = module
    self.moduleOrder[#self.moduleOrder + 1] = module
    return module
end

function OpenUI:GetModule(name)
    local module = self.modules[name]
    if not module then error("module not found: " .. tostring(name), 2) end
    return module
end

-- ==== 启停配置（#6，修订 v2：注册时声明默认值）====
-- 解析顺序：DB 显式值 -> 模块注册时的 defaultEnabled（缺省 true，保持 #1
-- 「注册即参与生命周期」契约）-> 未注册名视为关；Core 恒开不可关。
-- B1+/工具模块注册时声明 defaultEnabled = false（D07「其他默认关闭」）。

local initialized = {}   -- 注册名 -> 是否已执行过 OnInitialize
local pendingSwitches = {} -- 注册名 -> 最新启停意图（战斗中登记，脱战后应用）

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

local function setEnabled(name, value)
    local cfg = activeConfig(true)
    if type(cfg.modules) ~= "table" then cfg.modules = {} end
    if type(cfg.modules.enabled) ~= "table" then cfg.modules.enabled = {} end
    cfg.modules.enabled[name] = value
end

function OpenUI:IsModuleEnabled(name)
    if name == "Core" then return true end
    local module = self.modules[name]
    if not module then return false end
    local cfg = activeConfig(false)
    local enabled = cfg and cfg.modules and cfg.modules.enabled
    local saved = enabled and enabled[name]
    if saved ~= nil then return saved end
    return module.defaultEnabled ~= false
end

-- 战斗锁定查询（#6 Q2）：API 不存在时保守返回 true（行为退化为即时）。
function OpenUI:CanModifyNow()
    if type(InCombatLockdown) == "function" then
        return not InCombatLockdown()
    end
    return true
end

-- 脱战后应用意图队列（由 Resources 的核心自有 PLAYER_REGEN_ENABLED 监听触发）。
function OpenUI.ApplyPendingSwitches()
    for name, want in pairs(pendingSwitches) do
        pendingSwitches[name] = nil
        if want then
            OpenUI:EnableModule(name)
        else
            OpenUI:DisableModule(name)
        end
    end
end

-- 启停状态机：状态先行、回调 Run 隔离（失败只进诊断，状态保持一致）。
function OpenUI:EnableModule(name)
    if name == "Core" then return false end
    local module = self:GetModule(name) -- 未注册名报错
    if self:IsModuleEnabled(name) then
        pendingSwitches[name] = nil -- 最新命令（启用）取消挂起的禁用意图
        return true
    end
    if not self:CanModifyNow() then
        pendingSwitches[name] = true
        return false
    end
    setEnabled(name, true)
    if not initialized[name] then
        initialized[name] = true
        Run(name .. "/OnInitialize", module.OnInitialize, module)
    end
    Run(name .. "/OnEnable", module.OnEnable, module)
    return true
end

function OpenUI:DisableModule(name)
    if name == "Core" then return false end
    local module = self:GetModule(name)
    if not self:IsModuleEnabled(name) then
        pendingSwitches[name] = nil -- 最新命令（禁用）取消挂起的启用意图
        return true
    end
    if not self:CanModifyNow() then
        pendingSwitches[name] = false
        return false
    end
    setEnabled(name, false)
    if OpenUI.Release then OpenUI.Release(name) end -- 先释放资源，再回调（#6 design 边界 7）
    Run(name .. "/OnDisable", module.OnDisable, module)
    return true
end

local function callAll(method)
    for _, module in ipairs(OpenUI.moduleOrder) do
        if OpenUI:IsModuleEnabled(module.name) then
            if method == "OnInitialize" then
                initialized[module.name] = true
            end
            local func = module[method]
            if type(func) == "function" then
                Run(module.name .. "/" .. method, func, module)
            end
        end
    end
end

-- Core 自注册为首个模块，保证 /openui 模块列表非空（验收 7.5）。
OpenUI:RegisterModule("Core")

-- 生命周期：ADDON_LOADED（本插件，SavedVariables 就绪）-> OnInitialize；
-- PLAYER_LOGIN -> OnEnable。仅启用模块参与（#6）。
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName == OpenUI.name then
        OpenUIDB = OpenUI.Config.MergeDefaults(OpenUIDB)
        callAll("OnInitialize")
    elseif event == "PLAYER_LOGIN" then
        callAll("OnEnable")
    end
end)
