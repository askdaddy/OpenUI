-- OpenUI 本地化模块黑盒测试（Issue #4 plan 步骤 1–3 冻结验收 + 翻译完整性检查，QA 独立编写）。
-- 以 WoW API 桩模拟客户端边界，按 TOC 次序加载插件文件后断言；
-- 不读游戏客户端、不修改业务代码。
-- 运行：lua test/openui_locale_test.lua（仓库任意位置可执行）

local HERE = (arg[0]:match("^(.*)[/\\]") or ".")
local ADDON = HERE .. "/.." -- 包根即仓库根（D54）

local ns = {}
local output = {} -- print 捕获
local passCount, failCount = 0, 0
local failures = {}

-- ==== WoW 环境桩（与 openui_skeleton_test.lua 同型） ====
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

local frame
function CreateFrame(frameType)
    frame = { frameType = frameType, registered = {}, scripts = {} }
    function frame:RegisterEvent(ev) self.registered[ev] = true end
    function frame:SetScript(name, fn) self.scripts[name] = fn end
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

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function diagnoseHas(fragment)
    for _, e in ipairs(ns.OpenUI.Diagnose.Errors()) do
        if e:find(fragment, 1, true) then return true end
    end
    return false
end

-- ==== 按 TOC 次序加载插件文件（含 Manager.lua） ====
local order = {
    "Init.lua",
    "Locales/enUS.lua",
    "Locales/zhCN.lua",
    "Config/Defaults.lua",
    "Core/Core.lua",
    "Core/Slash.lua",
    "Locales/Manager.lua",
    "UI/Theme.lua",
}
for _, file in ipairs(order) do
    local chunk = assert(loadfile(("%s/%s"):format(ADDON, file)))
    chunk("OpenUI", ns)
end

local OpenUI = ns.OpenUI
local L = OpenUI.L
local Loc = OpenUI.Locale

print("== S1 资源表与双语文案（步骤 1）==")
check(type(OpenUI.Locales) == "table" and type(OpenUI.Locales.enUS) == "table"
    and type(OpenUI.Locales.zhCN) == "table", "Locales.enUS/zhCN 资源表存在")
check(count(OpenUI.Locales.enUS) == 26, "enUS key 计数 = 26（#8/#10 文案；实际 " .. count(OpenUI.Locales.enUS) .. "）")
check(count(OpenUI.Locales.zhCN) == 26, "zhCN key 计数 = 26（#8/#10 文案；实际 " .. count(OpenUI.Locales.zhCN) .. "）")
check(L.LOCALE_INVALID:find("%%s") ~= nil and L.LOCALE_INVALID:find("Invalid", 1, true) ~= nil,
    "enUS LOCALE_INVALID 为含 %s 的英文串")
local zh = OpenUI.Locales.zhCN
check(zh.LOCALE_INVALID:find("无效", 1, true) ~= nil and zh.LOCALE_INVALID:find("%%s") ~= nil,
    "zhCN LOCALE_INVALID 为含 %s 的中文串")
check(L.MODULES_LINE == "Modules: %s", "enUS 客户端基表英文生效")
check(L.UNKNOWN_KEY_XYZ == "UNKNOWN_KEY_XYZ", "未知 key 回退 key 本身")

print("== S2 Locale 管理器（步骤 2）==")
check(OpenUI.GetModule(OpenUI, "Locale") ~= nil, "Locale 自注册为模块")
local capturedL = OpenUI.L
check(Loc.Get() == "auto", "ADDON_LOADED 前 Get 缺省 auto")
check(Loc.Set("zhCN") == true, "Set(zhCN) 返回 true")
check(L.VERSION_LINE:find("已加载", 1, true) ~= nil and L.MODULES_LINE:find("模块", 1, true) ~= nil,
    "切换 zhCN 即时生效（无需重载）")
check(_G.OpenUIDB ~= nil and _G.OpenUIDB.locale == "zhCN" and Loc.Get() == "zhCN",
    "DB 记录 zhCN 且 Get 同步")
check(Loc.Set("enUS") == true and L.VERSION_LINE == "OpenUI %s loaded."
    and _G.OpenUIDB.locale == "enUS", "切回 enUS 即时生效 + DB 更新")
check(Loc.Set("auto") == true and L.VERSION_LINE == "OpenUI %s loaded."
    and _G.OpenUIDB.locale == "auto", "auto 按客户端解析为英文")
