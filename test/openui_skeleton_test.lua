-- OpenUI 骨架黑盒测试（Issue #1 冻结计划步骤 4-9 的行为验收）。
-- 以 WoW API 桩模拟客户端边界，按 TOC 次序加载插件文件后做断言；
-- 不读游戏客户端、不修改业务代码。
-- 运行：lua test/openui_skeleton_test.lua（仓库任意位置可执行）

local HERE = (arg[0]:match("^(.*)[/\\]") or ".")
local ADDON = HERE .. "/.." -- 包根即仓库根（D54）

local ns = {}
local output = {} -- print 捕获
local passCount, failCount = 0, 0
local failures = {}

-- ==== WoW 环境桩 ====
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

local frame -- 捕获 Core 创建的事件帧
function CreateFrame(frameType)
    frame = { frameType = frameType, registered = {}, scripts = {} }
    function frame:RegisterEvent(ev)
        self.registered[ev] = true
    end
    function frame:SetScript(name, fn)
        self.scripts[name] = fn
    end
    return frame
end

SlashCmdList = {}

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

-- ==== 按 TOC 次序加载插件文件 ====
local order = {
    "Init.lua",
    "Locales/enUS.lua",
    "Locales/zhCN.lua",
    "Config/Defaults.lua",
    "Core/Core.lua",
    "Core/Slash.lua",
    "UI/Theme.lua",
}
for _, file in ipairs(order) do
    local chunk = assert(loadfile(("%s/%s"):format(ADDON, file)))
    chunk("OpenUI", ns)
end

local OpenUI = ns.OpenUI

print("== T1 命名空间（步骤 4）==")
check(OpenUI ~= nil, "ns.OpenUI 存在")
check(_G.OpenUI == OpenUI, "_G.OpenUI 与命名空间主表恒等")
check(type(OpenUI.modules) == "table" and type(OpenUI.moduleOrder) == "table", "modules/moduleOrder 表存在")

print("== T2 本地化（步骤 5）==")
local L = OpenUI.L
check(type(L.VERSION_LINE) == "string", "enUS 基表含 VERSION_LINE")
check(L.UNKNOWN_KEY_XYZ == "UNKNOWN_KEY_XYZ", "未知 key 返回 key 本身（无异常）")

