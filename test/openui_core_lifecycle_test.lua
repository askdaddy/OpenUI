-- OpenUI 核心生命周期黑盒测试（Issue #6 plan 步骤 1–4 + 修订 v2 冻结验收，QA 独立编写）。
-- 以 WoW API 桩模拟客户端边界（可控 C_Timer / InCombatLockdown / 事件帧），按 TOC 次序加载后断言；
-- 不读游戏客户端、不修改业务代码。
-- 运行：lua test/openui_core_lifecycle_test.lua（仓库任意位置可执行）

local HERE = (arg[0]:match("^(.*)[/\\]") or ".")
local ADDON = HERE .. "/.." -- 包根即仓库根（D54）

local ns = {}
local output = {} -- print 捕获
local passCount, failCount = 0, 0
local failures = {}

-- ==== WoW 环境桩（与既有测试同型；新增可控 C_Timer / 双帧捕获） ====
function print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    output[#output + 1] = table.concat(parts, " ")
end

function strtrim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function GetAddOnMetadata(name, field)
    if name == "OpenUI" and field == "Version" then
        return "2026.11.0-dev.1"
    end
end

function GetLocale()
    return "enUS"
end

local frames = {} -- 按创建次序捕获：[1]=Core 生命周期帧，[2]=Resources 共享帧
local function mkframe(frameType)
    local f = { frameType = frameType, registered = {}, unregistered = {}, scripts = {} }
    function f:RegisterEvent(ev) self.registered[ev] = true end
    function f:UnregisterEvent(ev) self.unregistered[ev] = true; self.registered[ev] = nil end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    table.insert(frames, f)
    return f
end
function CreateFrame(frameType) return mkframe(frameType) end

SlashCmdList = {}

-- 可控时钟：NewTicker 返回带 Tick 的句柄；tickAll() 推进一轮
C_Timer = { tickers = {} }
function C_Timer.NewTicker(interval, fn)
    local t = { interval = interval, fn = fn, cancelled = false }
    function t:Cancel() self.cancelled = true end
    function t:Tick() if not self.cancelled then self.fn() end end
    table.insert(C_Timer.tickers, t)
    return t
end
local function tickAll()
    local snapshot = {}
    for i, t in ipairs(C_Timer.tickers) do snapshot[i] = t end
    for _, t in ipairs(snapshot) do t:Tick() end
end

-- ==== 断言工具 ====
local function check(cond, label)
    if cond then
        passCount = passCount + 1
    else
        failCount = failCount + 1
        failures[#failures + 1] = label
    end
    io.write(("  [%s] %s\n"):format(cond and "PASS" or "FAIL", label))
end

local function diagnoseHas(fragment)
    for _, e in ipairs(ns.OpenUI.Diagnose.Errors()) do
        if e:find(fragment, 1, true) then return true end
    end
    return false
end

-- ==== 按 TOC 次序加载插件文件（含 Resources.lua） ====
local order = {
    "Init.lua",
    "Locales/enUS.lua",
    "Locales/zhCN.lua",
    "Config/Defaults.lua",
    "Core/Core.lua",
    "Core/Resources.lua",
    "Core/Slash.lua",
    "Locales/Manager.lua",
    "UI/Theme.lua",
}
for _, file in ipairs(order) do
    local chunk = assert(loadfile(("%s/%s"):format(ADDON, file)))
    chunk("OpenUI", ns)
end

local OpenUI = ns.OpenUI
local coreFrame, resFrame = frames[1], frames[2]

print("== S1 启停配置与默认组合解析（步骤 1 + 修订 v2）==")
local m = OpenUI.Config.MergeDefaults(nil)
check(type(m.modules) == "table" and type(m.modules.enabled) == "table", "MergeDefaults(nil) 含 modules.enabled")
local u = OpenUI.Config.MergeDefaults({ configVersion = 1, modules = { enabled = { Theme = false } } })
check(u.modules.enabled.Theme == false, "用户 modules.enabled 值合并后保留")
_G.OpenUIDB = OpenUI.Config.MergeDefaults(nil)
check(OpenUI:IsModuleEnabled("Theme") and OpenUI:IsModuleEnabled("Locale"), "注册缺省默认启用（Theme/Locale）")
check(OpenUI:IsModuleEnabled("Core") == true, "Core 恒开")
_G.OpenUIDB.modules.enabled.Core = false
check(OpenUI:IsModuleEnabled("Core") == true, "Core 无视 DB false")
_G.OpenUIDB.modules.enabled.Core = nil
check(OpenUI:IsModuleEnabled("Nope") == false, "未注册名视为关")
OpenUI:RegisterModule("DeclaredOff", { defaultEnabled = false, OnEnable = function() end })
check(OpenUI:IsModuleEnabled("DeclaredOff") == false, "注册声明 defaultEnabled=false 判关（修订 v2）")
_G.OpenUIDB.modules.enabled.DeclaredOff = true
check(OpenUI:IsModuleEnabled("DeclaredOff") == true, "DB 显式 true 覆盖注册声明")
_G.OpenUIDB.modules.enabled.DeclaredOff = nil
_G.OpenUIDB.modules.enabled.Theme = false
check(OpenUI:IsModuleEnabled("Theme") == false, "DB 显式 false 覆盖默认")
_G.OpenUIDB.modules.enabled.Theme = nil

print("== S2 生命周期筛选与启停状态机（步骤 2）==")
local seq = {}
OpenUI:RegisterModule("ProbeOn", {
    OnInitialize = function() seq[#seq + 1] = "O-init" end,
    OnEnable = function() seq[#seq + 1] = "O-enable" end,
    OnDisable = function() seq[#seq + 1] = "O-disable" end,
})
OpenUI:RegisterModule("ProbeOff", {
    defaultEnabled = false,
    OnEnable = function() seq[#seq + 1] = "F-enable" end,
})
-- 预置 Theme=false + theme 定制 0.7：被禁模块的 OnInitialize 应跳过（定制不生效）
_G.OpenUIDB = OpenUI.Config.MergeDefaults({
    theme = { ["opacity.panel"] = 0.7 },
    modules = { enabled = { Theme = false } },
})
seq = {}
coreFrame.scripts.OnEvent(coreFrame, "ADDON_LOADED", "OpenUI")
coreFrame.scripts.OnEvent(coreFrame, "PLAYER_LOGIN")
check(table.concat(seq, ",") == "O-init,O-enable",
    "仅启用模块执行生命周期（声明关的跳过）: " .. table.concat(seq, ","))
check(OpenUI.Theme.Get("opacity.panel") == 0.95, "被禁 Theme 的 OnInitialize 未应用 DB 定制")
-- Enable：Core 拒绝 / 未注册报错 / 补初始化 / 幂等
check(OpenUI:EnableModule("Core") == false, "Enable Core 被拒")
local ok, err = pcall(function() return OpenUI:EnableModule("Ghost") end)
check(not ok and tostring(err):find("Ghost", 1, true) ~= nil, "Enable 未注册名报错")
local themeInitCalls = 0
local themeModule = OpenUI:GetModule("Theme")
local origInit = themeModule.OnInitialize
themeModule.OnInitialize = function() themeInitCalls = themeInitCalls + 1 end
check(OpenUI:EnableModule("Theme") == true and themeInitCalls == 1, "Enable 被禁模块补 OnInitialize 一次")
themeModule.OnInitialize = origInit
check(_G.OpenUIDB.modules.enabled.Theme == true, "Enable 写入 DB")
check(OpenUI:EnableModule("Theme") == true and themeInitCalls == 1, "重复 Enable 幂等（不再初始化）")
-- Disable：回调一次 + DB + 幂等
check(OpenUI:DisableModule("ProbeOn") == true and seq[#seq] == "O-disable", "Disable 调用 OnDisable")
check(OpenUI:DisableModule("ProbeOn") == true and seq[#seq] == "O-disable", "重复 Disable 幂等")
check(_G.OpenUIDB.modules.enabled.ProbeOn == false, "Disable 写入 DB")
-- 回调错误隔离：状态翻转 + 诊断 + 他模块不受影响
OpenUI:RegisterModule("EvilCb", {
    defaultEnabled = false,
    OnEnable = function() error("boom-enable") end,
    OnDisable = function() error("boom-disable") end,
})
check(OpenUI:EnableModule("EvilCb") == true and OpenUI:IsModuleEnabled("EvilCb") == true,
    "OnEnable 抛错：状态仍正确翻转")
check(diagnoseHas("EvilCb") and diagnoseHas("boom-enable"), "OnEnable 异常进诊断队列")
check(OpenUI:DisableModule("EvilCb") == true and OpenUI:IsModuleEnabled("EvilCb") == false,
    "OnDisable 抛错：禁用状态仍成立")
check(diagnoseHas("boom-disable"), "OnDisable 异常进诊断队列")
check(OpenUI:EnableModule("ProbeOn") == true and seq[#seq] == "O-enable",
    "异常不影响其他模块启停")

print("== S3 资源调度器（步骤 3）==")
OpenUI:RegisterModule("ResA", { defaultEnabled = false })
OpenUI:RegisterModule("ResErr", { defaultEnabled = false })
OpenUI:EnableModule("ResA")
OpenUI:EnableModule("ResErr")
local hits = {}
local ownA = OpenUI.Own("ResA")
local ownErr = OpenUI.Own("ResErr")
ownA:On("QA_EVT", function(arg) hits[#hits + 1] = "A:" .. tostring(arg) end)
ownErr:On("QA_EVT", function(arg) hits[#hits + 1] = "E:" .. tostring(arg) error("handler-boom") end)
check(resFrame.registered["QA_EVT"] ~= nil, "登记后共享帧注册事件")
resFrame.scripts.OnEvent(resFrame, "QA_EVT", "x")
check(#hits == 2 and hits[1] == "A:x" and hits[2] == "E:x", "两模块按登记序派发")
check(diagnoseHas("handler-boom") and diagnoseHas("QA_EVT"), "handler 抛错隔离并进诊断")
OpenUI:DisableModule("ResErr")
hits = {}
resFrame.scripts.OnEvent(resFrame, "QA_EVT", "y")
check(#hits == 1 and hits[1] == "A:y", "被禁模块不再派发、其他模块照常")
local once, every = 0, 0
ownA:After(1, function() once = once + 1 end)
ownA:Every(1, function() every = every + 1 end)
OpenUI:DisableModule("ResA")
tickAll()
check(once == 0 and every == 0, "禁用后 After/Every 均不再触发")
OpenUI:EnableModule("ResA")
ownA = OpenUI.Own("ResA")
ownA:After(1, function() once = once + 1 end)
ownA:Every(1, function() every = every + 1 end)
tickAll(); tickAll(); tickAll()
check(once == 1, "After 恰好回调一次（实际 " .. once .. "）")
check(every == 3, "Every 按轮次重复回调（实际 " .. every .. "）")
ownA:On("LAST_EVT", function() end)
check(resFrame.registered["LAST_EVT"] ~= nil, "LAST_EVT 已注册")
OpenUI:DisableModule("ResA")
check(resFrame.unregistered["LAST_EVT"] ~= nil and resFrame.registered["LAST_EVT"] == nil,
    "末位 owner 释放后事件反注册")

print("== S4 战斗锁定适配（步骤 4）==")
check(OpenUI:CanModifyNow() == true, "非战斗 CanModifyNow=true")
function InCombatLockdown() return true end
check(OpenUI:CanModifyNow() == false, "战斗中 CanModifyNow=false")
OpenUI:RegisterModule("CombatM", {
    defaultEnabled = false,
    OnEnable = function() seq[#seq + 1] = "C-on" end,
    OnDisable = function() seq[#seq + 1] = "C-off" end,
})
check(OpenUI:EnableModule("CombatM") == false, "战斗中 Enable 返回 false（登记意图）")
check(OpenUI:IsModuleEnabled("CombatM") == false and _G.OpenUIDB.modules.enabled.CombatM == nil,
    "战斗中未生效、DB 未写")
check(OpenUI:DisableModule("CombatM") == true, "对已禁用模块战斗中 Disable 幂等返回 true")
OpenUI:EnableModule("CombatM")  -- 意图：启用
OpenUI:DisableModule("CombatM") -- 意图：禁用（幂等路径取消挂起启用）
InCombatLockdown = nil
check(OpenUI:CanModifyNow() == true, "InCombatLockdown 缺失时保守 true")
resFrame.scripts.OnEvent(resFrame, "PLAYER_REGEN_ENABLED")
check(OpenUI:IsModuleEnabled("CombatM") == false and _G.OpenUIDB.modules.enabled.CombatM ~= true,
    "最新意图胜：脱战后保持禁用")
function InCombatLockdown() return true end
OpenUI:EnableModule("CombatM")
function InCombatLockdown() return false end
local cBefore = #seq
resFrame.scripts.OnEvent(resFrame, "PLAYER_REGEN_ENABLED")
check(OpenUI:IsModuleEnabled("CombatM") == true and _G.OpenUIDB.modules.enabled.CombatM == true,
    "挂起启用脱战后应用并写 DB")
check(seq[#seq] == "C-on" and #seq == cBefore + 1, "脱战应用恰好触发一次 OnEnable")

print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do
        io.stderr:write("FAIL: " .. f .. "\n")
    end
    os.exit(1)
end
os.exit(0)