local frozen = L.VERSION_LINE
local errBefore = #OpenUI.Diagnose.Errors()
check(Loc.Set("jp") == false and L.VERSION_LINE == frozen, "非法值 jp 拒绝且 L 不变")
check(Loc.Set("ENUS") == false and L.VERSION_LINE == frozen, "大写 ENUS 拒绝且 L 不变")
check(#OpenUI.Diagnose.Errors() >= errBefore + 2 and diagnoseHas("Locale"),
    "两次软失败进诊断队列（含 Locale 归属）")
check(_G.OpenUIDB.locale == "auto", "非法 Set 不改写 DB")
check(OpenUI.L == capturedL, "L 表身份恒等（消费者引用有效）")
Loc.Set("zhCN")
output = {}
SlashCmdList.OPENUI("")
local cmd = table.concat(output, " | ")
check(cmd:find("模块：", 1, true) ~= nil and cmd:find("Core", 1, true) ~= nil
    and cmd:find("Locale", 1, true) ~= nil and cmd:find("Theme", 1, true) ~= nil,
    "/openui 输出随切换为中文且含 Locale/Theme")
_G.OpenUIDB = { configVersion = 1, locale = "zhCN" }
frame.scripts.OnEvent(frame, "ADDON_LOADED", "OpenUI")
check(L.VERSION_LINE:find("已加载", 1, true) ~= nil, "保存的手动选择经 OnInitialize 生效")
_G.OpenUIDB = { configVersion = 1, locale = "jp" }
frame.scripts.OnEvent(frame, "ADDON_LOADED", "OpenUI")
check(L.VERSION_LINE == "OpenUI %s loaded.", "DB 非法值按 enUS 生效")
check(_G.OpenUIDB.locale == "jp", "DB 非法值不被清洗")
check(diagnoseHas("jp"), "DB 非法值进诊断报告")

print("== S3 配置默认节点（步骤 3）==")
local m = OpenUI.Config.MergeDefaults(nil)
check(m.locale == "auto", "MergeDefaults(nil) 补 locale=auto")
local u = OpenUI.Config.MergeDefaults({ configVersion = 1, locale = "zhCN" })
check(u.locale == "zhCN", "用户 locale 值合并后保留")

print("== S4 翻译完整性检查（spec A3/A4）==")
-- ① zhCN 覆盖表 ⊆ enUS 基表
local orphan = {}
for key in pairs(zh) do
    if OpenUI.Locales.enUS[key] == nil then orphan[#orphan + 1] = key end
end
check(#orphan == 0, "zhCN 键均为 enUS 子集" .. (#orphan > 0 and "（孤儿: " .. table.concat(orphan, ",") .. "）" or ""))
-- ② 占位符（%s/%d/%%）有序序列一致
local function placeholders(s)
    local list = s:gmatch("%%[sd%%]")
    local out, seq = {}, list
    for p in seq do out[#out + 1] = p end
    return table.concat(out, ",")
end
local mismatch = {}
for key, enText in pairs(OpenUI.Locales.enUS) do
    local zhText = zh[key]
    if type(enText) == "string" and type(zhText) == "string"
        and placeholders(enText) ~= placeholders(zhText) then
        mismatch[#mismatch + 1] = key
    end
end
check(#mismatch == 0, "双语占位符序列一致" .. (#mismatch > 0 and "（不一致: " .. table.concat(mismatch, ",") .. "）" or ""))
-- ③ 生产 .lua 全量扫描：L.KEY 引用（排除赋值定义）⊆ enUS 键集
local production = {
    "Init.lua", "Locales/enUS.lua", "Locales/zhCN.lua", "Locales/Manager.lua",
    "Config/Defaults.lua", "Core/Core.lua", "Core/Slash.lua", "UI/Theme.lua",
    "UI/Widgets.lua", "UI/Settings.lua", "UI/Diagnostics.lua",
}
local missingRefs = {}
for _, sf in ipairs(production) do
    local f = assert(io.open(("%s/%s"):format(ADDON, sf)))
    local src = f:read("*a")
    f:close()
    local stripped = src:gsub("L%.([A-Z_]+)%s*=", "") -- 去掉赋值定义形态
    for key in stripped:gmatch("L%.([A-Z_]+)") do
        if OpenUI.Locales.enUS[key] == nil then
            missingRefs[#missingRefs + 1] = sf .. ":" .. key
        end
    end
end
check(#missingRefs == 0, "生产代码 L 引用均在 enUS 定义"
    .. (#missingRefs > 0 and "（缺: " .. table.concat(missingRefs, ", ") .. "）" or ""))

print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do
        io.stderr:write("FAIL: " .. f .. "\n")
    end
    os.exit(1)
end
os.exit(0)