-- 源码 L 引用覆盖扫描：生产代码引用的每个 key 都必须有 enUS 条目
local missing = {}
for _, sf in ipairs({ "Core/Core.lua", "Core/Slash.lua" }) do
    local f = assert(io.open(("%s/%s"):format(ADDON, sf)))
    local src = f:read("*a")
    f:close()
    for key in src:gmatch("L%.([A-Z_]+)") do
        if type(L[key]) ~= "string" then
            missing[#missing + 1] = sf .. ":" .. key
        end
    end
end
check(#missing == 0, "代码引用的全部 L key 均在 enUS 定义"
    .. (#missing > 0 and "（缺: " .. table.concat(missing, ", ") .. "）" or ""))

print("== T3 配置合并（步骤 6）==")
local merged = OpenUI.Config.MergeDefaults(nil)
check(merged.configVersion == 1, "首次（nil）合并含 configVersion")
check(merged.debug == false, "首次（nil）合并补齐默认 debug")
local user = { configVersion = 1, debug = true, custom = { deep = 7 } }
local m2 = OpenUI.Config.MergeDefaults(user)
check(m2.debug == true and m2.custom.deep == 7, "已有用户值不被默认覆盖")
local m3 = OpenUI.Config.MergeDefaults({})
check(m3.debug == false and m3.configVersion == 1, "缺失字段补默认")

print("== T4 生命周期与错误隔离（步骤 7/8）==")
check(OpenUI.modules.Core ~= nil, "Core 自注册为模块")
local seq = {}
OpenUI:RegisterModule("Alpha", {
    OnInitialize = function() seq[#seq + 1] = "A-init" end,
    OnEnable = function() seq[#seq + 1] = "A-enable" end,
    OnDisable = function() seq[#seq + 1] = "A-disable" end,
})
OpenUI:RegisterModule("Beta", {
    OnInitialize = function() seq[#seq + 1] = "B-init" end,
    OnEnable = function() seq[#seq + 1] = "B-enable" end,
})

-- /openui（错误队列为空时）
output = {}
SlashCmdList.OPENUI("")
local cmd1 = table.concat(output, " | ")
check(SLASH_OPENUI1 == "/openui", "slash 命令注册为 /openui")
check(cmd1:find("OpenUI", 1, true) ~= nil, "/openui 输出含 OpenUI")
check(cmd1:find("2026.11.0-dev.1", 1, true) ~= nil, "/openui 输出含版本串")
check(cmd1:find("Core", 1, true) ~= nil, "/openui 输出含模块名 Core")
output = {}
SlashCmdList.OPENUI("errors")
local cmd2 = table.concat(output, " | ")
check(cmd2:find(L.NO_ERRORS, 1, true) ~= nil, "/openui errors 空队列输出提示文案")

-- ADDON_LOADED / PLAYER_LOGIN 生命周期
frame.scripts.OnEvent(frame, "ADDON_LOADED", "OpenUI")
check(_G.OpenUIDB ~= nil and _G.OpenUIDB.configVersion == 1, "ADDON_LOADED 后 OpenUIDB 已合并默认")
frame.scripts.OnEvent(frame, "PLAYER_LOGIN")
check(table.concat(seq, ",") == "A-init,B-init,A-enable,B-enable",
    "OnInitialize/OnEnable 按注册顺序执行: " .. table.concat(seq, ","))

-- 重复注册拒绝
local ok, err = pcall(OpenUI.RegisterModule, OpenUI, "Alpha")
check(not ok and tostring(err):find("Alpha", 1, true) ~= nil, "重复注册被拒且信息含模块名")

-- 错误隔离：Evil 抛错不阻断 Alpha/Beta
OpenUI:RegisterModule("Evil", {
    OnEnable = function() error("boom-intentional") end,
})
seq = {}
frame.scripts.OnEvent(frame, "PLAYER_LOGIN")
local hasEvil = false
for _, e in ipairs(OpenUI.Diagnose.Errors()) do
    if e:find("Evil", 1, true) and e:find("boom-intentional", 1, true) then
        hasEvil = true
    end
end
check(hasEvil, "回调异常进入诊断队列（含模块名与错误信息）")
check(#seq == 2, "异常不中断其余模块（Alpha/Beta 仍执行 2 项）")

-- DisableModule
OpenUI:DisableModule("Alpha")
check(seq[#seq] == "A-disable", "DisableModule 调用 OnDisable")

-- 错误入队后 /openui errors
output = {}
SlashCmdList.OPENUI("errors")
local cmd3 = table.concat(output, " | ")
check(cmd3:find("Evil", 1, true) ~= nil and cmd3:find("boom-intentional", 1, true) ~= nil,
    "/openui errors 列出已记录错误")

print("== T5 主题挂点（步骤 9）==")
check(OpenUI.Theme.GetColor("bg") == OpenUI.Theme.colors.bg, "GetColor 返回预定义值")
check(OpenUI.Theme.GetColor("nonexistent") == nil, "未定义颜色返回 nil 无异常")
check(OpenUI.Theme.GetFont("normal") == "GameFontNormal", "GetFont 返回字体名")
check(OpenUI.Theme.GetFont("nonexistent") == nil, "未定义字体返回 nil 无异常")

print("== T6 zhCN 覆盖与回退（步骤 5.2）==")
L.TEST_FALLBACK = "fallback-value" -- 测试注入的未覆盖 key
function GetLocale()
    return "zhCN"
    end
assert(loadfile(ADDON .. "/Locales/zhCN.lua"))("OpenUI", ns)
check(L.VERSION_LINE ~= "OpenUI %s loaded." and L.VERSION_LINE:find("已加载", 1, true) ~= nil,
    "zhCN 环境下已覆盖 key 为中文")
check(L.TEST_FALLBACK == "fallback-value", "zhCN 未覆盖 key 保留 enUS 值")

print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do
        io.stderr:write("FAIL: " .. f .. "\n")
    end
    os.exit(1)
end
os.exit(0)
