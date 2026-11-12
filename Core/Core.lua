-- 核心最小实现（spec C5/C7）：模块注册表 + 三段生命周期 + 错误隔离。
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

function OpenUI:DisableModule(name)
    local module = self:GetModule(name)
    Run(name .. "/OnDisable", module.OnDisable, module)
end

local function callAll(method)
    for _, module in ipairs(OpenUI.moduleOrder) do
        local func = module[method]
        if type(func) == "function" then
            Run(module.name .. "/" .. method, func, module)
        end
    end
end

-- Core 自注册为首个模块，保证 /openui 模块列表非空（验收 7.5）。
OpenUI:RegisterModule("Core")

-- 生命周期：ADDON_LOADED（本插件，SavedVariables 就绪）-> OnInitialize；
-- PLAYER_LOGIN -> OnEnable。
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
